use ../bound
use ../build
use ../chardev
use ../nonce
use ../process
use ../program
use ../sdl/bundle
use ../sdl/report
use ../target
use ../tool
use ../workspace

# A program probed under a window by its kind, `sdl` the one probe
def probe-kind [dir: path, kind: string, names: list<string>, seconds: int, --api, --send: string = "", --trace]: nothing -> nothing {
    match $kind {
        "sdl" => { probe-sdl $dir $names $seconds --api=$api --send $send --trace=$trace },
        _ => { error make {msg: $"no probe called ($kind); there is `sdl`"} },
    }
}

# The SDL probe: a program run under the shim, its flips reported and bundled
def probe-sdl [dir: path, names: list<string>, seconds: int, --api, --send: string = "", --trace]: nothing -> nothing {
    if $nu.os-info.name != "linux" { error make {msg: "the sdl probe preloads a library into QEMU, which is Linux only"} }
    let c = (build context $dir "program" $names)
    if $c.workspace == null { error make {msg: "the sdl probe needs the program's workspace, above it or named by its manifest, which holds shim/crates/sdl"} }
    if $send != "" and not ($send | path exists) { error make {msg: $"--send ($send): no such file"} }
    let shim = (tool shim $c.workspace "jabshim_sdl")
    let nonce = (nonce mint 0 true)
    let planned = (plan $c.manifest $names $nonce --api=$api --send (if $send == "" { 0x[] } else { open --raw $send | into binary }))
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

# What a probe puts on the machine and sends; a paired one its nonce's frame first
export def plan [manifest: record, names: list<string>, nonce: int, --api, --send: binary = 0x[]]: nothing -> record<profile: string, api: bool, sends: list<record<at: duration, bytes: binary>>> {
    let paired = (probe-paired $manifest $names)
    let framed = (if $paired { [{ at: 200ms, bytes: (wnon-frame $nonce) }] } else { [] })
    let sends = ($framed ++ (if ($send | bytes length) == 0 { [] } else { [{ at: 200ms, bytes: $send }] }))
    { profile: (if $paired { "paired" } else { "generic" }), api: ($api or not ($sends | is-empty)), sends: $sends }
}

# Whether a probe of a build is paired: its build sets the manifest's `paired`
def probe-paired [manifest: record, names: list<string>]: nothing -> bool {
    let symbol = ($manifest | get -o paired | default "")
    $symbol != "" and (($symbol | str screaming-snake-case) in $names)
}

# The capture nonce's 16-byte WNON frame a paired program reads first
export def wnon-frame [nonce: int]: nothing -> binary {
    if $nonce < 1 { error make {msg: $"a capture nonce is 1 to 2^63 - 1, not ($nonce)"} }
    0x[57 4e 4f 4e 00 00 00 00] ++ ($nonce | into binary --endian little)
}

# QEMU's words tracing the GPU's flushes and set_scanouts, stamped, into a log
export def trace-args [qemu: string, log: path]: nothing -> list<string> {
    let events = (^$qemu -trace help | complete | get stdout | lines | each {|l| $l | str trim })
    let missing = (["virtio_gpu_cmd_res_flush" "virtio_gpu_cmd_set_scanout"] | where {|e| $e not-in $events })
    if not ($missing | is-empty) { error make {msg: $"($qemu) lists no trace event ($missing | str join ' or '), which --trace needs"} }
    ["-msg" "timestamp=on" "-trace" "virtio_gpu_cmd_res_flush" "-trace" "virtio_gpu_cmd_set_scanout" "-D" $log]
}

# A probe's QEMU run to its exit or bound, its pid kept and its sends written
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

# One program probed under a window, one NUON record on how its flips reached it
export def main [dir: path, kind: string, ...words: string, --seconds: int = 12, --set: string = "", --api, --send: string = "", --trace] {
    let program = (if (workspace is-workspace $dir) { workspace program-at $dir $words } else { $dir | path expand })
    let send = (if $send == "" { "" } else { $send | path expand })
    build prepare $program "run"
    probe-kind $program $kind (build symbols $set) $seconds --api=$api --send $send --trace=$trace
}
