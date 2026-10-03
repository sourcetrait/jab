# jab.nu: the Jab SDK's nushell tooling.
#
# As a module (`use jab.nu`) it gives a program's integration test
# `jab launch`, which runs a program headless and can take its screen,
# and the helpers that read a screen: `jab screen`, `jab ink`,
# `jab pixel`, `jab thumbnail`. As a script (`nu jab.nu <command> ...`)
# it builds, runs, and tests the kernel and the programs for the
# justfiles, doing every lookup the workspace defines: the workspace
# directory (the nearest parent holding workspace.jab.toml, or the one
# a program's manifest names from outside any), the
# toolchain (RISCV_TOOLCHAIN, else extern/riscv beside the kernel or
# program, else the workspace's, else the tools on PATH, under the
# official triple or a distribution's name), QEMU (extern/qemu beside
# the program, else the workspace's, else qemu-system-riscv64 on PATH),
# the target (.target in the workspace, else beside the kernel or
# program), and the manifests.
#
# A build is described by its symbols: `--set debug,stats` names them,
# comma separated, in any case, and each reaches the assembler as
# `--defsym NAME=1` for `.ifdef NAME` to read, in the kernel and the
# programs alike. DEBUG picks the debug tree, .target/debug, and every
# other build lands in .target/release, so the two coexist. `test`
# always sets DEBUG, so a program's own debug reporting is there for its
# test; `run` and `build` are release unless asked otherwise. The API,
# a port between the program and the host, is not a build symbol: every
# kernel carries it, and `--api` on a run (or `jab launch --api`) puts
# the port on the machine, off by default, so one build runs either
# way. A build is skipped when its output is newer than every input and
# the flags, symbols included, match the last build.

# The riscv64 binutils prefixes: the official toolchain's triple first,
# then the names distributions package the tools under.
const triples = [
    "riscv64-unknown-linux-gnu-" "riscv64-linux-gnu-"
    "riscv64-unknown-elf-" "riscv64-elf-"
]
# The window's base (jab.inc): the kernel's 2 MiB and the framebuffer's
# 8 MiB come first, and the program has the rest of the machine's 4 GiB.
const program_base = "0x80a00000"
const memory = ["-m" "4G"]
# virt's map has this many virtio-mmio transports, a hard ceiling on
# the devices a line can carry.
const transport_limit = 8
# The QEMU every machine runs on, by its binary's name.
const qemu_name = "qemu-system-riscv64"
# RVA23 is the profile Jab pins, so everything it mandates is on whether
# or not Jab itself uses it; the supervisor profile is the one carrying
# an MMU mode and the supervisor timer the frame clock needs. RVA23 says
# nothing about machine mode, so QEMU's model of it has no physical
# memory protection at all, and the kernel enters in machine mode and
# opens PMP before it has a trap vector: without `pmp=true` that write
# is an illegal instruction which traps to address zero and spins there
# forever. It is the one CPU a machine runs: QEMU carries it from 9.2,
# and a QEMU without it is refused rather than run on another model.
const cpu_profile = "rva23s64,pmp=true"
# The assembler takes the same profile, so the source may use whatever
# the CPU carries: the user profile for a program, which runs in U-mode,
# and the supervisor profile for the kernel.
const march_program = "-march=rva23u64"
const march_kernel = "-march=rva23s64"
# No parallel port: QEMU's default is a text console of its own, which
# under SDL is a second, hidden window with its own GL context, drawn
# on every refresh its cursor blinks.
const machine_rest = [
    "-accel" "tcg" "-smp" "4"
    "-global" "virtio-mmio.force-legacy=false"
    "-parallel" "none"
]

# The QEMU a machine runs on: an extern when there is one, else PATH.
# `extern/qemu` is a QEMU install, the binary under its `bin/` or at its
# top, where the Windows installer puts it, looked for as the
# toolchain's `extern/riscv` is, beside `here` (the program) and then in
# the workspace; one that holds no binary is an error rather than a
# quiet fall to PATH, since a run on another QEMU is what the link is
# there to prevent. With no extern, the name, for PATH.
def qemu-binary [here: path, workspace: oneof<string, nothing>]: nothing -> string {
    let places = (if $workspace == null { [$here] } else { [$here $workspace] })
    let file = (exe-name $qemu_name)
    for place in $places {
        let prefix = ($place | path join "extern" "qemu")
        if ($prefix | path type) != null {
            let found = ([($prefix | path join "bin" $file) ($prefix | path join $file)] | where {|b| $b | path exists })
            if ($found | is-empty) {
                error make {msg: $"($prefix) holds no ($file), in bin/ or at its top: link extern/qemu to a QEMU install"}
            }
            return ($found | first)
        }
    }
    $qemu_name
}

# An executable's file name on this host: `<name>.exe` on Windows, which
# a path checked for the file has to name whole.
def exe-name [name: string]: nothing -> string {
    if $nu.os-info.name == "windows" { $name + ".exe" } else { $name }
}

# Where a launch looks for extern/qemu before the workspace, as a run
# does: the directory of the program a built image came from. A member's
# image lies under the workspace's .target at the member's path, any
# other program's under the program's own .target, and an image under no
# .target is taken to sit beside its program.
def image-home [image: path]: nothing -> string {
    let parts = ($image | path expand | path split)
    let marks = ($parts | enumerate | where item == ".target" | get index)
    if ($marks | is-empty) { return ($image | path expand | path dirname) }
    let mark = ($marks | last)
    let base = ($parts | first $mark | path join)
    # past .target: the tree, debug or release, then the program's
    # workspace-relative path or its name, then the image
    let relative = ($parts | skip ($mark + 2) | drop 1)
    if ($relative | is-empty) or not ($base | path join "workspace.jab.toml" | path exists) { return $base }
    let program = ($base | path join ...$relative)
    if (member-of $program $base) { $program } else { $base }
}

# The CPU every machine runs, the RVA23 profile, once the QEMU it runs on
# lists the model; a QEMU that does not is refused with its version.
def cpu-model [qemu: string]: nothing -> string {
    let listed = (^$qemu -cpu help | complete | get stdout | lines | any {|l| ($l | str trim) == "rva23s64" })
    if not $listed {
        let version = (^$qemu --version | complete | get stdout | lines | get -o 0 | default "a QEMU")
        let found = (which $qemu | get -o 0.path | default $qemu)
        error make {msg: $"($version) at ($found) has no rva23s64, the RVA23 CPU every Jab machine runs on\nlink extern/qemu, in the workspace or beside the program, to a QEMU 11 install"}
    }
    $cpu_profile
}

# The machine on `qemu`: virt, the RVA23 CPU, four harts, every
# transport modern.
def machine-args [qemu: string]: nothing -> list<string> {
    ["-machine" "virt" "-cpu" (cpu-model $qemu)] ++ $machine_rest
}
# The guest is named for the program, `jab <program>`, which is what
# QEMU's window shows inside its own prefix, hardcoded in every front
# end (SDL adds the console's index too: `QEMU (jab pad-0)`), and the
# threads are named (CPU 0/TCG and the rest), so a per-thread listing
# reads; on Linux the process is named jab, so `pgrep -x jab` finds it.
# `-name` alone names only the guest, and `process=` is a Linux prctl
# that QEMU refuses to start without elsewhere ("Change of process name
# not supported by your OS"), so the process name is Linux's alone.
def name-args [program: string]: nothing -> list<string> {
    let process = (if $nu.os-info.name == "linux" { ",process=jab" } else { "" })
    ["-name" $"jab ($program)($process),debug-threads=on"]
}
const display_device = ["-device" "virtio-gpu-device,xres=1920,yres=1080"]
const input_devices = [
    "-device" "virtio-keyboard-device"
    "-device" "virtio-tablet-device"
]
# The entropy device, on a run and on a launch alike, since the
# kernel's jab.sys.random draws from it
const rng_device = ["-device" "virtio-rng-device"]
const devices = [
    "-device" "virtio-net-device,netdev=net0" "-netdev" "user,id=net0"
] ++ $rng_device

# The sound device over a host backend: `backend` is an -audiodev
# driver name with any of its own options after it (`pipewire`,
# `coreaudio`, `none`, `wav,path=...`), and the backend runs at the
# kernel's one rate so nothing resamples between them. The device
# carries `streams`, playback and capture by default; a launch's wav
# recorder has no capture voice and QEMU says so on its stderr for a
# device that asks for one, so a launch gives the device playback
# alone, the one stream the kernel drives.
def sound-args [backend: string, --streams: int = 2]: nothing -> list<string> {
    ["-audiodev" $"($backend),id=snd0,out.frequency=48000" "-device" $"virtio-sound-device,audiodev=snd0,streams=($streams)"]
}

# The host's audio backend for a run, from jabdisco's audio record:
# JAB_AUDIO as given is the backend and its options verbatim; no
# output found is `none`, which discards, so a program's sound calls
# still answer; an output found goes to the backend that reaches it,
# the device named: on Linux ALSA's `default`, which is the sound
# server's default sink, the one the record names, through the server's
# ALSA plugin (the pipewire backend dropped the start of a stream and
# the pa backend errored on volume and cut off, both measured on the
# reference host); on macOS coreaudio and on Windows dsound, whose
# default is the system's chosen output, the one the record names.
def audio-plan [found: oneof<record, nothing>]: nothing -> string {
    let forced = ($env.JAB_AUDIO? | default "")
    if $forced != "" { return $forced }
    if $found == null { return "none" }
    match $nu.os-info.name {
        "linux" => "alsa,out.dev=default",
        "macos" => "coreaudio",
        "windows" => "dsound",
        _ => "none",
    }
}

# A headless machine prepared and not run: everything a launch sets up
# before QEMU starts, handed back for whoever runs and drives it, the SDK's
# own `launch` or a harness that plays interactively. `qemu_binary` is the
# QEMU it runs on (qemu-binary, beside the program the image came from and
# then in the workspace, as a run's), `qemu` the whole argument vector
# after it, `env` what the
# process runs under (the evdev shim preloaded when a gamepad rides the
# fifo), and the
# rest the paths: the UART's log, QEMU's guest-error log, the screen a
# screendump lands in, the pid file, the monitor's pipe pair (`<monitor>.in`
# and `.out`), the debug channel's log under DEBUG, the API's `api_in` pipe
# and `api_out` file with `--api`, and the pad: with `--gamepad`, on Linux
# the fifo QEMU reads as the pad, which the driver writes 24-byte
# input_event records into, else (and with `--pad-port`) the pad port's
# `pad_pipe_in` pipe, whose header, `pad_header` as hex, the driver writes
# first. Every stale file of a previous run is removed and the pipes made.
export def plan [
    --kernel: path
    --image: path
    --out: path
    --api
    --disk: path = ""
    --serial: string = "disk0"
    --set: string = ""
    --gamepad
    --pad-port
    --no-kbm
    --sound
]: nothing -> record<qemu_binary: string, qemu: list<string>, env: record, out: string, serial_log: string, qemu_log: string, screen: string, pidfile: string, monitor: string, debug_log: string, api_in: string, api_out: string, pad_fifo: string, pad_pipe_in: string, pad_port: bool, pad_header: string, sound: string, workspace: string> {
    let out = ($out | path expand)
    mkdir $out
    let log = ($out | path join "serial.log")
    let qemu_log = ($out | path join "qemu.log")
    let screen = ($out | path join "screen.ppm")
    let pidfile = ($out | path join "qemu.pid")
    let monitor = ($out | path join "monitor")
    for f in [$log $qemu_log $screen $pidfile ($monitor + ".in") ($monitor + ".out")] {
        if ($f | path exists) { rm $f }
    }
    ^mkfifo ($monitor + ".in") ($monitor + ".out")
    let ws = (workspace-dir ($kernel | path expand) | default (workspace-dir $out))
    let qemu = (qemu-binary (image-home $image) $ws)
    let pad = (pad-attach $gamepad $out $pad_port $ws)
    let ports = (ports (symbols $set) $out $api $pad.port)
    let inputs = (if $no_kbm { [] } else { $input_devices })
    let wav = (if $sound { $out | path join "sound.wav" } else { "" })
    if $wav != "" and ($wav | path exists) { rm $wav }
    let audio = (if $sound { sound-args $"wav,path=($wav)" --streams 1 } else { [] })
    let args = ((machine-args $qemu) ++ (name-args ($image | path parse | get stem)) ++ $memory ++ $display_device ++ $inputs ++ $rng_device ++ $audio ++ $ports.args ++ $pad.args ++ [
        "-bios" "none" "-kernel" ($kernel | path expand)
        "-device" $"loader,file=($image | path expand),addr=($program_base),force-raw=on"
        "-display" "none" "-monitor" $"pipe:($monitor)" "-serial" $"file:($log)"
        "-pidfile" $pidfile "-d" "guest_errors" "-D" $qemu_log
    ] ++ (disks-args (machine-disks $disk $serial true $ws)))
    {
        qemu_binary: $qemu,
        qemu: $args,
        env: $pad.env,
        out: $out,
        serial_log: $log,
        qemu_log: $qemu_log,
        screen: $screen,
        pidfile: $pidfile,
        monitor: $monitor,
        debug_log: $ports.debug_log,
        api_in: (if $ports.api_pipe == "" { "" } else { $ports.api_pipe + ".in" }),
        api_out: (if $ports.api_pipe == "" { "" } else { $ports.api_pipe + ".out" }),
        pad_fifo: $pad.fifo,
        pad_pipe_in: (if $ports.pad_pipe == "" { "" } else { $ports.pad_pipe + ".in" }),
        pad_port: $pad.port,
        pad_header: ($pad.header | encode hex),
        sound: $wav,
        workspace: ($ws | default ""),
    }
}

# Run a program on the kernel under QEMU with no window, the UART to
# serial.log in `out`, for at most `seconds`. The status is what jab.sys.exit
# gave, 1 on a program fault, 124 when the bound ended the run. With
# `capture`, the screen is taken into screen.ppm that long after the
# start and the run is then ended (status 0); with `keys`, each key is
# pressed through the monitor that long after the start. `set` names the
# symbols the kernel was built with: DEBUG puts the kernel's debug
# channel on the machine, whose text comes back as `debug`. With `api`,
# or with anything to `send`, the API's port is on the machine: each
# entry of `send` is written into it that long after the start, and
# every byte the program sent, landed in api.out, comes back as `api`.
# QEMU's own complaints about the guest go to qemu.log and what it
# wrote to its stderr comes back as `stderr`, so a backend's complaint
# reaches a test; cpu_seconds is the QEMU process's CPU time over the
# run, on a host with /proc, and wall_seconds the run's length. The
# timed actions, the pad header, the keys, the API bytes, the pad
# events, and the capture, go in while QEMU's process is alive, which
# is asked of the process table rather than of /proc, so they happen
# on every host. The workspace, whose generic disk rides along and
# whose shim plays a pad, is the one above the kernel ELF, else the
# one above `out`.
export def launch [
    --kernel: path             # the kernel ELF
    --image: path              # the program's .jab
    --out: path                # where serial.log and the rest go
    --seconds: int = 10        # the bound
    --capture: duration = 0sec # when to take the screen and end the run; 0 never
    --keys: table<at: duration, key: string, hold: int> = [] # keys to press that long after the start, QEMU's names, held for hold ms
    --api                      # put the API's port on the machine
    --send: table<at: duration, bytes: binary> = [] # bytes to write into the API that long after the start; puts the port on the machine
    --disk: path = ""          # a raw image to put on the machine as its first virtio-blk disk; the workspace's generic disk follows it
    --serial: string = "disk0" # the disk's serial, which the guest reads back as its own; 19 characters at most
    --set: string = ""         # the symbols the kernel was built with, comma separated
    --pad: path = ""           # a NUON file of pad events, [[at, type, code, value]; ...], played as a gamepad: into a fifo attached through the evdev shim on Linux, else into the pad port
    --pad-port                 # play --pad into the pad port on Linux too, the route every other host takes
    --kbm                      # the keyboard and the tablet on the machine, which is the default
    --no-kbm                   # neither on the machine
    --sound                    # the sound device on the machine, its output recorded to sound.wav in `out`, handed back as `sound`
]: nothing -> record<status: int, serial: string, debug: string, api: binary, screen: string, qemu_log: string, stderr: string, cpu_seconds: float, wall_seconds: float, sound: string> {
    if $kbm and $no_kbm { error make {msg: "--kbm and --no-kbm together: one or the other"} }
    let gamepad = (pad-table $pad)
    let machine = (plan --kernel $kernel --image $image --out $out --api=($api or (not ($send | is-empty))) --disk $disk --serial $serial --set $set --gamepad=(not ($pad | is-empty)) --pad-port=$pad_port --no-kbm=$no_kbm --sound=$sound)
    let out = $machine.out
    let log = $machine.serial_log
    let qemu_log = $machine.qemu_log
    let screen = $machine.screen
    let pidfile = $machine.pidfile
    let monitor = $machine.monitor
    let ports = { debug_log: $machine.debug_log }
    let wav = $machine.sound
    let disked = (["--signal=TERM" $"($seconds)" $machine.qemu_binary] ++ $machine.qemu)
    let api_out = $machine.api_out
    let api_in = $machine.api_in
    let pad_in = $machine.pad_pipe_in
    let gamepad = ($gamepad | merge { port: $machine.pad_port, fifo: $machine.pad_fifo, header: ($machine.pad_header | decode hex), env: $machine.env })
    let started = (date now)
    job spawn { with-env $gamepad.env { ^timeout ...$disked | complete } | job send 0 }
    mut result: any = null
    mut cpu = 0.0
    mut captured = ($capture == 0sec)
    mut sent = 0
    mut sent_data = 0
    mut sent_pad = 0
    mut header_sent = (not $gamepad.port)
    while $result == null {
        $result = (try { job recv --timeout 100ms } catch { null })
        let pid = (if ($pidfile | path exists) { open --raw $pidfile | str trim } else { "" })
        let alive = ($result == null and (process-alive $pid))
        let sample = (if $pid == "" { null } else { cpu-seconds $pid })
        if $sample != null { $cpu = $sample }
        let elapsed = ((date now) - $started)
        # the pad port's header goes in as soon as QEMU is up, before any
        # event, since the kernel waits for the whole of it
        if (not $header_sent) and $alive {
            $gamepad.header | save --raw --append $pad_in
            $header_sent = true
        }
        while $sent < ($keys | length) and ($keys | get $sent | get at) <= $elapsed {
            let k = ($keys | get $sent)
            if $alive { monitor-send $monitor $"sendkey ($k.key) ($k.hold)" }
            $sent += 1
        }
        while $sent_data < ($send | length) and ($send | get $sent_data | get at) <= $elapsed {
            let d = ($send | get $sent_data)
            if $alive and $api_in != "" { $d.bytes | save --raw --append $api_in }
            $sent_data += 1
        }
        while $sent_pad < ($gamepad.groups | length) and ($gamepad.groups | get $sent_pad | get at) <= $elapsed {
            let g = ($gamepad.groups | get $sent_pad)
            if $alive {
                if $gamepad.port { pad-frames $g.items | save --raw --append $pad_in } else if $gamepad.fifo != "" { pad-report $g.items | save --raw --append $gamepad.fifo }
            }
            $sent_pad += 1
        }
        if (not $captured) and ($elapsed >= $capture) {
            $captured = true
            if $alive {
                monitor-send $monitor $"screendump ($screen)"
                wait-for-file $screen
                monitor-send $monitor "quit"
            }
        }
    }
    {
        status: $result.exit_code,
        serial: (if ($log | path exists) { open --raw $log | decode } else { "" }),
        debug: (if $ports.debug_log != "" and ($ports.debug_log | path exists) { open --raw $ports.debug_log | decode } else { "" }),
        api: (if $api_out != "" and ($api_out | path exists) { open --raw $api_out | into binary } else { 0x[] }),
        screen: (if ($screen | path exists) { $screen } else { "" }),
        qemu_log: $qemu_log,
        stderr: $result.stderr,
        cpu_seconds: $cpu,
        wall_seconds: (((date now) - $started) / 1sec),
        sound: (if $wav != "" and ($wav | path exists) { $wav } else { "" }),
    }
}

# Read a wav QEMU's wav backend recorded: its rate, channels, and bits
# a sample from the format chunk, and the data chunk's samples as they
# lie, little-endian, the channels interleaved a frame at a time, to the
# end of the file when the chunk's size was never written.
export def wave [path: path]: nothing -> record<rate: int, channels: int, bits: int, frames: int, samples: binary> {
    let bytes = (open --raw ($path | path expand) | into binary)
    let total = ($bytes | bytes length)
    if ($bytes | bytes at 0..<4 | decode) != "RIFF" or ($bytes | bytes at 8..<12 | decode) != "WAVE" { error make {msg: $"($path): not a wav"} }
    mut at = 12
    mut rate = 0
    mut channels = 0
    mut bits = 0
    mut samples = 0x[]
    while $at + 8 <= $total {
        let id = ($bytes | bytes at $at..<($at + 4) | decode)
        let size = ($bytes | bytes at ($at + 4)..<($at + 8) | into int --endian little)
        let body = ($at + 8)
        if $id == "fmt " {
            $channels = ($bytes | bytes at ($body + 2)..<($body + 4) | into int --endian little)
            $rate = ($bytes | bytes at ($body + 4)..<($body + 8) | into int --endian little)
            $bits = ($bytes | bytes at ($body + 14)..<($body + 16) | into int --endian little)
        } else if $id == "data" {
            # the backend writes this size as it closes the file, which
            # QEMU 11.1.2 never does at exit, so a size of 0, or one past
            # the file's end, means the samples run to the end of the file
            let unwritten = ($size == 0 or ($body + $size) > $total)
            $samples = ($bytes | bytes at $body..<(if $unwritten { $total } else { $body + $size }))
            if $unwritten { break }
        }
        $at = ($body + $size + ($size mod 2))
    }
    if $rate == 0 or $channels == 0 { error make {msg: $"($path): no format chunk"} }
    { rate: $rate, channels: $channels, bits: $bits, frames: (($samples | bytes length) // ($channels * ($bits // 8))), samples: $samples }
}

# Read a screen `jab launch` took: its size and its pixels, three bytes
# each, red, green, blue, row by row from the top left.
export def screen [path: path]: nothing -> record<width: int, height: int, pixels: binary> {
    let bytes = (open --raw ($path | path expand))
    # P6, a line of width and height, the maximum, then the pixels
    let newlines = ($bytes | bytes index-of --all 0x[0a] | take 3)
    let header = ($bytes | bytes at 0..<($newlines.2) | decode | lines)
    let size = ($header.1 | split row " ")
    { width: ($size.0 | into int), height: ($size.1 | into int), pixels: ($bytes | bytes at ($newlines.2 + 1)..) }
}

# Where a color is on a screen: how many pixels have it and their
# bounding box (-1 all round when none do). `color` is six hex digits,
# RRGGBB.
export def ink [screen: record<width: int, height: int, pixels: binary>, color: string]: nothing -> record<count: int, left: int, top: int, right: int, bottom: int> {
    let pattern = ($color | decode hex)
    let hits = ($screen.pixels | bytes index-of --all $pattern | where {|i| $i mod 3 == 0 })
    if ($hits | is-empty) { return { count: 0, left: -1, top: -1, right: -1, bottom: -1 } }
    let xs = ($hits | each {|i| ($i // 3) mod $screen.width })
    let ys = ($hits | each {|i| ($i // 3) // $screen.width })
    { count: ($hits | length), left: ($xs | math min), top: ($ys | math min), right: ($xs | math max), bottom: ($ys | math max) }
}

# The color of the pixel at x, y as six hex digits, RRGGBB.
export def pixel [screen: record<width: int, height: int, pixels: binary>, x: int, y: int]: nothing -> string {
    let i = (($y * $screen.width + $x) * 3)
    $screen.pixels | bytes at $i..<($i + 3) | encode hex | str lowercase
}

# A rough look at a screen as text, one character per block from the
# pixel at the block's centre: space for black, then . o # by
# brightness.
export def thumbnail [screen: record<width: int, height: int, pixels: binary>, --columns: int = 96, --rows: int = 27]: nothing -> string {
    let block_w = ($screen.width // $columns)
    let block_h = ($screen.height // $rows)
    let row_bytes = ($screen.width * 3)
    0..<$rows | each {|r|
        let y = ($r * $block_h + ($block_h // 2))
        let row = ($screen.pixels | bytes at ($y * $row_bytes)..<(($y + 1) * $row_bytes))
        0..<$columns | each {|c|
            let x = ($c * $block_w + ($block_w // 2))
            let p = ($row | bytes at ($x * 3)..<($x * 3 + 3))
            let brightness = (($p | bytes at 0..<1 | into int) + ($p | bytes at 1..<2 | into int) + ($p | bytes at 2..<3 | into int))
            if $brightness < 48 { " " } else if $brightness < 256 { "." } else if $brightness < 512 { "o" } else { "#" }
        } | str join ""
    } | str join "\n"
}

# The strings in a binary that start with `prefix`, each read to its
# terminator: how a test asks a kernel image what text it carries.
export def strings [path: path, prefix: string]: nothing -> list<string> {
    let bytes = (open --raw ($path | path expand) | into binary)
    let total = ($bytes | bytes length)
    $bytes | bytes index-of --all ($prefix | into binary) | each {|at|
        let tail = ($bytes | bytes at $at..<([($at + 256) $total] | math min))
        let end = ($tail | bytes index-of 0x[00])
        (if $end < 0 { $tail } else { $tail | bytes at 0..<$end }) | decode
    }
}

# The named functions of a program's ELF as QEMU's translator sees
# them: each one's start and end from the ELF's symbols, the end being
# the next symbol's address, whether it lies within one page of code,
# since a translation block ends at a page boundary and chains within
# a page only, so a loop straddling one runs several times slower, and
# how many ecalls its code holds, read from the disassembly, since a
# kernel call in a hot loop is a trap each time round. The tools are
# the ones the build's flags stamp names, beside the ELF.
export def hot [elf: path, names: list<string>]: nothing -> table<name: string, start: int, end: int, paged: bool, ecalls: int> {
    let elf = ($elf | path expand)
    let built = ($elf | path dirname)
    let prefix = (open --raw ($built | path join "flags") | lines | first | split row " " | last)
    let symbols = (^$"($prefix)nm" -n $elf | lines | parse "{addr} {kind} {name}" | each {|s| { addr: ($s.addr | into int --radix 16), name: $s.name } })
    let ecalls = (^$"($prefix)objdump" -d $elf | lines | parse --regex '^\s*(?P<addr>[0-9a-f]+):\s+[0-9a-f]+\s+ecall\b' | each {|d| $d.addr | into int --radix 16 })
    $names | each {|name|
        let at = ($symbols | enumerate | where {|s| $s.item.name == $name } | get -o 0.index)
        if $at == null { error make {msg: $"($name) is not among the symbols of ($elf)"} }
        let start = ($symbols | get $at | get addr)
        let next = ($symbols | get -o ($at + 1))
        if $next == null { error make {msg: $"($name) is the last symbol of ($elf), so its end is unknown"} }
        let end = $next.addr
        {
            name: $name,
            start: $start,
            end: $end,
            paged: (($start // 4096) == (($end - 1) // 4096)),
            ecalls: ($ecalls | where {|a| $a >= $start and $a < $end } | length),
        }
    }
}

# The QEMU arguments that put raw images on the machine as virtio-blk
# disks, in the order given, so the first is disk 1 to the kernel. Each
# rides the PCI Express root rather than one of the eight mmio slots,
# modern-only and on INTx (`disable-legacy=on,vectors=0`), which is how
# the kernel drives it. A serial is what the guest reads back with
# jab.sys.block.list, so it is how a program tells one disk from another.
# An image built from assets, the program's own or the generic disk,
# is attached read-only, so a program cannot change what the next run
# reads: a write to it comes back to the program as the device's error
# code, and the file on the host is never touched. The blank data disk
# a run carries when a program ships no assets stays writable.
def disks-args [disks: table<id: string, file: string, serial: string, readonly: bool>]: nothing -> list<string> {
    $disks | each {|d| [
        "-drive" $"if=none,id=($d.id),file=($d.file | path expand),format=raw(if $d.readonly { ',readonly=on' } else { '' })"
        "-device" $"virtio-blk-pci,disable-legacy=on,vectors=0,drive=($d.id),serial=($d.serial)"
    ] } | flatten
}

# The disks a machine carries: the program's own first, when there is
# one, read-only when it is an asset image, then the generic assets
# disk, always read-only, when the workspace has one, so a program's
# disk is 1 and the generic disk 2, or 1 on its own.
def machine-disks [own: string, own_serial: string, own_readonly: bool, ws: oneof<string, nothing>]: nothing -> table<id: string, file: string, serial: string, readonly: bool> {
    let first = (if ($own | is-empty) { [] } else { [{ id: "disk0", file: $own, serial: $own_serial, readonly: $own_readonly }] })
    let mix = (mix-image $ws)
    let second = (if $mix == "" { [] } else { [{ id: "mix", file: $mix, serial: "mix", readonly: true }] })
    $first ++ $second
}

# The generic assets disk, disk 1 of every run and launch: `generic/`
# in the workspace mirrored to the image's root, plus what
# `generic/manifest.nuon` fetches, each entry an archive by URL and
# sha256 with the members to take and where each lands, so the large
# third-party assets, the soundfonts today, are never committed and
# are verified on every build. Staged under .target/generic and built
# into .target/mix.romfs whenever the tree or the manifest changes,
# the archives kept under .target/fetch. The path, or "" with no
# workspace or no generic/ in it.
def mix-image [ws: oneof<string, nothing>]: nothing -> string {
    if $ws == null { return "" }
    let generic = ($ws | path join "generic")
    if not ($generic | path exists) { return "" }
    let target = ($ws | path join ".target")
    let image = ($target | path join "mix.romfs")
    let stamp = ($target | path join "mix.flags")
    let manifest_path = ($generic | path join "manifest.nuon")
    let manifest = (if ($manifest_path | path exists) { open $manifest_path } else { [] })
    let inputs = (tree-under [$generic])
    let flags = (build-id ($manifest | to nuon) $inputs)
    if ($image | path exists) and (not (stale $image $inputs $flags $stamp)) { return $image }
    let stage = ($target | path join "generic")
    if ($stage | path exists) { rm -r $stage }
    mkdir $stage
    for f in (files-under [$generic]) {
        let relative = ($f | path relative-to $generic)
        if $relative == "manifest.nuon" { continue }
        let dest = ($stage | path join $relative)
        mkdir ($dest | path dirname)
        cp $f $dest
    }
    for entry in $manifest {
        let archive = (fetched $target $entry.url $entry.sha256)
        let unpack = ($target | path join "fetch" "unpack")
        if ($unpack | path exists) { rm -r $unpack }
        mkdir $unpack
        ^tar -xzf $archive -C $unpack ...($entry.members | get from)
        for m in $entry.members {
            let dest = ($stage | path join $m.to)
            mkdir ($dest | path dirname)
            mv ($unpack | path join $m.from) $dest
        }
        rm -r $unpack
    }
    assets-names $stage
    ^genromfs -d $stage -f $image -V (volume-name "mix")
    $flags | save -f $stamp
    $image
}

# An archive the manifest names, fetched into .target/fetch on first
# use, which a run says once since it can take a while, and verified
# by its sha256 then and on every later build; a mismatch stops with
# both digests named.
def fetched [target: path, url: string, sha256: string]: nothing -> string {
    let dir = ($target | path join "fetch")
    mkdir $dir
    let file = ($dir | path join ($url | path basename))
    if not ($file | path exists) {
        http get --raw $url | save --raw -f $file
    }
    let digest = (open --raw $file | hash sha256)
    if $digest != $sha256 { error make {msg: $"($file): sha256 ($digest), where the manifest says ($sha256)"} }
    $file
}

# The ports, each of one virtio-serial-device: DEBUG in the build puts
# the kernel's debug channel on port 1 with the host's end a file,
# debug.log in `out`; `api` puts the API on port 2 with the host's end
# QEMU's pipe chardev over api.in, a named pipe the host writes into,
# and api.out, a plain file the program's bytes land in as they are
# sent, both made here. A file rather than a second pipe, so nothing
# has to hold a pipe open for the run and a program is never held by a
# host that stopped reading. `pad_port` puts the pad's port on port 3
# the same way, over padport.in, which the host writes the pad's header
# and events into (doc/padport.md). Nothing at all with none, so the
# machine carries no serial device. The console keeps the UART in
# every build, since a fault line has to reach the host when a port has
# not come up.
def ports [names: list<string>, out: path, api: bool, pad_port: bool]: nothing -> record<args: list<string>, debug_log: string, api_pipe: string, pad_pipe: string> {
    mkdir $out
    let debug = (if "DEBUG" in $names {
        let log = ($out | path join "debug.log")
        if ($log | path exists) { rm $log }
        { args: ["-chardev" $"file,id=jabdebug,path=($log)" "-device" "virtserialport,chardev=jabdebug,nr=1,name=jab.debug"], log: $log }
    } else { { args: [], log: "" } })
    let port = (if $api {
        let pipe = (pipe-pair ($out | path join "api"))
        { args: ["-chardev" $"pipe,id=jabapi,path=($pipe)" "-device" "virtserialport,chardev=jabapi,nr=2,name=jab.api"], pipe: $pipe }
    } else { { args: [], pipe: "" } })
    let pad = (if $pad_port {
        let pipe = (pipe-pair ($out | path join "padport"))
        { args: ["-chardev" $"pipe,id=jabpad,path=($pipe)" "-device" "virtserialport,chardev=jabpad,nr=3,name=jab.pad"], pipe: $pipe }
    } else { { args: [], pipe: "" } })
    let device = (if ($debug.args | is-empty) and ($port.args | is-empty) and ($pad.args | is-empty) { [] } else { ["-device" "virtio-serial-device"] })
    { args: ($device ++ $debug.args ++ $port.args ++ $pad.args), debug_log: $debug.log, api_pipe: $port.pipe, pad_pipe: $pad.pipe }
}

# What QEMU's pipe chardev opens at `pipe`: `<pipe>.in`, a named pipe
# the host writes into, made when it is not one already, and
# `<pipe>.out`, a plain file made empty, where the guest's bytes land.
def pipe-pair [pipe: path]: nothing -> string {
    let inward = ($pipe + ".in")
    if (($inward | path type) != "pipe") {
        if ($inward | path exists) { rm $inward }
        ^mkfifo $inward
    }
    let outward = ($pipe + ".out")
    if ($outward | path exists) { rm $outward }
    "" | save -f $outward
    $pipe
}

# The gamepad a machine carries: nothing at all unless asked. Asked, on
# Linux unless `port` says otherwise, the fifo `pad` in `out`, made fresh,
# which QEMU's host-input device opens as the pad with the evdev shim
# preloaded to answer its ioctls as the reference pad, the QEMU arguments
# and environment for that; on every other host, and on Linux with
# `port`, the pad port instead, the same reference pad described by the
# header the driver writes first. The shim is one of the workspace's,
# `ws`, the kernel's or the one above `out`.
def pad-attach [wanted: bool, out: path, port: bool, ws: oneof<string, nothing>]: nothing -> record<args: list<string>, env: record, fifo: string, port: bool, header: binary> {
    let none = { args: [], env: {}, fifo: "", port: false, header: 0x[] }
    if not $wanted { return $none }
    if $port or $nu.os-info.name != "linux" {
        return ($none | merge { port: true, header: (pad-port-header) })
    }
    if $ws == null { error make {msg: "a gamepad needs a workspace, above the kernel or the output directory, which holds shim/crates/evdev"} }
    let shim = (shim-build $ws "jabshim_evdev")
    let fifo = ($out | path join "pad")
    if (($fifo | path type) != null) { rm $fifo }
    ^mkfifo $fifo
    {
        args: ["-device" $"virtio-input-host-device,evdev=($fifo)"],
        env: { LD_PRELOAD: $shim, EVDEV_SHIM_FIFO: $fifo },
        fifo: $fifo,
        port: false,
        header: 0x[],
    }
}

# A launch's pad table as the groups it plays: the rows grouped by their
# time, each group one report the launch loop writes at that time; none
# without a table.
def pad-table [table: path]: nothing -> record<groups: list<any>> {
    if ($table | is-empty) { return { groups: [] } }
    let rows = (open ($table | path expand))
    let wanted = [at type code value]
    if not ($wanted | all {|c| $c in ($rows | columns) }) {
        error make {msg: $"($table): a pad table has the columns at, type, code, value; this one has ($rows | columns | str join ', ')"}
    }
    { groups: ($rows | sort-by at | group-by --to-table {|r| $r.at | into int } | each {|g| { at: ($g.items | first | get at), items: $g.items } }) }
}

# One report of pad events, as the device would send them: each row an
# input_event, then a SYN_REPORT closing the report.
def pad-report [items: table<type: int, code: int, value: int>]: nothing -> binary {
    ($items | each {|e| input-event $e.type $e.code $e.value } | bytes collect) ++ (input-event 0 0 0)
}

# The same events as the pad port takes them: eight bytes each, type,
# code, value, little-endian, no SYN (doc/padport.md).
def pad-frames [items: table<type: int, code: int, value: int>]: nothing -> binary {
    $items | each {|e| (le $e.type 2) ++ (le $e.code 2) ++ (le $e.value 4) } | bytes collect
}

# The pad port's header for the reference pad, the one the evdev shim
# answers as, so a table plays the same either way (doc/padport.md):
# the magic, the version, the name, the buttons BTN_GAMEPAD to
# BTN_GAMEPAD plus 15, the axes X, Y, Z, RZ, GAS, BRAKE, HAT0X, HAT0Y
# with the shim's absinfo, and zero for every other axis.
def pad-port-header []: nothing -> binary {
    let name = ("8BitDo Ultimate" | into binary)
    let axes = {
        0: [0 255 0 15 0], 1: [0 255 0 15 0], 2: [0 255 0 15 0], 5: [0 255 0 15 46],
        9: [0 255 0 15 0], 10: [0 255 0 15 0], 16: [-1 1 0 0 0], 17: [-1 1 0 0 0],
    }
    let axis_mask = ($axes | columns | each {|c| 1 bit-shl ($c | into int) } | math sum)
    let absinfo = (0..<64 | each {|code|
        let info = ($axes | get -o ($code | into string))
        if $info == null { zeros 20 } else { $info | each {|f| le $f 4 } | bytes collect }
    } | bytes collect)
    ("JPAD" | into binary) ++ (le 1 4) ++ $name ++ (zeros (128 - ($name | bytes length))) ++ (le 0xffff 4) ++ (le 0 4) ++ (le $axis_mask 8) ++ $absinfo
}

# A value as `width` little-endian bytes, two's complement.
def le [value: int, width: int]: nothing -> binary {
    $value | into binary --endian little | bytes at 0..<$width
}

# `n` zero bytes.
def zeros [n: int]: nothing -> binary {
    if $n <= 0 { 0x[] } else { 1..$n | each {|| 0x[00] } | bytes collect }
}

# One input_event as an evdev device writes it, 24 bytes: the wall
# clock's seconds and microseconds as two 64-bit fields, then the type
# and the code as 16 bits each and the value as 32, all little-endian.
def input-event [type: int, code: int, value: int]: nothing -> binary {
    let ns = (date now | into int)
    let sec = ($ns // 1_000_000_000)
    let usec = (($ns mod 1_000_000_000) // 1000)
    ($sec | into binary --endian little | bytes at 0..<8) ++ ($usec | into binary --endian little | bytes at 0..<8) ++ ($type | into binary --endian little | bytes at 0..<2) ++ ($code | into binary --endian little | bytes at 0..<2) ++ ($value | into binary --endian little | bytes at 0..<4)
}

# The build symbols named by `--set`: comma separated, in any case,
# each made screaming snake case (debug, Debug and some-thing become
# DEBUG and SOME_THING), sorted so order cannot matter, and refused when
# the assembler would not take the name, which it would only say much
# later.
def symbols [set: string]: nothing -> list<string> {
    let names = ($set | split row "," | each {|s| $s | str trim } | where {|s| $s != "" } | each {|s| $s | str screaming-snake-case } | uniq | sort)
    for n in $names {
        if not ($n =~ '^[A-Z_][A-Z0-9_]*$') {
            error make {msg: $"--set ($n): not a symbol the assembler takes; a name starts with a letter"}
        }
    }
    $names
}

# A test build's symbols: whatever was asked, and DEBUG.
def with-debug [names: list<string>]: nothing -> list<string> { $names | append "DEBUG" | uniq | sort }

# Which tree a build lands in: debug with DEBUG set, else release.
def profile [names: list<string>]: nothing -> string { if "DEBUG" in $names { "debug" } else { "release" } }

# The symbols as the assembler takes them.
def defsyms [names: list<string>]: nothing -> list<string> { $names | each {|n| ["--defsym" $"($n)=1"] } | flatten }

# A program's assets as a romfs image, built when the directory it names
# has moved on: `assets` in its manifest, relative to the manifest, with
# the program's own name as the volume's. The image is what `just run`
# puts on the machine, and the program reads it with jab.sys.romfs.*.
def assets-image [c: record]: nothing -> string {
    let declared = ($c.manifest | get -o assets | default "")
    if $declared == "" { return "" }
    let dir = ($c.here | path join $declared | path expand)
    if not ($dir | path exists) {
        error make {msg: $"($c.manifest.name): assets = '($declared)' names no directory at ($dir)"}
    }
    assets-names $dir
    let image = ($c.out | path join $"($c.manifest.name).romfs")
    let stamp = ($c.out | path join "assets.flags")
    let inputs = (tree-under [$dir])
    let id = (build-id $c.manifest.name $inputs)
    if ($image | path exists) and (not (stale $image $inputs $id $stamp)) { return $image }
    mkdir $c.out
    ^genromfs -d $dir -f $image -V (volume-name $c.manifest.name)
    $id | save -f $stamp
    $image
}

# A romfs name is at most 127 bytes of UTF-8, which is what a Linux
# mount of the same image can read: its driver lists through a
# 128-byte buffer and works out where a file's data begins from a
# length that stops there, so a longer name makes it read the wrong
# bytes. The kernel reports such a name cut rather than wrong, but an
# image Jab builds never has one. `str length` counts bytes, which is
# the measure the record and the driver use.
def assets-names [dir: path]: nothing -> nothing {
    let long = (glob ($dir | path join "**" "*") | each {|p| $p | path basename } | where {|n| ($n | str length) > 127 })
    if not ($long | is-empty) {
        error make {msg: $"romfs names are 127 bytes at most, which is what a linux mount can read; too long: ($long | first)"}
    }
}

# A volume's name is bound the same way, and a disk's serial by virtio's
# 20-byte ID string, which carries a terminator only when it fits; each
# is cut on a character, never inside one.
def volume-name [name: string]: nothing -> string { cut-bytes $name 127 }
def disk-serial [name: string]: nothing -> string { cut-bytes $name 19 }

# The longest prefix of `name` within `limit` bytes of UTF-8 that ends
# on a whole character.
def cut-bytes [name: string, limit: int]: nothing -> string {
    mut out = ""
    for g in ($name | split chars --grapheme-clusters) {
        if (($out + $g) | str length) > $limit { break }
        $out = ($out + $g)
    }
    $out
}

# Whether the process is in the process table, which nushell reads on
# every host; "" is no process at all.
def process-alive [pid: string]: nothing -> bool {
    if $pid == "" { return false }
    let id = (try { $pid | into int } catch { -1 })
    if $id < 0 { return false }
    ps | where pid == $id | is-not-empty
}

# The CPU seconds a process has used, user plus system, from /proc,
# or null where there is no /proc or the process is gone; accounting
# only, never what a launch's actions wait on.
def cpu-seconds [pid: string]: nothing -> oneof<float, nothing> {
    let stat = (try { open --raw ("/proc" | path join $pid "stat") | decode } catch { "" })
    if $stat == "" { return null }
    # after the command's closing parenthesis: state, ppid, pgrp,
    # session, tty, tpgid, flags, minflt, cminflt, majflt, cmajflt,
    # utime, stime, in clock ticks of a hundredth
    let fields = ($stat | split row ") " | last | split row " ")
    (($fields | get 11 | into int) + ($fields | get 12 | into int)) / 100.0
}

# Give the QEMU monitor a command through its pipe.
def monitor-send [monitor: path, command: string]: nothing -> nothing {
    $"($command)\n" | save --raw --append ($monitor + ".in")
}

# Wait for a file QEMU writes whole to appear and stop growing.
def wait-for-file [path: path]: nothing -> nothing {
    mut last = -1
    for _ in 0..100 {
        sleep 50ms
        if ($path | path exists) {
            let size = (ls -D $path | get 0.size | into int)
            if $size > 0 and $size == $last { return }
            $last = $size
        }
    }
}

# The Jab QEMU processes on this host, by their command line, which
# every Jab line marks with `-name jab`: the QEMU itself, wherever its
# binary lives, never the `timeout` a test wraps it in, whose command
# line carries the same words.
def jab-pids []: nothing -> list<int> {
    ps -l | where {|p| ((command-binary $p.command | path basename) == $qemu_name) and ($p.command | str contains "-name jab") } | get pid
}

# The binary a command line runs: everything before its first option, so
# a binary whose path holds a space, an extern/qemu under such a
# directory, stays whole.
def command-binary [command: string]: nothing -> string {
    $command | split row " -" | first
}

# The threads of a process with their cumulative CPU seconds: on Linux
# from /proc, by thread id and name (the harts `CPU 0/TCG` and on, the
# main loop under the process name); on macOS from `ps -M`, its rows
# in order, the first the AppKit thread that draws the window, the
# rest unnamed, so a thread is identified by its row.
def threads-of [pid: int]: nothing -> table<id: string, name: string, cpu: float> {
    match $nu.os-info.name {
        "linux" => {
            let tasks = (try { ls ("/proc" | path join ($pid | into string) "task") | get name } catch { [] })
            $tasks | each {|t|
                let stat = (try { open --raw ($t | path join "stat") | decode } catch { "" })
                if $stat == "" { null } else {
                    let fields = ($stat | split row ") " | last | split row " ")
                    let name = (try { open --raw ($t | path join "comm") | decode | str trim } catch { "" })
                    { id: ($t | path basename), name: $name, cpu: ((($fields | get 11 | into int) + ($fields | get 12 | into int)) / 100.0) }
                }
            } | compact
        },
        "macos" => {
            let out = (^ps -M -p ($pid | into string) | complete | get stdout)
            $out | lines | skip 1 | enumerate | each {|row|
                let times = ($row.item | parse --regex '(?P<stime>\d+:\d+(?::\d+)?\.\d+)\s+(?P<utime>\d+:\d+(?::\d+)?\.\d+)' | get -o 0)
                if $times == null { null } else {
                    { id: ($row.index | into string), name: (if $row.index == 0 { "main" } else { $"thread ($row.index)" }), cpu: ((clock-seconds $times.stime) + (clock-seconds $times.utime)) }
                }
            } | compact
        },
        _ => { error make {msg: $"no thread reading here for ($nu.os-info.name)"} },
    }
}

# `ps` clock text, M:SS.hh or H:MM:SS.hh, as seconds.
def clock-seconds [text: string]: nothing -> float {
    $text | split row ":" | each {|p| $p | into float } | reduce --fold 0.0 {|it, acc| $acc * 60.0 + $it }
}

# Where `watch` records: watch.nuonl under the workspace's .target.
def watch-file [ws: path]: nothing -> string {
    $ws | path expand | path join ".target" "watch.nuonl"
}

# Record the running Jab QEMU per thread, once a second, to the
# workspace's .target/watch.nuonl, whatever shell this is run from: a
# first line describing the run (host, the running QEMU's version, the
# window, the kernel and the symbols it was built with, read from its
# tree's flags stamp), then a line per sample with every thread's
# cumulative CPU seconds, one short line printed per sample with the
# rates since the last. When the run ends, the report on the recording
# is printed to paste (watch-report), the first `--skip` seconds dropped
# as the load. Interrupted, it ends with no report.
def "main watch" [ws: path, --skip: float = 5.0] {
    let pids = (jab-pids)
    if ($pids | is-empty) { error make {msg: "no jab is running"} }
    let pid = ($pids | first)
    let command = (ps -l | where pid == $pid | get -o 0.command | default "")
    let window = ($command | parse --regex '-display (?P<w>\S+)' | get -o 0.w | default "")
    let kernel = ($command | parse --regex '-kernel (?P<k>\S+)' | get -o 0.k | default "")
    let stamp_file = (if $kernel == "" { "" } else { $kernel | path dirname | path join "flags" })
    let stamp = (if $stamp_file != "" and ($stamp_file | path exists) { open --raw $stamp_file | decode | str trim } else { "" })
    let symbols = ($stamp | parse --regex '--defsym (?P<s>[A-Z0-9_]+)=1' | get s)
    let binary = (command-binary $command)
    let qemu = (try { ^$binary --version | complete | get stdout | lines | get -o 0 | default "" } catch { "" })
    let file = (watch-file $ws)
    mkdir ($file | path dirname)
    let started = (date now)
    let run = { os: $nu.os-info.name, arch: $nu.os-info.arch, qemu: $qemu, window: $window, kernel: $kernel, symbols: $symbols, pid: $pid, started: ($started | format date "%Y-%m-%dT%H:%M:%S") }
    ({ run: $run } | to nuon) + (char nl) | save --raw -f $file
    print $"jab watch: recording ($pid) to ($file), ($symbols | str join ', ') under ($window)"
    if ($pids | length) > 1 { print $"jab watch: ($pids | length) jab processes; recording the first" }
    mut last: any = null
    loop {
        if (jab-pids | where {|p| $p == $pid } | is-empty) { print "jab watch: the run has ended"; break }
        let at = (((date now) - $started) / 1sec)
        let threads = (threads-of $pid)
        ({ at: $at, threads: $threads } | to nuon) + (char nl) | save --raw --append $file
        let previous = $last
        if $previous != null {
            let seconds = ($at - $previous.at)
            let rates = ($threads | each {|t|
                let before = ($previous.threads | where id == $t.id | get -o 0.cpu | default $t.cpu)
                { name: $t.name, rate: (($t.cpu - $before) / $seconds) }
            } | where rate >= 0.01 | sort-by rate --reverse)
            print $"($at | math round)s  ($rates | each {|r| $'($r.name) ($r.rate | math round -p 2)' } | str join '  ')"
        }
        $last = { at: $at, threads: $threads }
        sleep 1sec
    }
    print (watch-report $ws $skip | to nuon --indent 2)
}

# The report on what `watch` recorded, as one NUON record: the run as
# recorded, the stretch reported on, and per thread the steady CPU
# seconds a second over that stretch and the peak second, with the
# process total; threads under 0.005 a second are left out. The stretch
# drops the first `skip` seconds as the load, or nothing for a run too
# short to spare them, `skipped` saying which. On macOS a thread is its
# row, and QEMU's worker threads come and go, so a row can change
# identity between samples: a row whose second-by-second rate is
# impossible for one thread, negative or past one, is reported with
# `stable: false` and no peak, its steady figure a mix.
def watch-report [ws: path, skip: float]: nothing -> record {
    let lines = (open --raw (watch-file $ws) | decode | lines | where {|l| ($l | str trim) != "" })
    let header = ($lines | first | from nuon)
    let recorded = ($lines | skip 1 | each {|l| $l | from nuon })
    let after = ($recorded | where at >= $skip)
    let skipped = (if ($after | length) >= 2 { $skip } else { 0.0 })
    let samples = (if ($after | length) >= 2 { $after } else { $recorded })
    if ($samples | length) < 2 { error make {msg: $"the run ended after ($samples | length) samples, too few for a report; watch a run of two seconds or more"} }
    let first = ($samples | first)
    let last = ($samples | last)
    let seconds = ($last.at - $first.at)
    let threads = ($last.threads | get id | each {|id|
        let series = ($samples | each {|s|
            let t = ($s.threads | where id == $id | get -o 0)
            if $t == null { null } else { { at: $s.at, cpu: $t.cpu, name: $t.name } }
        } | compact)
        if ($series | length) < 2 { null } else {
            let steady = ((($series | last).cpu - ($series | first).cpu) / (($series | last).at - ($series | first).at))
            let rates = ($series | window 2 | each {|w| ($w.1.cpu - $w.0.cpu) / ($w.1.at - $w.0.at) })
            let stable = (not ($rates | any {|r| $r < -0.001 or $r > 1.05 }))
            { name: ($series | last).name, id: $id, steady: ($steady | math round -p 3), peak: (if $stable { $rates | math max | math round -p 3 } else { null }), stable: $stable }
        }
    } | compact | where steady >= 0.005 | sort-by steady --reverse)
    {
        run: $header.run,
        skipped: $skipped,
        seconds: ($seconds | math round -p 1),
        samples: ($samples | length),
        process: (if ($threads | is-empty) { 0.0 } else { $threads | get steady | math sum | math round -p 3 }),
        threads: $threads,
    }
}

# The nearest parent of `dir` holding workspace.jab.toml, or null.
def workspace-dir [dir: path]: nothing -> oneof<string, nothing> {
    mut d = ($dir | path expand)
    loop {
        if ($d | path join "workspace.jab.toml" | path exists) { return $d }
        let parent = ($d | path dirname)
        if $parent == $d { return null }
        $d = $parent
    }
}

# The toolchain's install directory, or null for the tools on PATH.
def toolchain [here: path, workspace: oneof<string, nothing>]: nothing -> oneof<string, nothing> {
    let from_env = ($env.RISCV_TOOLCHAIN? | default "")
    if $from_env != "" { return $from_env }
    let local = ($here | path join "extern" "riscv")
    if ($local | path exists) { return $local }
    if $workspace != null {
        let shared = ($workspace | path join "extern" "riscv")
        if ($shared | path exists) { return $shared }
    }
    null
}

# The tools' command prefix: under a toolchain directory, `bin/<triple>`
# for the first triple whose `as` is there, `as.exe` on Windows; on PATH,
# the first triple whose `as` `which` finds. Untyped because it ends in
# an error.
def tool-prefix [toolchain: oneof<string, nothing>] {
    let looked = ($triples | each {|t| exe-name ($t + "as") } | str join ", ")
    if $toolchain != null {
        let bin = ($toolchain | path join "bin")
        for t in $triples {
            let prefix = ($bin | path join $t)
            if (exe-name ($prefix + "as") | path exists) { return $prefix }
        }
        error make {msg: $"no riscv64 binutils under ($bin): looked for ($looked)"}
    }
    for t in $triples {
        if not (which ($t + "as") | is-empty) { return $t }
    }
    error make {msg: $"no riscv64 binutils on PATH: looked for ($looked); set RISCV_TOOLCHAIN or link extern/riscv to a toolchain"}
}

# Whether the assembler takes the RVA23 profile `march` names, tried on an
# empty source in `dir` before a build assembles anything; one that does
# not, binutils before 2.45, is refused with its version, since no other
# ISA will do. Untyped because it can end in an error.
def march-check [asm: string, march: string, dir: path] {
    let source = ($dir | path join "march.S")
    let object = ($dir | path join "march.o")
    "" | save -f $source
    let tried = (^$asm $march $source -o $object | complete)
    rm -f $source $object
    if $tried.exit_code != 0 {
        let version = (^$asm --version | complete | get stdout | lines | get -o 0 | default "an assembler")
        let found = (which $asm | get -o 0.path | default $asm)
        error make {msg: $"($version) at ($found) has no RVA23 profile, ($march), which every Jab build assembles for\nlink extern/riscv, in the workspace or beside the kernel or program, to a toolchain with binutils 2.45 or later, or name one with RISCV_TOOLCHAIN"}
    }
}

# Every file under the directories, for the staleness check.
def files-under [dirs: list<string>]: nothing -> list<string> {
    $dirs | each {|d| glob ($d | path join "**" "*") } | flatten | where {|p| ($p | path type) == "file" }
}

# Every file and directory under the directories, the directories
# included since a deletion inside one moves its time and nothing
# else's.
def tree-under [dirs: list<string>]: nothing -> list<string> {
    $dirs | each {|d| [$d] ++ (glob ($d | path join "**" "*")) } | flatten | where {|p| ($p | path type) in ["file" "dir"] }
}

# What a build was made from, for its stamp: the flags, then every
# input path, sorted, so a source or asset deleted or renamed changes
# the stamp and forces the build, which the newest-input check alone
# cannot see, since a file that is gone is newer than nothing.
def build-id [flags: string, inputs: list<string>]: nothing -> string {
    $flags + (char nl) + ($inputs | sort | str join (char nl))
}

# Whether `output` needs building: missing, older than an input, or
# built from other flags or inputs than `stamp` records.
def stale [output: path, inputs: list<string>, flags: string, stamp: path]: nothing -> bool {
    if not ($output | path exists) { return true }
    if not ($stamp | path exists) { return true }
    if (open --raw $stamp) != $flags { return true }
    let newest = ($inputs | each {|p| ls -D $p | get 0.modified } | sort | last)
    (ls -D $output | get 0.modified) <= $newest
}

# The workspace a kernel or a program builds against: the nearest
# parent holding workspace.jab.toml, else the one the manifest's
# `workspace` names, relative to the manifest, for a program that lives
# outside any. Its kernel is built there with the same symbols and
# found in that workspace's tree, and its generic disk, its toolchain
# link, its shims, and discovery come from there, while the program's
# own output lands beside the program unless the program is a member
# (member-of). Under a workspace the key is not read. Null with neither.
def workspace-of [here: path, manifest: record]: nothing -> oneof<string, nothing> {
    let above = (workspace-dir $here)
    if $above != null { return $above }
    let declared = ($manifest | get -o workspace | default "")
    if $declared == "" { return null }
    let ws = ($here | path join $declared | path expand)
    if not ($ws | path join "workspace.jab.toml" | path exists) {
        error make {msg: $"($manifest.name): workspace = '($declared)' names no workspace at ($ws), which would hold workspace.jab.toml"}
    }
    $ws
}

# Whether `dir` is `root` or lies under it.
def under [dir: path, root: path]: nothing -> bool {
    try { $dir | path relative-to $root | ignore; true } catch { false }
}

# Whether `dir` is one of the workspace's own, its kernel or a program
# workspace.jab.toml lists, by its workspace-relative path: a member
# builds into the workspace's .target under that path. A program under
# the workspace's directory that it does not list, a game's say, builds
# against the workspace with its output beside itself.
def member-of [dir: path, ws: path]: nothing -> bool {
    if not (under $dir $ws) { return false }
    let relative = ($dir | path relative-to $ws | str replace --all "\\" "/")
    let listed = (open ($ws | path join "workspace.jab.toml"))
    $relative == $listed.kernel or ($relative in $listed.programs)
}

# The kernel's or a program's context for a build with `names` set:
# manifest, workspace (workspace-of) and whether the directory is a
# member of it, toolchain, symbols, the target tree (.target's debug or
# release, the workspace's for a member and the program's own
# otherwise), and the output directory (the workspace-relative path
# under the tree, or the name).
def context [dir: path, kind: string, names: list<string>]: nothing -> record {
    let here = ($dir | path expand)
    let manifest_path = ($here | path join $"($kind).jab.toml")
    let manifest = (open $manifest_path)
    let workspace = (workspace-of $here $manifest)
    let member = ($workspace != null and (member-of $here $workspace))
    let tree = (profile $names)
    let target = (if $member { $workspace | path join ".target" $tree } else { $here | path join ".target" $tree })
    let relative = (if $member { $here | path relative-to $workspace } else { $manifest.name })
    let tc = (toolchain $here $workspace)
    {
        here: $here,
        manifest: $manifest,
        manifest_path: $manifest_path,
        workspace: $workspace,
        member: $member,
        toolchain: $tc,
        prefix: (tool-prefix $tc),
        symbols: $names,
        profile: $tree,
        target: $target,
        out: ($target | path join $relative),
    }
}

# The kernel ELF a program runs on: the workspace's, in the same tree
# of that workspace's own .target, or JAB_KERNEL. Left untyped because
# it ends in an error, which the output check rejects.
def kernel-elf [c: record] {
    if $c.workspace != null {
        let ws = (open ($c.workspace | path join "workspace.jab.toml"))
        return ($c.workspace | path join ".target" $c.profile $ws.kernel "jab.elf")
    }
    let from_env = ($env.JAB_KERNEL? | default "")
    if $from_env != "" { return $from_env }
    error make {msg: "no workspace above this program and no JAB_KERNEL: where is the kernel?"}
}

# The window for a run: JAB_DISPLAY, else the manifest's display, else
# the best QEMU window the host has: SDL with OpenGL on Linux and
# Windows, cocoa on macOS (its only window, and it has no OpenGL). A
# Linux machine with no display server is nobody's console; there the
# display goes out over VNC for development.
def display [manifest: record]: nothing -> string {
    let forced = ($env.JAB_DISPLAY? | default "")
    if $forced != "" { return $forced }
    let declared = ($manifest | get -o display | default "")
    if $declared != "" { return $declared }
    match $nu.os-info.name {
        "macos" => "cocoa",
        "windows" => "sdl,gl=on",
        _ => {
            let server = (($env.DISPLAY? | default "") != "") or (($env.WAYLAND_DISPLAY? | default "") != "")
            if $server { "sdl,gl=on" } else { "vnc=127.0.0.1:30" }
        },
    }
}

def build-kernel [dir: path, names: list<string>]: nothing -> nothing {
    let c = (context $dir "kernel" $names)
    let m = $c.manifest
    let includes = ($m | get -o includes | default [])
    let include_flags = ($includes | each {|i| ["-I" $i] } | flatten)
    let set_flags = (defsyms $names)
    let flags = (($include_flags ++ $set_flags ++ [$march_kernel $c.prefix]) | str join " ")
    let elf = ($c.out | path join "jab.elf")
    let stamp = ($c.out | path join "flags")
    cd $c.here
    let inputs = ((files-under (["src"] ++ $includes)) ++ [$c.manifest_path $m.link])
    let id = (build-id $flags $inputs)
    if not (stale $elf $inputs $id $stamp) { return }
    mkdir $c.out
    let asm = ($c.prefix + "as")
    let ld = ($c.prefix + "ld")
    let objdump = ($c.prefix + "objdump")
    march-check $asm $march_kernel $c.out
    # only the objects of the sources there are go into the link, so an
    # object left by a source since deleted or renamed never rides along
    let objects = (glob src/*.S | sort | each {|f|
        let obj = ($c.out | path join (($f | path parse | get stem) + ".o"))
        ^$asm $march_kernel ...$include_flags ...$set_flags $f -o $obj
        $obj
    })
    for stray in (glob ($c.out | path join "*.o") | where {|o| $o not-in $objects }) { rm $stray }
    ^$ld -T $m.link -nostdlib ...$objects -o $elf
    ^$objdump -d $elf | save -f ($c.out | path join "jab.disas")
    $id | save -f $stamp
}

def build-program [dir: path, names: list<string>]: nothing -> nothing {
    let c = (context $dir "program" $names)
    let m = $c.manifest
    let includes = ($m | get -o includes | default [])
    let include_flags = ($includes | each {|i| ["-I" $i] } | flatten)
    let set_flags = (defsyms $names)
    let flags = (($include_flags ++ $set_flags ++ [$march_program $c.prefix]) | str join " ")
    let image = ($c.out | path join $"($m.name).jab")
    let stamp = ($c.out | path join "flags")
    cd $c.here
    let inputs = ((files-under (["src"] ++ $includes)) ++ [$c.manifest_path $m.link])
    let id = (build-id $flags $inputs)
    if not (stale $image $inputs $id $stamp) { return }
    mkdir $c.out
    let asm = ($c.prefix + "as")
    let ld = ($c.prefix + "ld")
    let objcopy = ($c.prefix + "objcopy")
    march-check $asm $march_program $c.out
    let obj = ($c.out | path join $"($m.name).o")
    let elf = ($c.out | path join $"($m.name).elf")
    ^$asm $march_program ...$include_flags ...$set_flags src/main.S -o $obj
    ^$ld -T $m.link -nostdlib $obj -o $elf
    ^$objcopy -O binary $elf $image
    $id | save -f $stamp
}

# What a program's test or run needs, after building it with `names`
# set: the kernel built with the same symbols in the same tree, so a
# debug program runs on a debug kernel; standalone, with no workspace,
# JAB_KERNEL is taken as it is.
def prepared [dir: path, names: list<string>]: nothing -> record {
    build-program $dir $names
    let c = (context $dir "program" $names)
    if $c.workspace != null {
        let ws = (open ($c.workspace | path join "workspace.jab.toml"))
        build-kernel ($c.workspace | path join $ws.kernel) $names
    }
    let kernel = (kernel-elf $c)
    if not ($kernel | path exists) { error make {msg: $"no kernel at ($kernel); build the kernel first, with the same --set"} }
    { context: $c, kernel: $kernel, image: ($c.out | path join $"($c.manifest.name).jab") }
}

# Build the kernel and every program of the workspace at `ws` with
# `names` set.
def workspace-build [ws: path, names: list<string>]: nothing -> nothing {
    let m = (open ($ws | path join "workspace.jab.toml"))
    build-kernel ($ws | path join $m.kernel) $names
    for p in $m.programs { build-program ($ws | path join $p) $names }
}

# The arguments that run a program's test/test.nu on the kernel: the
# kernel, the image, the output directory, the assets image when the
# program has one, and the symbols the build was made with.
def test-args [ready: record]: nothing -> list<string> {
    let script = ($ready.context.here | path join "test" "test.nu")
    if not ($script | path exists) { error make {msg: $"($ready.context.manifest.name) has no test/test.nu"} }
    let assets = (assets-image $ready.context)
    let set = ($ready.context.symbols | str join ",")
    let common = [$script "--kernel" $ready.kernel "--image" $ready.image "--out" $ready.context.out "--set" $set]
    if $assets == "" { $common } else { $common ++ ["--assets" $assets] }
}

# The QEMU line that runs a program, built first: the QEMU it runs on
# (qemu-binary, beside the program and then in the workspace) and its
# arguments, the full virtio device set, the program's own disk when it
# has one else the blank image that has always been there, the debug
# channel to a file when DEBUG is set, the API's port when `api` asks,
# the window given (null for the one a run would open), the UART where
# `serial` says (`stdio` or `none`), and no monitor. The ports' files sit
# beside the build output, named in the README.
def run-line [dir: path, names: list<string>, api: bool, window: oneof<string, nothing>, serial: string, kbm: bool, pad: bool, sound: bool]: nothing -> record<qemu_binary: string, args: list<string>, window: string, context: record, bridge: oneof<record<name: string, vendor: oneof<int, nothing>, product: oneof<int, nothing>>, nothing>, pad_pipe: string> {
    let ready = (prepared $dir $names)
    let c = $ready.context
    let qemu = (qemu-binary $c.here $c.workspace)
    let machine = (machine-args $qemu)
    let assets = (assets-image $c)
    let disk = (if $assets == "" {
        let blank = ($c.target | path join "disk.img")
        if not ($blank | path exists) { ^truncate -s 64M $blank }
        $blank
    } else { $assets })
    let disk_serial = (if $assets == "" { "disk0" } else { disk-serial $c.manifest.name })
    let shown = (if $window == null { display $c.manifest } else { $window })
    let found = (if (discovery-wanted $pad $sound) { discover $c.workspace } else { { gamepad: null, audio: null } })
    let gamepad = (if $pad { gamepad-plan $found } else { { args: [], port: false, bridge: null } })
    let ports = (ports $c.symbols $c.out $api $gamepad.port)
    let inputs = (if $kbm { $input_devices } else { [] })
    let audio = (if $sound { sound-args (audio-plan ($found | get -o audio)) } else { [] })
    let args = ($machine ++ (name-args $c.manifest.name) ++ $memory ++ $display_device ++ $inputs ++ $gamepad.args ++ $devices ++ $audio ++ (disks-args (machine-disks $disk $disk_serial ($assets != "") $c.workspace)) ++ $ports.args ++ [
        "-bios" "none" "-kernel" $ready.kernel
        "-device" $"loader,file=($ready.image),addr=($program_base),force-raw=on"
        "-display" $shown "-serial" $serial "-monitor" "none"
    ] ++ (extra-args))
    let count = (transports $args)
    if $count > $transport_limit {
        error make {msg: $"the machine line carries ($count) virtio transports and virt has ($transport_limit): drop --api or --set debug, which share one, or run with --no-kbm, which frees two"}
    }
    { qemu_binary: $qemu, args: $args, window: $shown, context: $c, bridge: $gamepad.bridge, pad_pipe: $ports.pad_pipe }
}

# Whatever JAB_QEMU_ARGS holds, split into words as a shell would read
# them and nothing more, appended to a run's QEMU line after everything
# else: for looking at a run with QEMU's own instruments, `-trace
# alsa_* -trace virtio_snd_* -D trace.log` on a host where a stream
# misbehaves. No shell reads the value, so a quote is removed here and
# a `*` is passed as it is; quotes keep a word with spaces together, as
# `-D "my trace.log"`. Nothing without it.
def extra-args []: nothing -> list<string> {
    shell-words ($env.JAB_QEMU_ARGS? | default "")
}

# The words of a line as a POSIX shell splits them, nothing expanded
# and nothing run: spaces separate words; a run inside single or double
# quotes is part of one word with the quotes removed; a backslash keeps
# the character after it, outside single quotes. An unclosed quote is
# an error.
def shell-words [line: string]: nothing -> list<string> {
    mut words: list<string> = []
    mut word = ""
    mut in_word = false
    mut quote = ""
    mut escaped = false
    for c in ($line | split chars) {
        if $escaped {
            $word = ($word + $c)
            $escaped = false
            $in_word = true
        } else if $quote != "" {
            if $c == $quote {
                $quote = ""
            } else if $c == "\\" and $quote == '"' {
                $escaped = true
            } else {
                $word = ($word + $c)
            }
        } else if $c == "'" or $c == '"' {
            $quote = $c
            $in_word = true
        } else if $c == "\\" {
            $escaped = true
        } else if $c in [" " "\t" "\n"] {
            if $in_word {
                $words = ($words | append $word)
                $word = ""
                $in_word = false
            }
        } else {
            $word = ($word + $c)
            $in_word = true
        }
    }
    if $quote != "" { error make {msg: $"JAB_QEMU_ARGS: a ($quote) quote is not closed: ($line)"} }
    if $escaped { error make {msg: $"JAB_QEMU_ARGS: a backslash ends the value: ($line)"} }
    if $in_word { $words = ($words | append $word) }
    $words
}

# The virtio transports a QEMU line uses: every `-device` of a
# virtio-*-device, which is how a device rides virt's mmio transports;
# a port on the serial device's own bus, and the loader, ride none.
def transports [args: list<string>]: nothing -> int {
    $args | window 2 | where {|w| $w.0 == "-device" and ($w.1 =~ '^virtio-.*-device') } | length
}

# The gamepad on the line, when there is one, from jabdisco's record.
# On Linux the pad is passed through: JAB_PAD names its evdev path
# outright, else the expected pad's path from the record, and nothing
# goes on the line with none. On macOS QEMU cannot pass a pad through,
# so with a pad in the record the pad port goes on the line and the
# bridge, jabshim_pad, is to be started beside QEMU with the pad's
# identity, which is what `bridge` carries (doc/padport.md); Linux
# never takes that route. Any other host gets no pad.
def gamepad-plan [found: record]: nothing -> record<args: list<string>, port: bool, bridge: oneof<record<name: string, vendor: oneof<int, nothing>, product: oneof<int, nothing>>, nothing>> {
    let none = { args: [], port: false, bridge: null }
    let pad = ($found | get -o gamepad)
    match $nu.os-info.name {
        "linux" => {
            let forced = ($env.JAB_PAD? | default "")
            let path = (if $forced != "" { $forced } else if $pad == null { "" } else { $pad | get -o path | default "" })
            if $path == "" { $none } else { { args: ["-device" $"virtio-input-host-device,evdev=($path)"], port: false, bridge: null } }
        },
        "macos" => {
            if $pad == null { $none } else { { args: [], port: true, bridge: { name: $pad.name, vendor: ($pad | get -o vendor), product: ($pad | get -o product) } } }
        },
        _ => $none,
    }
}

# Whether a run needs jabdisco's record at all: for the pad, unless
# JAB_PAD names one or the host takes none; for the sound, unless
# JAB_AUDIO names the backend. Nothing is discovered that an
# override already decides.
def discovery-wanted [pad: bool, sound: bool]: nothing -> bool {
    let pad_wanted = ($pad and ($env.JAB_PAD? | default "") == "" and ($nu.os-info.name in ["linux" "macos"]))
    let sound_wanted = ($sound and ($env.JAB_AUDIO? | default "") == "")
    $pad_wanted or $sound_wanted
}

# jabdisco's record: the expected gamepad and the audio output, each
# null when it finds none. With no workspace to build jabdisco in the
# record is empty.
def discover [ws: oneof<string, nothing>]: nothing -> record {
    if $ws == null { return { gamepad: null, audio: null } }
    let disco = (disco-build $ws)
    let found = (^$disco | complete)
    if $found.exit_code != 0 { error make {msg: $"jabdisco failed:\n($found.stderr)"} }
    $found.stdout | from nuon
}

# The jabdisco binary, one package of the tool workspace (tool-build).
def disco-build [ws: path]: nothing -> string {
    tool-build $ws "jabdisco" "JAB_PAD names a pad's evdev path outright and --no-pad leaves the pad off; JAB_AUDIO names the audio backend outright and --no-sound leaves the sound device off"
}

# The robojab binary, the play harness, one package of the tool workspace
# (tool-build): its path, for a script that serves a planned machine to
# an agent.
export def robo-build [ws: path]: nothing -> string {
    tool-build $ws "robojab" "the harness needs it"
}

# A package of the tool workspace, tool/ in the jab workspace, built with
# cargo into its own target/ on first use and whenever it changes, so a
# `cargo build --release` there is the same build: the binary's path,
# named as the package is. `without` says what to do with no workspace.
def tool-build [ws: path, package: string, without: string]: nothing -> string {
    let tool = ($ws | path join "tool")
    let manifest = ($tool | path join "Cargo.toml")
    if not ($manifest | path exists) { error make {msg: $"no tool workspace in this one at ($tool); ($without)"} }
    let built = (^cargo build --release --quiet --manifest-path $manifest -p $package | complete)
    if $built.exit_code != 0 { error make {msg: $"building ($package) failed:\n($built.stderr)"} }
    $tool | path join "target" "release" $package
}

# Run a program with the console window, the UART on stdio; QEMU's exit
# code is the program's exit status. A run says nothing of its own.
# With a pad on the port, the bridge runs beside QEMU, started first
# so it is writing the header as the kernel comes up, and ended with
# it; the bridge ends itself as well once its pipe has no reader.
def run-program [dir: path, names: list<string>, api: bool, kbm: bool, pad: bool, sound: bool]: nothing -> nothing {
    let line = (run-line $dir $names $api null "stdio" $kbm $pad $sound)
    if ($line.window | str starts-with "vnc=") {
        print "no display server here, so this is a development run: the display is served over VNC on 127.0.0.1:5930; tunnel it with `ssh -N -L 5930:127.0.0.1:5930 <this host>` and view it with `vncviewer 127.0.0.1:5930`"
    }
    let bridge = (if $line.bridge == null { null } else {
        let bin = (shim-build $line.context.workspace "jabshim_pad" --bin)
        let pipe = ($line.pad_pipe + ".in")
        let b = $line.bridge
        let vendor = (if $b.vendor == null { "" } else { $b.vendor | into string })
        let product = (if $b.product == null { "" } else { $b.product | into string })
        job spawn { ^$bin $pipe $b.name $vendor $product | complete | ignore }
    })
    let qemu = $line.qemu_binary
    ^$qemu ...$line.args
    if $bridge != null { try { job kill $bridge } }
}

# A shim, one package of the workspace's shim/ workspace, built with
# cargo into .target/shim on first use and whenever it changes: the
# path of its shared library, to preload into QEMU, or with --bin of
# its binary.
def shim-build [ws: path, name: string, --bin]: nothing -> string {
    let manifest = ($ws | path join "shim" "Cargo.toml")
    let target = ($ws | path join ".target" "shim")
    let built = (^cargo build --release --quiet --manifest-path $manifest -p $name --target-dir $target | complete)
    if $built.exit_code != 0 { error make {msg: $"building the shim package ($name) failed:\n($built.stderr)"} }
    if $bin { $target | path join "release" $name } else { $target | path join "release" $"lib($name).so" }
}

# Probe a program under a window. `sdl`: run it under SDL with OpenGL
# for `seconds` with the shim of probe/sdl_shim preloaded into QEMU,
# then report how its flips reached the window.
def probe [dir: path, kind: string, names: list<string>, seconds: int]: nothing -> nothing {
    match $kind {
        "sdl" => { probe-sdl $dir $names $seconds },
        _ => { error make {msg: $"no probe called ($kind); there is `sdl`"} },
    }
}

# The SDL probe: the shim built with cargo into the workspace's .target,
# the program run under `sdl,gl=on` with the UART off for `seconds`, the
# shim's log read back, and one NUON record printed. Linux only, since
# it preloads a library into QEMU. With no display server SDL runs its
# offscreen driver, which draws nothing but keeps every path the same.
def probe-sdl [dir: path, names: list<string>, seconds: int]: nothing -> nothing {
    if $nu.os-info.name != "linux" { error make {msg: "the sdl probe preloads a library into QEMU, which is Linux only"} }
    let ws = (context $dir "program" $names | get workspace)
    if $ws == null { error make {msg: "the sdl probe needs the program's workspace, above it or named by its manifest, which holds shim/crates/sdl"} }
    let shim = (shim-build $ws "jabshim_sdl")
    let line = (run-line $dir $names false "sdl,gl=on" "none" true false false)
    let out = ($line.context.out | path join "probe")
    mkdir $out
    let log = ($out | path join "sdl.log")
    if ($log | path exists) { rm $log }
    let server = (($env.DISPLAY? | default "") != "") or (($env.WAYLAND_DISPLAY? | default "") != "")
    let driver = (if $server { "" } else { "offscreen" })
    let preload = { LD_PRELOAD: $shim, SDL_SHIM_LOG: $log }
    let extra = (if $driver == "" { $preload } else { $preload | insert SDL_VIDEODRIVER $driver })
    let binary = $line.qemu_binary
    let run = (with-env $extra { ^timeout --signal=TERM ($seconds | into string) $binary ...$line.args | complete })
    if not ($log | path exists) { error make {msg: $"QEMU wrote no shim log; its stderr:\n($run.stderr)"} }
    let qemu = (^$binary --version | complete | get stdout | lines | get -o 0 | default "")
    let report = (sdl-report $log)
    let record = ({
        run: {
            program: $line.context.manifest.name,
            os: $nu.os-info.name,
            qemu: $qemu,
            window: "sdl,gl=on",
            driver: (if $driver == "" { "the host's" } else { $driver }),
            symbols: $line.context.symbols,
            seconds: $seconds,
            qemu_said: ($run.stderr | lines | where {|l| not ($l | str contains "terminating on signal") } | first 3),
        },
    } | merge $report)
    print ($record | to nuon --indent 2)
}

# The report on a shim log: how the flips reached the window. A
# make_current followed by a window-size call within 2 ms opens a drawn
# frame. Any other is an upload: one per rectangle flushed when it comes
# through the virtio-gpu device, which its callers name, and otherwise
# one of the console's own, which a timer makes now and then and which
# is no flip of the program's. Flush uploads within 5 ms of the previous
# belong to one flip. A drawn frame with a flush upload under 3 ms on
# each side sits inside a flip, which is the half-drawn tick to look
# for.
def sdl-report [log: path]: nothing -> record {
    let events = (open --raw $log | decode | lines | each {|l| $l | parse --regex '^(?P<ts>\d+\.\d+) (?P<name>\S+)(?P<rest>.*)$' | get -o 0 } | compact | each {|e| { ts: ($e.ts | into float), name: $e.name, callers: ($e.rest | str trim) } })
    if ($events | is-empty) { error make {msg: "the shim log is empty; the window made no SDL calls"} }
    let t0 = ($events | first | get ts)
    let kinds = ($events | enumerate | each {|e|
        if $e.item.name != "make_current" { { ts: $e.item.ts, kind: $e.item.name, callers: "" } } else {
            let next = ($events | get -o ($e.index + 1))
            if $next != null and $next.name == "size" and (($next.ts - $e.item.ts) < 0.002) { { ts: $e.item.ts, kind: "render", callers: $e.item.callers } } else if ($e.item.callers | str contains "virtio-gpu") or ($e.item.callers | str contains "virtio_gpu") { { ts: $e.item.ts, kind: "upload", callers: $e.item.callers } } else { { ts: $e.item.ts, kind: "other_upload", callers: $e.item.callers } }
        }
    })
    let uploads = ($kinds | where kind == "upload")
    let others = ($kinds | where kind == "other_upload")
    let renders = ($kinds | where kind == "render" | get ts)
    let polls = ($kinds | where kind == "poll" | get ts)
    mut flips: list<record<start: float, end: float, size: int, gaps: list<float>>> = []
    for u in $uploads {
        if (($flips | length) > 0) and (($u.ts - ($flips | last | get end)) < 0.005) {
            let f = ($flips | last)
            $flips = (($flips | drop 1) ++ [{ start: $f.start, end: $u.ts, size: ($f.size + 1), gaps: ($f.gaps ++ [(($u.ts - $f.end) * 1000.0)]) }])
        } else {
            $flips = ($flips ++ [{ start: $u.ts, end: $u.ts, size: 1, gaps: [] }])
        }
    }
    let done = $flips
    mut last_upload = -1.0
    mut befores: list<float> = []
    for e in $kinds {
        if $e.kind == "upload" { $last_upload = $e.ts } else if $e.kind == "render" { $befores = ($befores ++ [(if $last_upload < 0.0 { 1.0 } else { $e.ts - $last_upload })]) }
    }
    mut next_upload = -1.0
    mut afters: list<float> = []
    for e in ($kinds | reverse) {
        if $e.kind == "upload" { $next_upload = $e.ts } else if $e.kind == "render" { $afters = ($afters ++ [(if $next_upload < 0.0 { 1.0 } else { $next_upload - $e.ts })]) }
    }
    let afters_in_order = ($afters | reverse)
    let befores_in_order = $befores
    let inside = ($renders | enumerate | each {|r|
        let before = (($befores_in_order | get $r.index) * 1000.0)
        let after = (($afters_in_order | get $r.index) * 1000.0)
        if $before < 3.0 and $after < 3.0 { { at: (($r.item - $t0) | math round -p 3), upload_before_ms: ($before | math round -p 2), upload_after_ms: ($after | math round -p 2) } } else { null }
    } | compact)
    let spans = ($done | where size > 1 | each {|f| ($f.end - $f.start) * 1000.0 })
    let gaps = ($done | get gaps | flatten)
    let cadence = ($done | window 2 | each {|w| ($w.1.start - $w.0.start) * 1000.0 })
    let intervals = ($renders | window 2 | each {|w| ($w.1 - $w.0) * 1000.0 })
    let hist = {|values: list<float>| $values | each {|v| $v | math round -p 0 } | uniq --count | sort-by count --reverse | first 6 | each {|c| { ms: $c.value, count: $c.count } } }
    let stat = {|values: list<float>| if ($values | is-empty) { { median: 0.0, max: 0.0 } } else { { median: ($values | math median | math round -p 2), max: ($values | math max | math round -p 2) } } }
    let range = {|values: list<float>| if ($values | is-empty) { { median: 0.0, min: 0.0, max: 0.0 } } else { { median: ($values | math median | math round -p 0), min: ($values | math min | math round -p 0), max: ($values | math max | math round -p 0) } } }
    # which guest frame each render showed: the flips whose last upload
    # landed since the render before it; none is the frame before shown
    # again, one is that flip shown, more is every one but the last
    # skipped, so a beat between the guest's cadence and the window's
    # timer reads as skips or repeats at a steady interval and a stall
    # as a burst of them
    let flip_count = ($done | length)
    mut next_flip = 0
    mut showings: list<record<at: float, flips: int>> = []
    for r in $renders {
        mut n = 0
        while ($next_flip < $flip_count) and (($done | get $next_flip | get end) <= $r) {
            $n += 1
            $next_flip += 1
        }
        $showings = ($showings ++ [{ at: ($r - $t0), flips: $n }])
    }
    let showed = $showings
    let repeats = ($showed | where flips == 0)
    let skips = ($showed | where flips > 1)
    let skipped = (if ($skips | is-empty) { 0 } else { $skips | each {|s| $s.flips - 1 } | math sum })
    let skip_times = ($skips | get at)
    let repeat_times = ($repeats | get at)
    let between = {|times: list<float>| $times | window 2 | each {|w| ($w.1 - $w.0) * 1000.0 } }
    {
        seconds_logged: ((($events | last | get ts) - $t0) | math round -p 1),
        flips: ($done | length),
        uploads_per_flip: ($done | get size | uniq --count | sort-by count --reverse | first 6 | each {|c| { uploads: $c.value, count: $c.count } }),
        flip_span_ms: (do $stat $spans),
        upload_gap_ms: (do $stat $gaps),
        flip_cadence_ms: (do $hist $cadence),
        renders: ($renders | length),
        render_interval_ms: (do $hist $intervals),
        frames_shown: { shown: ($showed | where flips == 1 | length), repeated: ($repeats | length), skipped: $skipped, unshown_at_end: ($flip_count - $next_flip) },
        skip_times_s: ($skip_times | first 24 | each {|t| $t | math round -p 3 }),
        skip_interval_ms: (do $range (do $between $skip_times)),
        repeat_times_s: ($repeat_times | first 24 | each {|t| $t | math round -p 3 }),
        repeat_interval_ms: (do $range (do $between $repeat_times)),
        renders_inside_flip: ($inside | length),
        inside_cases: ($inside | first 8),
        polls: ($polls | length),
        other_uploads: ($others | length),
        upload_callers: ($uploads | get callers | uniq --count | sort-by count --reverse | first 2 | each {|c| { callers: $c.value, count: $c.count } }),
        other_upload_callers: ($others | get callers | uniq --count | sort-by count --reverse | first 2 | each {|c| { callers: $c.value, count: $c.count } }),
        render_callers: ($kinds | where kind == "render" | get callers | uniq --count | sort-by count --reverse | first 2 | each {|c| { callers: $c.value, count: $c.count } }),
    }
}

# Build the kernel and every program of the workspace at `ws`; release
# unless --set says otherwise.
def "main workspace build" [ws: path, --set: string = ""] {
    workspace-build $ws (symbols $set)
}

# Test every program, a category, or one program, on a build with DEBUG
# set beside whatever --set names; prints each test's output and a
# summary, exits 1 if any fails. A test that drives the API asks
# `jab launch` for the port itself.
def "main workspace test" [ws: path, category: string = "", name: string = "", --set: string = ""] {
    let names = (with-debug (symbols $set))
    workspace-build $ws $names
    let m = (open ($ws | path join "workspace.jab.toml"))
    let selected = ($m.programs | where {|p| ($category == "" or ($p | str starts-with $"($category)/")) and ($name == "" or ($p | path basename) == $name) })
    if ($selected | is-empty) { error make {msg: $"no program matches ($category) ($name)"} }
    let results = ($selected | each {|p|
        let ready = (prepared ($ws | path join $p) $names)
        let r = (^nu ...(test-args $ready) | complete)
        print $"--- ($p)"
        print -n $r.stdout
        if $r.exit_code != 0 { print -n $r.stderr }
        { program: $p, passed: ($r.exit_code == 0) }
    })
    print ($results | table)
    if not ($results | all {|r| $r.passed }) { exit 1 }
}

# Build everything, then run one program with the console window;
# release unless --set says otherwise, the API's port on the machine
# with --api; the keyboard and the tablet on by default and off with
# --no-kbm; the gamepad found on the host attached by default and left
# off with --no-pad; the sound device over the host's audio by default
# and off with --no-sound.
def "main workspace run" [ws: path, category: string, name: string, --set: string = "", --api, --kbm, --no-kbm, --pad, --no-pad, --no-sound] {
    let names = (symbols $set)
    workspace-build $ws $names
    run-program ($ws | path join $category $name) $names $api (kbm-choice $kbm $no_kbm) (pad-choice $pad $no_pad) (not $no_sound)
}

# The keyboard and the tablet on the line: on unless --no-kbm, and
# never both flags of the pair.
def kbm-choice [kbm: bool, no_kbm: bool]: nothing -> bool {
    if $kbm and $no_kbm { error make {msg: "--kbm and --no-kbm together: one or the other"} }
    not $no_kbm
}

# The gamepad on the line: on unless --no-pad, and never both flags.
def pad-choice [pad: bool, no_pad: bool]: nothing -> bool {
    if $pad and $no_pad { error make {msg: "--pad and --no-pad together: one or the other"} }
    not $no_pad
}

# Build everything, then probe one program under a window for
# --seconds: `just probe sdl example walk`; release unless --set says
# otherwise. Prints one NUON record on how the program's flips reached
# the window.
def "main workspace probe" [ws: path, kind: string, category: string, name: string, --seconds: int = 12, --set: string = ""] {
    let names = (symbols $set)
    workspace-build $ws $names
    probe ($ws | path join $category $name) $kind $names $seconds
}

# Build the kernel at `dir` (--kernel) or the program at `dir`; release
# unless --set says otherwise.
# The headless machine for a program prepared and printed as JSON, for a
# harness in another language to run and drive: `nu jab.nu plan <dir>
# --disk <romfs> --serial fps --api --gamepad --set debug`, the kernel and
# the image the program's own builds, `out` under the program's build tree
# unless given.
def "main plan" [dir: path, --out: string = "", --disk: string = "", --serial: string = "disk0", --set: string = "", --api, --gamepad, --pad-port, --no-kbm, --sound] {
    let names = (symbols $set)
    let c = (context ($dir | path expand) "program" $names)
    let ready = (prepared ($dir | path expand) $names)
    let out = (if $out == "" { $c.target | path join "machine" } else { $out | path expand })
    plan --kernel $ready.kernel --image $ready.image --out $out --api=$api --disk $disk --serial $serial --set $set --gamepad=$gamepad --pad-port=$pad_port --no-kbm=$no_kbm --sound=$sound | to json
}

def "main build" [dir: path, --kernel, --set: string = ""] {
    let names = (symbols $set)
    if $kernel { build-kernel $dir $names } else { build-program $dir $names }
}

# Build the program at `dir` with DEBUG set beside whatever --set names
# and run its test/test.nu on the debug kernel.
def "main test" [dir: path, --set: string = ""] {
    ^nu ...(test-args (prepared $dir (with-debug (symbols $set))))
}

# Build the program at `dir` and run it with the console window; release
# unless --set says otherwise, the API's port on the machine with --api,
# the keyboard and the tablet off with --no-kbm, the gamepad off with
# --no-pad.
def "main run" [dir: path, --set: string = "", --api, --kbm, --no-kbm, --pad, --no-pad, --no-sound] {
    run-program $dir (symbols $set) $api (kbm-choice $kbm $no_kbm) (pad-choice $pad $no_pad) (not $no_sound)
}

# Build the program at `dir` and probe it under a window for --seconds;
# release unless --set says otherwise. `sdl` is the one probe.
def "main probe" [dir: path, kind: string, --seconds: int = 12, --set: string = ""] {
    probe $dir $kind (symbols $set) $seconds
}

# Remove the kernel's (--kernel) or the program's build output from both
# trees.
def "main clean" [dir: path, --kernel] {
    for names in [[] ["DEBUG"]] {
        let c = (context $dir (if $kernel { "kernel" } else { "program" }) $names)
        if ($c.out | path exists) { rm -r $c.out }
    }
}

def main [] {
    print "nu jab.nu <build|test|clean> <dir> [--kernel] [--set names]; nu jab.nu run <dir> [--set names] [--api] [--no-kbm] [--no-pad]; nu jab.nu probe <dir> sdl [--seconds N] [--set names]; nu jab.nu workspace <build|test|run> <ws> [category [name]] [--set names] [--api] [--no-kbm] [--no-pad]; nu jab.nu workspace probe <ws> sdl <category> <name> [--seconds N]; nu jab.nu watch <ws> [--skip N]"
}
