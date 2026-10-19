use ../audio
use ../bound
use ../build
use ../chardev
use ../demand
use ../disco
use ../disk
use ../image
use ../machine
use ../nonce
use ../pad
use ../process
use ../target
use ../tool
use ../machine [rng_device]

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

# The order a launch's poll takes its timed actions in, the screen among them
export def due-order [events: table<kind: string, index: int, at: duration>, screen: oneof<duration, nothing>, elapsed: duration]: nothing -> table<kind: string, index: int, at: duration> {
    let due = ($events | enumerate | each {|e| $e.item | insert order $e.index } | where {|e| $e.at <= $elapsed } | sort-by at order | reject -o order)
    if $screen == null or $screen > $elapsed { return $due }
    ($due | where {|e| $e.at < $screen }) ++ [{ kind: "screen", index: 0, at: $screen }] ++ ($due | where {|e| $e.at >= $screen })
}
