# spec's integration test: the launcher's named specs. Each spec the
# launcher provisions today, 1KA1 and 1KB1, planned from asset/spec.nuon:
# -smp its cores, -m its RAM, the GPU at its display, and `jab.spec=<name>`
# on the kernel's line, its record the spec's and no custom machine's;
# QEMU's tree for it dumped and read back, its cpus as many as the spec's
# cores and its one bank from RAM's base its RAM; and a launch on it,
# declared and not diagnostic. Every other spec refused before QEMU
# starts, naming why: cores past the eight harts a machine takes, or a
# display other than the ABI's. --spec with --harts refused by plan,
# launch, and dump-tree, naming both, with no QEMU run; a custom machine of
# three harts recorded diagnostic, its 4 GiB and no `jab.spec`; a name the
# spec data does not define refused; a program listing 1KA1 alone refused
# on 1KB1, naming both. Last the default, in a scratch XDG config home:
# `jab/config.toml` seeded from asset/default/config.toml byte for byte,
# one there never written over, JAB_SPEC ahead of it, one naming no spec
# refused, a home that is not there refused and never made, and a launch
# naming neither flag on the configured spec.
use ../../../sdk/nu/jab.nu
use std/assert

const GIB = 1073741824

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let ws = ($env.FILE_PWD | path join ".." ".." ".." | path expand)
    let specs = (jab specs-of $ws)

    # each spec provisioned: the line and the tree from the table
    let provisioned = ($specs | where {|s| $s.cores <= 8 and $s.display == { width: 1920, height: 1080 } })
    assert equal ($provisioned | get name | each {|n| $n | str lowercase }) ["1ka1" "1kb1"] $"the specs the launcher provisions: ($provisioned | get name)"
    for s in $provisioned {
        let name = ($s.name | str lowercase)
        let ram = ($s.ram / 1GiB | into int)
        let p = (jab plan --kernel $kernel --image $image --out ($out | path join $"plan_($name)") --spec $name)
        assert (paired $p.qemu "-smp" ($s.cores | into string)) $"($name): -smp ($s.cores): ($p.qemu)"
        assert (paired $p.qemu "-m" $"($ram)G") $"($name): -m ($ram)G: ($p.qemu)"
        assert (paired $p.qemu "-device" $"virtio-gpu-device,xres=($s.display.width),yres=($s.display.height)") $"($name): the GPU at its display: ($p.qemu)"
        assert ((after $p.qemu "-append") | split row " " | any {|w| $w == $"jab.spec=($name)" }) $"($name): jab.spec=($name) on the kernel's line: ($p.qemu)"
        assert equal [$p.machine.spec $p.machine.diagnostic] [{ name: $name, cores: $s.cores, ram_gib: $ram, display: $s.display } null] $"($name): the machine's record the spec's: ($p.machine)"
        let tree = (open --raw (jab dump-tree --kernel $kernel --image $image --out ($out | path join $"($name).dtb") --spec $name) | into binary)
        assert equal (cpus-of $tree) $s.cores $"($name): its tree's cpus"
        assert equal (banks-of $tree) [{ base: 0x80000000, size: ($ram * $GIB) }] $"($name): its tree's one bank, its RAM from RAM's base"
        let run = (jab launch --kernel $kernel --image $image --out ($out | path join $"run_($name)") --set $set --spec $name --seconds 20)
        assert equal [$run.status ($run.serial | lines)] [0 ["spec: up"]] $"($name): the program runs on it: ($run.serial)"
        assert equal [$run.declared $run.diagnostic] [true false] $"($name): a declared run, not diagnostic: ($run.declared), ($run.diagnostic)"
    }

    # every other spec refused before QEMU starts, naming why
    for s in ($specs | where {|s| $s.name not-in ($provisioned | get name) }) {
        let said = (refusal { jab plan --kernel $kernel --image $image --out ($out | path join $"plan_($s.name)") --spec $s.name })
        let why = (if $s.cores > 8 { $"($s.name) has ($s.cores) cores, past the 8 harts a machine takes" } else { $"($s.name)'s display is ($s.display.width) by ($s.display.height), and the ABI's 1920 by 1080" })
        assert ($said | str contains $why) $"($s.name) refused, saying ($why): ($said)"
    }

    # --spec with --harts, refused naming both, no QEMU run
    let both = $"--spec 1ka1 with --harts 3"
    let both_out = ($out | path join "both")
    jab retire $both_out
    for c in [
        { name: "plan", call: { jab plan --kernel $kernel --image $image --out $both_out --spec 1ka1 --harts 3 } }
        { name: "launch", call: { jab launch --kernel $kernel --image $image --out $both_out --set $set --spec 1ka1 --harts 3 } }
        { name: "dump-tree", call: { jab dump-tree --kernel $kernel --image $image --out ($both_out | path join "both.dtb") --spec 1ka1 --harts 3 } }
    ] {
        let said = (refusal $c.call)
        assert ($said | str contains $both) $"($c.name): --spec with --harts refused naming both: ($said)"
    }
    assert (($both_out | path join "serial.log" | path type) == null) $"no QEMU run for --spec with --harts: ($both_out)"

    # a custom machine of three harts: diagnostic, 4 GiB, no jab.spec
    let custom = (jab plan --kernel $kernel --image $image --out ($out | path join "custom") --harts 3)
    assert equal [$custom.machine.spec $custom.machine.diagnostic] [null { harts: 3, ram_gib: 4 }] $"a custom machine of three harts, diagnostic: ($custom.machine)"
    assert (paired $custom.qemu "-m" "4G") $"a custom machine's 4 GiB: ($custom.qemu)"
    assert (not ($custom.qemu | any {|w| $w =~ 'jab\.spec=' })) $"no jab.spec on a custom machine's line: ($custom.qemu)"
    let custom_run = (jab launch --kernel $kernel --image $image --out ($out | path join "custom_run") --set $set --harts 3 --seconds 20)
    assert equal [$custom_run.status $custom_run.declared $custom_run.diagnostic] [0 true true] $"a custom machine's run declared and diagnostic: ($custom_run.serial)"

    # a name the data does not define
    let unknown = (refusal { jab plan --kernel $kernel --image $image --out ($out | path join "unknown") --spec 9zz9 })
    assert ($unknown | str contains "no spec 9zz9 in the spec data, which defines 1KA1") $"an unknown spec refused: ($unknown)"

    # a program listing 1KA1 alone, refused on 1KB1, naming both
    let listed = (fixture $ws ($out | path join "fixtures" "listed") "listed" "specs = ['1ka1']\n")
    let unlisted = (refusal { jab plan --kernel $kernel --image $listed --out ($out | path join "unlisted") --spec 1kb1 })
    assert ($unlisted | str contains "listed does not list 1kb1, the spec this launch names; it lists 1KA1") $"a spec its program does not list refused: ($unlisted)"
    let on_listed = (jab plan --kernel $kernel --image $listed --out ($out | path join "listed_plan") --spec 1ka1)
    assert equal $on_listed.machine.spec.name "1ka1" $"the spec it lists planned: ($on_listed.machine)"

    # the default, in a scratch XDG config home
    let xdg = ($out | path join "xdg")
    jab retire $xdg
    mkdir $xdg
    let seed = ($ws | path join "asset" "default" "config.toml")
    let config = ($xdg | path join "jab" "config.toml")
    let in_xdg = {|task: closure| with-env { XDG_CONFIG_HOME: $xdg, JAB_SPEC: "" } { do $task } }
    let seeded = (do $in_xdg { jab spec-default $ws })
    assert equal $seeded (open $seed | get spec) $"the default seeded from the asset: ($seeded)"
    assert equal (open --raw $config | into binary) (open --raw $seed | into binary) "the config seeded byte for byte"
    "spec = '1kb1'\n" | save --raw -f $config
    assert equal (do $in_xdg { jab spec-default $ws }) "1kb1" "a config there read as it is"
    assert equal (open --raw $config | into binary | decode) "spec = '1kb1'\n" "a config there never written over"
    let unflagged = (do $in_xdg { jab plan --kernel $kernel --image $image --out ($out | path join "unflagged") })
    assert equal $unflagged.machine.spec.name "1kb1" $"a launch naming neither flag on the configured spec: ($unflagged.machine)"
    assert equal (with-env { XDG_CONFIG_HOME: $xdg, JAB_SPEC: "1ka1" } { jab spec-default $ws }) "1ka1" "JAB_SPEC ahead of the config"
    "other = 1\n" | save --raw -f $config
    let unnamed = (refusal { do $in_xdg { jab spec-default $ws } })
    assert ($unnamed | str contains "names no `spec`") $"a config naming no spec refused: ($unnamed)"
    let gone = ($out | path join "xdg_gone")
    jab retire $gone
    let absent = (refusal { with-env { XDG_CONFIG_HOME: $gone, JAB_SPEC: "" } { jab spec-default $ws } })
    assert ($absent | str contains $"the XDG config home ($gone) is not there") $"a home that is not there refused: ($absent)"
    assert (($gone | path type) == null) $"the XDG config home never made: ($gone)"
    print $"spec: ($provisioned | length) specs provisioned, each line and tree from the table; ($specs | length) defined"
    print "spec: ok"
}

# The message a call raises, "" when it raises none.
def refusal [call: closure]: nothing -> string {
    try { do $call | ignore; "" } catch {|e| $e.msg }
}

# Whether a QEMU line carries the word `key` with `value` after it.
def paired [words: list<string>, key: string, value: string]: nothing -> bool {
    $words | window 2 | any {|w| $w.0 == $key and $w.1 == $value }
}

# The word after `key` on a QEMU line, "" where it is not there.
def after [words: list<string>, key: string]: nothing -> string {
    $words | window 2 | where {|w| $w.0 == $key } | get -o 0.1 | default ""
}

# A fixture program of the test's own, built through the tool: its
# manifest naming the workspace and `body` after it, a program that exits
# 0. Its image.
def fixture [ws: path, dir: path, name: string, body: string]: nothing -> string {
    jab retire $dir
    mkdir ($dir | path join "src")
    let sdk = ($ws | path join "sdk")
    $"name = '($name)'\nsdk = '($sdk)'\nworkspace = '($ws)'\nincludes = ['($sdk | path join src)']\nlink = '($sdk | path join src program.ld)'\ndisplay = 'none'\n($body)" | save -f ($dir | path join "program.jab.toml")
    ".include \"jab.inc\"\n\n.section .text\n.global _start\n_start:\n    jab.sys.exit 0\n" | save -f ($dir | path join "src" "main.S")
    let made = (^nu ($ws | path join "sdk" "nu" "jab.nu") build $dir | complete)
    if $made.exit_code != 0 { error make { msg: $"the fixture ($name) did not build: ($made.stderr)" } }
    jab program-out $dir release | path join $"($name).jab"
}

# A tree's header fields.
def header [b: binary]: nothing -> record<off_struct: int, off_strings: int, size_strings: int, size_struct: int> {
    let w = {|o| $b | bytes at $o..<($o + 4) | into int --endian big }
    { off_struct: (do $w 8), off_strings: (do $w 12), size_strings: (do $w 32), size_struct: (do $w 36) }
}

# Every node of a tree with its path, and each property of it, by name
# with its value, read on the host.
def nodes-of [b: binary]: nothing -> list<record<path: string, props: record>> {
    let h = (header $b)
    let strings = ($b | bytes at $h.off_strings..<($h.off_strings + $h.size_strings))
    let end = ($h.off_struct + $h.size_struct)
    mut at = $h.off_struct
    mut names = []
    mut open = []
    mut done = []
    while $at < $end {
        let kind = ($b | bytes at $at..<($at + 4) | into int --endian big)
        $at = $at + 4
        if $kind == 1 {
            let n = ($b | bytes at $at..<$end | bytes index-of 0x[00])
            $names = ($names | append ($b | bytes at $at..<($at + $n) | decode))
            $open = ($open | append {})
            $at = $at + ((($n + 4) // 4) * 4)
        } else if $kind == 2 {
            $done = ($done | append { path: ("/" + ($names | skip 1 | str join "/")), props: ($open | last) })
            $names = ($names | drop 1)
            $open = ($open | drop 1)
        } else if $kind == 3 {
            let len = ($b | bytes at $at..<($at + 4) | into int --endian big)
            let off = ($b | bytes at ($at + 4)..<($at + 8) | into int --endian big)
            let tail = ($strings | bytes at $off..)
            let pname = ($tail | bytes at 0..<($tail | bytes index-of 0x[00]) | decode)
            let value = ($b | bytes at ($at + 8)..<($at + 8 + $len))
            $open = ($open | drop 1 | append (($open | last) | insert $pname $value))
            $at = $at + 8 + ((($len + 3) // 4) * 4)
        } else if $kind == 9 {
            break
        }
    }
    $done
}

# The cpus a tree holds under /cpus.
def cpus-of [b: binary]: nothing -> int {
    nodes-of $b | where {|n| $n.path =~ '^/cpus/cpu@[0-9a-f]+$' } | length
}

# The banks of a tree's memory nodes, two cells a base and two a size, as
# QEMU's virt writes them.
def banks-of [b: binary]: nothing -> list<record<base: int, size: int>> {
    let memory = (nodes-of $b | where {|n| ($n.props | get -o device_type) == ("memory" | into binary | bytes add 0x[00] --end) })
    $memory | each {|n|
        let reg = ($n.props | get reg)
        0..<(($reg | bytes length) // 16) | each {|i|
            let at = ($i * 16)
            { base: ($reg | bytes at $at..<($at + 8) | into int --endian big --signed), size: ($reg | bytes at ($at + 8)..<($at + 16) | into int --endian big --signed) }
        }
    } | flatten
}
