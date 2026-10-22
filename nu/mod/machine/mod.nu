use (path self ../host)
use (path self ../image)
use (path self ../process)
use (path self ../spec)
use (path self ../target)
use (path self ../spec) [harts_allowed]

# A custom machine's RAM in GiB, the 4 every machine had before named specs
const custom_ram_gib = 4

# The kernel's command line at most, in bytes: harts.S's BOOT_ARGS_BYTES less one
const boot_args_max = 255

# The CPU every machine runs: RVA23's supervisor profile with PMP
const cpu_profile = "rva23s64,pmp=true"

# Multithreaded TCG, a host thread a hart, on every line
export const accel = "tcg,thread=multi"

# The machine: virt with the AIA's APLIC and IMSICs and the ACLINT's timer
const machine_name = "virt,aia=aplic-imsic,aclint=on"

# The line's last words: no parallel port, its hidden text console
const machine_rest = [
    "-global" "virtio-mmio.force-legacy=false"
    "-parallel" "none"
]

# The entropy device jab.sys.random draws from, on a run and a launch alike
export const rng_device = ["-device" "virtio-rng-device"]

# The QEMU a machine runs on: extern/qemu's binary, else the name for PATH
export def qemu-binary [here: path, workspace: oneof<string, nothing>]: nothing -> string {
    let places = (if $workspace == null { [$here] } else { [$here $workspace] })
    let file = (host exe-name $process.qemu_name)
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
    $process.qemu_name
}

# The CPU every machine runs, RVA23, once its QEMU lists the model; else refused
def cpu-model [qemu: string]: nothing -> string {
    let listed = (^$qemu -cpu help | complete | get stdout | lines | any {|l| ($l | str trim) == "rva23s64" })
    if not $listed {
        let version = (^$qemu --version | complete | get stdout | lines | get -o 0 | default "a QEMU")
        let found = (which $qemu | get -o 0.path | default $qemu)
        error make {msg: $"($version) at ($found) has no rva23s64, the RVA23 CPU every Jab machine runs on\nlink extern/qemu, in the workspace or beside the program, to a QEMU 11 install"}
    }
    $cpu_profile
}

# A launch's machine as its record keeps it: a named spec's, or a custom one's
export def of [harts?: int, --spec: any = null, --overrides: list<string> = []]: nothing -> record<harts: int, ram_gib: int, spec: any, diagnostic: any, machine: string, cpu: string, accel: string, overrides: list<string>> {
    if $spec != null and $harts != null { error make {msg: "--spec with --harts: a named spec provisions its own harts, and --harts names a custom machine"} }
    if $spec == null and $harts == null { error make {msg: "a machine is a named spec's, --spec, or a custom one, --harts N"} }
    let common = { machine: $machine_name, cpu: $cpu_profile, accel: $accel, overrides: $overrides }
    if $spec != null {
        let ram = ($spec.ram / 1GiB | into int)
        let named = { name: ($spec.name | str lowercase), cores: $spec.cores, ram_gib: $ram, display: $spec.display }
        { harts: $spec.cores, ram_gib: $ram, spec: $named, diagnostic: null } | merge $common
    } else {
        if $harts not-in $harts_allowed { error make {msg: $"--harts takes ($harts_allowed | first) to ($harts_allowed | last), a custom machine's harts, not ($harts)"} }
        { harts: $harts, ram_gib: $custom_ram_gib, spec: null, diagnostic: { harts: $harts, ram_gib: $custom_ram_gib } } | merge $common
    }
}

# The machine a launch asks for: --harts a custom one, else --spec or the default
export def resolve [ws: oneof<string, nothing>, spec: string, harts: int]: nothing -> record {
    if $spec != "" and $harts != 0 { error make {msg: $"--spec ($spec) with --harts ($harts): a named spec provisions its own harts, and --harts names a custom machine; one or the other"} }
    if $harts != 0 { return (of $harts) }
    if $ws == null { error make {msg: "a named spec needs its workspace's asset/spec.nuon, and this launch has no workspace; name a custom machine with --harts"} }
    let name = (if $spec != "" { $spec } else { spec configured $ws })
    of --spec (spec row $ws $name)
}

# A launch's kernel command line: its bootargs, then a named spec's jab.spec
export def spec-bootargs [m: record, bootargs: string]: nothing -> string {
    if $m.spec != null {
        let named = ($bootargs | split row " " | where {|w| $w starts-with "jab.spec=" })
        if ($named | is-not-empty) {
            error make {msg: $"--bootargs holds ($named | first), and this launch names the spec ($m.spec.name): its jab.spec= is the launcher's alone"}
        }
    }
    let line = (if $m.spec == null { $bootargs } else { [$bootargs $"jab.spec=($m.spec.name)"] | where {|w| $w != "" } | str join " " })
    let length = ($line | into binary | bytes length)
    if $length > $boot_args_max {
        error make {msg: $"the kernel's command line is ($length) bytes, past the ($boot_args_max) the kernel reads: ($line)"}
    }
    $line
}

# The GPU at the machine's display: a named spec's, a custom machine's the ABI's
export def gpu-args [m: record]: nothing -> list<string> {
    let size = (if $m.spec == null { $spec.display_size } else { $m.spec.display })
    ["-device" $"virtio-gpu-device,xres=($size.width),yres=($size.height)"]
}

# A debug kernel's knob from a command line: `<name>=` and digits, else null
export def knob-of [line: string, name: string]: nothing -> oneof<int, nothing> {
    let word = ($line | split row " " | where {|w| $w starts-with $"($name)=" } | get -o 0)
    if $word == null { return null }
    let value = ($word | str substring (($name | str length) + 1)..)
    if ($value =~ '^[0-9]+$') { $value | into int } else { null }
}

# QEMU's machine arguments: virt, the RVA23 CPU, multithreaded TCG, its harts
export def machine-args [qemu: string, m: record, --options: string = ""]: nothing -> list<string> {
    let machine = (if $options == "" { $m.machine } else { $"($m.machine),($options)" })
    ["-machine" $machine "-cpu" (cpu-model $qemu) "-accel" $m.accel "-smp" ($m.harts | into string)] ++ $machine_rest
}

# QEMU's memory argument for a machine's RAM, in GiB
export def memory-args [m: record]: nothing -> list<string> {
    ["-m" $"($m.ram_gib)G"]
}

# QEMU's name arguments: the guest named for the program, its threads named
export def name-args [program: string]: nothing -> list<string> {
    let process = (if $nu.os-info.name == "linux" { ",process=jab" } else { "" })
    ["-name" $"jab ($program)($process),debug-threads=on"]
}

# The device tree QEMU builds for a launch's machine, written out: its path
export def dump-tree [--kernel: path, --image: path, --out: path, --spec: string = "", --harts: int = 0, --bootargs: string = ""]: nothing -> string {
    let file = ($out | path expand)
    let dir = ($file | path dirname)
    let ws = (image workspace $kernel $image $dir)
    let machine = (resolve $ws $spec $harts)
    mkdir $dir
    let root = (target root (if $ws != null { $ws } else { image home $image }))
    target retire $file $root
    let qemu = (qemu-binary (image home $image) $ws)
    let line = (spec-bootargs $machine $bootargs)
    let append = (if $line == "" { [] } else { ["-append" $line] })
    let args = ((machine-args $qemu $machine --options $"dumpdtb=($file)") ++ (memory-args $machine) ++ ["-bios" "none" "-kernel" ($kernel | path expand) "-display" "none"] ++ $append)
    let made = (^$qemu ...$args | complete)
    if $made.exit_code != 0 or not ($file | path exists) { error make {msg: $"QEMU wrote no device tree to ($file): ($made.stderr | str trim)"} }
    $file
}

# A run's window: JAB_DISPLAY, else the manifest's, else the host's best
export def display [manifest: record]: nothing -> string {
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

# JAB_QEMU_ARGS split as a shell would, for the end of a run's line
export def extra-args []: nothing -> list<string> {
    shell-words ($env.JAB_QEMU_ARGS? | default "")
}

# A line's words as a POSIX shell splits them, nothing expanded or run
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

# How many virtio-mmio transports a QEMU line uses
export def transports [args: list<string>]: nothing -> int {
    $args | window 2 | where {|w| $w.0 == "-device" and ($w.1 =~ '^virtio-.*-device') } | length
}
