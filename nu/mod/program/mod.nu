use (path self ../audio)
use (path self ../build)
use (path self ../chardev)
use (path self ../demand)
use (path self ../disco)
use (path self ../disk)
use (path self ../launch)
use (path self ../machine)
use (path self ../pad)
use (path self ../tool)
use (path self ../workspace)

# The virtio-mmio transports virt's map holds, a line's hard ceiling
const transport_limit = 8

# The virtio devices every run's line carries
const devices = [
    "-device" "virtio-net-device,netdev=net0" "-netdev" "user,id=net0"
] ++ $machine.rng_device

# A program built with its kernel in the same tree, for its test or its run
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

# The arguments that run a program's test/test.nu on its kernel and image
def test-args [ready: record]: nothing -> list<string> {
    let script = ($ready.context.here | path join "test" "test.nu")
    if not ($script | path exists) { error make {msg: $"($ready.context.manifest.name) has no test/test.nu"} }
    let assets = (disk assets-image $ready.context)
    let set = ($ready.context.symbols | str join ",")
    let common = [$script "--kernel" $ready.kernel "--image" $ready.image "--out" $ready.context.out "--set" $set]
    if $assets == "" { $common } else { $common ++ ["--assets" $assets] }
}

# The QEMU line that runs a program, built first, on the machine asked for
export def run-line [dir: path, names: list<string>, api: bool, window: oneof<string, nothing>, serial: string, kbm: bool, pad: bool, sound: bool, --spec: string = "", --harts: int = 0]: nothing -> record<qemu_binary: string, args: list<string>, window: string, context: record, bridge: oneof<record<name: string, vendor: oneof<int, nothing>, product: oneof<int, nothing>>, nothing>, bridge_pipe: string, relays: list<record<endpoint: string, name: string, inward: string, outward: string, done: string>>, relay_binary: string, machine: record> {
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

# A program run in its window with the UART on stdio; QEMU's exit its status
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

# The programs at or under a path tested, each one's output, then a summary
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

# A program's headless machine prepared and printed as JSON for a harness
export def plan [dir: path, --out: string = "", --disk: string = "", --serial: string = "disk0", --set: string = "", --api, --gamepad, --pad-port, --no-kbm, --sound, --spec (-s): string = "", --harts: int = 0, --bootargs: string = ""] {
    let names = (build symbols $set)
    let c = (build context ($dir | path expand) "program" $names)
    let ready = (prepared ($dir | path expand) $names)
    let out = (if $out == "" { $c.out | path join "machine" } else { $out | path expand })
    launch plan --kernel $ready.kernel --image $ready.image --out $out --api=$api --disk $disk --serial $serial --set $set --gamepad=$gamepad --pad-port=$pad_port --no-kbm=$no_kbm --sound=$sound --spec $spec --harts $harts --bootargs $bootargs | to json
}

# A workspace's tests, or one program's, built with DEBUG, then a summary
export def test [dir: path, ...words: string, --set: string = "", --spec (-s): string = ""] {
    let names = (build symbols $set)
    let s = (workspace subject $dir $words)
    let forced = (if $spec == "" { {} } else { { JAB_SPEC: $spec } })
    with-env $forced {
        if (workspace is-workspace $s.dir) { test-under $s.dir $s.words $names; return }
        build prepare $s.dir "test"
        ^nu ...(test-args (prepared $s.dir (build with-debug $names)))
    }
}

# A program built, then run in its window with the UART on stdio
export def boot [dir: path, ...words: string, --set: string = "", --api, --kbm, --no-kbm, --pad, --no-pad, --no-sound, --spec (-s): string = "", --harts: int = 0] {
    let s = (workspace subject $dir $words)
    let program = (if (workspace is-workspace $s.dir) { workspace run-target $s.dir $s.words } else { $s.dir | path expand })
    if $spec != "" and $harts != 0 { error make {msg: $"--spec ($spec) with --harts ($harts): a named spec provisions its own harts, and --harts names a custom machine; one or the other"} }
    if $harts != 0 { machine of $harts | ignore }
    build prepare $program "run"
    run-program $program (build symbols $set) $api (pad kbm-choice $kbm $no_kbm) (pad pad-choice $pad $no_pad) (not $no_sound) --spec $spec --harts $harts
}
