# demand's integration test: a program's declared demand as the SDK reads
# it, `jab demand-of` and the build's check, the constants the build
# generates, and a launch's record of it. First this program, on the legacy
# path: no demand, its build carrying no generated constants, and its run
# on the specification's three harts undeclared and diagnostic, the plan
# carrying no demand. Then manifests of the test's own, each in a program
# directory under the output naming the workspace: either section beside
# no specs, `specs` empty, not a list, holding no name, naming a spec the
# data does not define, or naming one twice in two cases; a role neither
# section takes, a count at zero, below it, or not a whole number, a section
# that is no table, a feature's name not snake_case, and a feature
# demanding nothing; a base demand one past the smallest listed spec's
# harts, which names that spec alone; and a spec whose data gives no
# harts, from a workspace of the test's own: each refused naming its fault.
# A spec named in another case is held under the data's name, and a base
# demand equal to the smallest spec's harts holds, its feature's demand
# past every spec refusing nothing. Last, the tool, each program built
# afresh: the manifest past its spec refused with that message, and a
# declared program, two specs, one hart reserved for graphics, and a
# feature demanding one I/O hart, built with its constants generated and
# its include, exiting with the status its numbers make, so they reached
# the assembly, its run declared and not diagnostic on three harts and
# diagnostic on four, the plan carrying the demand demand-of gives; then
# its declaration dropped, its next build retiring the constants and
# including none.
use ../../../sdk/nu/jab.nu
use std/assert

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let here = ($env.FILE_PWD | path join ".." | path expand)
    let ws = ($here | path join ".." ".." | path expand)
    let specs = (jab specs-of $ws)

    # this program, on the legacy path
    let own = (read-demand $here)
    assert equal $own null $"no specs is the legacy path: ($own | to nuon)"
    let own_build = (generated ($image | path dirname))
    assert (not $own_build.included) $"the legacy build carries no generated constants' directory: ($own_build.flags)"
    assert ($own_build.constants == null) "the legacy build generates no constants"
    let undeclared = (jab launch --kernel $kernel --image $image --out ($out | path join "legacy") --set $set)
    assert equal $undeclared.status 0 $"the legacy program runs: ($undeclared.status), ($undeclared.serial)"
    assert equal [$undeclared.declared $undeclared.diagnostic] [false true] $"a legacy program's run is undeclared and diagnostic: ($undeclared.declared), ($undeclared.diagnostic)"
    let unplanned = (jab plan --kernel $kernel --image $image --out ($out | path join "legacy_plan"))
    assert equal $unplanned.demand null $"a legacy program's plan carries no demand: ($unplanned.demand | to nuon)"

    # manifests of the test's own, each naming the workspace
    let fixtures = ($out | path join "fixtures")
    jab retire $fixtures
    mkdir $fixtures
    let sdk = ($ws | path join "sdk")
    let head = $"name = 'fixture'\nsdk = '($sdk)'\nworkspace = '($ws)'\nincludes = ['($sdk | path join src)']\nlink = '($sdk | path join src program.ld)'\ndisplay = 'none'\n"
    let manifest = {|name: string, body: string|
        let dir = ($fixtures | path join $name)
        mkdir $dir
        $head + $body | save -f ($dir | path join "program.jab.toml")
        $dir
    }
    let one = ($specs | first | get name)
    let listed = $"specs = ['($one | str lowercase)']\n"
    let smallest = ($specs | sort-by cores | first)
    let larger = ($specs | where {|s| $s.cores > $smallest.cores } | first)
    let largest = ($specs | get cores | math max)
    let refusals = [
        { name: "legacy_reserved", body: "[reserved]\ngfx_harts = 1\n", says: "fixture: [reserved] beside no `specs`" }
        { name: "legacy_feature", body: "[feature.probe]\nio_harts = 1\n", says: "fixture: [feature] beside no `specs`" }
        { name: "empty", body: "specs = []\n", says: "fixture: `specs` names no spec" }
        { name: "not_list", body: $"specs = '($one)'\n", says: "fixture: `specs` is a list of spec names, not string" }
        { name: "not_name", body: $"specs = ['($one)', 3]\n", says: "fixture: `specs` holds 3, no spec's name" }
        { name: "blank", body: $"specs = ['($one)', ' ']\n", says: "fixture: `specs` holds \" \", no spec's name" }
        { name: "undefined", body: $"specs = ['($one)', '9zz9']\n", says: "fixture: `specs` names 9zz9, which its workspace's asset/spec.nuon does not define" }
        { name: "twice", body: $"specs = ['($one | str lowercase)', '($one)']\n", says: $"fixture: `specs` names ($one) twice, without regard to case" }
        { name: "reserved_role", body: $"($listed)[reserved]\nio_harts = 1\n", says: "fixture: [reserved] names io_harts; it names gfx_harts" }
        { name: "reserved_zero", body: $"($listed)[reserved]\ngfx_harts = 0\n", says: "fixture: reserved.gfx_harts is 0, where a whole number of harts, one or more, is wanted" }
        { name: "reserved_below", body: $"($listed)[reserved]\ngfx_harts = -1\n", says: "fixture: reserved.gfx_harts is -1," }
        { name: "reserved_fraction", body: $"($listed)[reserved]\ngfx_harts = 1.5\n", says: "fixture: reserved.gfx_harts is 1.5," }
        { name: "reserved_text", body: $"($listed)[reserved]\ngfx_harts = '1'\n", says: "fixture: reserved.gfx_harts is \"1\"," }
        { name: "reserved_value", body: $"($listed)reserved = 2\n", says: "fixture: [reserved] is a table of roles and their harts, not int" }
        { name: "feature_value", body: $"($listed)feature = 2\n", says: "fixture: `feature` holds a [feature.<name>] table for each feature, not int" }
        { name: "feature_table", body: $"($listed)[feature]\nprobe = 1\n", says: "fixture: [feature.probe] is a table of roles and their harts, not int" }
        { name: "feature_name", body: $"($listed)[feature.Probe]\nio_harts = 1\n", says: "fixture: [feature.Probe]: a feature's name is snake_case" }
        { name: "feature_role", body: $"($listed)[feature.probe]\ngfx_harts = 1\n", says: "fixture: [feature.probe] names gfx_harts; it names io_harts" }
        { name: "feature_none", body: $"($listed)[feature.probe]\n", says: "fixture: [feature.probe] demands no hart" }
        { name: "feature_zero", body: $"($listed)[feature.probe]\nio_harts = 0\n", says: "fixture: feature.probe.io_harts is 0," }
        { name: "base_past", body: $"specs = ['($smallest.name)', '($larger.name)']\n[reserved]\ngfx_harts = ($smallest.cores)\n", says: $"fixture: its base demand, the main hart and the ($smallest.cores) its [reserved] holds, is ($smallest.cores + 1) harts, more than ($smallest.name)'s ($smallest.cores)", unsaid: $larger.name }
    ]
    for c in $refusals {
        let said = (read-demand (do $manifest $c.name $c.body))
        assert ((($said | describe) == "string") and ($said | str starts-with $"refused: ($c.says)")) $"($c.name): refused, saying ($c.says): ($said | to nuon)"
        let unsaid = ($c | get -o unsaid | default "")
        if $unsaid != "" { assert (not ($said | str contains $unsaid)) $"($c.name): ($unsaid) holds the demand and goes unnamed: ($said)" }
    }
    # a workspace of the test's own whose spec data gives no harts
    let coreless = ($fixtures | path join "coreless")
    mkdir ($coreless | path join "asset")
    mkdir ($coreless | path join "program")
    "kernel = 'kernel'\nprograms = ['program']\n" | save -f ($coreless | path join "workspace.jab.toml")
    "[{name: 'CORELESS'}]" | save -f ($coreless | path join "asset" "spec.nuon")
    "table<name: string>" | save -f ($coreless | path join "asset" "spec.nutype")
    "name = 'fixture'\nspecs = ['coreless']\n" | save -f ($coreless | path join "program" "program.jab.toml")
    let unsized = (read-demand ($coreless | path join "program"))
    assert ((($unsized | describe) == "string") and ($unsized | str starts-with "refused: fixture: CORELESS gives no `cores: int`")) $"coreless: refused, naming the spec whose data gives no harts: ($unsized | to nuon)"
    let cased = (read-demand (do $manifest "cased" $listed))
    assert equal $cased { specs: [$one], reserved: { gfx_harts: 0 }, features: [], base: 1 } $"a spec named in another case is held under the data's name, nothing reserved: ($cased | to nuon)"
    let fits = ($smallest.cores - 1)
    let reserving = (if $fits > 0 { $"[reserved]\ngfx_harts = ($fits)\n" } else { "" })
    let fitted = (read-demand (do $manifest "fitted" $"specs = ['($smallest.name)']\n($reserving)[feature.probe]\nio_harts = ($largest)\n"))
    assert equal $fitted { specs: [$smallest.name], reserved: { gfx_harts: $fits }, features: [{ name: "probe", io_harts: $largest }], base: $smallest.cores } $"a base demand equal to the spec's harts holds, and a feature's demand past every spec refuses nothing: ($fitted | to nuon)"

    # the tool, each program built afresh
    let tool = ($sdk | path join "nu" "jab.nu")
    let past = ($fixtures | path join "base_past")
    mkdir ($past | path join "src")
    ".include \"jab.inc\"\n\n.section .text\n.global _start\n_start:\n    jab.sys.exit 0\n" | save -f ($past | path join "src" "main.S")
    let refused = (^nu $tool build $past | complete)
    let past_says = ($refusals | where name == "base_past" | first | get says)
    assert ($refused.exit_code != 0 and ((bare $refused.stderr) | str contains (bare $past_says))) $"the tool's build refuses a base demand past a listed spec: ($refused.exit_code), ($refused.stderr)"
    let declared = (do $manifest "declared" $"specs = ['($one)', '($larger.name)']\n\n[reserved]\ngfx_harts = 1\n\n[feature.probe]\nio_harts = 1\n")
    mkdir ($declared | path join "src")
    ".include \"jab.inc\"\n.include \"jab_manifest.inc\"\n\n.set DEMAND_STATUS, JAB_BASE_HARTS + 8 * JAB_RESERVED_GFX_HARTS + 32 * JAB_FEATURE_PROBE_IO_HARTS\n\n.section .text\n.global _start\n_start:\n    jab.sys.exit DEMAND_STATUS\n" | save -f ($declared | path join "src" "main.S")
    let demand = (read-demand $declared)
    assert equal $demand { specs: [$one $larger.name], reserved: { gfx_harts: 1 }, features: [{ name: "probe", io_harts: 1 }], base: 2 } $"the declared fixture's demand: ($demand | to nuon)"
    let made = (^nu $tool build $declared | complete)
    assert equal $made.exit_code 0 $"the declared fixture builds afresh against its generated constants: ($made.stderr)"
    let declared_out = (jab program-out $declared release)
    let built = (generated $declared_out)
    assert equal $built.constants [".set JAB_BASE_HARTS, 2" ".set JAB_RESERVED_GFX_HARTS, 1" ".set JAB_FEATURE_PROBE_IO_HARTS, 1"] $"the declared fixture's constants, generated afresh: ($built.constants)"
    assert $built.included $"the declared fixture's build includes its generated constants' directory: ($built.flags)"
    let status = ($demand.base + 8 * $demand.reserved.gfx_harts + 32 * ($demand.features | where name == "probe" | first | get io_harts))
    let declared_image = ($declared_out | path join "fixture.jab")
    let three = (jab launch --kernel $kernel --image $declared_image --out ($out | path join "three") --set $set)
    assert equal $three.status $status $"the declared fixture exits with the status its demand's numbers make: ($three.status), ($three.serial)"
    assert equal [$three.declared $three.diagnostic] [true false] $"on the specification's three harts a declared program's run is declared and not diagnostic: ($three.declared), ($three.diagnostic)"
    let four = (jab launch --kernel $kernel --image $declared_image --out ($out | path join "four") --set $set --harts 4)
    assert equal $four.status $status $"on four harts the declared fixture exits as on three: ($four.status), ($four.serial)"
    assert equal [$four.declared $four.diagnostic] [true true] $"on four harts a declared program's run is declared and diagnostic: ($four.declared), ($four.diagnostic)"
    let planned = (jab plan --kernel $kernel --image $declared_image --out ($out | path join "plan"))
    assert equal $planned.demand $demand $"the declared fixture's plan carries its demand: ($planned.demand | to nuon)"
    # the declaration dropped: the constants it left are retired
    do $manifest "declared" "" | ignore
    ".include \"jab.inc\"\n\n.section .text\n.global _start\n_start:\n    jab.sys.exit 0\n" | save -f ($declared | path join "src" "main.S")
    let dropped = (^nu $tool build $declared | complete)
    assert equal $dropped.exit_code 0 $"the fixture builds with its declaration dropped: ($dropped.stderr)"
    let undone = (generated $declared_out)
    assert (($undone.constants == null) and (not $undone.included)) $"a build with the declaration dropped retires its constants and includes none: ($undone.constants | to nuon), ($undone.flags)"

    print $"demand: a legacy program read, built, and run undeclared and diagnostic; ($refusals | length) manifests and a spec with no harts refused, each naming its fault; a spec in another case and a feature past every spec held; built afresh, a base demand past its spec refused, and a declared program's constants generated, reaching its assembly, its runs declared, diagnostic on four harts alone, and retired once its declaration was dropped"
    print "demand: ok"
}

# A program's declared demand (jab demand-of), or its refusal as text,
# `refused: ` and the message.
def read-demand [dir: path] {
    try { jab demand-of $dir } catch {|e| $"refused: ($e.msg)" }
}

# What a build left in its output directory `out` of a declared demand:
# the lines of the generated jab_manifest.inc, null with none there, and
# whether the flags it was built with carry that directory among the
# includes, with the flags.
def generated [out: path]: nothing -> record<constants: oneof<list<string>, nothing>, included: bool, flags: string> {
    let inc = ($out | path join "jab_manifest.inc")
    let flags = (open --raw ($out | path join "flags") | decode | lines | first)
    { constants: (if ($inc | path exists) { open --raw $inc | decode | lines } else { null }), included: ($flags | str contains $"-I ($out)"), flags: $flags }
}

# A text's letters and digits alone, so a message reads the same however
# an error report wraps it.
def bare [text: string]: nothing -> string {
    $text | str replace --all --regex '[^A-Za-z0-9]' ''
}
