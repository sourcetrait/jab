# jab.nu: the Jab SDK's nushell tooling.
#
# As a module (`use jab.nu`) it gives a program's integration test
# `jab launch`, which runs a program headless and can take its screen,
# and the capture module's helpers read it: `capture screen`, `capture ink`,
# `capture pixel`, `capture thumbnail`. As a script (`nu jab.nu <command> ...`)
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
# away is deleted: it is retired into the tmp beside the checkouts'
# targets, or into a `.target`'s own (retire), and `retire` is the one
# command that deletes, that tmp alone.
#
# A build is described by its symbols: `--set debug,stats` names them,
# comma separated, in any case, and each reaches the assembler as
# `--defsym NAME=1` for `.ifdef NAME` to read, in the kernel and the
# programs alike. DEBUG picks the target's debug tree, and every other
# build lands in its release tree, so the two coexist. A program's
# manifest may name a `prepare` script, run before it is built, tested,
# or run, and a `do` script, whose commands `just do` lists; and the
# `specs` it supports, by the names the workspace's asset/spec.nuon gives
# them, with the harts it reserves, `[reserved]`, and those each of its
# optional features demands, `[feature.<name>]`, which the build checks,
# hands the program as constants (program-demand), and records beside
# its image, where a launch reads it (image-demand). Every image begins
# with a page the build writes ahead of its code, the jump to it, a
# header, and for a program listing specs its declaration, each spec's
# definition and the base demand (header-source), which the kernel holds
# the machine to before the program starts and check-image reads. `test`
# always sets DEBUG, so a program's own debug reporting is there for its
# test; `run` and `build` are release unless asked otherwise. The API,
# a port between the program and the host, is not a build symbol: every
# kernel carries it, and `--api` on a run (or `jab launch --api`) puts
# the port on the machine, off by default, so one build runs either
# way. A build is skipped when its output is newer than every input and
# the flags, symbols included, match the last build.

use ../../nu/mod/audio
use ../../nu/mod/bound
use ../../nu/mod/build
use ../../nu/mod/chardev
use ../../nu/mod/demand
use ../../nu/mod/disco
use ../../nu/mod/disk
use ../../nu/mod/host
use ../../nu/mod/image
use ../../nu/mod/machine
use ../../nu/mod/nonce
use ../../nu/mod/pad
use ../../nu/mod/process
use ../../nu/mod/sdl/classify
use ../../nu/mod/sdl/log
use ../../nu/mod/sdl/symbols
use ../../nu/mod/target
use ../../nu/mod/tool
use ../../nu/mod/walk
use ../../nu/mod/workspace
use ../../nu/mod/machine [rng_device]

# This tool's own file, which `do` runs again for the SDK's commands.
const self = (path self)
# The window's base (jab.inc): the kernel's 2 MiB and the framebuffer's
# 8 MiB come first, and the program has the rest of the machine's 4 GiB.
const program_base = "0x80a00000"
# virt's map has this many virtio-mmio transports, a hard ceiling on
# the devices a line can carry.
const transport_limit = 8
const display_device = ["-device" "virtio-gpu-device,xres=1920,yres=1080"]
const input_devices = [
    "-device" "virtio-keyboard-device"
    "-device" "virtio-tablet-device"
]
const devices = [
    "-device" "virtio-net-device,netdev=net0" "-netdev" "user,id=net0"
] ++ $machine.rng_device

# A headless machine prepared and not run: everything a launch sets up
# before QEMU starts, handed back for whoever runs and drives it, the
# SDK's own `launch` or a harness that plays interactively. `qemu_binary`
# is the QEMU it runs on (qemu-binary, beside the program the image came
# from and then in the workspace, as a run's), `qemu` the whole argument
# vector after it, `env` what the process runs under (the evdev shim
# preloaded when a gamepad rides the fifo), and the rest the paths: the
# UART's log, QEMU's guest-error log, the screen a screendump lands in,
# the pid file, the monitor's pipe pair (`<monitor>.in` and `.out`), the
# debug channel's log under DEBUG, the API's `api_in` pipe and `api_out`
# file with `--api`, and the pad: with `--gamepad`, on Linux the fifo
# QEMU reads as the pad, which the driver writes 24-byte input_event
# records into, else (and with `--pad-port`) the pad port's `pad_pipe_in`
# pipe, whose header, `pad_header` as hex, the driver writes first, the
# pipes made. On Windows, where QEMU makes each pipe chardev one named
# pipe and waits for its client before it starts (pipe-path), each pipe's
# in-file is a plain file a writer appends to (pipe-write), and `relays`
# names the relay each pipe with no client of its own takes, the
# monitor's, the API's, and a scripted pad's port (relays-of), its
# binary `relay_binary` (relay-build), none and "" elsewhere;
# `bridge_pipe` is the pipe the pad bridge writes, "" with no pad port
# (bridge-pipe). The machine is headless unless `--window` puts it in the
# window a run of the program would open (`window`, `none` without); the sound device
# records to `sound` with `--sound`, or plays through the host's audio as
# a run's does with `--live-sound` (`audio`, the backend); and
# `--host-pad` attaches the host's own gamepad as a run does, on macOS
# through the bridge `bridge` names, to be started beside QEMU. A
# recording and the host's audio together are refused, as is the host's
# pad beside a scripted one. A previous run's files in `out` are retired
# into the retire home of `target`, the workspace's target or else the
# program's, wherever `out` lies (retire), its pipes kept; `target` is
# handed back for a harness that clears away files of its own. The
# machine is the one `--spec` names, or with `--harts` a custom one of 1
# to 8 harts, or with neither the configured default (machine-for), and
# `machine` is its record (machine-of), `below_minimum` true beside it
# where `bootargs` carries a debug kernel's jab.nominimum=1, which skips
# the program's minimum (knob-of); a named spec the image's demand
# does not list is refused before anything is made, a legacy image's run
# taking the named machine. `bootargs` goes to the kernel through QEMU's
# -append, into the device tree's /chosen, a named spec's
# `jab.spec=<name>` after it (spec-bootargs), where a debug kernel reads its test
# knobs, and the record's `bootargs` is the line as given; `dtb` hands the kernel that
# tree through -dtb in place of the one QEMU builds, QEMU checking its
# header before any hart runs. `demand` is the demand recorded with the
# image at its build (image-demand), null for a program on the legacy path
# and for an image with no record; a record that does not hold is refused.
# `send` is what a launch writes into the API at its times, kept as given
# in `sends`, and anything to send puts the port on as `--api` does. With
# `--sdl-probe`, a probing launch, Linux only: the window `sdl,gl=on`, the
# sdl shim built and preloaded beside any other (`shim`), logging to that
# file (`sdl_log`, a stale one retired), SDL's offscreen driver where no
# display server is. `capture_nonce` is the caller's, never minted here,
# 1 to 2^63 - 1 or none, handed to the shim as `SDL_SHIM_NONCE` in its
# sixteen hex digits (nonce-hex); `profile` the capture's, `paired` only
# with a nonce, `generic` for a probe that names none, "" for a run that
# claims none; `capture` the run's capture identity as it stands before
# QEMU starts (capture-identity).
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
    --spec: string = ""
    --harts: int = 0
    --bootargs: string = ""
    --dtb: path = ""
    --send: table<at: duration, bytes: binary> = []
    --sdl-probe: path = ""
    --capture-nonce: int = 0
    --profile: string = ""
]: nothing -> record<qemu_binary: string, timeout_binary: string, timeout_version: string, qemu: list<string>, env: record, out: string, serial_log: string, qemu_log: string, screen: string, pidfile: string, monitor: string, debug_log: string, api_in: string, api_out: string, pad_fifo: string, pad_pipe_in: string, pad_port: bool, pad_header: string, sound: string, workspace: string, target: string, window: string, audio: string, bridge: oneof<record<name: string, vendor: oneof<int, nothing>, product: oneof<int, nothing>>, nothing>, bridge_pipe: string, relays: list<record<endpoint: string, name: string, inward: string, outward: string, done: string>>, relay_binary: string, machine: record, bootargs: string, demand: oneof<record, nothing>, sends: table<at: duration, bytes: binary>, sdl_log: string, shim: string, capture_nonce: oneof<int, nothing>, profile: string, capture: record> {
    let out = ($out | path expand)
    let ws = (image workspace $kernel $image $out)
    # a debug kernel's jab.nominimum=1 skips a program's minimum, so the run
    # is recorded below it, where a release kernel reads no knob and refuses
    let asked = (machine resolve $ws $spec $harts)
    let machine = (if (machine knob-of $bootargs "jab.nominimum") == 1 { $asked | insert below_minimum true } else { $asked })
    let demand = (demand image $image)
    demand spec-listed $machine $demand ($image | path parse | get stem)
    if $sound and $live_sound { error make {msg: "--sound and --live-sound together: the recording or the host's audio, one or the other"} }
    if $host_pad and ($gamepad or $pad_port) { error make {msg: "--host-pad with a scripted pad: the host's own gamepad or a table, one or the other"} }
    let probed = ($sdl_probe != "")
    if $probed and $nu.os-info.name != "linux" { error make {msg: "--sdl-probe preloads the sdl shim into QEMU, which is Linux only"} }
    if $capture_nonce < 0 { error make {msg: $"--capture-nonce ($capture_nonce): a capture nonce is 1 to 2^63 - 1, or 0 for none"} }
    let profile = (if $profile == "" and $probed { "generic" } else { $profile })
    if $profile not-in ["" "generic" "paired"] { error make {msg: $"--profile ($profile): a capture's profile is paired or generic"} }
    if $profile == "generic" and not $probed { error make {msg: "--profile generic is a probing launch's, classification alone; it needs --sdl-probe"} }
    if $profile == "paired" and $capture_nonce == 0 { error make {msg: "--profile paired needs the run's --capture-nonce, minted by the caller that makes the request"} }
    mkdir $out
    let root = (target root (if $ws != null { $ws } else { image home $image }))
    let log = ($out | path join "serial.log")
    let qemu_log = ($out | path join "qemu.log")
    let screen = ($out | path join "screen.ppm")
    let pidfile = ($out | path join "qemu.pid")
    let monitor = ($out | path join "monitor")
    for f in [$log $qemu_log $screen $pidfile] { target retire $f $root }
    # a Windows run's pipes are named pipes, named by a nonce of its own
    let windows = ($nu.os-info.name == "windows")
    let nonce = (if $windows { random int 1.. } else { 0 })
    let watch = (if $windows { chardev pipe-pair $out "monitor" $nonce "windows" $root } else {
        chardev fifo-at ($monitor + ".in") $root
        chardev fifo-at ($monitor + ".out") $root
        { name: $monitor, inward: ($monitor + ".in"), outward: ($monitor + ".out") }
    })
    let qemu = (machine qemu-binary (image home $image) $ws)
    let bound = (bound timeout)
    let found = (if (disco discovery-wanted $host_pad $live_sound) { disco discover $ws } else { { gamepad: null, audio: null } })
    let hosted = (if $host_pad { pad gamepad-plan $found } else { { args: [], port: false, bridge: null } })
    let pad = (pad pad-attach $gamepad $out $pad_port $ws $root)
    let api_on = ($api or (not ($send | is-empty)))
    let ports = (chardev ports (build symbols $set) $out $api_on ($pad.port or $hosted.port) $root $nonce)
    # Windows' relays, one a pipe with no client of its own: the monitor's,
    # the API's, and a scripted pad's port, the host's pad's client being
    # the bridge
    let piped = (if not $windows { [] } else {
        [{ endpoint: "monitor", pipe: $watch } { endpoint: "api", pipe: $ports.api }] ++ (if $hosted.port { [] } else { [{ endpoint: "padport", pipe: $ports.pad }] })
    })
    let relays = (chardev relays-of $out $piped)
    let relay_binary = (chardev relay-build $relays $ws)
    let inputs = (if $no_kbm { [] } else { $input_devices })
    let wav = (if $sound { $out | path join "sound.wav" } else { "" })
    if $wav != "" { target retire $wav $root }
    let backend = (if $sound { $"wav,path=($wav)" } else if $live_sound { audio audio-plan ($found | get -o audio) } else { "" })
    let audio = (if $sound { audio sound-args $backend --streams 1 } else if $live_sound { audio sound-args $backend } else { [] })
    if $probed and $ws == null { error make {msg: "--sdl-probe needs the program's workspace, which holds shim/crates/sdl"} }
    let shim = (if $probed { tool shim $ws "jabshim_sdl" } else { "" })
    let sdl_log = (if $probed { $sdl_probe | path expand } else { "" })
    if $probed { target retire $sdl_log $root }
    let shown = (if $probed { "sdl,gl=on" } else if $window { machine display (image manifest $image) } else { "none" })
    let run_env = (if not $probed { $pad.env } else {
        let server = (($env.DISPLAY? | default "") != "") or (($env.WAYLAND_DISPLAY? | default "") != "")
        let preload = ([($pad.env | get -o LD_PRELOAD | default "") $shim] | where {|p| $p != "" } | str join " ")
        let nonce = (if $capture_nonce == 0 { {} } else { { SDL_SHIM_NONCE: (nonce hex $capture_nonce) } })
        let driver = (if $server { {} } else { { SDL_VIDEODRIVER: "offscreen" } })
        $pad.env | merge { LD_PRELOAD: $preload, SDL_SHIM_LOG: $sdl_log } | merge $nonce | merge $driver
    })
    let line = (machine spec-bootargs $machine $bootargs)
    let append = (if $line == "" { [] } else { ["-append" $line] }) ++ (if $dtb == "" { [] } else { ["-dtb" ($dtb | path expand)] })
    let args = ((machine machine-args $qemu $machine) ++ (machine name-args ($image | path parse | get stem)) ++ (machine memory-args $machine) ++ $display_device ++ $inputs ++ $hosted.args ++ $rng_device ++ $audio ++ $ports.args ++ $pad.args ++ [
        "-bios" "none" "-kernel" ($kernel | path expand)
        "-device" $"loader,file=($image | path expand),addr=($program_base),force-raw=on"
        "-display" $shown "-monitor" $"pipe:($watch.name)" "-serial" $"file:($log)"
        "-pidfile" $pidfile "-d" "guest_errors" "-D" $qemu_log
    ] ++ $append ++ (disk disks-args (disk machine-disks $disk $serial true $ws)))
    let planned = {
        qemu_binary: $qemu,
        timeout_binary: $bound.path,
        timeout_version: $bound.version,
        qemu: $args,
        env: $run_env,
        out: $out,
        serial_log: $log,
        qemu_log: $qemu_log,
        screen: $screen,
        pidfile: $pidfile,
        monitor: $monitor,
        debug_log: $ports.debug_log,
        api_in: (if $ports.api == null { "" } else { $ports.api.inward }),
        api_out: (if $ports.api == null { "" } else { $ports.api.outward }),
        pad_fifo: $pad.fifo,
        pad_pipe_in: (if $ports.pad == null { "" } else { $ports.pad.inward }),
        pad_port: $pad.port,
        pad_header: ($pad.header | encode hex),
        sound: $wav,
        workspace: ($ws | default ""),
        target: $root,
        window: $shown,
        audio: $backend,
        bridge: $hosted.bridge,
        bridge_pipe: (chardev bridge-pipe $ports.pad),
        relays: $relays,
        relay_binary: $relay_binary,
        machine: $machine,
        bootargs: $line,
        demand: $demand,
        sends: $send,
        sdl_log: $sdl_log,
        shim: $shim,
        capture_nonce: (if $capture_nonce == 0 { null } else { $capture_nonce }),
        profile: $profile,
    }
    $planned | insert capture (capture-identity $planned null)
}

# A run's capture identity, what its identity records of the capture
# (CaptureBundle), from a machine as plan prepared it and the pid of the
# QEMU that ran it, read while it lived (null before or without one): the
# profile; `capture_nonce`; `qemu_pid`; the shim's log and library, ""
# for a run unprobed; the window; `api`, whether the API's port was on the
# machine; and `sends`, each entry to write into it by its time in
# seconds, its bytes' length, and their SHA-256.
export def capture-identity [machine: record, pid: oneof<int, nothing>]: nothing -> record<profile: string, capture_nonce: oneof<int, nothing>, qemu_pid: oneof<int, nothing>, sdl_log: string, shim: string, window: string, api: bool, sends: list<record<at: float, length: int, sha256: string>>> {
    {
        profile: $machine.profile,
        capture_nonce: $machine.capture_nonce,
        qemu_pid: $pid,
        sdl_log: $machine.sdl_log,
        shim: $machine.shim,
        window: $machine.window,
        api: ($machine.api_in != ""),
        sends: ($machine.sends | each {|s| { at: ($s.at / 1sec), length: ($s.bytes | bytes length), sha256: ($s.bytes | hash sha256) } }),
    }
}

# Run a program on the kernel under QEMU with no window, the UART to
# serial.log in `out`, for at most `seconds`. The status is what jab.sys.exit
# gave, 1 on a program fault, 124 when the bound ended the run. With
# `capture`, the screen is taken into screen.ppm that long after the
# start and the run is then ended (status 0); with `screen`, it is taken
# that long after the start while the run goes on to its bound or its
# exit; with `keys`, each key is pressed through the monitor that long
# after the start. `set` names the
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
# events, and the screen, go in while QEMU's process is alive, which
# is asked of the process table rather than of /proc, so they happen
# on every host. Each poll takes the keys, the API bytes, and the pad
# events in due-order's order: every one due in the order of its time,
# and the screen after those due before its time and ahead of those
# due at or after it, which wait until its file is whole
# (screen-whole); a screen that fails or never comes whole leaves the
# result no screen and every action after it unwritten.
# `screen_started` and `screen_completed` are the screen's asking and
# its file's completion, and `send_seconds` each entry of `send`'s
# write, all seconds from the start, null for what never happened. The
# workspace, whose generic disk rides along and whose shim plays a pad,
# is the one above the kernel ELF, else the one above `out`. `--window`, `--live-sound`, and `--host-pad` put the
# machine on the host as a run puts it, the window, the host's audio,
# and the host's own gamepad (plan), with the bridge run beside QEMU
# where the pad needs one and ended after; the screen and the timed
# actions go through the monitor and the pipes as headless. The result
# carries the machine's line, `qemu_binary` and `qemu`, with the
# `window` and the `audio` backend it ran with, and `machine`, the
# record of the machine it had (machine-of); `--spec`, `--harts`,
# `--bootargs`, and `--dtb` are plan's. With `--threads`, every QEMU thread's CPU is read
# that long after the start and again a second on (threads-of), each
# reading timed as it is taken, since the loop polls: `threads_span` is
# the seconds between the two, a second give or take a poll, and
# `threads` carries each thread's name, the CPU seconds it used in
# between, and those over the span (threads-between), the harts' threads
# named `CPU N/TCG` on Linux; empty, its span null, when the run ended
# before the second reading. With `--threads-at`, every QEMU thread's
# cumulative CPU seconds are read at each time it lists, `thread_readings`
# keeping each reading whole: the time asked, `requested`, and the time
# it was taken, `at`, both seconds from the launch's start, which comes
# before QEMU's spawn, the reading taken at the first poll past its
# request, so `at` trails `requested` by up to a poll; and every thread's
# id, name, and counter (threads-of); a time the run ended before keeps
# its request with `at` and `threads` null, missing. `--qemu` appends words of its own
# to the line, unchanged, after the launch's: a device or a property a
# test needs that no launch flag gives. Such a run is diagnostic, its
# `machine` keeping the platform asked for with the words in its
# `overrides`, and the words
# come back apart as `overrides` too, so the requested platform and the
# custom command stay distinct; `qemu` is the line as it ran. `declared`
# says whether the demand recorded with the image at its build declares
# one (image-demand), and `diagnostic` is the run's standing: on a
# custom machine, with QEMU words of its own, of an image built on the
# legacy path or with no record beside it, undeclared and claiming no
# console, or below its program's minimum (plan's `below_minimum`). `--sdl-probe`,
# `--capture-nonce`, and `--profile` are plan's, the nonce the caller's,
# minted here only for a probing launch given none (launch-nonce); the
# launch writes the API only what its caller sends, never for itself. On
# Windows, where QEMU waits for a client of each of its pipes before it
# starts, the relays plan names start beside QEMU, a job each
# (relays-start), every write goes into a pipe's in-file (pipe-write), and
# once QEMU has ended each relay is given a second to end with its pipe,
# any left stopped, and one that ended in failure fails the launch,
# naming its pipe (relays-held).
# `qemu_pid` is QEMU's pid as the loop read it while QEMU lived, since
# QEMU removes its pid file as it exits, null where it never came up; the
# result carries `sdl_log`, `shim`, `capture_nonce`, and `profile` as
# planned, and `capture`, the run's capture identity (capture-identity).
export def launch [
    --kernel: path             # the kernel ELF
    --image: path              # the program's .jab
    --out: path                # where serial.log and the rest go
    --seconds: int = 10        # the bound
    --capture: duration = 0sec # when to take the screen and end the run; 0 never
    --screen: duration = 0sec  # when to take the screen while the run goes on; 0 never
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
    --spec (-s): string = ""   # the named spec the machine is, its cores, RAM, and display; the configured default unless given
    --harts: int = 0           # a custom machine of 1 to 8 harts in place of a named spec, the run then diagnostic
    --bootargs: string = ""    # the kernel's command line, its debug knobs, through -append
    --dtb: path = ""           # a device tree for the kernel in place of QEMU's, through -dtb
    --threads: duration = 0sec # when to read every QEMU thread's CPU and again a second on, the result's `threads` and `threads_span`; 0 never
    --threads-at: list<duration> = [] # each time to read every QEMU thread's CPU, kept whole in the result's `thread_readings`; none unless given
    --qemu: list<string> = []  # words appended to the QEMU line unchanged, after the launch's own; the run is then diagnostic
    --sdl-probe: path = ""     # the sdl shim's log: QEMU under sdl,gl=on with the shim preloaded, Linux only
    --capture-nonce: int = 0   # the run's capture nonce from the caller making the request; minted here for a probe given none
    --profile: string = ""     # the capture's profile, paired or generic (plan)
]: nothing -> record<status: int, serial: string, debug: string, api: binary, screen: string, qemu_log: string, stderr: string, cpu_seconds: float, wall_seconds: float, sound: string, qemu_binary: string, timeout_binary: string, timeout_version: string, qemu: list<string>, overrides: list<string>, window: string, audio: string, machine: record, threads: list<record<name: string, delta: float, rate: float>>, threads_span: oneof<float, nothing>, thread_readings: list<any>, screen_started: oneof<float, nothing>, screen_completed: oneof<float, nothing>, send_seconds: list<oneof<float, nothing>>, declared: bool, diagnostic: bool, qemu_pid: oneof<int, nothing>, sdl_log: string, shim: string, capture_nonce: oneof<int, nothing>, profile: string, capture: record> {
    if $kbm and $no_kbm { error make {msg: "--kbm and --no-kbm together: one or the other"} }
    if $capture != 0sec and $screen != 0sec { error make {msg: "--capture and --screen together: one screen a run, ending it or not"} }
    let gamepad = (pad pad-table $pad)
    let nonce = (nonce mint $capture_nonce ($sdl_probe != ""))
    let machine = (plan --kernel $kernel --image $image --out $out --api=$api --send $send --disk $disk --serial $serial --set $set --gamepad=(not ($pad | is-empty)) --pad-port=$pad_port --no-kbm=$no_kbm --sound=$sound --window=$window --live-sound=$live_sound --host-pad=$host_pad --spec $spec --harts $harts --bootargs $bootargs --dtb $dtb --sdl-probe $sdl_probe --capture-nonce $nonce --profile $profile)
    let send = $machine.sends
    let out = $machine.out
    let log = $machine.serial_log
    let qemu_log = $machine.qemu_log
    let screen_file = $machine.screen
    let pidfile = $machine.pidfile
    let monitor = $machine.monitor
    let ports = { debug_log: $machine.debug_log }
    let wav = $machine.sound
    let line = ($machine.qemu ++ $qemu)
    let disked = (["--signal=TERM" $"($seconds)" $machine.qemu_binary] ++ $line)
    let api_out = $machine.api_out
    let api_in = $machine.api_in
    let pad_in = $machine.pad_pipe_in
    let gamepad = ($gamepad | merge { port: $machine.pad_port, fifo: $machine.pad_fifo, header: ($machine.pad_header | decode hex), env: $machine.env })
    let bridge = (if $machine.bridge == null { null } else {
        let bin = (tool shim $machine.workspace "jabshim_pad" --bin)
        let b = $machine.bridge
        let vendor = (if $b.vendor == null { "" } else { $b.vendor | into string })
        let product = (if $b.product == null { "" } else { $b.product | into string })
        let pipe = $machine.bridge_pipe
        job spawn { ^$bin $pipe $b.name $vendor $product | complete | ignore }
    })
    # the timed actions in the order a poll takes them (due-order): by
    # time, and at one time the keys, then the API's bytes, then the pad's
    # groups, each in its table's order
    let events = ([
        ($keys | enumerate | each {|e| { kind: "key", index: $e.index, at: $e.item.at } })
        ($send | enumerate | each {|e| { kind: "send", index: $e.index, at: $e.item.at } })
        ($gamepad.groups | enumerate | each {|e| { kind: "pad", index: $e.index, at: $e.item.at } })
    ] | flatten | enumerate | each {|e| $e.item | insert order $e.index } | sort-by at order | reject -o order)
    let started = (date now)
    let bound = $machine.timeout_binary
    job spawn { with-env $gamepad.env { ^$bound ...$disked | complete } | job send 0 }
    let relays = (chardev relays-start $machine.relays $machine.relay_binary $machine.target)
    mut result: any = null
    mut cpu = 0.0
    mut events_taken = 0
    mut screen_due = (if $capture != 0sec { $capture } else if $screen != 0sec { $screen } else { null })
    mut screen_started: any = null
    mut screen_completed: any = null
    mut held = false
    mut send_seconds = ($send | each --keep-empty {|_| null })
    mut header_sent = (not $gamepad.port)
    mut threads_first: any = null
    mut threads_held: any = null
    let thread_requests = ($threads_at | sort)
    mut readings = []
    mut taken = 0
    mut qemu_pid: any = null
    while $result == null {
        $result = (try { job recv --timeout 100ms } catch { null })
        # QEMU deletes its pid file as it exits, so the read is tried, never
        # checked first: an exit between a check and the open is no pid
        let pid = (try { open --raw $pidfile | str trim } catch { "" })
        let alive = ($result == null and (process process-alive $pid))
        # the pid kept while QEMU lives, its pid file gone once it ends
        if $alive and $qemu_pid == null { $qemu_pid = ($pid | into int) }
        let sample = (if $pid == "" { null } else { process cpu-seconds $pid })
        if $sample != null { $cpu = $sample }
        let elapsed = ((date now) - $started)
        # the pad port's header goes in as soon as QEMU is up, before any
        # event, since the kernel waits for the whole of it
        # every write into QEMU's pipes is bounded (pipe-write), since QEMU
        # can end between the check that it runs and the write
        if (not $header_sent) and $alive {
            chardev pipe-write $pad_in $gamepad.header $bound | ignore
            $header_sent = true
        }
        # every due action in due-order's order: a screen that fails holds
        # every action after it for the rest of the run, as the capture's
        # quit does
        if not $held {
            for action in (due-order ($events | skip $events_taken) $screen_due $elapsed) {
                if $action.kind == "screen" {
                    $screen_started = (((date now) - $started) / 1sec)
                    let asked = (if $alive { chardev monitor-send $monitor $"screendump (chardev hmp-quoted $screen_file)" $bound } else { false })
                    if not ($asked and (chardev screen-whole $screen_file)) {
                        $held = true
                        break
                    }
                    $screen_completed = (((date now) - $started) / 1sec)
                    $screen_due = null
                    if $capture != 0sec {
                        if (process process-alive $pid) { chardev monitor-send $monitor "quit" $bound | ignore }
                        $held = true
                        break
                    }
                } else {
                    let written = (if not $alive { false } else if $action.kind == "key" {
                        let k = ($keys | get $action.index)
                        chardev monitor-send $monitor $"sendkey ($k.key) ($k.hold)" $bound
                    } else if $action.kind == "send" {
                        if $api_in == "" { false } else { chardev pipe-write $api_in ($send | get $action.index | get bytes) $bound }
                    } else {
                        let g = ($gamepad.groups | get $action.index)
                        if $gamepad.port { chardev pipe-write $pad_in (pad pad-frames $g.items) $bound } else if $gamepad.fifo != "" { chardev fifo-write $gamepad.fifo (pad pad-report $g.items) $bound } else { false }
                    })
                    if $written and $action.kind == "send" {
                        $send_seconds = ($send_seconds | update $action.index (((date now) - $started) / 1sec))
                    }
                    $events_taken += 1
                }
            }
        }
        # each thread's CPU over the held span: a reading at `threads`,
        # another a second on, each timed as it is taken, since the loop
        # polls and the span is a second give or take a poll
        if $threads != 0sec and $alive {
            if $threads_first == null and $elapsed >= $threads {
                let reading = (process threads-of ($pid | into int))
                $threads_first = { threads: $reading, at: (date now) }
            } else if $threads_first != null and $threads_held == null and $elapsed >= ($threads + 1sec) {
                let reading = (process threads-of ($pid | into int))
                let at = (date now)
                $threads_held = (process threads-between $threads_first.threads $reading (($at - $threads_first.at) / 1sec))
            }
        }
        # every thread's counter at each time `--threads-at` asks, read at
        # the first poll past it, its own time taken with it
        while $alive and $taken < ($thread_requests | length) and ($thread_requests | get $taken) <= $elapsed {
            let threads = (process threads-of ($pid | into int))
            $readings = ($readings | append { requested: (($thread_requests | get $taken) / 1sec), at: (((date now) - $started) / 1sec), threads: $threads })
            $taken += 1
        }
    }
    let unread = ($thread_requests | skip $taken | each {|r| { requested: ($r / 1sec), at: null, threads: null } })
    let relayed = (chardev relays-stop $relays)
    if $bridge != null { try { job kill $bridge } }
    chardev relays-held $relayed $result
    let ran_on = ($machine.machine | update overrides $qemu)
    {
        status: $result.exit_code,
        serial: (if ($log | path exists) { open --raw $log | decode } else { "" }),
        debug: (if $ports.debug_log != "" and ($ports.debug_log | path exists) { open --raw $ports.debug_log | decode } else { "" }),
        api: (if $api_out != "" and ($api_out | path exists) { open --raw $api_out | into binary } else { 0x[] }),
        screen: (if $screen_completed != null { $screen_file } else { "" }),
        qemu_log: $qemu_log,
        stderr: $result.stderr,
        cpu_seconds: $cpu,
        wall_seconds: (((date now) - $started) / 1sec),
        sound: (if $wav != "" and ($wav | path exists) { $wav } else { "" }),
        qemu_binary: $machine.qemu_binary,
        timeout_binary: $machine.timeout_binary,
        timeout_version: $machine.timeout_version,
        qemu: $line,
        overrides: $qemu,
        window: $machine.window,
        audio: $machine.audio,
        machine: $ran_on,
        threads: (if $threads_held == null { [] } else { $threads_held.threads }),
        threads_span: (if $threads_held == null { null } else { $threads_held.span }),
        thread_readings: ($readings | append $unread),
        screen_started: $screen_started,
        screen_completed: $screen_completed,
        send_seconds: $send_seconds,
        declared: ($machine.demand != null),
        diagnostic: ($ran_on.diagnostic != null or (not ($qemu | is-empty)) or $machine.demand == null or ($ran_on | get -o below_minimum | default false)),
        qemu_pid: $qemu_pid,
        sdl_log: $machine.sdl_log,
        shim: $machine.shim,
        capture_nonce: $machine.capture_nonce,
        profile: $machine.profile,
        capture: (capture-identity $machine $qemu_pid),
    }
}

# The order a launch's poll takes its timed actions in, `elapsed` after
# the start: every event due by then, its `at` at or before it, in the
# order of their times and at one time in the order given; and the
# screen, due at `screen` while it is still to take (null when none
# is), once due after every event due before its time and ahead of
# every event due at or after it, which wait on it, the poll writing
# them only once the screen is whole. The events come back as given,
# the screen as a row of kind `screen`, its `index` 0 and its `at` its
# time.
export def due-order [events: table<kind: string, index: int, at: duration>, screen: oneof<duration, nothing>, elapsed: duration]: nothing -> table<kind: string, index: int, at: duration> {
    let due = ($events | enumerate | each {|e| $e.item | insert order $e.index } | where {|e| $e.at <= $elapsed } | sort-by at order | reject -o order)
    if $screen == null or $screen > $elapsed { return $due }
    ($due | where {|e| $e.at < $screen }) ++ [{ kind: "screen", index: 0, at: $screen }] ++ ($due | where {|e| $e.at >= $screen })
}

# Where `watch` records: watch.nuonl in the workspace's target.
def watch-file [ws: path]: nothing -> string {
    target root $ws | path join "watch.nuonl"
}

# What a recording says first about the QEMU it records: the host, the
# QEMU's version, the machine from its line (the harts, -machine, the
# CPU, and the accelerator), the window, the kernel and the symbols it
# was built with, read from its tree's flags stamp, its pid, and when the
# recording started.
def watch-header [pid: int, started: datetime]: nothing -> record {
    let command = (ps -l | where pid == $pid | get -o 0.command | default "")
    let window = ($command | parse --regex '-display (?P<w>\S+)' | get -o 0.w | default "")
    let kernel = ($command | parse --regex '-kernel (?P<k>\S+)' | get -o 0.k | default "")
    let smp = ($command | parse --regex '-smp (?P<n>\d+)' | get -o 0.n | default "")
    let machine = ($command | parse --regex '-machine (?P<m>\S+)' | get -o 0.m | default "")
    let cpu = ($command | parse --regex '-cpu (?P<c>\S+)' | get -o 0.c | default "")
    let accel = ($command | parse --regex '-accel (?P<a>\S+)' | get -o 0.a | default "")
    let stamp_file = (if $kernel == "" { "" } else { $kernel | path dirname | path join "flags" })
    let stamp = (if $stamp_file != "" and ($stamp_file | path exists) { open --raw $stamp_file | decode | str trim } else { "" })
    let symbols = ($stamp | parse --regex '--defsym (?P<s>[A-Z0-9_]+)=1' | get s)
    let binary = (process command-binary $command)
    let qemu = (try { ^$binary --version | complete | get stdout | lines | get -o 0 | default "" } catch { "" })
    { os: $nu.os-info.name, arch: $nu.os-info.arch, qemu: $qemu, harts: (if $smp == "" { null } else { $smp | into int }), machine: $machine, cpu: $cpu, accel: $accel, window: $window, kernel: $kernel, symbols: $symbols, pid: $pid, started: ($started | format date "%Y-%m-%dT%H:%M:%S") }
}

# Record the running Jab QEMU per thread, once a second, to the
# workspace's target's watch.nuonl, a previous recording retired,
# whatever shell this is run from: a first line describing the run
# (watch-header), then a line per sample with every thread's cumulative
# CPU seconds and the process's resident memory (memory-of), one short
# line printed per sample with the rates since the last. When the run ends, the report on the recording is printed to
# paste (watch-report-of), the first `--skip` seconds dropped as the
# load. Interrupted, it ends with no report. `watch bench` records a
# bench's runs instead.
def "main watch" [ws: path, --skip: float = 5.0] {
    let pids = (process jab-pids)
    if ($pids | is-empty) { error make {msg: "no jab is running"} }
    let pid = ($pids | first)
    let file = (watch-file $ws)
    mkdir ($file | path dirname)
    target retire $file (target root $ws)
    let started = (date now)
    let run = (watch-header $pid $started)
    ({ run: $run } | to nuon) + (char nl) | save --raw $file
    print $"jab watch: recording ($pid) to ($file), ($run.symbols | str join ', ') under ($run.window)"
    if ($pids | length) > 1 { print $"jab watch: ($pids | length) jab processes; recording the first" }
    mut last: any = null
    loop {
        if (process jab-pids | where {|p| $p == $pid } | is-empty) { print "jab watch: the run has ended"; break }
        let at = (((date now) - $started) / 1sec)
        let threads = (process threads-of $pid)
        ({ at: $at, threads: $threads, rss: (process memory-of $pid) } | to nuon) + (char nl) | save --raw --append $file
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
# `stable: false` and no peak, its steady figure a mix. `tcg` names the
# translator's mode from the threads' names: a lone `ALL CPUs/TCG` thread
# runs every hart on one host thread, single-threaded and never evidence
# of multicore performance, `CPU N/TCG` threads a thread a hart; null
# where the names say neither, as on macOS. `memory` the process's
# resident memory in bytes over the stretch, its median by nearest rank
# and its peak with the samples holding it, null for a recording made
# before the watch read it.
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
    let names = ($last.threads | get name)
    let tcg = (if ($names | any {|n| $n == "ALL CPUs/TCG" }) { "single-threaded" } else if ($names | any {|n| $n =~ '^CPU \d+/TCG$' }) { "multi-threaded" } else { null })
    let resident = ($samples | each {|s| $s | get -o rss } | compact | sort)
    {
        run: $header.run,
        skipped: $skipped,
        seconds: ($seconds | math round -p 1),
        samples: ($samples | length),
        tcg: $tcg,
        process: (if ($threads | is-empty) { 0.0 } else { $threads | get steady | math sum | math round -p 3 }),
        threads: $threads,
        memory: (if ($resident | is-empty) { null } else { { median: ($resident | get ((($resident | length) * 0.5 | math ceil) - 1)), peak: ($resident | last), samples: ($resident | length) } }),
    }
}

# A watch report's memory in words, the resident median and peak in MiB,
# empty where it holds none.
def memory-text [memory: any]: nothing -> string {
    if $memory == null { "" } else { $"; resident ($memory.median / 1048576 | math round) MiB at the median, ($memory.peak / 1048576 | math round) at the peak" }
}

# What a program's test or run needs, after building it with `names`
# set: the kernel built with the same symbols in the same tree, so a
# debug program runs on a debug kernel; standalone, with no workspace,
# JAB_KERNEL is taken as it is.
def prepared [dir: path, names: list<string>]: nothing -> record {
    build build-program $dir $names
    let c = (build context $dir "program" $names)
    if $c.workspace != null {
        let ws = (open ($c.workspace | path join "workspace.jab.toml"))
        build build-kernel ($c.workspace | path join $ws.kernel) $names
    }
    let kernel = (build kernel-elf $c)
    if not ($kernel | path exists) { error make {msg: $"no kernel at ($kernel); build the kernel first, with the same --set"} }
    { context: $c, kernel: $kernel, image: ($c.out | path join $"($c.manifest.name).jab") }
}

# The arguments that run a program's test/test.nu on the kernel: the
# kernel, the image, the output directory, the assets image when the
# program has one, and the symbols the build was made with.
def test-args [ready: record]: nothing -> list<string> {
    let script = ($ready.context.here | path join "test" "test.nu")
    if not ($script | path exists) { error make {msg: $"($ready.context.manifest.name) has no test/test.nu"} }
    let assets = (disk assets-image $ready.context)
    let set = ($ready.context.symbols | str join ",")
    let common = [$script "--kernel" $ready.kernel "--image" $ready.image "--out" $ready.context.out "--set" $set]
    if $assets == "" { $common } else { $common ++ ["--assets" $assets] }
}

# The QEMU line that runs a program, built first: the QEMU it runs on
# (qemu-binary, beside the program and then in the workspace) and its
# arguments, the full virtio device set, the program's own disk when it
# has one, its serial the manifest's `serial` else the program's name,
# else the blank image that has always been there, the debug
# channel to a file when DEBUG is set, the API's port when `api` asks,
# the window given (null for the one a run would open), the UART where
# `serial` says (`stdio` or `none`), and no monitor, on the machine
# `spec` names, a custom one of `harts` harts, or the configured default
# (machine-for), a named spec the program does not list refused before
# QEMU starts (spec-listed). The ports' files sit beside the build
# output, named in the README. With a pad on the port, `bridge` is the
# pad's identity and `bridge_pipe` the pipe the bridge writes
# (bridge-pipe); on Windows the API's pipe takes a relay, `relays` and
# `relay_binary` as plan names them, none and "" elsewhere.
def run-line [dir: path, names: list<string>, api: bool, window: oneof<string, nothing>, serial: string, kbm: bool, pad: bool, sound: bool, --spec: string = "", --harts: int = 0]: nothing -> record<qemu_binary: string, args: list<string>, window: string, context: record, bridge: oneof<record<name: string, vendor: oneof<int, nothing>, product: oneof<int, nothing>>, nothing>, bridge_pipe: string, relays: list<record<endpoint: string, name: string, inward: string, outward: string, done: string>>, relay_binary: string, machine: record> {
    let ready = (prepared $dir $names)
    let c = $ready.context
    let m = (machine resolve $c.workspace $spec $harts)
    demand spec-listed $m (demand image $ready.image) $c.manifest.name
    let qemu = (machine qemu-binary $c.here $c.workspace)
    let line = (machine spec-bootargs $m "")
    let machine = ((machine machine-args $qemu $m) ++ (if $line == "" { [] } else { ["-append" $line] }))
    let assets = (disk assets-image $c)
    let disk = (if $assets == "" {
        let blank = ($c.target | path join "disk.img")
        if not ($blank | path exists) { ^truncate -s 64M $blank }
        $blank
    } else { $assets })
    let disk_serial = (if $assets == "" { "disk0" } else { disk disk-serial ($c.manifest | get -o serial | default $c.manifest.name) })
    let shown = (if $window == null { machine display $c.manifest } else { $window })
    let found = (if (disco discovery-wanted $pad $sound) { disco discover $c.workspace } else { { gamepad: null, audio: null } })
    let gamepad = (if $pad { pad gamepad-plan $found } else { { args: [], port: false, bridge: null } })
    # a Windows run's pipes are named pipes, named by a nonce of its own,
    # the API's taking a relay and the pad port's client the bridge
    let windows = ($nu.os-info.name == "windows")
    let nonce = (if $windows { random int 1.. } else { 0 })
    let ports = (chardev ports $c.symbols $c.out $api $gamepad.port $c.root $nonce)
    let relays = (if $windows { chardev relays-of $c.out [{ endpoint: "api", pipe: $ports.api }] } else { [] })
    let relay_binary = (chardev relay-build $relays $c.workspace)
    let inputs = (if $kbm { $input_devices } else { [] })
    let audio = (if $sound { audio sound-args (audio audio-plan ($found | get -o audio)) } else { [] })
    let args = ($machine ++ (machine name-args $c.manifest.name) ++ (machine memory-args $m) ++ $display_device ++ $inputs ++ $gamepad.args ++ $devices ++ $audio ++ (disk disks-args (disk machine-disks $disk $disk_serial ($assets != "") $c.workspace)) ++ $ports.args ++ [
        "-bios" "none" "-kernel" $ready.kernel
        "-device" $"loader,file=($ready.image),addr=($program_base),force-raw=on"
        "-display" $shown "-serial" $serial "-monitor" "none"
    ] ++ (machine extra-args))
    let count = (machine transports $args)
    if $count > $transport_limit {
        error make {msg: $"the machine line carries ($count) virtio transports and virt has ($transport_limit): drop --api or --set debug, which share one, or run with --no-kbm, which frees two"}
    }
    { qemu_binary: $qemu, args: $args, window: $shown, context: $c, bridge: $gamepad.bridge, bridge_pipe: (chardev bridge-pipe $ports.pad), relays: $relays, relay_binary: $relay_binary, machine: $m }
}

# Run a program with the console window, the UART on stdio; QEMU's exit
# code is the program's exit status. A run says nothing of its own.
# With a pad on the port, the bridge runs beside QEMU, started first
# so it is writing the header as the kernel comes up, and ended with
# it; the bridge ends itself as well once its pipe has no reader. On
# Windows the relays run-line names start ahead of QEMU too, which waits
# for each pipe's client as it makes the pipe, and once QEMU has ended
# each is given a second to end with its pipe, any left stopped, and one
# that ended in failure said on stderr, naming its pipe.
def run-program [dir: path, names: list<string>, api: bool, kbm: bool, pad: bool, sound: bool, --spec: string = "", --harts: int = 0]: nothing -> nothing {
    let line = (run-line $dir $names $api null "stdio" $kbm $pad $sound --spec $spec --harts $harts)
    if ($line.window | str starts-with "vnc=") {
        print "no display server here, so this is a development run: the display is served over VNC on 127.0.0.1:5930; tunnel it with `ssh -N -L 5930:127.0.0.1:5930 <this host>` and view it with `vncviewer 127.0.0.1:5930`"
    }
    let bridge = (if $line.bridge == null { null } else {
        let bin = (tool shim $line.context.workspace "jabshim_pad" --bin)
        let pipe = $line.bridge_pipe
        let b = $line.bridge
        let vendor = (if $b.vendor == null { "" } else { $b.vendor | into string })
        let product = (if $b.product == null { "" } else { $b.product | into string })
        job spawn { ^$bin $pipe $b.name $vendor $product | complete | ignore }
    })
    let relays = (chardev relays-start $line.relays $line.relay_binary $line.context.root)
    let qemu = $line.qemu_binary
    ^$qemu ...$line.args
    let relayed = (chardev relays-stop $relays)
    if $bridge != null { try { job kill $bridge } }
    for r in ($relayed | where {|r| $r.exit != null and $r.exit != 0 }) {
        print -e $"jab: the ($r.endpoint) pipe's relay, for ($r.name), ended with ($r.exit): ($r.said | str trim)"
    }
}

# Probe a program under a window. `sdl`: run it under SDL with OpenGL
# for `seconds` with shim/crates/sdl preloaded into QEMU, then report how
# its flips reached the window, read through QEMU's own symbol tables;
# `api`, `send`, and `trace` are probe-sdl's.
def probe [dir: path, kind: string, names: list<string>, seconds: int, --api, --send: string = "", --trace]: nothing -> nothing {
    match $kind {
        "sdl" => { probe-sdl $dir $names $seconds --api=$api --send $send --trace=$trace },
        _ => { error make {msg: $"no probe called ($kind); there is `sdl`"} },
    }
}

# The SDL probe: the shim built with cargo into the target's shim/, the
# program run under `sdl,gl=on` with the UART off for `seconds`, the
# shim's log read back through binutils' nm (sdl-report), and one NUON
# record printed, or the refusal saying why the log cannot be read and
# no record. Linux only, since it preloads a library into QEMU. With no
# display server SDL runs its offscreen driver, which draws nothing but
# keeps every path the same. Each run mints its capture nonce for the
# shim (launch-nonce), keeps QEMU's pid while it lives (probe-launch),
# and writes the run's identity beside the log, `identity.nuon`. Its
# profile, its port, and its sends are probe-plan's: paired where the
# build sets the manifest's `paired`, the nonce's frame sent first;
# `--api` puts the port on with nothing sent for it; `--send <file>`
# writes the file's bytes. With the port on, the program's bytes are kept
# beside the log as `api.out`.
# `--trace` has QEMU trace the device's flushes and set_scanouts into
# `trace.log` there, its messages stamped (trace-args). The run is
# bundled last (sdl-bundle) into `bundle` there, a previous bundle and
# every file the probe writes retired first.
def probe-sdl [dir: path, names: list<string>, seconds: int, --api, --send: string = "", --trace]: nothing -> nothing {
    if $nu.os-info.name != "linux" { error make {msg: "the sdl probe preloads a library into QEMU, which is Linux only"} }
    let c = (build context $dir "program" $names)
    if $c.workspace == null { error make {msg: "the sdl probe needs the program's workspace, above it or named by its manifest, which holds shim/crates/sdl"} }
    if $send != "" and not ($send | path exists) { error make {msg: $"--send ($send): no such file"} }
    let shim = (tool shim $c.workspace "jabshim_sdl")
    let nonce = (nonce mint 0 true)
    let planned = (probe-plan $c.manifest $names $nonce --api=$api --send (if $send == "" { 0x[] } else { open --raw $send | into binary }))
    let sends = $planned.sends
    let api_on = $planned.api
    let line = (run-line $dir $names $api_on "sdl,gl=on" "none" true false false)
    let out = ($line.context.out | path join "probe")
    mkdir $out
    let log = ($out | path join "sdl.log")
    let identity_file = ($out | path join "identity.nuon")
    let bundle = ($out | path join "bundle")
    let kept = ($out | path join "api.out")
    let trace_log = ($out | path join "trace.log")
    let pidfile = ($out | path join "qemu.pid")
    for f in [$log $identity_file $bundle $kept $trace_log $pidfile] { target retire $f $line.context.root }
    let traced = (if $trace { trace-args $line.qemu_binary $trace_log } else { [] })
    let server = (($env.DISPLAY? | default "") != "") or (($env.WAYLAND_DISPLAY? | default "") != "")
    let driver = (if $server { "" } else { "offscreen" })
    let preload = { LD_PRELOAD: $shim, SDL_SHIM_LOG: $log, SDL_SHIM_NONCE: (nonce hex $nonce) }
    let extra = (if $driver == "" { $preload } else { $preload | insert SDL_VIDEODRIVER $driver })
    let binary = $line.qemu_binary
    let api_in = (if $api_on { $line.context.out | path join "api.in" } else { "" })
    let bound = (bound timeout)
    let run = (probe-launch $binary ($line.args ++ ["-pidfile" $pidfile] ++ $traced) $extra $seconds $pidfile $api_in $sends $bound.path)
    if not ($log | path exists) { error make {msg: $"QEMU wrote no shim log; its stderr:\n($run.stderr)"} }
    if $api_on { cp ($line.context.out | path join "api.out") $kept }
    let qemu = (^$binary --version | complete | get stdout | lines | get -o 0 | default "")
    let profile = $planned.profile
    let sent = ($sends | each {|s| { at: ($s.at / 1sec), length: ($s.bytes | bytes length), sha256: ($s.bytes | hash sha256) } })
    { profile: $profile, capture_nonce: $nonce, qemu_pid: $run.qemu_pid, sdl_log: $log, shim: $shim, window: "sdl,gl=on", api: $api_on, sends: $sent } | to nuon --indent 2 | save --raw $identity_file
    let report = (sdl-report $log)
    sdl-bundle $out $bundle | ignore
    let record = ({
        run: {
            program: $line.context.manifest.name,
            os: $nu.os-info.name,
            qemu: $qemu,
            binary: $report.run.binary,
            window: "sdl,gl=on",
            driver: (if $driver == "" { "the host's" } else { $driver }),
            symbols: $line.context.symbols,
            seconds: $seconds,
            qemu_said: ($run.stderr | lines | where {|l| not ($l | str contains "terminating on signal") } | first 3),
            exit: $run.exit,
            capture_nonce: $nonce,
            qemu_pid: $run.qemu_pid,
            profile: $profile,
            api: (if $api_on { $kept } else { "" }),
            sends: ($sent | zip $run.send_seconds | each {|p| $p.0 | insert written $p.1 }),
            trace: (if $trace { $trace_log } else { "" }),
            bundle: $bundle,
        },
    } | merge ($report | reject run))
    print ($record | to nuon --indent 2)
}

# What a probe of a program's build puts on the machine and sends
# (CaptureBundle's profiles): paired where the build sets the manifest's
# `paired` (probe-paired), the port on and the nonce's frame (nonce-frame)
# at 200 ms, then `send`'s bytes at 200 ms where there are any; generic
# otherwise, the port on with `api` or bytes to send, and only those
# bytes sent, never a frame of the probe's own.
export def probe-plan [manifest: record, names: list<string>, nonce: int, --api, --send: binary = 0x[]]: nothing -> record<profile: string, api: bool, sends: list<record<at: duration, bytes: binary>>> {
    let paired = (probe-paired $manifest $names)
    let framed = (if $paired { [{ at: 200ms, bytes: (nonce-frame $nonce) }] } else { [] })
    let sends = ($framed ++ (if ($send | bytes length) == 0 { [] } else { [{ at: 200ms, bytes: $send }] }))
    { profile: (if $paired { "paired" } else { "generic" }), api: ($api or not ($sends | is-empty)), sends: $sends }
}

# Whether a probe of a program's build is paired (CaptureBundle): the
# manifest's `paired` names the build symbol under which the program
# reads the capture nonce's frame from the API before it starts, and the
# build sets it. Any other probe is generic.
def probe-paired [manifest: record, names: list<string>]: nothing -> bool {
    let symbol = ($manifest | get -o paired | default "")
    $symbol != "" and (($symbol | str screaming-snake-case) in $names)
}

# The capture nonce's frame, what a paired program reads from the API
# before it starts (CaptureBundle): `WNON` as a le32, a zero word, and
# the nonce as a le64, 16 bytes; the nonce 1 to 2^63 - 1.
export def nonce-frame [nonce: int]: nothing -> binary {
    if $nonce < 1 { error make {msg: $"a capture nonce is 1 to 2^63 - 1, not ($nonce)"} }
    0x[57 4e 4f 4e 00 00 00 00] ++ ($nonce | into binary --endian little)
}

# The QEMU words that trace the GPU device's flushes and set_scanouts into
# `log`, each message stamped with the host's wall clock (-msg
# timestamp=on), which sdl-bundle-check pairs with the shim's uploads;
# refused on a QEMU whose trace events do not list both.
export def trace-args [qemu: string, log: path]: nothing -> list<string> {
    let events = (^$qemu -trace help | complete | get stdout | lines | each {|l| $l | str trim })
    let missing = (["virtio_gpu_cmd_res_flush" "virtio_gpu_cmd_set_scanout"] | where {|e| $e not-in $events })
    if not ($missing | is-empty) { error make {msg: $"($qemu) lists no trace event ($missing | str join ' or '), which --trace needs"} }
    ["-msg" "timestamp=on" "-trace" "virtio_gpu_cmd_res_flush" "-trace" "virtio_gpu_cmd_set_scanout" "-D" $log]
}

# A probe's QEMU run to its exit or its bound, `seconds`, polled as a
# launch polls (launch): QEMU's pid kept from `pidfile` at the first poll
# that finds it alive, since QEMU unlinks the file as it exits, and each
# entry of `sends` written into `api_in` once its time has come, in
# order, through fifo-write. The exit, QEMU's stderr, the pid, null where
# QEMU never came up, and each entry's write in seconds from the start,
# null where it never went in.
def probe-launch [binary: string, args: list<string>, environment: record, seconds: int, pidfile: path, api_in: string, sends: list<record<at: duration, bytes: binary>>, bound: string]: nothing -> record<exit: int, stderr: string, qemu_pid: oneof<int, nothing>, send_seconds: list<oneof<float, nothing>>> {
    let started = (date now)
    job spawn { with-env $environment { ^$bound --signal=TERM ($seconds | into string) $binary ...$args | complete } | job send 0 }
    mut result: any = null
    mut qemu_pid: any = null
    mut written = ($sends | each --keep-empty {|_| null })
    mut taken = 0
    while $result == null {
        $result = (try { job recv --timeout 100ms } catch { null })
        let pid = (try { open --raw $pidfile | str trim } catch { "" })
        let alive = ($result == null and (process process-alive $pid))
        if $alive and $qemu_pid == null { $qemu_pid = ($pid | into int) }
        let elapsed = ((date now) - $started)
        while $alive and $taken < ($sends | length) and ($sends | get $taken | get at) <= $elapsed {
            if $api_in != "" and (chardev fifo-write $api_in ($sends | get $taken | get bytes) $bound) {
                $written = ($written | update $taken (((date now) - $started) / 1sec))
            }
            $taken += 1
        }
    }
    { exit: $result.exit_code, stderr: $result.stderr, qemu_pid: $qemu_pid, send_seconds: $written }
}

# The report on a shim log (sdl-classify): how the flips reached the
# window, one record, or the refusal saying why the log cannot be read.
# A flip's uploads within 5 ms of the previous belong to one flip;
# switches and the console's own never join one. A drawn frame with a
# flip's upload under 3 ms on each side sits inside a flip, which is the
# half-drawn tick to look for.
export def sdl-report [log: path]: nothing -> record {
    let classified = (classify $log)
    let events = $classified.events
    let executable = ($classified.objects | where index == 0 | get -o 0)
    let kinds = ($events | select ts kind callers)
    let t0 = ($events | first | get ts)
    let uploads = ($kinds | where kind == "upload")
    let others = ($kinds | where kind == "console")
    let switches = ($kinds | where kind == "switch")
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
    let top = {|rows: list| $rows | get callers | uniq --count | sort-by count --reverse | first 2 | each {|c| { callers: $c.value, count: $c.count } } }
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
        run: { binary: (if $executable == null { "" } else { $executable.path }) },
        virtio_gpu_in: $classified.virtio_gpu_in,
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
        switches: ($switches | length),
        other_uploads: ($others | length),
        upload_callers: (do $top $uploads),
        other_upload_callers: (do $top $others),
        switch_callers: (do $top $switches),
        render_callers: (do $top ($kinds | where kind == "render")),
    }
}

# A probed run's capture made portable, `jab sdl-bundle <probe dir>
# <bundle dir>`, on the host that took it as the run's last step, while
# the objects its log names are still the files their lines name. The log
# in the probe directory, `sdl.log`, is classified as the probe reads it
# (sdl-classify), a refusal ending the bundle with nothing written; then
# into `bundle`, a directory not yet there, go the log as it was written;
# for each object whose table the reading read, nm's text as it was
# parsed, `tables/<index>.nm`, the file's own SHA-256 taken with its
# inode, size, and modification time its line's before the hash and
# unchanged after it, a change refusing the bundle as changed while
# bundling; `classified.nuon`, every event with its line, stamp, name,
# render flag, chain key, kind, and callers, each chain's decision, and
# the counts by kind; the probe directory's `api.out`, `identity.nuon`,
# `trace.log`, and each file `extra` names, where it has them, copied
# whole; and last `bundle.nuon`, the manifest, bundle_schema 1: the
# profile; the reader (sdl-reader); the host, its OS, kernel release,
# hostname, and QEMU (sdl-qemu-of); every object of the log's table with
# its line's fields, its state, and for a read one its SHA-256 and its
# table with that file's SHA-256 and its source; every other file with
# its SHA-256 and size; the events counted; and the run, the identity's
# capture fields beside the log's process and nonce. The profile is
# `--profile`, else the identity's, else generic, and historical for a
# log written before the run's lines; a paired bundle needs the log's
# nonce, `api.out`, and `identity.nuon`. The manifest. Untyped because it
# ends in an error.
export def sdl-bundle [probe: path, bundle: path, --profile: string = "", --extra: list<string> = []] {
    let probe = ($probe | path expand)
    let bundle = ($bundle | path expand)
    let log = ($probe | path join "sdl.log")
    if not ($log | path exists) { error make {msg: $"($probe) holds no sdl.log to bundle"} }
    if ($bundle | path type) != null { error make {msg: $"($bundle) is already there; a bundle is written once"} }
    let identity_file = ($probe | path join "identity.nuon")
    let identity = (if ($identity_file | path exists) { open --raw $identity_file | into binary | decode | from nuon } else { null })
    let c = (classify sdl-classified $log "")
    let lined = ($c.process != null)
    let given = (if $identity == null { "" } else { $identity | get -o profile | default "" })
    let named = (if $profile != "" { $profile } else if $given != "" { $given } else if $lined { "generic" } else { "historical" })
    if $named not-in [paired generic historical] { error make {msg: $"a bundle's profile is paired, generic, or historical, not ($named)"} }
    if $lined and $named == "historical" { error make {msg: "the log carries the run's lines, so its bundle is paired or generic, never historical"} }
    if (not $lined) and $named != "historical" { error make {msg: $"the log has no process line, so it was written before the run's lines and its bundle is historical, not ($named)"} }
    if $named == "paired" {
        if $c.nonce == null { error make {msg: "a paired bundle needs the log's nonce line, and this log has none"} }
        let missing = (["api.out" "identity.nuon"] | where {|f| not ($probe | path join $f | path exists) })
        if not ($missing | is-empty) { error make {msg: $"a paired bundle needs ($missing | str join ' and ') beside the log in ($probe)"} }
    }
    let carried = (["api.out" "identity.nuon" "trace.log"] ++ $extra | uniq | where {|f| $probe | path join $f | path exists })
    let read = ($c.objects | where {|o| ($c.tables | get ($o.index | into string) | get state) == "read" })
    let hashed = ($read | each {|o|
        let before = (symbols sdl-stat $o.path)
        if $before != { inode: $o.inode, size: $o.size, mtime: $o.mtime } { error make {msg: $"($o.path) changed while bundling: it is no longer the file its line names"} }
        let sha256 = (open --raw $o.path | hash sha256)
        if (symbols sdl-stat $o.path) != $before { error make {msg: $"($o.path) changed while bundling, during its hash"} }
        { index: $o.index, sha256: $sha256 }
    })
    mkdir ($bundle | path join "tables")
    cp $log ($bundle | path join "sdl.log")
    for x in $hashed { $c.tables | get ($x.index | into string) | get nm | save --raw ($bundle | path join "tables" $"($x.index).nm") }
    let events = ($c.events | each {|e| { line: ($e.at + 1), stamp: $e.stamp, name: $e.name, render: $e.render, key: $e.key, kind: $e.kind, callers: $e.callers } })
    let counts = ($events | get kind | uniq --count | reduce --fold {} {|k, acc| $acc | insert $k.value $k.count })
    { events: $events, decisions: $c.decisions, counts: $counts } | to nuon --indent 1 | save --raw ($bundle | path join "classified.nuon")
    for f in $carried {
        mkdir ($bundle | path join $f | path dirname)
        cp ($probe | path join $f) ($bundle | path join $f)
    }
    let files = (walk paths ($bundle | path join "**" "*") --no-dir | each {|p| { path: ($p | path relative-to $bundle), sha256: (open --raw $p | hash sha256), size: (ls -D $p | get 0.size | into int) } } | sort-by path)
    let field = {|name: string| if $identity == null { null } else { $identity | get -o $name } }
    let manifest = {
        bundle_schema: 1,
        profile: $named,
        reader: (sdl-reader),
        host: { os: $nu.os-info.name, kernel: $nu.os-info.kernel_version, hostname: (sys host | get hostname), qemu: (sdl-qemu-of ($c.objects | where index == 0 | get -o 0) ($hashed | where index == 0 | get -o 0.sha256)) },
        objects: ($c.objects | each {|o|
            let t = ($c.tables | get ($o.index | into string))
            let h = ($hashed | where index == $o.index | get -o 0)
            let table = (if $h == null { null } else { $"tables/($o.index).nm" })
            {
                index: $o.index, path: $o.path, inode: $o.inode, size: $o.size, mtime: $o.mtime,
                state: $t.state, why: $t.why, sha256: (if $h == null { null } else { $h.sha256 }),
                table: $table, table_sha256: (if $table == null { null } else { $files | where path == $table | get 0.sha256 }), source: $t.source,
            }
        }),
        files: $files,
        events: ($events | length),
        run: { process: $c.process, nonce: $c.nonce, capture_nonce: (do $field "capture_nonce"), qemu_pid: (do $field "qemu_pid"), api: (do $field "api"), sends: (do $field "sends") },
    }
    $manifest | to nuon --indent 1 | save --raw ($bundle | path join "bundle.nuon")
    $manifest
}

# The reader a bundle records and its check sets beside its own: the jab
# commit this tool runs from, null outside a git checkout, and this
# file's SHA-256.
def sdl-reader []: nothing -> record<jab: oneof<string, nothing>, jab_nu_sha256: string> {
    let at = (try { ^git -C ($self | path dirname) rev-parse HEAD | complete } catch { { exit_code: 1, stdout: "" } })
    { jab: (if $at.exit_code == 0 { $at.stdout | str trim } else { null }), jab_nu_sha256: (open --raw $self | hash sha256) }
}

# The QEMU a log names, object 0 of its table (sdl-log): its path, and
# while the file is the one its line names, its version and its SHA-256,
# `sha256` where it was taken already; null fields otherwise.
def sdl-qemu-of [exe: oneof<record, nothing>, sha256: oneof<string, nothing>]: nothing -> record<path: string, version: oneof<string, nothing>, sha256: oneof<string, nothing>> {
    if $exe == null { return { path: "", version: null, sha256: null } }
    if (symbols sdl-stat $exe.path) != { inode: $exe.inode, size: $exe.size, mtime: $exe.mtime } { return { path: $exe.path, version: null, sha256: null } }
    let version = (try { ^$exe.path --version | complete | get stdout | lines | get -o 0 } catch { null })
    { path: $exe.path, version: $version, sha256: (if $sha256 != null { $sha256 } else { open --raw $exe.path | hash sha256 }) }
}

# A bundle (sdl-bundle) held to its manifest wherever it is read, `jab
# sdl-bundle-check <bundle dir>`, stage by stage, the first that fails
# refusing it by its stage and name with nothing read from it: 1, the
# inventory, every file the manifest lists there with its SHA-256 and size
# and none it does not but bundle.nuon, sdl.log and classified.nuon among
# them and a paired bundle's api.out and identity.nuon; 2, the
# correspondence, the manifest's objects one for one with the log's table
# lines, index, path, inode, size, and modification time alike, a read
# object's table listed and no other's; 3, the sequence, the log's events
# as sdl-log reads them, which reads no object file, classified.nuon's in
# count and line by line in line, stamp, name, render flag, and chain key;
# 4, the replay, the log classified again from the bundle's tables
# (sdl-classify --tables), every event's kind and callers classified.nuon's;
# 5, the run by its profile: paired, the log's process the identity's
# qemu_pid, the log's nonce the identity's capture_nonce, and the nonce
# the guest echoed, read from the bundle's api.out by `guest`, the
# program's reader, equal to both, a 0 or a missing value refused; generic
# and historical, nothing bound and nothing paired; and with trace.log,
# QEMU's flushes paired in order one for one with the log's flip uploads,
# each upload within 5 ms after its flush on the one host clock; 6, the
# reader, the host's set beside this one, the replay's equality being what
# admits another revision. The profile, the run, both readers, the trace's
# pairing, and classified.nuon's events. Untyped because it ends in an
# error.
export def sdl-bundle-check [bundle: path, --guest: closure] {
    let dir = ($bundle | path expand)
    let refuse = {|stage: int, name: string, why: string| error make {msg: $"the bundle is refused at stage ($stage), ($name): ($why)"} }
    let manifest_file = ($dir | path join "bundle.nuon")
    if not ($manifest_file | path exists) { do $refuse 1 "the inventory" $"($dir) holds no bundle.nuon" }
    let m = (try { open --raw $manifest_file | into binary | decode | from nuon } catch {|e| do $refuse 1 "the inventory" $"bundle.nuon is no NUON the check reads: ($e.msg)" })
    if ($m | get -o bundle_schema) != 1 { do $refuse 1 "the inventory" $"bundle.nuon's bundle_schema is ($m | get -o bundle_schema | to nuon), where 1 is read" }
    let profile = ($m | get -o profile | default "")
    let listed = ($m | get -o files | default [])
    let names = ($listed | get -o path | default [])
    let present = (walk paths ($dir | path join "**" "*") --no-dir | each {|p| $p | path relative-to $dir } | where {|p| $p != "bundle.nuon" } | sort)
    let unlisted = ($present | where {|p| $p not-in $names })
    if not ($unlisted | is-empty) { do $refuse 1 "the inventory" $"files the manifest does not list: ($unlisted | str join ', ')" }
    for f in $listed {
        let file = ($dir | path join $f.path)
        if not ($file | path exists) { do $refuse 1 "the inventory" $"($f.path), listed, is not there" }
        let size = (ls -D $file | get 0.size | into int)
        let sha256 = (open --raw $file | hash sha256)
        if $size != $f.size or $sha256 != $f.sha256 { do $refuse 1 "the inventory" $"($f.path) is not the file the manifest lists: ($size) bytes of ($sha256), where it lists ($f.size) of ($f.sha256)" }
    }
    let required = (["sdl.log" "classified.nuon"] ++ (if $profile == "paired" { ["api.out" "identity.nuon"] } else { [] }))
    for r in $required { if $r not-in $names { do $refuse 1 "the inventory" $"the manifest lists no ($r), which a ($profile) bundle holds" } }
    let read = (try { log ($dir | path join "sdl.log") } catch {|e| do $refuse 2 "the correspondence" $"the reader refuses the log: ($e.msg)" })
    let objects = ($m | get -o objects | default [])
    if ($objects | length) != ($read.objects | length) { do $refuse 2 "the correspondence" $"the manifest lists ($objects | length) objects and the log's table ($read.objects | length)" }
    for pair in ($read.objects | zip $objects) {
        let o = $pair.0
        let e = $pair.1
        for k in [index path inode size mtime] {
            if ($o | get $k) != ($e | get -o $k) { do $refuse 2 "the correspondence" $"object ($o.index)'s ($k) is ($e | get -o $k | to nuon) in the manifest and ($o | get $k | to nuon) in the log's table" }
        }
        let table = ($e | get -o table)
        if ($e | get -o state) == "read" {
            if $table == null or $table not-in $names { do $refuse 2 "the correspondence" $"object ($o.index)'s table was read, and the manifest lists none for it" }
        } else if $table != null { do $refuse 2 "the correspondence" $"object ($o.index)'s table went unread, and the manifest lists one for it" }
    }
    let cls = (try { open --raw ($dir | path join "classified.nuon") | into binary | decode | from nuon } catch {|e| do $refuse 3 "the sequence" $"classified.nuon is no NUON the check reads: ($e.msg)" })
    let logged = ($read.events | each {|e| { line: ($e.at + 1), stamp: $e.stamp, name: $e.name, render: $e.render, key: (classify sdl-chain-key $e.frames) } })
    let held = ($cls.events | each {|e| { line: $e.line, stamp: $e.stamp, name: $e.name, render: $e.render, key: $e.key } })
    if ($logged | length) != ($held | length) { do $refuse 3 "the sequence" $"the log holds ($logged | length) events and classified.nuon ($held | length)" }
    for pair in ($logged | zip $held) {
        if $pair.0 != $pair.1 { do $refuse 3 "the sequence" $"the log's event at line ($pair.0.line) is ($pair.0 | to nuon), classified.nuon's ($pair.1 | to nuon)" }
    }
    let replay = (try { classify sdl-classified ($dir | path join "sdl.log") $dir } catch {|e| do $refuse 4 "the replay" $"the log classified from the bundle's tables is refused: ($e.msg)" })
    for pair in ($replay.events | zip $cls.events) {
        let got = { kind: $pair.0.kind, callers: $pair.0.callers }
        let want = { kind: $pair.1.kind, callers: $pair.1.callers }
        if $got != $want { do $refuse 4 "the replay" $"the event at line ($pair.1.line) replays as ($got | to nuon), where classified.nuon holds ($want | to nuon)" }
    }
    let run = (match $profile {
        "paired" => {
            let id = (open --raw ($dir | path join "identity.nuon") | into binary | decode | from nuon)
            let pid = ($id | get -o qemu_pid)
            let nonce = ($id | get -o capture_nonce)
            if $read.process == null { do $refuse 5 "the run" "the log has no process line" }
            if $pid == null or $pid == 0 { do $refuse 5 "the run" "the identity records no qemu_pid" }
            if $read.process != $pid { do $refuse 5 "the run" $"the log's process ($read.process) is not the identity's qemu_pid ($pid)" }
            if $read.nonce == null { do $refuse 5 "the run" "the log has no nonce line" }
            if $nonce == null or $nonce == 0 { do $refuse 5 "the run" "the identity records no capture_nonce" }
            if $read.nonce != (nonce hex $nonce) { do $refuse 5 "the run" $"the log's nonce ($read.nonce) is not the identity's capture_nonce, (nonce hex $nonce)" }
            if $guest == null { do $refuse 5 "the run" "the guest's echoed nonce goes unread: a paired bundle is checked with its program's reader of api.out, --guest" }
            let echoed = (do $guest ($dir | path join "api.out"))
            if $echoed == null or $echoed == 0 { do $refuse 5 "the run" "the guest echoed no nonce, its records reading 0" }
            if $echoed != $nonce { do $refuse 5 "the run" $"the guest echoed (nonce hex $echoed), where the run's nonce is (nonce hex $nonce)" }
            { process: $read.process, nonce: $read.nonce, capture_nonce: $nonce, qemu_pid: $pid, guest_nonce: $echoed }
        },
        "generic" | "historical" => { { process: $read.process, nonce: $read.nonce, capture_nonce: null, qemu_pid: null, guest_nonce: null } },
        _ => { do $refuse 5 "the run" $"the manifest's profile is ($profile | to nuon), where paired, generic, or historical is read" },
    })
    let trace = (if "trace.log" not-in $names { null } else {
        let flushes = (open --raw ($dir | path join "trace.log") | into binary | decode | lines
            | parse --regex '^(?P<at>\S+) virtio_gpu_cmd_res_flush\b'
            | each {|c| ($c.at | into datetime | into int) / 1e9 })
        let uploads = ($replay.events | where kind == "upload" | get ts)
        if ($flushes | length) != ($uploads | length) { do $refuse 5 "the run" $"the trace holds ($flushes | length) flushes and the log ($uploads | length) flip uploads" }
        let lags = ($flushes | zip $uploads | each {|p| ($p.1 - $p.0) * 1000.0 })
        let off = ($lags | enumerate | where {|l| $l.item < 0.0 or $l.item >= 5.0 })
        if not ($off | is-empty) { do $refuse 5 "the run" $"flip upload ($off | first | get index | $in + 1) lies ($off | first | get item | math round -p 3) ms after its flush, outside the 5 ms after it" }
        { flushes: ($flushes | length), uploads: ($uploads | length), max_lag_ms: (if ($lags | is-empty) { null } else { $lags | math max | math round -p 3 }) }
    })
    let host = ($m | get -o reader)
    let box = (sdl-reader)
    { profile: $profile, run: $run, reader: { host: $host, box: $box, same: ($host == $box) }, trace: $trace, events: $cls.events }
}

# Test the programs at or under a path in the workspace, every program
# for none, each on a build with DEBUG beside `names` and prepared to
# test first; prints each test's output and a summary, exits 1 if any
# fails. A test that drives the API asks `jab launch` for the port
# itself.
def test-under [ws: path, words: list<string>, names: list<string>]: nothing -> nothing {
    let ws = ($ws | path expand)
    let names = (build with-debug $names)
    let selected = (workspace programs-under $ws $words)
    let m = (open ($ws | path join "workspace.jab.toml"))
    build build-kernel ($ws | path join $m.kernel) $names
    let results = ($selected | each {|p|
        let dir = ($ws | path join $p)
        build prepare $dir "test"
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

# The development commands, `just do`: with no command the list, the
# SDK's own, probe and clean, then the kernel's and every program's, the
# `main <command>` definitions of the nushell script its manifest's `do`
# names; with one, the SDK's or the script's that defines it, run with
# the rest of the words as they came, from the directory the command was
# given in, so a relative path among them is the caller's.
def --wrapped "main do" [dir: path, ...words: string] {
    let ws = ($dir | path expand)
    if not (workspace is-workspace $ws) { error make {msg: $"($ws) is no workspace's root"} }
    let commands = (do-commands $ws)
    if ($words | is-empty) { print (do-list $commands); return }
    let name = ($words | first)
    let rest = ($words | skip 1)
    if $name == "probe" { ^nu $self probe $ws ...$rest; return }
    if $name == "clean" { build clean $ws ...$rest; return }
    let hit = ($commands | where command == $name)
    if ($hit | is-empty) { error make {msg: $"no development command called ($name); `just do` lists them"} }
    ^nu ($hit | first | get script) $name ...$rest
}

# Every development command the kernel and the programs declare: the
# `main <command>` definitions of the script a manifest's `do` names,
# relative to it, each with the comment above it, the script, and its
# owner's path and directory.
def do-commands [ws: path]: nothing -> table<command: string, usage: string, owner: string, home: string, script: string, summary: string> {
    let m = (open ($ws | path join "workspace.jab.toml"))
    let owners = ([{ path: $m.kernel, manifest: "kernel.jab.toml" }] ++ (workspace programs-of $ws | each {|p| { path: $p, manifest: "program.jab.toml" } }))
    $owners | each {|o|
        let home = ($ws | path join $o.path)
        let declared = (open ($home | path join $o.manifest) | get -o "do" | default "")
        if $declared == "" { [] } else {
            let script = ($home | path join $declared)
            let lines = (open --raw $script | decode | lines)
            $lines | enumerate | each {|l|
                let hit = ($l.item | parse --regex '^def (?:--wrapped )?"main (?P<command>[^"]+)"\s*\[(?P<params>.*)\][^\]]*$' | get -o 0)
                if $hit == null { null } else {
                    let above = ($lines | first $l.index | reverse | take while {|x| $x | str starts-with "#" } | reverse | each {|x| $x | str replace --regex '^#\s?' '' } | str join " ")
                    { command: $hit.command, usage: (do-usage $hit.params), owner: $o.path, home: $home, script: $script, summary: $above }
                }
            } | compact
        }
    } | flatten
}

# A command's arguments as `just do` shows them, from its definition's
# parameters: a required one `<name>`, one with a default `[name]`, a
# flag `[--flag value]` or `[--flag]`, the rest `[args...]`.
def do-usage [params: string]: nothing -> string {
    $params | split row "," | each {|p| $p | str trim } | where {|p| $p != "" } | each {|p|
        let name = ($p | split row ":" | first | split row "=" | first | str trim)
        let default = (if ($p | str contains "=") { $p | split row "=" | skip 1 | str join "=" | str trim | str trim --char '"' } else { "" })
        if ($name | str starts-with "...") { "[args...]" } else if ($name | str starts-with "--") {
            if ($p | str contains ":") { $"[($name) ($default)]" } else { $"[($name)]" }
        } else if $default != "" { $"[($name)]" } else { $"<($name)>" }
    } | str join " "
}

# The list `just do` prints: each command with its arguments and its
# owner, and its description up to its first example or full stop.
def do-list [commands: table]: nothing -> string {
    let sdk = [
        { command: "probe", usage: "<kind> <program> [--seconds 12] [--set names] [--api] [--send <file>] [--trace]", owner: "sdk", summary: "Probe one program under a window and print one NUON record on how its flips reached it, `sdl` the one kind, Linux only" }
        { command: "clean", usage: "[path] [--tree release|debug]", owner: "sdk", summary: "Retire the build outputs of the programs at or under a path, or the kernel's with `kernel`, in both trees or the one --tree names; with no path the whole target, as `just clean` does" }
    ]
    let all = ($sdk ++ ($commands | select command usage owner summary))
    let shown = ($all | each {|c|
        let cut = ($c.summary | split row ": `" | first | split row ". " | first)
        let usage = (if $c.usage == "" { "" } else { $" ($c.usage)" })
        $"  just do ($c.command)($usage)  [($c.owner)]\n      ($cut)"
    })
    (["the commands for development, `just do <command> [args]`:"] ++ $shown) | str join "\n"
}

# The benches of the workspace's programs, `<program>/<bench>` each: the
# NUON files under a program's bench/ directory.
def benches-of [ws: path]: nothing -> list<string> {
    workspace programs-of $ws | each {|p|
        walk paths ($ws | path expand | path join $p "bench" "*.nuon") | sort | each {|f| $"($p)/($f | path parse | get stem)" }
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
    let program = (workspace program-path $ws ($words | drop 1))
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
    build program-shard $b.dir "bench" | path join $b.bench
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
    ($s.state not-in [done failed]) and (process process-alive ($s.pid | into string))
}

# The state file written whole, through a file beside it moved over it,
# so `watch bench` never reads half of one.
def bench-save-state [file: path, state: record]: nothing -> nothing {
    let next = $"($file).next"
    $state | to nuon | save --raw -f $next
    mv -f $next $file
}

# A bench's run packed whole into one tar beside its directory in the
# bench's home, so the run travels as one file: named for the bench, its
# path's slashes as underscores, and the stamp, `<bench>-<stamp>.tar`,
# the run's directory at the archive's top under its stamp. A tar of the
# run already there, an earlier packing, is retired first (retire), since
# nothing is deleted. The tar's path. Untyped because it can end in an
# error.
def bench-tar [home: path, stamp: string, name: string, root: path] {
    let file = ($home | path join $"($name | str replace --all '/' '_')-($stamp).tar")
    target retire $file $root
    let r = (do { cd $home; ^tar -cf ($file | path basename) $stamp | complete })
    if $r.exit_code != 0 { error make {msg: $"tar of ($home | path join $stamp) ended with ($r.exit_code): ($r.stderr | str trim)"} }
    $file
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
# for `just watch bench`. At the end the run is packed whole into one tar
# beside its directory (bench-tar), the file to copy off the host, and
# the last line names it; a watch recording the run packs it again when
# it ends, its recording included. A run with a failed step or a failed
# report exits 1 once everything is recorded, reported, packed, and said.
# `--only` runs the steps its comma-separated labels name; with no bench,
# the list. Nothing is deleted: a run writes its own directory, its tar,
# and the state.
def "main bench" [ws: path, name?: string, --only: string = ""] {
    let ws = ($ws | path expand)
    if not (workspace is-workspace $ws) { error make {msg: $"($ws) is no workspace's root"} }
    if $name == null { print (bench-list $ws); return }
    let b = (bench-at $ws $name)
    let labels = ($b.def.steps | get label)
    let picked = ($only | split row "," | each {|l| $l | str trim } | where {|l| $l != "" })
    let unknown = ($picked | where {|l| $l not-in $labels })
    if not ($unknown | is-empty) { error make {msg: $"($b.name) has no step ($unknown | str join ', '); its steps: ($labels | str join ', ')"} }
    let steps = (if ($picked | is-empty) { $b.def.steps } else { $b.def.steps | where {|s| $s.label in $picked } })
    let tree = ($b.def | get -o tree | default "release")
    let names = (target tree-symbols $tree)
    let home = (bench-home $b)
    let stamp = (date now | format date "%Y%m%d-%H%M%S")
    let dir = ($home | path join $stamp)
    if ($dir | path exists) { error make {msg: $"a run of ($b.name) started this second, at ($dir)"} }
    mkdir $dir
    let state_file = ($home | path join "state.nuon")
    let record_file = ($dir | path join "bench.nuon")
    let total = ($steps | length)
    let base = { bench: $b.name, stamp: $stamp, dir: $dir, pid: $nu.pid, started: (date now | format date "%Y-%m-%dT%H:%M:%S"), total: $total }
    mut record: record = {
        bench: $b.name, summary: $b.def.summary, tree: $tree, stamp: $stamp, started: $base.started, file: $b.file,
        steps: ($steps | each {|s| { label: $s.label, attend: ($s | get -o attend), run: $s.run, state: "pending", exit: null, seconds: null } }),
        report: null, state: "building",
    }
    $record | to nuon --indent 2 | save --raw $record_file
    bench-save-state $state_file ($base | merge { step: 0, label: "", state: "building" })
    print $"jab bench: ($b.name), ($total) steps, into ($dir): ($b.def.summary)"
    let broken = (try {
        let m = (open ($ws | path join "workspace.jab.toml"))
        build build-kernel ($ws | path join $m.kernel) $names
        build prepare $b.dir "build"
        build build-program $b.dir $names
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
    let packed = (try { { tar: (bench-tar $home $stamp $b.name (target root $ws)), error: "" } } catch {|e| { tar: null, error: $e.msg } })
    bench-save-state $state_file ($base | merge { step: $total, label: "", state: $final })
    let failures = (if ($failed | is-empty) { "" } else { $"; failed: ($failed | str join ', ')" })
    let unreported = (if $reported == null or $reported == 0 { "" } else { $"; the report failed with exit ($reported)" })
    if $packed.tar == null { print $"jab bench: the run is left unpacked in its directory: ($packed.error)" }
    if ($dir | path join "watch" | path exists) { print "jab bench: the watch recording this run packs it again, its recording included, when it ends" }
    print $"jab bench: ($b.name) ($final), ($total) steps($failures)($unreported); everything in (if $packed.tar == null { $dir } else { $packed.tar })"
    if $final != "done" { exit 1 }
}

# The QEMUs of a bench's run, each its pid with its command line from
# one look at the process table: those whose command lines name the
# run's directory.
def bench-qemus [run: path]: nothing -> list<record<pid: int, command: string>> {
    ps -l | where {|p| ((process command-binary $p.command | path basename) == (host exe-name $process.qemu_name)) and ($p.command | str contains $run) } | each {|p| { pid: $p.pid, command: $p.command } }
}

# The step a QEMU of a bench's run belongs to, read from the command
# line the process table showed with its pid (bench-qemus): the step
# directory under the run's directory its pid file and its logs sit in,
# every step writing under `<run>/<label>/`; `unknown` when the line
# names none of the bench's steps.
def bench-step-of [command: string, run: path, labels: list<string>]: nothing -> string {
    let parts = ($command | split row $"($run)/")
    if ($parts | length) < 2 { return "unknown" }
    let named = ($parts | get 1 | split row "/" | first)
    if $named in $labels { $named } else { "unknown" }
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
# thread once a second, under the step its own command line names as the
# process table showed it, or `unknown` (bench-step-of), to
# watch/<step>-<n>.nuonl in the run's directory, a
# line printed as each
# starts and ends and the rates every five seconds. When the bench has
# finished and no QEMU of it is left, it prints the bench's report and
# its own per QEMU, the steady CPU seconds a second after the first
# `--skip` (watch-report-of), writes them together as watch.nuon in the
# run's directory, then packs the run again, its recording included
# (bench-tar), and names that tar last, the file to copy off the host.
# Interrupted, it ends with no report.
def "main watch bench" [...words: string, --skip: float = 5.0] {
    if ($words | is-empty) { error make {msg: "nu jab.nu watch bench <program>/<bench> <workspace>"} }
    let ws = ($words | last | path expand)
    if not (workspace is-workspace $ws) { error make {msg: $"($ws) is no workspace's root"} }
    let named = ($words | drop 1)
    if ($named | is-empty) { print (bench-list $ws); return }
    let b = (bench-at $ws ($named | first))
    let state_file = (bench-home $b | path join "state.nuon")
    let before = (bench-state $state_file)
    mut state: any = (if $before != null and (bench-live $before) { $before } else { null })
    if $state == null { print $"jab watch: waiting for ($b.name) to start: `just bench ($b.name)` in another terminal" }
    while $state == null {
        sleep 1sec
        let s = (bench-state $state_file)
        if $s != null and ($before == null or $s.stamp != $before.stamp) { $state = $s }
    }
    let run = $state.dir
    let stamp = $state.stamp
    let root = (target root $ws)
    let labels = ($b.def.steps | get label)
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
        let found = (bench-qemus $run)
        let pids = ($found | each {|q| $q.pid })
        let known = ($seen | each {|e| $e.pid })
        for q in ($found | where {|x| $x.pid not-in $known }) {
            let pid = $q.pid
            let step = (bench-step-of $q.command $run $labels)
            let n = (($seen | where {|e| $e.label == $step } | length) + 1)
            let file = ($watch_dir | path join $"($step)-($n).nuonl")
            let started = (date now)
            target retire $file $root
            ({ run: (watch-header $pid $started) } | to nuon) + (char nl) | save --raw $file
            $seen = ($seen | append { pid: $pid, label: $step, n: $n, file: $file, started: $started, ended: false })
            print $"jab watch: ($step), QEMU ($n), ($pid)"
        }
        let now = (date now)
        for e in ($seen | enumerate | where {|x| not $x.item.ended }) {
            if $e.item.pid in $pids {
                ({ at: (($now - $e.item.started) / 1sec), threads: (process threads-of $e.item.pid), rss: (process memory-of $e.item.pid) } | to nuon) + (char nl) | save --raw --append $e.item.file
            } else {
                let i = $e.index
                $seen = ($seen | enumerate | each {|x| if $x.index == $i { $x.item | merge { ended: true } } else { $x.item } })
                let r = (try { watch-report-of $e.item.file $skip } catch { null })
                print (if $r == null { $"jab watch: ($e.item.label), QEMU ($e.item.n) ended, too short to report" } else { $"jab watch: ($e.item.label), QEMU ($e.item.n) ended: ($r.process) of a core over ($r.seconds) s; (watch-top $r.threads)(memory-text $r.memory)" })
            }
        }
        $tick += 1
        if ($tick mod 5) == 0 {
            for e in ($seen | where {|x| not $x.ended }) {
                let rates = (watch-rates $e.file 5)
                if $rates != "" { print $"  ($e.label) ($e.n): ($rates)" }
            }
        }
        let finished = ($current.state in [done failed]) or (not (process process-alive ($current.pid | into string)))
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
        print (if ($p.watch | get -o error) != null { $"  ($p.step) ($p.n): ($p.watch.error)" } else { $"  ($p.step) ($p.n): ($p.watch.process) of a core over ($p.watch.seconds) s; (watch-top $p.watch.threads)(memory-text $p.watch.memory)" })
    }
    let report_file = ($run | path join "report.nuon")
    let whole = {
        bench: $b.name, run: $stamp, dir: $run, state: $ended,
        steps: (try { open ($run | path join "bench.nuon") | get steps } catch { null }),
        report: (if ($report_file | path exists) { open $report_file } else { null }),
        watch: $per,
    }
    let out = ($run | path join "watch.nuon")
    target retire $out $root
    $whole | to nuon --indent 2 | save --raw $out
    let packed = (try { { tar: (bench-tar ($run | path dirname) $stamp $b.name $root), error: "" } } catch {|e| { tar: null, error: $e.msg } })
    print (if $packed.tar == null { $"jab watch: ($out); the run is left unpacked in its directory: ($packed.error)" } else { $"jab watch: everything in ($packed.tar)" })
}

# The headless machine for a program prepared and printed as JSON, for a
# harness in another language to run and drive: `nu jab.nu plan <dir>
# --disk <romfs> --serial fps --api --gamepad --set debug`, the kernel and
# the image the program's own builds, `out` under the program's build tree
# unless given, `--spec`, `--harts`, and `--bootargs` plan's.
def "main plan" [dir: path, --out: string = "", --disk: string = "", --serial: string = "disk0", --set: string = "", --api, --gamepad, --pad-port, --no-kbm, --sound, --spec (-s): string = "", --harts: int = 0, --bootargs: string = ""] {
    let names = (build symbols $set)
    let c = (build context ($dir | path expand) "program" $names)
    let ready = (prepared ($dir | path expand) $names)
    let out = (if $out == "" { $c.out | path join "machine" } else { $out | path expand })
    plan --kernel $ready.kernel --image $ready.image --out $out --api=$api --disk $disk --serial $serial --set $set --gamepad=$gamepad --pad-port=$pad_port --no-kbm=$no_kbm --sound=$sound --spec $spec --harts $harts --bootargs $bootargs | to json
}

# Test with DEBUG set beside whatever --set names: at a workspace's root
# every program's test, or those at or under a path, with a summary,
# failing if any fails; at a program's directory its test/test.nu on the
# debug kernel. `--spec` names the spec every launch of the tests runs
# that names none of its own, JAB_SPEC for them (spec-default).
def "main test" [dir: path, ...words: string, --set: string = "", --spec (-s): string = ""] {
    let names = (build symbols $set)
    let forced = (if $spec == "" { {} } else { { JAB_SPEC: $spec } })
    with-env $forced {
        if (workspace is-workspace $dir) { test-under $dir $words $names; return }
        build prepare $dir "test"
        ^nu ...(test-args (prepared $dir (build with-debug $names)))
    }
}

# Build, then run one program with its window and the UART on stdio: at
# a workspace's root the program at a path, never a test (run-target),
# at a program's directory that program. Release unless --set says
# otherwise; the API's port on the machine with --api; the keyboard and
# the tablet off with --no-kbm, the gamepad the host has off with
# --no-pad, the sound device off with --no-sound; the machine the spec
# --spec names, its cores, RAM, and display, or the configured default,
# or a custom one of one to eight harts with --harts for a diagnostic run,
# the two together refused.
# QEMU's exit code is the program's status.
def "main run" [dir: path, ...words: string, --set: string = "", --api, --kbm, --no-kbm, --pad, --no-pad, --no-sound, --spec (-s): string = "", --harts: int = 0] {
    let program = (if (workspace is-workspace $dir) { workspace run-target $dir $words } else { $dir | path expand })
    if $spec != "" and $harts != 0 { error make {msg: $"--spec ($spec) with --harts ($harts): a named spec provisions its own harts, and --harts names a custom machine; one or the other"} }
    if $harts != 0 { machine of $harts | ignore }
    build prepare $program "run"
    run-program $program (build symbols $set) $api (pad kbm-choice $kbm $no_kbm) (pad pad-choice $pad $no_pad) (not $no_sound) --spec $spec --harts $harts
}

# Probe one program under a window for --seconds and print one NUON
# record on how its flips reached the window, at a workspace's root the
# program at a path, at a program's directory that program; release
# unless --set says otherwise. `sdl` is the one probe; `--api`, `--send
# <file>`, and `--trace` are probe-sdl's.
def "main probe" [dir: path, kind: string, ...words: string, --seconds: int = 12, --set: string = "", --api, --send: string = "", --trace] {
    let program = (if (workspace is-workspace $dir) { workspace program-at $dir $words } else { $dir | path expand })
    let send = (if $send == "" { "" } else { $send | path expand })
    build prepare $program "run"
    probe $program $kind (build symbols $set) $seconds --api=$api --send $send --trace=$trace
}

def main [] {
    print "nu jab.nu test <workspace> [path] [--set names]; nu jab.nu run <workspace> <path> [--set names] [--api] [--no-kbm] [--no-pad] [--no-sound] [--spec name | --harts 1..8]; nu jab.nu <test|run> <program dir> [--set names]; nu jab.nu probe <workspace> sdl <path> [--seconds N]; nu jab.nu do <workspace> [command] [args]; nu jab.nu bench <workspace> [<program>/<bench>] [--only labels]; nu jab.nu watch [--skip N] <workspace>; nu jab.nu watch bench <program>/<bench> <workspace> [--skip N]; nu jab.nu plan <program dir> [flags]; build, clean, and retire: nu/bin/do.nu build and nu/bin/nuance.nu clean and retire"
}
