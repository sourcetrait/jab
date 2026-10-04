# jab.nu: the Jab SDK's nushell tooling.
#
# As a module (`use jab.nu`) it gives a program's integration test
# `jab launch`, which runs a program headless and can take its screen,
# and the helpers that read a screen: `jab screen`, `jab ink`,
# `jab pixel`, `jab thumbnail`. As a script (`nu jab.nu <command> ...`)
# it builds, runs, and tests the kernel and the programs for the
# repository's one justfile, doing every lookup the workspace defines:
# the programs (the members workspace.jab.toml lists and every other
# program under the workspace, each by its path from it or a word its
# `shortcuts` table names), the workspace directory (the nearest parent
# holding workspace.jab.toml, or the one a program's manifest names from
# outside any), the toolchain (RISCV_TOOLCHAIN, else extern/riscv beside
# the kernel or program, else the workspace's, else the tools on PATH,
# under the official triple or a distribution's name), QEMU (extern/qemu
# beside the program, else the workspace's, else qemu-system-riscv64 on
# PATH), the target (target-root: one tree for the whole workspace,
# .target at its root or $XDG_CACHE_HOME/jab/target/<checkout> where
# that is set, every build and every tool's output sharded within it),
# and the manifests. Nothing a build, a test, a bench, or a clean clears
# away is deleted: it is retired into the target's own tmp (retire).
#
# A build is described by its symbols: `--set debug,stats` names them,
# comma separated, in any case, and each reaches the assembler as
# `--defsym NAME=1` for `.ifdef NAME` to read, in the kernel and the
# programs alike. DEBUG picks the target's debug tree, and every other
# build lands in its release tree, so the two coexist. A program's
# manifest may name a `prepare` script, run before it is built, tested,
# or run, and an `adv` script, whose commands `just adv` lists. `test`
# always sets DEBUG, so a program's own debug reporting is there for its
# test; `run` and `build` are release unless asked otherwise. The API,
# a port between the program and the host, is not a build symbol: every
# kernel carries it, and `--api` on a run (or `jab launch --api`) puts
# the port on the machine, off by default, so one build runs either
# way. A build is skipped when its output is newer than every input and
# the flags, symbols included, match the last build.

# This tool's own file, which `adv` runs again for the SDK's commands.
const self = (path self)
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
# does: the directory of the program a built image came from, which the
# build writes beside the image as `home`. An image built before that
# is read from its path: a member's under the workspace's .target at the
# member's path, any other program's under the program's own .target,
# and an image under no .target is taken to sit beside its program.
def image-home [image: path]: nothing -> string {
    let marker = ($image | path expand | path dirname | path join "home")
    if ($marker | path exists) { return (open --raw $marker | decode | str trim) }
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
# The machine is headless unless `--window` puts it in the window a run
# of the program would open (`window`, `none` without); the sound device
# records to `sound` with `--sound`, or plays through the host's audio as
# a run's does with `--live-sound` (`audio`, the backend); and
# `--host-pad` attaches the host's own gamepad as a run does, on macOS
# through the bridge `bridge` names, to be started beside QEMU. A
# recording and the host's audio together are refused, as is the host's
# pad beside a scripted one. A previous run's files in `out` are retired,
# its pipes kept.
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
    --window
    --live-sound
    --host-pad
]: nothing -> record<qemu_binary: string, qemu: list<string>, env: record, out: string, serial_log: string, qemu_log: string, screen: string, pidfile: string, monitor: string, debug_log: string, api_in: string, api_out: string, pad_fifo: string, pad_pipe_in: string, pad_port: bool, pad_header: string, sound: string, workspace: string, window: string, audio: string, bridge: oneof<record<name: string, vendor: oneof<int, nothing>, product: oneof<int, nothing>>, nothing>> {
    if $sound and $live_sound { error make {msg: "--sound and --live-sound together: the recording or the host's audio, one or the other"} }
    if $host_pad and ($gamepad or $pad_port) { error make {msg: "--host-pad with a scripted pad: the host's own gamepad or a table, one or the other"} }
    let out = ($out | path expand)
    mkdir $out
    let log = ($out | path join "serial.log")
    let qemu_log = ($out | path join "qemu.log")
    let screen = ($out | path join "screen.ppm")
    let pidfile = ($out | path join "qemu.pid")
    let monitor = ($out | path join "monitor")
    for f in [$log $qemu_log $screen $pidfile] { retire $f }
    fifo-at ($monitor + ".in")
    fifo-at ($monitor + ".out")
    let ws = (launch-workspace $kernel $image $out)
    let qemu = (qemu-binary (image-home $image) $ws)
    let found = (if (discovery-wanted $host_pad $live_sound) { discover $ws } else { { gamepad: null, audio: null } })
    let hosted = (if $host_pad { gamepad-plan $found } else { { args: [], port: false, bridge: null } })
    let pad = (pad-attach $gamepad $out $pad_port $ws)
    let ports = (ports (symbols $set) $out $api ($pad.port or $hosted.port))
    let inputs = (if $no_kbm { [] } else { $input_devices })
    let wav = (if $sound { $out | path join "sound.wav" } else { "" })
    if $wav != "" { retire $wav }
    let backend = (if $sound { $"wav,path=($wav)" } else if $live_sound { audio-plan ($found | get -o audio) } else { "" })
    let audio = (if $sound { sound-args $backend --streams 1 } else if $live_sound { sound-args $backend } else { [] })
    let shown = (if $window { display (image-manifest $image) } else { "none" })
    let args = ((machine-args $qemu) ++ (name-args ($image | path parse | get stem)) ++ $memory ++ $display_device ++ $inputs ++ $hosted.args ++ $rng_device ++ $audio ++ $ports.args ++ $pad.args ++ [
        "-bios" "none" "-kernel" ($kernel | path expand)
        "-device" $"loader,file=($image | path expand),addr=($program_base),force-raw=on"
        "-display" $shown "-monitor" $"pipe:($monitor)" "-serial" $"file:($log)"
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
        window: $shown,
        audio: $backend,
        bridge: $hosted.bridge,
    }
}

# The workspace a launch belongs to, whose generic disk rides along and
# whose shims play a pad: the one the image's program builds against
# (workspace-of, through the manifest at the image's home), since the
# target an image and a kernel sit in can lie outside every workspace;
# else the one above the kernel's ELF, else the one above `out`.
def launch-workspace [kernel: path, image: path, out: path]: nothing -> oneof<string, nothing> {
    let home = (image-home $image)
    let manifest = ($home | path join "program.jab.toml")
    let found = (if ($manifest | path exists) { try { workspace-of $home (open $manifest) } catch { null } } else { null })
    if $found != null { return $found }
    workspace-dir ($kernel | path expand) | default (workspace-dir $out)
}

# The manifest of the program an image was built from (image-home), for
# the window it names; an empty record when there is none.
def image-manifest [image: path]: nothing -> record {
    let manifest = (image-home $image | path join "program.jab.toml")
    if ($manifest | path exists) { open $manifest } else { {} }
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
# one above `out`. `--window`, `--live-sound`, and `--host-pad` put the
# machine on the host as a run puts it, the window, the host's audio,
# and the host's own gamepad (plan), with the bridge run beside QEMU
# where the pad needs one and ended after; the screen and the timed
# actions go through the monitor and the pipes as headless. The result
# carries the machine's line, `qemu_binary` and `qemu`, with the
# `window` and the `audio` backend it ran with.
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
    --window                   # the window a run of the program opens, in place of none
    --live-sound               # the sound device over the host's audio as a run discovers it, in place of the --sound recording
    --host-pad                 # the host's own gamepad as a run attaches it, in place of a --pad table
]: nothing -> record<status: int, serial: string, debug: string, api: binary, screen: string, qemu_log: string, stderr: string, cpu_seconds: float, wall_seconds: float, sound: string, qemu_binary: string, qemu: list<string>, window: string, audio: string> {
    if $kbm and $no_kbm { error make {msg: "--kbm and --no-kbm together: one or the other"} }
    let gamepad = (pad-table $pad)
    let machine = (plan --kernel $kernel --image $image --out $out --api=($api or (not ($send | is-empty))) --disk $disk --serial $serial --set $set --gamepad=(not ($pad | is-empty)) --pad-port=$pad_port --no-kbm=$no_kbm --sound=$sound --window=$window --live-sound=$live_sound --host-pad=$host_pad)
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
    let bridge = (if $machine.bridge == null { null } else {
        let bin = (shim-build $machine.workspace "jabshim_pad" --bin)
        let b = $machine.bridge
        let vendor = (if $b.vendor == null { "" } else { $b.vendor | into string })
        let product = (if $b.product == null { "" } else { $b.product | into string })
        let pipe = $pad_in
        job spawn { ^$bin $pipe $b.name $vendor $product | complete | ignore }
    })
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
        # QEMU deletes its pid file as it exits, so the read is tried, never
        # checked first: an exit between a check and the open is no pid
        let pid = (try { open --raw $pidfile | str trim } catch { "" })
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
    if $bridge != null { try { job kill $bridge } }
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
        qemu_binary: $machine.qemu_binary,
        qemu: $machine.qemu,
        window: $machine.window,
        audio: $machine.audio,
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
# are verified on every build. Staged under the target's generic/ and
# built into its mix.romfs whenever the tree or the manifest changes,
# the archives kept under its fetch/, a stale stage retired. The path,
# or "" with no workspace or no generic/ in it.
def mix-image [ws: oneof<string, nothing>]: nothing -> string {
    if $ws == null { return "" }
    let generic = ($ws | path join "generic")
    if not ($generic | path exists) { return "" }
    let target = (target-root $ws)
    let image = ($target | path join "mix.romfs")
    let stamp = ($target | path join "mix.flags")
    let manifest_path = ($generic | path join "manifest.nuon")
    let manifest = (if ($manifest_path | path exists) { open $manifest_path } else { [] })
    let inputs = (tree-under [$generic])
    let flags = (build-id ($manifest | to nuon) $inputs)
    if ($image | path exists) and (not (stale $image $inputs $flags $stamp)) { return $image }
    let stage = ($target | path join "generic")
    retire $stage
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
        retire $unpack
        mkdir $unpack
        ^tar -xzf $archive -C $unpack ...($entry.members | get from)
        for m in $entry.members {
            let dest = ($stage | path join $m.to)
            mkdir ($dest | path dirname)
            mv ($unpack | path join $m.from) $dest
        }
        retire $unpack
    }
    assets-names $stage
    ^genromfs -d $stage -f $image -V (volume-name "mix")
    $flags | save -f $stamp
    $image
}

# An archive the manifest names, fetched into the target's fetch/ on
# first use, which a run says once since it can take a while, and verified
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
# not come up. A previous run's debug.log is retired.
def ports [names: list<string>, out: path, api: bool, pad_port: bool]: nothing -> record<args: list<string>, debug_log: string, api_pipe: string, pad_pipe: string> {
    mkdir $out
    let debug = (if "DEBUG" in $names {
        let log = ($out | path join "debug.log")
        retire $log
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
# the host writes into (fifo-at), and `<pipe>.out`, a plain file made
# empty, where the guest's bytes land, a previous run's retired first.
def pipe-pair [pipe: path]: nothing -> string {
    fifo-at ($pipe + ".in")
    let outward = ($pipe + ".out")
    retire $outward
    "" | save $outward
    $pipe
}

# A named pipe at `path`: one already there is kept, since a pipe holds
# nothing once every end has closed, and anything else there is retired
# before a fresh pipe is made.
def fifo-at [path: path]: nothing -> nothing {
    if ($path | path type) == "pipe" { return }
    retire $path
    ^mkfifo $path
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
    fifo-at $fifo
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
# has moved on: `assets` in its manifest, relative to the manifest, or
# `target_assets`, a tree the program's content compiles to under its
# asset shard of the target (program-shard), with the program's own name
# as the volume's. The image is what `just run` puts on the machine, and
# the program reads it with jab.sys.romfs.*.
def assets-image [c: record]: nothing -> string {
    let declared = ($c.manifest | get -o assets | default "")
    let compiled = ($c.manifest | get -o target_assets | default "")
    if $declared == "" and $compiled == "" { return "" }
    if $declared != "" and $compiled != "" { error make {msg: $"($c.manifest.name): assets and target_assets together; a program's disk is one or the other"} }
    let dir = (if $compiled != "" { shard-dir $c "asset" | path join $compiled } else { $c.here | path join $declared | path expand })
    if not ($dir | path exists) {
        let named = (if $compiled != "" { $"target_assets = '($compiled)'" } else { $"assets = '($declared)'" })
        error make {msg: $"($c.manifest.name): ($named) names no directory at ($dir)"}
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

# Where `watch` records: watch.nuonl in the workspace's target.
def watch-file [ws: path]: nothing -> string {
    target-root $ws | path join "watch.nuonl"
}

# What a recording says first about the QEMU it records: the host, the
# QEMU's version, the window, the kernel and the symbols it was built
# with, read from its tree's flags stamp, its pid, and when the
# recording started.
def watch-header [pid: int, started: datetime]: nothing -> record {
    let command = (ps -l | where pid == $pid | get -o 0.command | default "")
    let window = ($command | parse --regex '-display (?P<w>\S+)' | get -o 0.w | default "")
    let kernel = ($command | parse --regex '-kernel (?P<k>\S+)' | get -o 0.k | default "")
    let stamp_file = (if $kernel == "" { "" } else { $kernel | path dirname | path join "flags" })
    let stamp = (if $stamp_file != "" and ($stamp_file | path exists) { open --raw $stamp_file | decode | str trim } else { "" })
    let symbols = ($stamp | parse --regex '--defsym (?P<s>[A-Z0-9_]+)=1' | get s)
    let binary = (command-binary $command)
    let qemu = (try { ^$binary --version | complete | get stdout | lines | get -o 0 | default "" } catch { "" })
    { os: $nu.os-info.name, arch: $nu.os-info.arch, qemu: $qemu, window: $window, kernel: $kernel, symbols: $symbols, pid: $pid, started: ($started | format date "%Y-%m-%dT%H:%M:%S") }
}

# Record the running Jab QEMU per thread, once a second, to the
# workspace's target's watch.nuonl, a previous recording retired,
# whatever shell this is run from: a first line describing the run
# (watch-header), then a line per sample with every thread's cumulative
# CPU seconds, one short line printed per sample with the rates since
# the last. When the run ends, the report on the recording is printed to
# paste (watch-report-of), the first `--skip` seconds dropped as the
# load. Interrupted, it ends with no report. `watch bench` records a
# bench's runs instead.
def "main watch" [ws: path, --skip: float = 5.0] {
    let pids = (jab-pids)
    if ($pids | is-empty) { error make {msg: "no jab is running"} }
    let pid = ($pids | first)
    let file = (watch-file $ws)
    mkdir ($file | path dirname)
    retire $file
    let started = (date now)
    let run = (watch-header $pid $started)
    ({ run: $run } | to nuon) + (char nl) | save --raw $file
    print $"jab watch: recording ($pid) to ($file), ($run.symbols | str join ', ') under ($run.window)"
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
    print (watch-report-of $file $skip | to nuon --indent 2)
}

# The report on a recording `watch` made, as one NUON record: the run
# as recorded, the stretch reported on, and per thread the steady CPU
# seconds a second over that stretch and the peak second, with the
# process total; threads under 0.005 a second are left out. The stretch
# drops the first `skip` seconds as the load, or nothing for a run too
# short to spare them, `skipped` saying which. On macOS a thread is its
# row, and QEMU's worker threads come and go, so a row can change
# identity between samples: a row whose second-by-second rate is
# impossible for one thread, negative or past one, is reported with
# `stable: false` and no peak, its steady figure a mix.
def watch-report-of [file: path, skip: float]: nothing -> record {
    let lines = (open --raw $file | decode | lines | where {|l| ($l | str trim) != "" })
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

# The one build tree a workspace writes into, every build and every
# tool's output sharded within it: `.target` at the workspace's root, or
# where XDG_CACHE_HOME is set `$XDG_CACHE_HOME/jab/target/<checkout>`,
# the checkout its directory's name and the first eight hex digits of the
# SHA-256 of its path, so two checkouts on one machine never build over
# each other. `anchor` is the workspace, or a program with none above it.
export def target-root [anchor: path]: nothing -> string {
    let anchor = ($anchor | path expand)
    let cache = ($env.XDG_CACHE_HOME? | default "")
    if $cache == "" { return ($anchor | path join ".target") }
    let checkout = $"($anchor | path basename)-($anchor | hash sha256 | str substring 0..<8)"
    $cache | path expand | path join "jab" "target" $checkout
}

# Whether `dir` is a target this tool makes (target-root): a `.target`
# directory, or a checkout's under `jab/target` in the XDG cache.
def is-target [dir: path]: nothing -> bool {
    (($dir | path basename) == ".target") or (($dir | path dirname | path basename) == "target" and ($dir | path dirname | path dirname | path basename) == "jab")
}

# The target a path lies in, the nearest of its parents that is one
# (is-target), or null.
def target-of [path: path]: nothing -> oneof<string, nothing> {
    mut d = ($path | path expand --no-symlink | path dirname)
    loop {
        if (is-target $d) { return $d }
        let up = ($d | path dirname)
        if $up == $d { return null }
        $d = $up
    }
}

# Moves `path` out of the way whole in place of deleting it, so nothing a
# build, a test, a bench, or a clean clears away is lost: into the
# target's own tmp, `<target>/tmp/retired/<stamp>/`, at its path in the
# target, `root` when given, else the target the path lies in
# (target-of); a path outside the target lands under `outside/` there at
# its absolute path. A second retirement of one path within a second
# takes a numbered name, and `--stamp` sets the stamp, so a clean's
# entries share one. Nothing when nothing is there; a link is moved as a
# link. A path in no target with no root given is left as it is and
# refused. Untyped because it can end in an error.
export def retire [path: path, root?: path, --stamp: string = ""] {
    let from = ($path | path expand --no-symlink)
    if ($from | path type) == null { return }
    let target = (if $root != null { $root | path expand } else { target-of $from })
    if $target == null { error make {msg: $"($from) lies in no target, so there is nowhere to retire it to; it is left as it is"} }
    let stamp = (if $stamp == "" { date now | format date "%Y%m%d-%H%M%S" } else { $stamp })
    let rest = (if (under $from $target) { $from | path relative-to $target | path split } else { ["outside"] ++ ($from | path split | skip 1) })
    let at = ($target | path join "tmp" "retired" $stamp ...$rest)
    mut dest = $at
    mut n = 1
    while ($dest | path type) != null {
        $dest = $"($at).($n)"
        $n += 1
    }
    mkdir ($dest | path dirname)
    mv $from $dest
}

# Where a kernel's or a program's output lives in the target `root`:
# under its path relative to the workspace when it lies inside it,
# member or not; beside its own source when it lies inside the target
# itself, as a measured candidate's copy does, `inside`; under
# `external/<name>-<the first eight hex digits of its path's SHA-256>`
# when it lies outside both; under its name with no workspace.
def shard-of [here: path, workspace: oneof<string, nothing>, root: path, name: string]: nothing -> record<relative: string, inside: bool> {
    if (under $here $root) { return { relative: "", inside: true } }
    if $workspace == null { return { relative: $name, inside: false } }
    if (under $here $workspace) { return { relative: ($here | path relative-to $workspace | str replace --all "\\" "/"), inside: false } }
    { relative: (["external" $"($name)-($here | hash sha256 | str substring 0..<8)"] | path join), inside: false }
}

# A program's directory in the target for one purpose, whatever the
# tree: `<target>/<purpose>/<its shard>`, or `<its own>/<purpose>` for
# a program inside the target. The purposes: asset, the trees its
# content compiles to; bench, the benches' runs; gauge, measurements
# kept by name; candidates, measured copies of it; scratch.
export def program-shard [dir: path, purpose: string]: nothing -> string {
    let c = (context ($dir | path expand) "program" [])
    shard-dir $c $purpose
}

def shard-dir [c: record, purpose: string]: nothing -> string {
    if $c.inside { $c.here | path join $purpose } else { $c.root | path join $purpose $c.shard }
}

# Where a program's build of `tree`, release or debug, lands, its tests'
# and runs' output beside it.
export def program-out [dir: path, tree: string]: nothing -> string {
    (context ($dir | path expand) "program" (tree-symbols $tree)).out
}

# The kernel a program runs on in `tree` (kernel-elf).
export def program-kernel [dir: path, tree: string]: nothing -> string {
    kernel-elf (context ($dir | path expand) "program" (tree-symbols $tree))
}

# The symbols that put a build in `tree`: DEBUG for debug, none for
# release.
def tree-symbols [tree: string]: nothing -> list<string> {
    match $tree {
        "debug" => ["DEBUG"],
        "release" => [],
        _ => { error make {msg: $"a tree is release or debug, not ($tree)"} },
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
# empty source under `dir`'s march/ before a build assembles anything,
# the probe left there for the next; one that does not, binutils before
# 2.45, is refused with its version, since no other ISA will do. Untyped
# because it can end in an error.
def march-check [asm: string, march: string, dir: path] {
    let probe = ($dir | path join "march")
    mkdir $probe
    let source = ($probe | path join "march.S")
    let object = ($probe | path join "march.o")
    "" | save -f $source
    let tried = (^$asm $march $source -o $object | complete)
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
# link, its shims, and discovery come from there, and the program's own
# output lands in that workspace's target at the program's path
# (shard-of). Under a workspace the key is not read. Null with neither.
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
# workspace.jab.toml lists, by its workspace-relative path, which is how
# an image built before its `home` marker is placed (image-home).
def member-of [dir: path, ws: path]: nothing -> bool {
    if not (under $dir $ws) { return false }
    let relative = ($dir | path relative-to $ws | str replace --all "\\" "/")
    let listed = (open ($ws | path join "workspace.jab.toml"))
    $relative == $listed.kernel or ($relative in $listed.programs)
}

# The kernel's or a program's context for a build with `names` set:
# manifest, workspace (workspace-of), toolchain, symbols, the target
# (target-root, the workspace's or a lone program's own), the tree in
# it (debug or release), and the output directory, the tree's shard
# (shard-of).
def context [dir: path, kind: string, names: list<string>]: nothing -> record {
    let here = ($dir | path expand)
    let manifest_path = ($here | path join $"($kind).jab.toml")
    let manifest = (open $manifest_path)
    let workspace = (workspace-of $here $manifest)
    let tree = (profile $names)
    let root = (target-root (if $workspace == null { $here } else { $workspace }))
    let place = (shard-of $here $workspace $root $manifest.name)
    let target = (if $place.inside { $here | path join $tree } else { $root | path join $tree })
    let tc = (toolchain $here $workspace)
    {
        here: $here,
        manifest: $manifest,
        manifest_path: $manifest_path,
        workspace: $workspace,
        toolchain: $tc,
        prefix: (tool-prefix $tc),
        symbols: $names,
        profile: $tree,
        root: $root,
        shard: $place.relative,
        inside: $place.inside,
        target: $target,
        out: (if $place.inside { $target } else { $target | path join $place.relative }),
    }
}

# The kernel ELF a program runs on: the workspace's, in the same tree
# of that workspace's target, or JAB_KERNEL. Left untyped because it
# ends in an error, which the output check rejects.
def kernel-elf [c: record] {
    if $c.workspace != null {
        let ws = (open ($c.workspace | path join "workspace.jab.toml"))
        return (target-root $c.workspace | path join $c.profile $ws.kernel "jab.elf")
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
    for stray in (glob ($c.out | path join "*.o") | where {|o| $o not-in $objects }) { retire $stray }
    ^$ld -T $m.link -nostdlib ...$objects -o $elf
    ^$objdump -d $elf | save -f ($c.out | path join "jab.disas")
    $id | save -f $stamp
}

# Builds a program's image when stale, and writes beside it `home`, the
# program's directory, which image-home reads back from the image.
def build-program [dir: path, names: list<string>]: nothing -> nothing {
    let c = (context $dir "program" $names)
    let m = $c.manifest
    let includes = ($m | get -o includes | default [])
    let include_flags = ($includes | each {|i| ["-I" $i] } | flatten)
    let set_flags = (defsyms $names)
    let flags = (($include_flags ++ $set_flags ++ [$march_program $c.prefix]) | str join " ")
    let image = ($c.out | path join $"($m.name).jab")
    let stamp = ($c.out | path join "flags")
    mkdir $c.out
    let home = ($c.out | path join "home")
    if not ($home | path exists) or ((open --raw $home | decode | str trim) != $c.here) { $c.here | save -f $home }
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
# cargo into the target's shim/ on first use and whenever it changes:
# the path of its shared library, to preload into QEMU, or with --bin
# of its binary.
def shim-build [ws: path, name: string, --bin]: nothing -> string {
    let manifest = ($ws | path join "shim" "Cargo.toml")
    let target = (target-root $ws | path join "shim")
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

# The SDL probe: the shim built with cargo into the target's shim/, the
# program run under `sdl,gl=on` with the UART off for `seconds`, the
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
    retire $log
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

# Whether `dir` is a workspace's root, holding workspace.jab.toml.
def is-workspace [dir: path]: nothing -> bool {
    $dir | path expand | path join "workspace.jab.toml" | path exists
}

# Every program of the workspace at `ws` by its path from it: the members
# workspace.jab.toml lists, then the programs under its directory it does
# not list, the game's among them, found by their manifests outside the
# target, the cargo trees, and extern/.
def programs-of [ws: path]: nothing -> list<string> {
    let ws = ($ws | path expand)
    let listed = (open ($ws | path join "workspace.jab.toml") | get programs)
    let root = (target-root $ws)
    let found = (glob ($ws | path join "**" "program.jab.toml") --exclude ["**/.git/**" "**/.target/**" "**/target/**" "**/extern/**"]
        | each {|f| $f | path dirname }
        | where {|d| not (under $d $root) }
        | each {|d| $d | path relative-to $ws | str replace --all "\\" "/" }
        | where {|p| $p not-in $listed }
        | sort)
    $listed ++ $found
}

# A path given as words, each split on its slashes, so `example bounce`,
# `example/bounce`, and `game/fps/1k` all read; "" for none.
def path-words [words: list<string>]: nothing -> string {
    $words | each {|w| $w | split row "/" } | flatten | where {|w| $w != "" and $w != "." } | str join "/"
}

# A program's path in the workspace from words (path-words), a word the
# workspace's `shortcuts` table names standing for its path: `fps` for
# game/fps/1k.
def program-path [ws: path, words: list<string>]: nothing -> string {
    let at = (path-words $words)
    let shortcuts = (open ($ws | path expand | path join "workspace.jab.toml") | get -o shortcuts | default {})
    $shortcuts | get -o $at | default $at
}

# The programs at or under a path in the workspace, every program for no
# path; a path matching none is an error naming them all. Untyped because
# it ends in an error.
def programs-under [ws: path, words: list<string>] {
    let at = (program-path $ws $words)
    let all = (programs-of $ws)
    let picked = (if $at == "" { $all } else { $all | where {|p| $p == $at or ($p | str starts-with $"($at)/") } })
    if ($picked | is-empty) { error make {msg: $"no program at or under ($at); the programs: ($all | str join ', ')"} }
    $picked
}

# The one program at a path in the workspace, its directory. Untyped
# because it ends in an error.
def program-at [ws: path, words: list<string>] {
    let at = (program-path $ws $words)
    if $at == "" { error make {msg: "a program by its path from the workspace, or its shortcut: example/bounce, game/fps/1k, fps"} }
    let all = (programs-of $ws)
    if $at not-in $all { error make {msg: $"no program at ($at); the programs: ($all | str join ', ')"} }
    $ws | path expand | path join $at
}

# Whether a program, by its path from the workspace, is a test: one under
# a `test` directory, which `just test` runs and `just run` does not.
def is-test [at: string]: nothing -> bool {
    "test" in ($at | split row "/")
}

# The one program `just run` takes at a path in the workspace, its
# directory: any program but a test (is-test). Untyped because it ends
# in an error.
def run-target [ws: path, words: list<string>] {
    let at = (program-path $ws $words)
    let all = (programs-of $ws)
    let runnable = ($all | where {|p| not (is-test $p) })
    if $at == "" { error make {msg: $"a program to run by its path from the workspace, or its shortcut: ($runnable | str join ', ')"} }
    if $at in $all and (is-test $at) { error make {msg: $"($at) is a test; `just test ($at)` runs it"} }
    if $at not-in $runnable { error make {msg: $"no program to run at ($at); the programs: ($runnable | str join ', ')"} }
    $ws | path expand | path join $at
}

# A program's preparation before it is built, tested, or run: the script
# its manifest's `prepare` names, relative to the manifest, run from the
# program's directory with the phase, build, test, or run; nothing
# without one. A preparation that fails stops the command with its
# output.
def prepare [dir: path, phase: string]: nothing -> nothing {
    let here = ($dir | path expand)
    let script = (open ($here | path join "program.jab.toml") | get -o prepare | default "")
    if $script == "" { return }
    let r = (do { cd $here; ^nu ($here | path join $script) $phase } | complete)
    print -n $r.stdout
    if $r.exit_code != 0 { error make {msg: $"preparing ($here) to ($phase) failed:\n($r.stderr)"} }
}

# Build the kernel, then the programs at or under a path in the
# workspace, every program for none, each prepared first, with `names`.
def build-under [ws: path, words: list<string>, names: list<string>]: nothing -> nothing {
    let ws = ($ws | path expand)
    let m = (open ($ws | path join "workspace.jab.toml"))
    build-kernel ($ws | path join $m.kernel) $names
    for p in (programs-under $ws $words) {
        let dir = ($ws | path join $p)
        prepare $dir "build"
        build-program $dir $names
    }
}

# Test the programs at or under a path in the workspace, every program
# for none, each on a build with DEBUG beside `names` and prepared to
# test first; prints each test's output and a summary, exits 1 if any
# fails. A test that drives the API asks `jab launch` for the port
# itself.
def test-under [ws: path, words: list<string>, names: list<string>]: nothing -> nothing {
    let ws = ($ws | path expand)
    let names = (with-debug $names)
    let selected = (programs-under $ws $words)
    let m = (open ($ws | path join "workspace.jab.toml"))
    build-kernel ($ws | path join $m.kernel) $names
    let results = ($selected | each {|p|
        let dir = ($ws | path join $p)
        prepare $dir "test"
        let ready = (prepared $dir $names)
        let r = (^nu ...(test-args $ready) | complete)
        print $"--- ($p)"
        print -n $r.stdout
        if $r.exit_code != 0 { print -n $r.stderr }
        { program: $p, passed: ($r.exit_code == 0) }
    })
    print ($results | table)
    if not ($results | all {|r| $r.passed }) { exit 1 }
}

# The development commands, `just adv`: with no command the list, the
# SDK's own, probe and clean, then the kernel's and every program's, the
# `main <command>` definitions of the nushell script its manifest's `adv`
# names; with one, the SDK's or the script's that defines it, run with
# the rest of the words as they came, from the directory the command was
# given in, so a relative path among them is the caller's.
def --wrapped "main adv" [dir: path, ...words: string] {
    let ws = ($dir | path expand)
    if not (is-workspace $ws) { error make {msg: $"($ws) is no workspace's root"} }
    let commands = (adv-commands $ws)
    if ($words | is-empty) { print (adv-list $commands); return }
    let name = ($words | first)
    let rest = ($words | skip 1)
    if $name == "probe" { ^nu $self probe $ws ...$rest; return }
    if $name == "clean" { adv-clean $ws; return }
    let hit = ($commands | where command == $name)
    if ($hit | is-empty) { error make {msg: $"no development command called ($name); `just adv` lists them"} }
    ^nu ($hit | first | get script) $name ...$rest
}

# Every development command the kernel and the programs declare: the
# `main <command>` definitions of the script a manifest's `adv` names,
# relative to it, each with the comment above it, the script, and its
# owner's path and directory.
def adv-commands [ws: path]: nothing -> table<command: string, usage: string, owner: string, home: string, script: string, summary: string> {
    let m = (open ($ws | path join "workspace.jab.toml"))
    let owners = ([{ path: $m.kernel, manifest: "kernel.jab.toml" }] ++ (programs-of $ws | each {|p| { path: $p, manifest: "program.jab.toml" } }))
    $owners | each {|o|
        let home = ($ws | path join $o.path)
        let declared = (open ($home | path join $o.manifest) | get -o adv | default "")
        if $declared == "" { [] } else {
            let script = ($home | path join $declared)
            let lines = (open --raw $script | decode | lines)
            $lines | enumerate | each {|l|
                let hit = ($l.item | parse --regex '^def (?:--wrapped )?"main (?P<command>[^"]+)"\s*\[(?P<params>.*)\][^\]]*$' | get -o 0)
                if $hit == null { null } else {
                    let above = ($lines | first $l.index | reverse | take while {|x| $x | str starts-with "#" } | reverse | each {|x| $x | str replace --regex '^#\s?' '' } | str join " ")
                    { command: $hit.command, usage: (adv-usage $hit.params), owner: $o.path, home: $home, script: $script, summary: $above }
                }
            } | compact
        }
    } | flatten
}

# A command's arguments as `just adv` shows them, from its definition's
# parameters: a required one `<name>`, one with a default `[name]`, a
# flag `[--flag value]` or `[--flag]`, the rest `[args...]`.
def adv-usage [params: string]: nothing -> string {
    $params | split row "," | each {|p| $p | str trim } | where {|p| $p != "" } | each {|p|
        let name = ($p | split row ":" | first | split row "=" | first | str trim)
        let default = (if ($p | str contains "=") { $p | split row "=" | skip 1 | str join "=" | str trim | str trim --char '"' } else { "" })
        if ($name | str starts-with "...") { "[args...]" } else if ($name | str starts-with "--") {
            if ($p | str contains ":") { $"[($name) ($default)]" } else { $"[($name)]" }
        } else if $default != "" { $"[($name)]" } else { $"<($name)>" }
    } | str join " "
}

# The list `just adv` prints: each command with its arguments and its
# owner, and its description up to its first example or full stop.
def adv-list [commands: table]: nothing -> string {
    let sdk = [
        { command: "probe", usage: "<kind> <program> [--seconds 12] [--set names]", owner: "sdk", summary: "Probe one program under a window and print one NUON record on how its flips reached it, `sdl` the one kind, Linux only" }
        { command: "clean", usage: "", owner: "sdk", summary: "Retire everything every build, test, run, and bench here wrote into the target's own tmp, so the next build starts from nothing" }
    ]
    let all = ($sdk ++ ($commands | select command usage owner summary))
    let shown = ($all | each {|c|
        let cut = ($c.summary | split row ": `" | first | split row ". " | first)
        let usage = (if $c.usage == "" { "" } else { $" ($c.usage)" })
        $"  just adv ($c.command)($usage)  [($c.owner)]\n      ($cut)"
    })
    (["the commands for development, `just adv <command> [args]`:"] ++ $shown) | str join "\n"
}

# `just adv clean`: everything in the workspace's target but its tmp
# retired there under one stamp (retire), so the next build starts from
# nothing while nothing is deleted; only in a directory that is a target
# this tool makes (is-target). Emptying the target's tmp is the user's.
def adv-clean [ws: path]: nothing -> nothing {
    let target = (target-root $ws)
    if ($target | path type) != "dir" { print $"jab: no target at ($target)"; return }
    if not (is-target $target) { error make {msg: $"($target) is not a target this tool makes; leaving it"} }
    let stamp = (date now | format date "%Y%m%d-%H%M%S")
    let entries = (ls -a $target | get name | where {|e| ($e | path basename) != "tmp" })
    for e in $entries { retire $e $target --stamp $stamp }
    print $"jab: retired ($entries | length) entries of ($target) to ($target | path join 'tmp' 'retired' $stamp); emptying ($target | path join 'tmp') is yours"
}

# The benches of the workspace's programs, `<program>/<bench>` each: the
# NUON files under a program's bench/ directory.
def benches-of [ws: path]: nothing -> list<string> {
    programs-of $ws | each {|p|
        glob ($ws | path expand | path join $p "bench" "*.nuon") | sort | each {|f| $"($p)/($f | path parse | get stem)" }
    } | flatten
}

# The bench `name` names, `<program>/<bench>`, the program by its path
# or a shortcut (program-path): the program's path and directory, the
# bench's name and file, and its definition, held to its shape: a
# summary, and steps each with a label of its own and the script it runs
# with its arguments. Untyped because it ends in an error.
def bench-at [ws: path, name: string] {
    let words = ($name | split row "/" | where {|w| $w != "" })
    let all = (benches-of $ws)
    if ($words | length) < 2 { error make {msg: $"a bench by its program's path and its name, `just bench <program>/<bench>`: ($all | str join ', ')"} }
    let bench = ($words | last)
    let program = (program-path $ws ($words | drop 1))
    let file = ($ws | path expand | path join $program "bench" $"($bench).nuon")
    if not ($file | path exists) { error make {msg: $"no bench ($bench) in ($program); the benches: ($all | str join ', ')"} }
    let def = (open $file)
    if ($def | get -o summary) == null or ($def | get -o steps) == null { error make {msg: $"($file) needs a summary and steps"} }
    let labels = ($def.steps | each {|s| $s | get -o label | default "" })
    if ($labels | any {|l| $l == "" }) or ($labels | uniq | length) != ($labels | length) { error make {msg: $"($file): every step needs a label of its own"} }
    if ($def.steps | any {|s| ($s | get -o run | default [] | is-empty) }) { error make {msg: $"($file): every step needs `run`, its script and the script's arguments"} }
    { name: $"($program)/($bench)", program: $program, dir: ($ws | path expand | path join $program), bench: $bench, file: $file, def: $def }
}

# Where a bench's runs land: the program's bench shard of the target
# under the bench's name, each run a stamped directory in it, beside
# state.nuon, which says what the latest run is doing for `watch bench`.
def bench-home [b: record]: nothing -> string {
    program-shard $b.dir "bench" | path join $b.bench
}

# The list `just bench` prints: each bench with its summary.
def bench-list [ws: path]: nothing -> string {
    let shown = (benches-of $ws | each {|n|
        let b = (bench-at $ws $n)
        $"  just bench ($n)\n      ($b.def.summary)"
    })
    (["the benches, `just bench <program>/<bench>` with `just watch bench <program>/<bench>` in a second terminal:"] ++ $shown) | str join "\n"
}

# A bench's state file as its run last wrote it; null when there is
# none.
def bench-state [file: path]: nothing -> oneof<record, nothing> {
    if not ($file | path exists) { return null }
    try { open $file } catch { null }
}

# Whether the run a state describes is under way: not finished, and its
# process alive.
def bench-live [s: record]: nothing -> bool {
    ($s.state not-in [done failed]) and (process-alive ($s.pid | into string))
}

# The state file written whole, through a file beside it moved over it,
# so `watch bench` never reads half of one.
def bench-save-state [file: path, state: record]: nothing -> nothing {
    let next = $"($file).next"
    $state | to nuon | save --raw -f $next
    mv -f $next $file
}

# Run a bench, `just bench <program>/<bench>`: the NUON file of that name
# under the program's bench/ directory, with a summary, the tree, the
# steps, each a label and the program's script with its arguments and,
# for a step a person attends, `attend`, what they do; and the report, a
# script run over the run's directory at the end. The program is built
# in the tree, then every step runs in order with `--out` its own
# directory and `--label` its label, an attended step announced and
# counted down first, a step that fails recorded and the rest run; then
# the report. A run is a stamped directory in the program's bench shard
# of the target, its bench.nuon recording every step's outcome as it
# lands, and state.nuon beside the stamps says what the run is doing,
# for `just watch bench`. `--only` runs the steps its comma-separated
# labels name; with no bench, the list. Nothing is deleted: a run writes
# its own directory and the state.
def "main bench" [ws: path, name?: string, --only: string = ""] {
    let ws = ($ws | path expand)
    if not (is-workspace $ws) { error make {msg: $"($ws) is no workspace's root"} }
    if $name == null { print (bench-list $ws); return }
    let b = (bench-at $ws $name)
    let labels = ($b.def.steps | get label)
    let picked = ($only | split row "," | each {|l| $l | str trim } | where {|l| $l != "" })
    let unknown = ($picked | where {|l| $l not-in $labels })
    if not ($unknown | is-empty) { error make {msg: $"($b.name) has no step ($unknown | str join ', '); its steps: ($labels | str join ', ')"} }
    let steps = (if ($picked | is-empty) { $b.def.steps } else { $b.def.steps | where {|s| $s.label in $picked } })
    let tree = ($b.def | get -o tree | default "release")
    let names = (tree-symbols $tree)
    let home = (bench-home $b)
    let stamp = (date now | format date "%Y%m%d-%H%M%S")
    let dir = ($home | path join $stamp)
    if ($dir | path exists) { error make {msg: $"a run of ($b.name) started this second, at ($dir)"} }
    mkdir $dir
    let state_file = ($home | path join "state.nuon")
    let record_file = ($dir | path join "bench.nuon")
    let total = ($steps | length)
    let base = { bench: $b.name, stamp: $stamp, dir: $dir, pid: $nu.pid, started: (date now | format date "%Y-%m-%dT%H:%M:%S"), total: $total }
    mut record = {
        bench: $b.name, summary: $b.def.summary, tree: $tree, stamp: $stamp, started: $base.started, file: $b.file,
        steps: ($steps | each {|s| { label: $s.label, attend: ($s | get -o attend), run: $s.run, state: "pending", exit: null, seconds: null } }),
        report: null, state: "building",
    }
    $record | to nuon --indent 2 | save --raw $record_file
    bench-save-state $state_file ($base | merge { step: 0, label: "", state: "building" })
    print $"jab bench: ($b.name), ($total) steps, into ($dir): ($b.def.summary)"
    let broken = (try {
        let m = (open ($ws | path join "workspace.jab.toml"))
        build-kernel ($ws | path join $m.kernel) $names
        prepare $b.dir "build"
        build-program $b.dir $names
        null
    } catch {|e| $e.msg })
    if $broken != null {
        $record = ($record | merge { state: "failed" })
        $record | to nuon --indent 2 | save --raw -f $record_file
        bench-save-state $state_file ($base | merge { step: 0, label: "", state: "failed" })
        error make {msg: $"($b.name): the build failed: ($broken)"}
    }
    for entry in ($steps | enumerate) {
        let s = $entry.item
        let n = ($entry.index + 1)
        bench-save-state $state_file ($base | merge { step: $n, label: $s.label, state: "running" })
        let attend = ($s | get -o attend)
        if $attend != null {
            print $"jab bench: step ($n) of ($total), ($s.label): ($attend)"
            for left in 10..1 { print -n $"\r  starting in ($left) s "; sleep 1sec }
            print ""
        } else {
            print $"jab bench: step ($n) of ($total), ($s.label)"
        }
        let script = ($b.dir | path join ($s.run | first))
        let started = (date now)
        let code = (try {
            ^nu $script ...($s.run | skip 1) --out ($dir | path join $s.label) --label $s.label
            0
        } catch { $env.LAST_EXIT_CODE? | default 1 })
        let seconds = ((((date now) - $started) / 1sec) | math round --precision 1)
        let i = $entry.index
        let outcome = { state: (if $code == 0 { "done" } else { "failed" }), exit: $code, seconds: $seconds }
        let updated = ($record.steps | enumerate | each {|e| if $e.index == $i { $e.item | merge $outcome } else { $e.item } })
        $record = ($record | merge { steps: $updated })
        $record | to nuon --indent 2 | save --raw -f $record_file
        if $code != 0 { print $"jab bench: ($s.label) failed with exit ($code); on to the next step" }
    }
    bench-save-state $state_file ($base | merge { step: $total, label: "", state: "reporting" })
    let report = ($b.def | get -o report)
    let reported = (if $report == null { null } else {
        try { ^nu ($b.dir | path join ($report | first)) ...($report | skip 1) $dir; 0 } catch { $env.LAST_EXIT_CODE? | default 1 }
    })
    let failed = ($record.steps | where state != "done" | get label)
    let final = (if ($failed | is-empty) and ($reported == null or $reported == 0) { "done" } else { "failed" })
    $record = ($record | merge { report: $reported, state: $final })
    $record | to nuon --indent 2 | save --raw -f $record_file
    bench-save-state $state_file ($base | merge { step: $total, label: "", state: $final })
    let failures = (if ($failed | is-empty) { "" } else { $"; failed: ($failed | str join ', ')" })
    let unreported = (if $reported == null or $reported == 0 { "" } else { $"; the report failed with exit ($reported)" })
    print $"jab bench: ($b.name) ($final), ($total) steps($failures)($unreported); everything in ($dir)"
}

# The QEMUs of a bench's run: those whose command lines name its
# directory.
def bench-qemus [run: path]: nothing -> list<int> {
    ps -l | where {|p| ((command-binary $p.command | path basename) == (exe-name $qemu_name)) and ($p.command | str contains $run) } | get pid
}

# The busiest threads of a watch report as one short line.
def watch-top [threads: list<any>]: nothing -> string {
    $threads | first 4 | each {|t| $"($t.name) ($t.steady)" } | str join ", "
}

# A recording's threads' rates over its last `span` samples, the
# busiest first, as one short line; "" while it holds too few.
def watch-rates [file: path, span: int]: nothing -> string {
    let samples = (open --raw $file | decode | lines | where {|l| ($l | str trim) != "" } | skip 1)
    if ($samples | length) < 2 { return "" }
    let last = ($samples | last | from nuon)
    let first = ($samples | last ([($span + 1) ($samples | length)] | math min) | first | from nuon)
    let seconds = ($last.at - $first.at)
    if $seconds <= 0 { return "" }
    $last.threads | each {|t|
        let before = ($first.threads | where id == $t.id | get -o 0.cpu | default $t.cpu)
        { name: $t.name, rate: (($t.cpu - $before) / $seconds) }
    } | where rate >= 0.01 | sort-by rate --reverse | first 4 | each {|r| $"($r.name) ($r.rate | math round --precision 2)" } | str join "  "
}

# Record every QEMU of a bench's run, `just watch bench
# <program>/<bench>` in a second terminal: it waits for the bench's next
# run, or takes up one under way, then records each QEMU of the run per
# thread once a second, under the step running when it started, to
# watch/<step>-<n>.nuonl in the run's directory, a line printed as each
# starts and ends and the rates every five seconds. When the bench has
# finished and no QEMU of it is left, it prints the bench's report and
# its own per QEMU, the steady CPU seconds a second after the first
# `--skip` (watch-report-of), and writes them together as watch.nuon in
# the run's directory. Interrupted, it ends with no report.
def "main watch bench" [...words: string, --skip: float = 5.0] {
    if ($words | is-empty) { error make {msg: "nu jab.nu watch bench <program>/<bench> <workspace>"} }
    let ws = ($words | last | path expand)
    if not (is-workspace $ws) { error make {msg: $"($ws) is no workspace's root"} }
    let named = ($words | drop 1)
    if ($named | is-empty) { print (bench-list $ws); return }
    let b = (bench-at $ws ($named | first))
    let state_file = (bench-home $b | path join "state.nuon")
    let before = (bench-state $state_file)
    mut state = (if $before != null and (bench-live $before) { $before } else { null })
    if $state == null { print $"jab watch: waiting for ($b.name) to start: `just bench ($b.name)` in another terminal" }
    while $state == null {
        sleep 1sec
        let s = (bench-state $state_file)
        if $s != null and ($before == null or $s.stamp != $before.stamp) { $state = $s }
    }
    let run = $state.dir
    let stamp = $state.stamp
    let watch_dir = ($run | path join "watch")
    mkdir $watch_dir
    print $"jab watch: recording ($b.name)'s run ($stamp), ($state.total) steps, into ($watch_dir)"
    mut seen = []
    mut label = ""
    mut tick = 0
    loop {
        let read = (bench-state $state_file)
        let current = (if $read != null and $read.stamp == $stamp { $read } else { $state })
        if $current.label != "" and $current.label != $label { print $"jab watch: step ($current.step) of ($current.total), ($current.label)" }
        $label = $current.label
        let step = $label
        let pids = (bench-qemus $run)
        let known = ($seen | each {|e| $e.pid })
        for pid in ($pids | where {|p| $p not-in $known }) {
            let n = (($seen | where {|e| $e.label == $step } | length) + 1)
            let file = ($watch_dir | path join $"($step)-($n).nuonl")
            let started = (date now)
            retire $file
            ({ run: (watch-header $pid $started) } | to nuon) + (char nl) | save --raw $file
            $seen = ($seen | append { pid: $pid, label: $step, n: $n, file: $file, started: $started, ended: false })
            print $"jab watch: ($step), QEMU ($n), ($pid)"
        }
        let now = (date now)
        for e in ($seen | enumerate | where {|x| not $x.item.ended }) {
            if $e.item.pid in $pids {
                ({ at: (($now - $e.item.started) / 1sec), threads: (threads-of $e.item.pid) } | to nuon) + (char nl) | save --raw --append $e.item.file
            } else {
                let i = $e.index
                $seen = ($seen | enumerate | each {|x| if $x.index == $i { $x.item | merge { ended: true } } else { $x.item } })
                let r = (try { watch-report-of $e.item.file $skip } catch { null })
                print (if $r == null { $"jab watch: ($e.item.label), QEMU ($e.item.n) ended, too short to report" } else { $"jab watch: ($e.item.label), QEMU ($e.item.n) ended: ($r.process) of a core over ($r.seconds) s; (watch-top $r.threads)" })
            }
        }
        $tick += 1
        if ($tick mod 5) == 0 {
            for e in ($seen | where {|x| not $x.ended }) {
                let rates = (watch-rates $e.file 5)
                if $rates != "" { print $"  ($e.label) ($e.n): ($rates)" }
            }
        }
        let finished = ($current.state in [done failed]) or (not (process-alive ($current.pid | into string)))
        if $finished and ($pids | is-empty) and ($seen | all {|x| $x.ended }) { break }
        sleep 1sec
    }
    let last = (bench-state $state_file)
    let ended = (if $last == null or $last.stamp != $stamp { "superseded by a later run" } else if $last.state in [done failed] { $last.state } else { "ended unfinished" })
    let per = ($seen | each {|e|
        let w = (try { watch-report-of $e.file $skip } catch {|err| { error: $err.msg } })
        { step: $e.label, n: $e.n, pid: $e.pid, file: $e.file, watch: $w }
    })
    let text_file = ($run | path join "report.txt")
    print ""
    print $"jab watch: ($b.name)'s run ($stamp) ($ended)"
    print (if ($text_file | path exists) { open --raw $text_file | decode | str trim --right } else { "the bench wrote no report" })
    print "per QEMU, the steady CPU seconds a second:"
    for p in $per {
        print (if ($p.watch | get -o error) != null { $"  ($p.step) ($p.n): ($p.watch.error)" } else { $"  ($p.step) ($p.n): ($p.watch.process) of a core over ($p.watch.seconds) s; (watch-top $p.watch.threads)" })
    }
    let report_file = ($run | path join "report.nuon")
    let whole = {
        bench: $b.name, run: $stamp, dir: $run, state: $ended,
        steps: (try { open ($run | path join "bench.nuon") | get steps } catch { null }),
        report: (if ($report_file | path exists) { open $report_file } else { null }),
        watch: $per,
    }
    let out = ($run | path join "watch.nuon")
    retire $out
    $whole | to nuon --indent 2 | save --raw $out
    print $"jab watch: ($out)"
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

# The headless machine for a program prepared and printed as JSON, for a
# harness in another language to run and drive: `nu jab.nu plan <dir>
# --disk <romfs> --serial fps --api --gamepad --set debug`, the kernel and
# the image the program's own builds, `out` under the program's build tree
# unless given.
def "main plan" [dir: path, --out: string = "", --disk: string = "", --serial: string = "disk0", --set: string = "", --api, --gamepad, --pad-port, --no-kbm, --sound] {
    let names = (symbols $set)
    let c = (context ($dir | path expand) "program" $names)
    let ready = (prepared ($dir | path expand) $names)
    let out = (if $out == "" { $c.out | path join "machine" } else { $out | path expand })
    plan --kernel $ready.kernel --image $ready.image --out $out --api=$api --disk $disk --serial $serial --set $set --gamepad=$gamepad --pad-port=$pad_port --no-kbm=$no_kbm --sound=$sound | to json
}

# Build: at a workspace's root the kernel and every program, or the
# programs at or under a path (`example`, `example/bounce`,
# `game/fps/1k`), each prepared first; at a program's directory that
# program, prepared; with --kernel at the kernel's, the kernel. Release
# unless --set says otherwise.
def "main build" [dir: path, ...words: string, --kernel, --set: string = ""] {
    let names = (symbols $set)
    if (is-workspace $dir) { build-under $dir $words $names; return }
    if $kernel { build-kernel $dir $names } else {
        prepare $dir "build"
        build-program $dir $names
    }
}

# Test with DEBUG set beside whatever --set names: at a workspace's root
# every program's test, or those at or under a path, with a summary,
# failing if any fails; at a program's directory its test/test.nu on the
# debug kernel.
def "main test" [dir: path, ...words: string, --set: string = ""] {
    let names = (symbols $set)
    if (is-workspace $dir) { test-under $dir $words $names; return }
    prepare $dir "test"
    ^nu ...(test-args (prepared $dir (with-debug $names)))
}

# Build, then run one program with its window and the UART on stdio: at
# a workspace's root the program at a path, never a test (run-target),
# at a program's directory that program. Release unless --set says
# otherwise; the API's port on the machine with --api; the keyboard and
# the tablet off with --no-kbm, the gamepad the host has off with
# --no-pad, the sound device off with --no-sound. QEMU's exit code is
# the program's status.
def "main run" [dir: path, ...words: string, --set: string = "", --api, --kbm, --no-kbm, --pad, --no-pad, --no-sound] {
    let program = (if (is-workspace $dir) { run-target $dir $words } else { $dir | path expand })
    prepare $program "run"
    run-program $program (symbols $set) $api (kbm-choice $kbm $no_kbm) (pad-choice $pad $no_pad) (not $no_sound)
}

# Probe one program under a window for --seconds and print one NUON
# record on how its flips reached the window, at a workspace's root the
# program at a path, at a program's directory that program; release
# unless --set says otherwise. `sdl` is the one probe.
def "main probe" [dir: path, kind: string, ...words: string, --seconds: int = 12, --set: string = ""] {
    let program = (if (is-workspace $dir) { program-at $dir $words } else { $dir | path expand })
    prepare $program "run"
    probe $program $kind (symbols $set) $seconds
}

# Retire the kernel's (--kernel) or the program's build output from both
# trees (retire).
def "main clean" [dir: path, --kernel] {
    for names in [[] ["DEBUG"]] {
        let c = (context $dir (if $kernel { "kernel" } else { "program" }) $names)
        retire $c.out
    }
}

def main [] {
    print "nu jab.nu <build|test> <workspace> [path] [--set names]; nu jab.nu run <workspace> <path> [--set names] [--api] [--no-kbm] [--no-pad] [--no-sound]; nu jab.nu <build|test|run> <program dir> [--kernel] [--set names]; nu jab.nu probe <workspace> sdl <path> [--seconds N]; nu jab.nu adv <workspace> [command] [args]; nu jab.nu bench <workspace> [<program>/<bench>] [--only labels]; nu jab.nu clean <dir> [--kernel]; nu jab.nu watch [--skip N] <workspace>; nu jab.nu watch bench <program>/<bench> <workspace> [--skip N]; nu jab.nu plan <program dir> [flags]"
}
