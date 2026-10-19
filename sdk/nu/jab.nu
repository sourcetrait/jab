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

use ../../nu/mod/bound
use ../../nu/mod/build
use ../../nu/mod/chardev
use ../../nu/mod/nonce
use ../../nu/mod/process
use ../../nu/mod/program
use ../../nu/mod/sdl/bundle
use ../../nu/mod/sdl/report
use ../../nu/mod/target
use ../../nu/mod/tool
use ../../nu/mod/workspace

# This tool's own file, which `do` runs again for the SDK's commands.
const self = (path self)

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
    let line = (program run-line $dir $names $api_on "sdl,gl=on" "none" true false false)
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
    print "nu jab.nu probe <workspace> sdl <path> [--seconds N]; nu jab.nu do <workspace> [command] [args]; build, test, run, bench, and watch: nu/bin/do.nu; watch bench, clean, and retire: nu/bin/nuance.nu; plan: nu/bin/nuance/plan.nu"
}
