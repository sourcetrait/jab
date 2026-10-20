use (path self ../audio)
use (path self ../bound)
use (path self ../build)
use (path self ../chardev)
use (path self ../demand)
use (path self ../disco)
use (path self ../disk)
use (path self ../image)
use (path self ../machine)
use (path self ../nonce)
use (path self ../pad)
use (path self ../process)
use (path self ../spec)
use (path self ../supervise)
use (path self ../target)
use (path self ../tool)
use (path self ../machine) [rng_device]

# The program window's base, past the kernel's and the framebuffer's MiB
export const program_base = "0x80a00000"

# The GPU device at the ABI's display size
export const display_device = ["-device" "virtio-gpu-device,xres=1920,yres=1080"]

# The keyboard and the tablet, virtio-input devices on the line
export const input_devices = [
    "-device" "virtio-keyboard-device"
    "-device" "virtio-tablet-device"
]

# A headless machine prepared and not run: its line, environment, and paths
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
    --workspace: path = ""
]: nothing -> record<qemu_binary: string, timeout_binary: string, timeout_version: string, timeout_override: string, qemu: list<string>, env: record, out: string, serial_log: string, qemu_log: string, screen: string, pidfile: string, monitor: string, debug_log: string, api_in: string, api_out: string, pad_fifo: string, pad_pipe_in: string, pad_port: bool, pad_header: string, sound: string, workspace: string, target: string, window: string, audio: string, bridge: oneof<record<name: string, vendor: oneof<int, nothing>, product: oneof<int, nothing>>, nothing>, bridge_pipe: string, relays: list<record<endpoint: string, name: string, inward: string, outward: string>>, machine: record, bootargs: string, demand: oneof<record, nothing>, sends: table<at: duration, bytes: binary>, sdl_log: string, shim: string, capture_nonce: oneof<int, nothing>, profile: string, capture: record> {
    let out = ($out | path expand)
    let ws = (if $workspace != "" { $workspace | path expand } else { image workspace $kernel $image $out })
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
    let piped = (if not $windows { [] } else {
        [{ endpoint: "monitor", pipe: $watch } { endpoint: "api", pipe: $ports.api }] ++ (if $hosted.port { [] } else { [{ endpoint: "padport", pipe: $ports.pad }] })
    })
    let relays = (chardev relays-of $piped)
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
        timeout_version: $bound.version, timeout_override: $bound.override,
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

# A run's capture identity: profile, nonce, QEMU's pid, shim, window, sends
def capture-identity [machine: record, pid: oneof<int, nothing>]: nothing -> record<profile: string, capture_nonce: oneof<int, nothing>, qemu_pid: oneof<int, nothing>, sdl_log: string, shim: string, window: string, api: bool, sends: list<record<at: float, length: int, sha256: string>>> {
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

# A program run headless on the kernel under QEMU, its outputs read back
export def main [
    --kernel: path
    --image: path
    --out: path
    --seconds: int = 10
    --capture: duration = 0sec
    --screen: duration = 0sec
    --stop: duration = 0sec
    --keys: table<at: duration, key: string, hold: int> = []
    --api
    --send: table<at: duration, bytes: binary> = []
    --disk: path = ""
    --serial: string = "disk0"
    --set: string = ""
    --pad: path = ""
    --pad-port
    --kbm
    --no-kbm
    --sound
    --window
    --live-sound
    --host-pad
    --spec (-s): string = ""
    --harts: int = 0
    --bootargs: string = ""
    --dtb: path = ""
    --threads: duration = 0sec
    --threads-at: list<duration> = []
    --qemu: list<string> = []
    --sdl-probe: path = ""
    --capture-nonce: int = 0
    --profile: string = ""
    --workspace: path = ""
]: nothing -> record<status: oneof<int, nothing>, serial: string, debug: string, api: binary, screen: string, qemu_log: string, stderr: string, cpu_seconds: oneof<float, nothing>, wall_seconds: oneof<float, nothing>, sound: string, qemu_binary: string, timeout_binary: string, timeout_version: string, timeout_override: string, qemu: list<string>, overrides: list<string>, window: string, audio: string, machine: record, threads: list<record<name: string, delta: float, rate: float>>, threads_span: oneof<float, nothing>, thread_readings: list<any>, screen_started: oneof<float, nothing>, screen_completed: oneof<float, nothing>, send_seconds: list<oneof<float, nothing>>, quit_seconds: oneof<float, nothing>, unfinished: list<record<kind: string, index: int, state: string, accepted: int, length: int>>, incomplete: oneof<string, nothing>, launch: string, declared: bool, diagnostic: bool, qemu_pid: oneof<int, nothing>, sdl_log: string, shim: string, capture_nonce: oneof<int, nothing>, profile: string, capture: record> {
    if $kbm and $no_kbm { error make {msg: "--kbm and --no-kbm together: one or the other"} }
    if $capture != 0sec and $screen != 0sec { error make {msg: "--capture and --screen together: one screen a run, ending it or not"} }
    if $capture != 0sec and $stop != 0sec { error make {msg: "--capture and --stop together: a capture's quit ends the run at its screen, a stop's at its own time; one or the other"} }
    let gamepad = (pad pad-table $pad)
    let nonce = (nonce mint $capture_nonce ($sdl_probe != ""))
    let machine = (plan --kernel $kernel --image $image --out $out --api=$api --send $send --disk $disk --serial $serial --set $set --gamepad=(not ($pad | is-empty)) --pad-port=$pad_port --no-kbm=$no_kbm --sound=$sound --window=$window --live-sound=$live_sound --host-pad=$host_pad --spec $spec --harts $harts --bootargs $bootargs --dtb $dtb --sdl-probe $sdl_probe --capture-nonce $nonce --profile $profile --workspace $workspace)
    let out = $machine.out
    let line = ($machine.qemu ++ $qemu)
    for f in ["qemu.stdout" "qemu.stderr"] { target retire ($out | path join $f) $machine.target }
    let pads = ($gamepad | merge { port: $machine.pad_port, fifo: $machine.pad_fifo, header: ($machine.pad_header | decode hex) })
    let helpers = (pad bridge-helpers $machine.bridge $machine.bridge_pipe $machine.workspace $out $machine.target)
    let schedule = (schedule-of $machine (supervise hex (supervise token)) $line $seconds $keys $pads --capture $capture --screen $screen --stop $stop --threads $threads --threads-at $threads_at --helpers $helpers)
    let supervised = (supervise bounded $schedule $machine.target $seconds)
    let receipt = $supervised.receipt
    if $receipt != null and $receipt.outcome.decision != "go" { error make {msg: $"the launch's startup ended ($receipt.outcome.decision), so nothing measured ran"} }
    let stderr = (if $receipt != null and ($receipt.stderr | path exists) { open --raw $receipt.stderr | decode } else { "" })
    if $receipt != null and $receipt.failure != null {
        let said = ($stderr | str trim)
        error make {msg: $"($receipt.failure); QEMU ended with (ended-text $receipt)(if $said == '' { '' } else { $', saying: ($said)' })"}
    }
    let ran_on = ($machine.machine | update overrides $qemu)
    let actions = (if $receipt == null { [] } else { $receipt.actions })
    let shot = ($actions | where {|a| $a.kind == "screen" } | get -o 0)
    let whole = ($shot != null and $shot.whole == true)
    let quit = ($actions | where {|a| $a.kind == "quit" } | get -o 0)
    let readings = (if $receipt == null { [] } else { $receipt.readings })
    let held = ($readings | where {|r| $r.kind == "held" } | sort-by index)
    let span = (if ($held | length) == 2 and ($held | all {|r| $r.threads != null }) {
        process threads-between $held.0.threads $held.1.threads (seconds-of ($held.1.start_ns - $held.0.start_ns))
    } else { null })
    let qemu_pid = (if $receipt == null { null } else { $receipt.qemu_pid })
    {
        status: (status-of $receipt),
        serial: (if ($machine.serial_log | path exists) { open --raw $machine.serial_log | decode } else { "" }),
        debug: (if $machine.debug_log != "" and ($machine.debug_log | path exists) { open --raw $machine.debug_log | decode } else { "" }),
        api: (if $machine.api_out != "" and ($machine.api_out | path exists) { open --raw $machine.api_out | into binary } else { 0x[] }),
        screen: (if $whole { $machine.screen } else { "" }),
        qemu_log: $machine.qemu_log,
        stderr: $stderr,
        cpu_seconds: (if $receipt == null { null } else { $receipt.cpu_seconds }),
        wall_seconds: (if $receipt == null { null } else { seconds-of $receipt.end_ns }),
        sound: (if $machine.sound != "" and ($machine.sound | path exists) { $machine.sound } else { "" }),
        qemu_binary: $machine.qemu_binary,
        timeout_binary: $machine.timeout_binary,
        timeout_version: $machine.timeout_version, timeout_override: $machine.timeout_override,
        qemu: $line,
        overrides: $qemu,
        window: $machine.window,
        audio: $machine.audio,
        machine: $ran_on,
        threads: (if $span == null { [] } else { $span.threads }),
        threads_span: (if $span == null { null } else { $span.span }),
        thread_readings: ($readings | where {|r| $r.kind == "at" } | sort-by index | each {|r| { requested: (seconds-of $r.requested_ns), at: (seconds-of $r.start_ns), threads: $r.threads } }),
        screen_started: (if $shot == null { null } else { seconds-of $shot.first_ns }),
        screen_completed: (if $whole { seconds-of $shot.whole_ns } else { null }),
        send_seconds: ($machine.sends | enumerate | each --keep-empty {|e|
            let sent = ($actions | where {|a| $a.kind == "send" and $a.index == $e.index } | get -o 0)
            if $sent == null { null } else { seconds-of $sent.done_ns }
        }),
        quit_seconds: (if $quit == null { null } else { seconds-of $quit.done_ns }),
        unfinished: ($actions | where {|a| $a.state != "complete" } | each {|a| { kind: $a.kind, index: $a.index, state: $a.state, accepted: $a.accepted, length: $a.length } }),
        incomplete: $supervised.incomplete,
        launch: $supervised.launch,
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

# Nanoseconds as seconds, a float; null stays null
def seconds-of [ns: oneof<int, nothing>]: nothing -> oneof<float, nothing> {
    if $ns == null { null } else { $ns / 1e9 }
}

# A receipt's exit as the launch's status: the child's, else 128 and its signal
def status-of [receipt: oneof<record, nothing>]: nothing -> oneof<int, nothing> {
    if $receipt == null { return null }
    if $receipt.status != null { return $receipt.status }
    if $receipt.signal != null { return (128 + $receipt.signal) }
    null
}

# A receipt's exit as words: its status or its signal
def ended-text [receipt: record]: nothing -> string {
    if $receipt.status != null { $"status ($receipt.status)" } else if $receipt.signal != null { $"signal ($receipt.signal)" } else { "no status" }
}

# A launch's schedule: QEMU under the bound, its pipes, actions, and readings
export def schedule-of [machine: record, token: string, line: list<string>, seconds: int, keys: table<at: duration, key: string, hold: int>, pads: record, --capture: duration = 0sec, --screen: duration = 0sec, --stop: duration = 0sec, --threads: duration = 0sec, --threads-at: list<duration> = [], --helpers: list<any> = []]: nothing -> record {
    let windows = ($nu.os-info.name == "windows")
    let end = {|endpoint: string, fifo: string| if $windows { $endpoint } else { $fifo } }
    let monitor = [{ name: "monitor", path: (do $end "monitor" ($machine.monitor + ".in")) }]
    let api = (if $machine.api_in == "" { [] } else { [{ name: "api", path: (do $end "api" $machine.api_in) }] })
    let pad = (if $pads.port { [{ name: "pad", path: (do $end "padport" $machine.pad_pipe_in) }] } else if $pads.fifo != "" { [{ name: "pad", path: $pads.fifo }] } else { [] })
    let line_of = {|text: string| $text | into binary }
    let events = ([
        ($keys | enumerate | each {|e| { kind: "key", index: $e.index, at: $e.item.at, pipe: "monitor", bytes: (do $line_of $"sendkey ($e.item.key) ($e.item.hold)\n") } })
        ($machine.sends | enumerate | each {|e| { kind: "send", index: $e.index, at: $e.item.at, pipe: "api", bytes: $e.item.bytes } })
        ($pads.groups | enumerate | each {|e| { kind: "pad", index: $e.index, at: $e.item.at, pipe: "pad", bytes: (if $pads.port { pad pad-frames $e.item.items } else { pad pad-report $e.item.items }) } })
    ] | flatten | enumerate | each {|e| $e.item | insert rank 1 | insert order $e.index | insert screen null })
    let shot = (if $capture != 0sec { $capture } else if $screen != 0sec { $screen } else { null })
    let size = $spec.display_size
    let header = ($"P6\n($size.width) ($size.height)\n255\n" | into binary)
    let quit = { kind: "quit", index: 0, pipe: "monitor", bytes: (do $line_of "quit\n"), rank: 0, screen: null }
    let screens = (if $shot == null { [] } else {
        let shooting = { kind: "screen", index: 0, at: $shot, pipe: "monitor", bytes: (do $line_of $"screendump (chardev hmp-quoted $machine.screen)\n"), rank: 0, order: 0, screen: { file: $machine.screen, header: $header, size: (($header | bytes length) + $size.width * $size.height * 3) } }
        let ending = (if $capture != 0sec { [($quit | insert at $shot | insert order 1)] } else { [] })
        [$shooting] ++ $ending
    })
    let stops = (if $stop == 0sec { [] } else { [($quit | insert at $stop | insert order 2)] })
    let actions = ($events ++ $screens ++ $stops | sort-by at rank order | each {|a| { kind: $a.kind, index: $a.index, due_ns: ($a.at | into int), pipe: $a.pipe, bytes: $a.bytes, screen: $a.screen } })
    let held = (if $threads == 0sec { [] } else { [{ kind: "held", index: 0, requested_ns: ($threads | into int) } { kind: "held", index: 1, requested_ns: (($threads + 1sec) | into int) }] })
    let asked = ($threads_at | sort | enumerate | each {|e| { kind: "at", index: $e.index, requested_ns: ($e.item | into int) } })
    {
        token: $token,
        mode: "bounded",
        dir: $machine.out,
        command: ([$machine.timeout_binary "--signal=TERM" $"--kill-after=($supervise.kill_after / 1sec | into int)s" ($seconds | into string) $machine.qemu_binary] ++ $line),
        env: ($machine.env | transpose name value | each {|v| { name: $v.name, value: ($v.value | into string) } }),
        stdout: ($machine.out | path join "qemu.stdout"),
        stderr: ($machine.out | path join "qemu.stderr"),
        pidfile: $machine.pidfile,
        pipes: ($monitor ++ $api ++ $pad),
        header: (if $pads.port and ($pads.header | bytes length) > 0 { { pipe: "pad", bytes: $pads.header } } else { null }),
        actions: $actions,
        readings: ($held ++ $asked),
        relays: (if $windows { $machine.relays | each {|r| { endpoint: $r.endpoint, name: $r.name, inward: $r.inward, outward: $r.outward } } } else { [] }),
        helpers: $helpers,
        bounds: (supervise bounds),
    }
}

# The order a launch's poll takes its timed actions in, the screen among them
export def due-order [events: table<kind: string, index: int, at: duration>, screen: oneof<duration, nothing>, elapsed: duration]: nothing -> table<kind: string, index: int, at: duration> {
    let due = ($events | enumerate | each {|e| $e.item | insert order $e.index } | where {|e| $e.at <= $elapsed } | sort-by at order | reject -o order)
    if $screen == null or $screen > $elapsed { return $due }
    ($due | where {|e| $e.at < $screen }) ++ [{ kind: "screen", index: 0, at: $screen }] ++ ($due | where {|e| $e.at >= $screen })
}
