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
use ../../nu/mod/bench
use ../../nu/mod/bound
use ../../nu/mod/build
use ../../nu/mod/chardev
use ../../nu/mod/demand
use ../../nu/mod/disco
use ../../nu/mod/disk
use ../../nu/mod/launch
use ../../nu/mod/machine
use ../../nu/mod/nonce
use ../../nu/mod/pad
use ../../nu/mod/process
use ../../nu/mod/sdl/bundle
use ../../nu/mod/sdl/report
use ../../nu/mod/target
use ../../nu/mod/tool
use ../../nu/mod/workspace

# This tool's own file, which `do` runs again for the SDK's commands.
const self = (path self)
# virt's map has this many virtio-mmio transports, a hard ceiling on
# the devices a line can carry.
const transport_limit = 8
const devices = [
    "-device" "virtio-net-device,netdev=net0" "-netdev" "user,id=net0"
] ++ $machine.rng_device

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
    let inputs = (if $kbm { $launch.input_devices } else { [] })
    let audio = (if $sound { audio sound-args (audio audio-plan ($found | get -o audio)) } else { [] })
    let args = ($machine ++ (machine name-args $c.manifest.name) ++ (machine memory-args $m) ++ $launch.display_device ++ $inputs ++ $gamepad.args ++ $devices ++ $audio ++ (disk disks-args (disk machine-disks $disk $disk_serial ($assets != "") $c.workspace)) ++ $ports.args ++ [
        "-bios" "none" "-kernel" $ready.kernel
        "-device" $"loader,file=($ready.image),addr=($launch.program_base),force-raw=on"
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
    let report = (report $log)
    bundle $out $bundle | ignore
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
    if ($named | is-empty) { print (bench bench-list $ws); return }
    let b = (bench bench-at $ws ($named | first))
    let state_file = (bench bench-home $b | path join "state.nuon")
    let before = (bench bench-state $state_file)
    mut state: any = (if $before != null and (bench bench-live $before) { $before } else { null })
    if $state == null { print $"jab watch: waiting for ($b.name) to start: `just bench ($b.name)` in another terminal" }
    while $state == null {
        sleep 1sec
        let s = (bench bench-state $state_file)
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
        let read = (bench bench-state $state_file)
        let current = (if $read != null and $read.stamp == $stamp { $read } else { $state })
        if $current.label != "" and $current.label != $label { print $"jab watch: step ($current.step) of ($current.total), ($current.label)" }
        $label = $current.label
        let found = (bench bench-qemus $run)
        let pids = ($found | each {|q| $q.pid })
        let known = ($seen | each {|e| $e.pid })
        for q in ($found | where {|x| $x.pid not-in $known }) {
            let pid = $q.pid
            let step = (bench bench-step-of $q.command $run $labels)
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
    let last = (bench bench-state $state_file)
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
    let packed = (try { { tar: (bench bench-tar ($run | path dirname) $stamp $b.name $root), error: "" } } catch {|e| { tar: null, error: $e.msg } })
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
    launch plan --kernel $ready.kernel --image $ready.image --out $out --api=$api --disk $disk --serial $serial --set $set --gamepad=$gamepad --pad-port=$pad_port --no-kbm=$no_kbm --sound=$sound --spec $spec --harts $harts --bootargs $bootargs | to json
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
    print "nu jab.nu test <workspace> [path] [--set names]; nu jab.nu run <workspace> <path> [--set names] [--api] [--no-kbm] [--no-pad] [--no-sound] [--spec name | --harts 1..8]; nu jab.nu <test|run> <program dir> [--set names]; nu jab.nu probe <workspace> sdl <path> [--seconds N]; nu jab.nu do <workspace> [command] [args]; nu jab.nu watch [--skip N] <workspace>; nu jab.nu watch bench <program>/<bench> <workspace> [--skip N]; nu jab.nu plan <program dir> [flags]; build and bench: nu/bin/do.nu build and bench; clean and retire: nu/bin/nuance.nu clean and retire"
}
