use (path self ../bound)
use (path self ../build)
use (path self ../nonce)
use (path self ../program)
use (path self ../sdl/bundle)
use (path self ../sdl/report)
use (path self ../supervise)
use (path self ../target)
use (path self ../tool)
use (path self ../workspace)

# walk's CADENCE build's symbols, in the order its header names them
const cadence_symbols = [CADENCE TIMING REPLAY PREPARE CADENCE_TEST]

# A replay stream's header bytes
const replay_header = 64

# A replay stream's magic, WRPL little-endian
const replay_magic = 0x4c505257

# The most frames a replay stream holds, walk's frame buffer
const replay_frames = 8192

# The guest's clock, ticks a second
const time_hz = 10_000_000

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
    let program_at = ($dir | path relative-to $c.workspace)
    let fields = (if "REPLAY" in $names and $send != "" { build-fields $program_at $line.image $line.kernel --replay $send } else { build-fields $program_at $line.image $line.kernel })
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
    let run = (probe-launch $binary ($line.args ++ ["-pidfile" $pidfile] ++ $traced) $extra $seconds $pidfile $api_in $sends $bound.path $out $line.context.root)
    if not ($log | path exists) { error make {msg: $"QEMU wrote no shim log; its stderr:\n($run.stderr)"} }
    if $api_on { cp ($line.context.out | path join "api.out") $kept }
    let qemu = (^$binary --version | complete | get stdout | lines | get -o 0 | default "")
    let profile = $planned.profile
    let sent = ($sends | each {|s| { at: ($s.at / 1sec), length: ($s.bytes | bytes length), sha256: ($s.bytes | hash sha256) } })
    { profile: $profile, capture_nonce: $nonce, qemu_pid: $run.qemu_pid, sdl_log: $log, shim: $shim, window: "sdl,gl=on", api: $api_on, sends: $sent } | merge $fields | to nuon --indent 2 | save --raw $identity_file
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

# A run's build as its identity names it: the image, its kernel, and their symbols
export def build-fields [program: string, image: path, kernel: path, --replay: path]: nothing -> record<workload: record<program: string, order: string>, image: record<file: string, sha256: string>, kernel: record<file: string, sha256: string>, flags: string, cadence: list<string>, replay: oneof<record<file: string, sha256: string, frames: int, window_s: float, bound: int>, nothing>> {
    let image = ($image | path expand)
    let kernel = ($kernel | path expand)
    let stamp = ($image | path dirname | path join "flags")
    if not ($stamp | path exists) { error make {msg: $"the image has no build flags beside it: ($stamp)"} }
    let flags = (open --raw $stamp | decode | lines | get 0)
    let symbols = ($flags | parse --regex '--defsym (?P<name>[A-Z0-9_]+)=1' | get name)
    let replaying = ("REPLAY" in $symbols)
    if $replaying and $replay == null { error make {msg: $"the image is a REPLAY build and no replay stream was given: ($image)"} }
    if (not $replaying) and $replay != null { error make {msg: $"a replay stream was given and the image is no REPLAY build: ($image)"} }
    {
        workload: { program: $program, order: (if "PREPARE" in $symbols { "prepare" } else { "await" }) },
        image: (file-of $image),
        kernel: (file-of $kernel),
        flags: $flags,
        cadence: ($cadence_symbols | where {|s| $s in $symbols }),
        replay: (if $replaying { replay-stream $replay | reject bytes } else { null }),
    }
}

# A file as an identity names it, its path and its SHA-256
def file-of [file: path]: nothing -> record<file: string, sha256: string> {
    { file: $file, sha256: (open --raw $file | hash sha256) }
}

# A replay stream as a run sends it, held to the header walk reads
export def replay-stream [stream: path]: nothing -> record<file: string, sha256: string, frames: int, window_s: float, bound: int, bytes: binary> {
    let bytes = (open --raw $stream | into binary)
    let length = ($bytes | bytes length)
    if $length < $replay_header { error make {msg: $"the replay stream is shorter than its header: ($stream), ($length) bytes"} }
    let magic = ($bytes | bytes at 0..<4 | into int --endian little)
    if $magic != $replay_magic { error make {msg: $"the replay stream's magic is not WRPL: ($stream)"} }
    let frames = ($bytes | bytes at 8..<12 | into int --endian little)
    if $frames < 1 or $frames > $replay_frames { error make {msg: $"the replay stream's frames are 1 to ($replay_frames), not ($frames): ($stream)"} }
    if $length != ($replay_header + $frames * 4) { error make {msg: $"the replay stream holds ($length) bytes where its ($frames) frames need ($replay_header + $frames * 4): ($stream)"} }
    let ticks = (0..<$frames | each {|i| $bytes | bytes at ($replay_header + $i * 4)..<($replay_header + $i * 4 + 4) | into int --endian little } | math sum)
    let window_s = ($ticks / $time_hz)
    { file: ($stream | path expand), sha256: ($bytes | hash sha256), frames: $frames, window_s: $window_s, bound: ((2 * $window_s + 60) | math ceil), bytes: $bytes }
}

# QEMU's words tracing the GPU's flushes and set_scanouts, stamped, into a log
export def trace-args [qemu: string, log: path]: nothing -> list<string> {
    let events = (^$qemu -trace help | complete | get stdout | lines | each {|l| $l | str trim })
    let missing = (["virtio_gpu_cmd_res_flush" "virtio_gpu_cmd_set_scanout"] | where {|e| $e not-in $events })
    if not ($missing | is-empty) { error make {msg: $"($qemu) lists no trace event ($missing | str join ' or '), which --trace needs"} }
    ["-msg" "timestamp=on" "-trace" "virtio_gpu_cmd_res_flush" "-trace" "virtio_gpu_cmd_set_scanout" "-D" $log]
}

# A probe's QEMU run under its supervisor to its exit or bound, its sends written at their times
def probe-launch [binary: string, args: list<string>, environment: record, seconds: int, pidfile: path, api_in: string, sends: list<record<at: duration, bytes: binary>>, bound: string, out: path, root: path]: nothing -> record<exit: int, stderr: string, qemu_pid: oneof<int, nothing>, send_seconds: list<oneof<float, nothing>>> {
    for f in ["qemu.stdout" "qemu.stderr"] { target retire ($out | path join $f) $root }
    let actions = (if $api_in == "" { [] } else {
        $sends | enumerate | each {|e| { kind: "send", index: $e.index, at: $e.item.at, bytes: $e.item.bytes } } | sort-by at index | each {|s| { kind: "send", index: $s.index, due_ns: ($s.at | into int), pipe: "api", bytes: $s.bytes, screen: null } }
    })
    let schedule = {
        token: (supervise hex (supervise token)),
        mode: "bounded",
        dir: $out,
        command: ([$bound "--signal=TERM" $"--kill-after=($supervise.kill_after / 1sec | into int)s" ($seconds | into string) $binary] ++ $args),
        env: ($environment | transpose name value | each {|v| { name: $v.name, value: ($v.value | into string) } }),
        stdout: ($out | path join "qemu.stdout"),
        stderr: ($out | path join "qemu.stderr"),
        pidfile: $pidfile,
        pipes: (if $api_in == "" { [] } else { [{ name: "api", path: $api_in }] }),
        header: null,
        actions: $actions,
        readings: [],
        relays: [],
        helpers: [],
        bounds: (supervise bounds),
    }
    let supervised = (supervise bounded $schedule $root $seconds)
    let receipt = $supervised.receipt
    if $receipt == null { error make {msg: $"the probe's run left no receipt: ($supervised.incomplete)"} }
    if $receipt.outcome.decision != "go" { error make {msg: $"the probe's startup ended ($receipt.outcome.decision), so nothing ran"} }
    let stderr = (if ($receipt.stderr | path exists) { open --raw $receipt.stderr | decode } else { "" })
    if $receipt.failure != null { error make {msg: $"($receipt.failure); QEMU said: ($stderr | str trim)"} }
    let status = (if $receipt.status != null { $receipt.status } else { 128 + ($receipt.signal | default 0) })
    let written = ($sends | enumerate | each --keep-empty {|e|
        let sent = ($receipt.actions | where {|a| $a.kind == "send" and $a.index == $e.index } | get -o 0)
        if $sent == null or $sent.done_ns == null { null } else { $sent.done_ns / 1e9 }
    })
    { exit: $status, stderr: $stderr, qemu_pid: $receipt.qemu_pid, send_seconds: $written }
}

# One program probed under a window, one NUON record on how its flips reached it
export def main [dir: path, kind: string, ...words: string, --seconds: int = 12, --set: string = "", --api, --send: string = "", --trace] {
    let s = (workspace subject $dir $words)
    let program = (if (workspace is-workspace $s.dir) { workspace program-at $s.dir $s.words } else { $s.dir | path expand })
    let send = (if $send == "" { "" } else { $send | path expand })
    build prepare $program "run"
    probe-kind $program $kind (build symbols $set) $seconds --api=$api --send $send --trace=$trace
}
