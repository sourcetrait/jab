# demand's integration test: a program's declared demand as the SDK reads
# it, `jab demand-of` and the build's check, the constants the build
# generates, the demand recorded with its image, and a launch's record of
# it. First this program, on the legacy path: no demand, its build carrying
# no generated constants and recording a null demand beside its image,
# which reads as none, and its run on the specification's three harts
# undeclared and diagnostic, the plan carrying no demand. Then manifests of
# the test's own, each in a program directory under the output naming the
# workspace: either section beside no specs, `specs` empty, not a list,
# holding no name, naming a spec the data does not define, or naming one
# twice in two cases; a role neither section takes, a count at zero, below
# it, or not a whole number, a section that is no table, a feature's name
# not snake_case, and a feature demanding nothing; a base demand one past
# the smallest listed spec's harts, which names that spec alone; and a spec
# whose data gives no harts, from a workspace of the test's own: each
# refused naming its fault. A spec named in another case is held under the
# data's name, and a base demand equal to the smallest spec's harts holds,
# its feature's demand past every spec refusing nothing. Last, the tool,
# each program built afresh: the manifest past its spec refused with that
# message, and a declared program, two specs, one hart reserved for
# graphics, and a feature demanding one I/O hart, built with its constants
# generated and its include, exiting with the status its numbers make, so
# they reached the assembly, its demand recorded beside its image, its run
# declared and not diagnostic on three harts and diagnostic on four, the
# plan carrying the demand demand-of gives, and still the built demand
# with its reservation edited and then its `specs` removed, each without a
# rebuild. Its record is held to its rules (image-demand): unreadable as
# NUON or no record, a field missing or a third, `image` of another type,
# in capitals, or another image's, `demand` of another type, and every rule
# of the demand's shape broken in turn, each refused naming its fault, as
# is a record beside no image; a record altered alone and kept to the
# shape passes a launch. A build beside a record that holds takes its
# cached image; beside its generated include holding other text under a
# time older than the image, as a changed generator leaves it, it writes
# the include again and builds again; beside a record of another demand,
# one unreadable, an altered image, which a launch refuses, or none, it
# builds again whole, writing the record afresh, and a launch with the
# record retired runs undeclared and diagnostic. A legacy program built
# records a null demand, builds again with its record retired, and given
# `specs` without a rebuild plans none. Then the image's declaration keyed
# to its spec data: a listed spec's cores changed in a workspace of the
# test's own build its program again with the new number in its first
# page, the change undone builds it back, and nothing changed builds
# nothing. Then the declared program's declaration dropped, its next build
# retiring the constants, including none, and recording a null demand.
use ../../../nu/mod/target
use ../../../nu/mod/walk
use ../../../nu/mod/spec
use ../../../nu/mod/demand
use ../../../nu/mod/build
use ../../../nu/mod/launch
use std/assert

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let here = ($env.FILE_PWD | path join ".." | path expand)
    let ws = ($here | path join ".." ".." | path expand)
    let specs = (spec data $ws)

    # this program, on the legacy path
    let own = (read-demand $here)
    assert equal $own null $"no specs is the legacy path: ($own | to nuon)"
    let own_build = (generated ($image | path dirname))
    assert (not $own_build.included) $"the legacy build carries no generated constants' directory: ($own_build.flags)"
    assert ($own_build.constants == null) "the legacy build generates no constants"
    let own_record = (recorded $image)
    assert equal $own_record { image: (sha $image), demand: null } $"the legacy build records a null demand beside its image: ($own_record | to nuon)"
    let own_read = (read-recorded $image)
    assert equal $own_read null $"a legacy image's record reads as no demand: ($own_read | to nuon)"
    let undeclared = (launch --kernel $kernel --image $image --out ($out | path join "legacy") --set $set)
    assert equal $undeclared.status 0 $"the legacy program runs: ($undeclared.status), ($undeclared.serial)"
    assert equal [$undeclared.declared $undeclared.diagnostic] [false true] $"a legacy program's run is undeclared and diagnostic: ($undeclared.declared), ($undeclared.diagnostic)"
    let unplanned = (launch plan --kernel $kernel --image $image --out ($out | path join "legacy_plan"))
    assert equal $unplanned.demand null $"a legacy program's plan carries no demand: ($unplanned.demand | to nuon)"

    # manifests of the test's own, each naming the workspace
    let fixtures = ($out | path join "fixtures")
    target retire $fixtures
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
    let tool = ($sdk | path join ".." "nu" "bin" "do.nu" | path expand)
    let past = ($fixtures | path join "base_past")
    mkdir ($past | path join "src")
    let exit_zero = ".include \"jab.inc\"\n\n.section .text\n.global _start\n_start:\n    jab.sys.exit 0\n"
    $exit_zero | save -f ($past | path join "src" "main.S")
    let refused = (^nu $tool build $past | complete)
    let past_says = ($refusals | where name == "base_past" | first | get says)
    assert ($refused.exit_code != 0 and ((bare $refused.stderr) | str contains (bare $past_says))) $"the tool's build refuses a base demand past a listed spec: ($refused.exit_code), ($refused.stderr)"
    let declared_body = $"specs = ['($one)', '($larger.name)']\n\n[reserved]\ngfx_harts = 1\n\n[feature.probe]\nio_harts = 1\n"
    let declared = (do $manifest "declared" $declared_body)
    mkdir ($declared | path join "src")
    ".include \"jab.inc\"\n.include \"jab_manifest.inc\"\n\n.set DEMAND_STATUS, JAB_BASE_HARTS + 8 * JAB_RESERVED_GFX_HARTS + 32 * JAB_FEATURE_PROBE_IO_HARTS\n\n.section .text\n.global _start\n_start:\n    jab.sys.exit DEMAND_STATUS\n" | save -f ($declared | path join "src" "main.S")
    let demand = (read-demand $declared)
    assert equal $demand { specs: [$one $larger.name], reserved: { gfx_harts: 1 }, features: [{ name: "probe", io_harts: 1 }], base: 2 } $"the declared fixture's demand: ($demand | to nuon)"
    let made = (^nu $tool build $declared | complete)
    assert equal $made.exit_code 0 $"the declared fixture builds afresh against its generated constants: ($made.stderr)"
    let declared_out = (build program-out $declared release)
    let built = (generated $declared_out)
    assert equal $built.constants [".set JAB_BASE_HARTS, 2" ".set JAB_RESERVED_GFX_HARTS, 1" ".set JAB_FEATURE_PROBE_IO_HARTS, 1"] $"the declared fixture's constants, generated afresh: ($built.constants)"
    assert $built.included $"the declared fixture's build includes its generated constants' directory: ($built.flags)"
    let status = ($demand.base + 8 * $demand.reserved.gfx_harts + 32 * ($demand.features | where name == "probe" | first | get io_harts))
    let declared_image = ($declared_out | path join "fixture.jab")
    let declared_record = (recorded $declared_image)
    assert equal $declared_record { image: (sha $declared_image), demand: $demand } $"the build records its demand beside its image: ($declared_record | to nuon)"
    let three = (launch --kernel $kernel --image $declared_image --out ($out | path join "three") --set $set)
    assert equal $three.status $status $"the declared fixture exits with the status its demand's numbers make: ($three.status), ($three.serial)"
    assert equal [$three.declared $three.diagnostic] [true false] $"on the specification's three harts a declared program's run is declared and not diagnostic: ($three.declared), ($three.diagnostic)"
    let four = (launch --kernel $kernel --image $declared_image --out ($out | path join "four") --set $set --harts 4)
    assert equal $four.status $status $"on four harts the declared fixture exits as on three: ($four.status), ($four.serial)"
    assert equal [$four.declared $four.diagnostic] [true true] $"on four harts a declared program's run is declared and diagnostic: ($four.declared), ($four.diagnostic)"
    let planned = (launch plan --kernel $kernel --image $declared_image --out ($out | path join "plan"))
    assert equal $planned.demand $demand $"the declared fixture's plan carries its demand: ($planned.demand | to nuon)"

    # the manifest edited without a rebuild: a launch reads the demand
    # recorded with the image, never the manifest
    do $manifest "declared" $"specs = ['($one)', '($larger.name)']\n\n[reserved]\ngfx_harts = 2\n\n[feature.probe]\nio_harts = 1\n" | ignore
    let reread = (read-demand $declared)
    assert ($reread != $demand) $"the edited reservation changes what the manifest declares: ($reread | to nuon)"
    let edited = (launch plan --kernel $kernel --image $declared_image --out ($out | path join "edited"))
    assert equal $edited.demand $demand $"a reservation edited without a rebuild leaves the plan the built demand: ($edited.demand | to nuon)"
    do $manifest "declared" "" | ignore
    let unlisted = (launch plan --kernel $kernel --image $declared_image --out ($out | path join "unlisted"))
    assert equal $unlisted.demand $demand $"`specs` removed without a rebuild leaves the plan the built demand: ($unlisted.demand | to nuon)"

    # the declaration restored and built again; a build beside a record
    # that holds takes its cached image
    do $manifest "declared" $declared_body | ignore
    let restored = (^nu $tool build $declared | complete)
    assert equal $restored.exit_code 0 $"the declared fixture builds again with its declaration restored: ($restored.stderr)"
    let hash = (sha $declared_image)
    let whole = { image: $hash, demand: $demand }
    let restored_record = (recorded $declared_image)
    assert equal $restored_record $whole $"the restored build records its demand: ($restored_record | to nuon)"
    let held_at = (written $declared_image)
    let held = (^nu $tool build $declared | complete)
    assert equal $held.exit_code 0 $"the declared fixture builds over its cached image: ($held.stderr)"
    assert equal (written $declared_image) $held_at "a build beside a record that holds takes its cached image"

    # the generated include among the build's inputs, read against what
    # the generator writes now: other text under a time older than the
    # image, as a changed generator leaves it, is written again and the
    # image built again
    let include_file = ($declared_out | path join "jab_manifest.inc")
    let generated_text = (open --raw $include_file | into binary | decode)
    ".set JAB_BASE_HARTS, 9\n" | save -f $include_file
    touch -m -r ($declared | path join "src" "main.S") $include_file
    assert ((written $include_file) < (written $declared_image)) "the include's other text stands under a time older than its image"
    rebuilt $tool $declared $declared_image $whole "a build beside an include its generator no longer writes"
    let regenerated = (open --raw $include_file | into binary | decode)
    assert equal $regenerated $generated_text "the include its generator no longer wrote holds the generator's text after the build"

    # the record held to its rules (image-demand), each fault refused
    # naming it
    let record_file = (record-of $declared_image)
    let zeros = ("0" | fill --character "0" --width 64)
    let faults = [
        { name: "unreadable", text: "{image: ", says: "demand.nuon: not NUON the tools can read" }
        { name: "not_record", text: "[1 2]", says: "a record of `image` and `demand` expected, list<int> found" }
        { name: "no_image", record: { demand: $demand }, says: "image: missing" }
        { name: "no_demand", record: { image: $hash }, says: "demand: missing" }
        { name: "third", record: ($whole | insert built true), says: "built: a field the record does not hold" }
        { name: "image_int", record: ($whole | update image 7), says: "image: string expected, int found" }
        { name: "image_capitals", record: ($whole | update image ($hash | str uppercase)), says: $"image: ($hash | str uppercase | to nuon), no SHA-256" }
        { name: "other_image", record: ($whole | update image $zeros), says: $"image: ($zeros), where the image's SHA-256 is ($hash)" }
        { name: "demand_text", record: ($whole | update demand "declared"), says: "demand: a record or null expected, string found" }
        { name: "demand_field", record: ($whole | update demand ($demand | insert harts 3)), says: "demand.harts: a field the demand does not hold" }
        { name: "demand_missing", record: ($whole | update demand ($demand | reject features)), says: "demand.features: missing" }
        { name: "specs_text", record: ($whole | update demand ($demand | update specs $one)), says: "demand.specs: a list of names expected, string found" }
        { name: "specs_none", record: ($whole | update demand ($demand | update specs [])), says: "demand.specs: empty" }
        { name: "specs_unnamed", record: ($whole | update demand ($demand | update specs [$one 3])), says: "demand.specs.1: 3, no spec's name" }
        { name: "reserved_kind", record: ($whole | update demand ($demand | update reserved 1)), says: "demand.reserved: a record expected, int found" }
        { name: "reserved_missing", record: ($whole | update demand ($demand | update reserved {})), says: "demand.reserved.gfx_harts: missing" }
        { name: "reserved_foreign", record: ($whole | update demand ($demand | update reserved { gfx_harts: 1, io_harts: 1 })), says: "demand.reserved.io_harts: a role no program reserves" }
        { name: "reserved_negative", record: ($whole | update demand ($demand | update reserved { gfx_harts: -1 } | update base 0)), says: "demand.reserved.gfx_harts: -1, where a whole number of harts, 0 or more, is wanted" }
        { name: "features_value", record: ($whole | update demand ($demand | update features 1)), says: "demand.features: a list expected, int found" }
        { name: "feature_kind", record: ($whole | update demand ($demand | update features [1])), says: "demand.features.0: a record expected, int found" }
        { name: "feature_unnamed", record: ($whole | update demand ($demand | update features [{ io_harts: 1 }])), says: "demand.features.0.name: missing" }
        { name: "feature_capitals", record: ($whole | update demand ($demand | update features [{ name: "Probe", io_harts: 1 }])), says: $"demand.features.0.name: ("Probe" | to nuon), no snake_case name" }
        { name: "feature_foreign", record: ($whole | update demand ($demand | update features [{ name: "probe", io_harts: 1, gfx_harts: 1 }])), says: "demand.features.0.gfx_harts: a role no feature demands" }
        { name: "feature_idle", record: ($whole | update demand ($demand | update features [{ name: "probe" }])), says: "demand.features.0: demands no hart" }
        { name: "feature_count", record: ($whole | update demand ($demand | update features [{ name: "probe", io_harts: 0 }])), says: "demand.features.0.io_harts: 0, where a whole number of harts, 1 or more, is wanted" }
        { name: "base_text", record: ($whole | update demand ($demand | update base "2")), says: "demand.base: int expected, string found" }
        { name: "base_off", record: ($whole | update demand ($demand | update base 3)), says: "demand.base: 3, where 1 plus the reserved harts is 2" }
    ]
    for f in $faults {
        let text = (if ($f | get -o text) != null { $f.text } else { $f.record | to nuon })
        $text | save -f $record_file
        let said = (read-recorded $declared_image)
        assert ((($said | describe) == "string") and ($said | str starts-with "refused: ") and ($said | str contains $f.says)) $"($f.name): refused, saying ($f.says): ($said | to nuon)"
    }
    let lone = (read-recorded ($declared_out | path join "absent.jab"))
    assert ((($lone | describe) == "string") and ($lone | str contains "is the record of an image, and there is none at")) $"a record beside no image is refused: ($lone | to nuon)"

    # a record altered alone and kept to the shape passes a launch; a build
    # beside it, or beside a record unreadable, builds again whole
    let other = { specs: [$one], reserved: { gfx_harts: 0 }, features: [], base: 1 }
    { image: $hash, demand: $other } | to nuon | save -f $record_file
    let shaped = (launch plan --kernel $kernel --image $declared_image --out ($out | path join "shaped"))
    assert equal $shaped.demand $other $"a record altered alone and kept to the shape passes a launch: ($shaped.demand | to nuon)"
    rebuilt $tool $declared $declared_image $whole "a build beside a record of another demand"
    "{image: " | save -f $record_file
    rebuilt $tool $declared $declared_image $whole "a build beside an unreadable record"

    # an image altered after its build: refused at a launch, built again
    let built_bytes = (open --raw $declared_image | into binary)
    $built_bytes | bytes add --end 0x[00] | save -f $declared_image
    let altered = (sha $declared_image)
    let tampered = (try { launch plan --kernel $kernel --image $declared_image --out ($out | path join "tampered") | ignore; "planned" } catch {|e| $e.msg })
    assert ($tampered | str contains $"image: ($hash), where the image's SHA-256 is ($altered)") $"a launch of an image altered after its build is refused: ($tampered)"
    rebuilt $tool $declared $declared_image $whole "a build beside an altered image"
    assert equal (sha $declared_image) $hash "the altered image built again is the build's own"

    # the record retired: a launch undeclared and diagnostic, and the next
    # build writing it again
    target retire $record_file
    let unrecorded = (launch --kernel $kernel --image $declared_image --out ($out | path join "unrecorded") --set $set)
    assert equal $unrecorded.status $status $"with its record retired the declared image runs as built: ($unrecorded.status), ($unrecorded.serial)"
    assert equal [$unrecorded.declared $unrecorded.diagnostic] [false true] $"with its record retired, a run of the declared image is undeclared and diagnostic: ($unrecorded.declared), ($unrecorded.diagnostic)"
    rebuilt $tool $declared $declared_image $whole "a build with its record retired"

    # a legacy program: its record a null demand, written again once
    # retired, and given `specs` without a rebuild, its plan still none
    let legacy = (do $manifest "legacy" "")
    mkdir ($legacy | path join "src")
    $exit_zero | save -f ($legacy | path join "src" "main.S")
    let legacy_made = (^nu $tool build $legacy | complete)
    assert equal $legacy_made.exit_code 0 $"the legacy fixture builds: ($legacy_made.stderr)"
    let legacy_image = (build program-out $legacy release | path join "fixture.jab")
    let legacy_whole = { image: (sha $legacy_image), demand: null }
    let legacy_record = (recorded $legacy_image)
    assert equal $legacy_record $legacy_whole $"a legacy build records a null demand: ($legacy_record | to nuon)"
    target retire (record-of $legacy_image)
    rebuilt $tool $legacy $legacy_image $legacy_whole "a legacy build with its record retired"
    do $manifest "legacy" $listed | ignore
    let relisted = (read-demand $legacy)
    assert ($relisted != null) $"the legacy fixture's manifest now lists its specs: ($relisted | to nuon)"
    let listed_plan = (launch plan --kernel $kernel --image $legacy_image --out ($out | path join "legacy_listed"))
    assert equal $listed_plan.demand null $"a legacy image given `specs` without a rebuild plans none: ($listed_plan.demand | to nuon)"

    # paths-of names what glob names, the build's walks taking it since
    # nu's glob breaks on a Windows drive letter (WindowsHost): a tree of
    # the test's own with a hidden file and a nested directory, each
    # pattern the tool walks read against glob's own, with and without
    # --no-dir, a relative one from inside the tree, and a pattern matching
    # nothing empty; glob the oracle where it works, every host but Windows
    let tree = ($out | path join "paths_of")
    target retire $tree
    mkdir ($tree | path join "a" "b")
    for f in [["a" "x.S"] ["a" ".hidden"] ["a" "b" "y.S"] ["top.nuon"]] { "x" | save -f ($tree | path join ...$f) }
    if $nu.os-info.name != "windows" {
        for p in [($tree | path join "**" "*") ($tree | path join "**" "*.S") ($tree | path join "*.nuon")] {
            assert equal (walk paths $p | sort) (glob $p | sort) $"paths-of names what glob names for ($p)"
            assert equal (walk paths $p --no-dir | sort) (glob $p --no-dir | sort) $"paths-of names what glob names for ($p) with --no-dir"
        }
        let relative = (do { cd $tree; [(walk paths ("a" | path join "*.S") | sort) (glob ("a" | path join "*.S") | sort)] })
        assert equal $relative.0 $relative.1 "a relative pattern joined to the working directory as glob joins it"
    }
    assert equal (walk paths ($tree | path join "*.none")) [] "a pattern matching nothing names nothing"

    # the declaration's build key (ProgramMinimums): a program declaring a
    # spec of a workspace of the test's own, its spec data a copy of this
    # one's; the spec's cores changed there build it again with the new
    # number in its image's declaration (check-image), the change undone
    # builds it back, and a build with nothing changed builds nothing
    let keyed = ($fixtures | path join "keyed")
    mkdir ($keyed | path join "asset")
    "kernel = 'kernel'\nprograms = ['program']\n" | save -f ($keyed | path join "workspace.jab.toml")
    let data = ($keyed | path join "asset" "spec.nuon")
    cp ($ws | path join "asset" "spec.nuon") $data
    cp ($ws | path join "asset" "spec.nutype") ($keyed | path join "asset" "spec.nutype")
    let program = ($keyed | path join "program")
    mkdir ($program | path join "src")
    $head + $listed | save -f ($program | path join "program.jab.toml")
    $exit_zero | save -f ($program | path join "src" "main.S")
    let keyed_made = (^nu $tool build $program | complete)
    assert equal $keyed_made.exit_code 0 $"the keyed program builds: ($keyed_made.stderr)"
    let keyed_image = (build program-out $program release | path join "fixture.jab")
    let first = ($specs | first)
    let declared_cores = {|| demand check-image $keyed_image | get declaration.specs.0.cores }
    assert equal (do $declared_cores) $first.cores $"its image declares ($first.name)'s cores"
    let original = (open --raw $data | decode)
    let edited = ($original | str replace $"cores: ($first.cores)," $"cores: ($first.cores + 1),")
    assert ($edited != $original) $"the copy's ($first.name) given ($first.cores + 1) cores"
    $edited | save -f $data
    let key_at = (written $keyed_image)
    let changed = (^nu $tool build $program | complete)
    assert equal $changed.exit_code 0 $"the keyed program builds with its spec changed: ($changed.stderr)"
    assert ((written $keyed_image) > $key_at) "a listed spec's cores changed build the program again"
    assert equal (do $declared_cores) ($first.cores + 1) "its image declares the new cores"
    $original | save -f $data
    let changed_at = (written $keyed_image)
    let undone = (^nu $tool build $program | complete)
    assert equal $undone.exit_code 0 $"the keyed program builds with the change undone: ($undone.stderr)"
    assert ((written $keyed_image) > $changed_at) "the change undone builds it back"
    assert equal (do $declared_cores) $first.cores "its image declares the spec's cores again"
    let undone_at = (written $keyed_image)
    let unchanged = (^nu $tool build $program | complete)
    assert equal $unchanged.exit_code 0 $"the keyed program builds with nothing changed: ($unchanged.stderr)"
    assert equal (written $keyed_image) $undone_at "a build with nothing changed builds nothing"

    # the declaration dropped: the constants it left are retired
    do $manifest "declared" "" | ignore
    $exit_zero | save -f ($declared | path join "src" "main.S")
    let dropped = (^nu $tool build $declared | complete)
    assert equal $dropped.exit_code 0 $"the fixture builds with its declaration dropped: ($dropped.stderr)"
    let undone = (generated $declared_out)
    assert (($undone.constants == null) and (not $undone.included)) $"a build with the declaration dropped retires its constants and includes none: ($undone.constants | to nuon), ($undone.flags)"
    let undeclared_record = (recorded $declared_image)
    assert equal $undeclared_record { image: (sha $declared_image), demand: null } $"a build with the declaration dropped records a null demand: ($undeclared_record | to nuon)"

    print $"demand: a legacy program read, built, and run undeclared and diagnostic; ($refusals | length) manifests and a spec with no harts refused, each naming its fault; a spec in another case and a feature past every spec held; built afresh, a base demand past its spec refused, and a declared program's constants generated, reaching its assembly, its runs declared, diagnostic on four harts alone, and retired once its declaration was dropped; each image's demand recorded with it and read from there, an edited manifest unread, ($faults | length) faults of a record and one beside no image refused, a record kept to the shape passing, and a build beside an include its generator no longer writes, a record of another demand, an unreadable one, an altered image, or none built again whole; a listed spec's cores changed and undone each building again with the image's declaration following, and nothing changed building nothing; paths-of naming what glob names"
    print "demand: ok"
}

# A program's declared demand (jab demand-of), or its refusal as text,
# `refused: ` and the message.
def read-demand [dir: path] {
    try { demand of $dir } catch {|e| $"refused: ($e.msg)" }
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

# The record a build left beside an image (record-of), as NUON reads it;
# null with none there.
def recorded [image: path] {
    let file = (record-of $image)
    if ($file | path exists) { open --raw $file | decode | from nuon } else { null }
}

# Where an image's record lies: beside it, demand.nuon.
def record-of [image: path]: nothing -> string {
    $image | path expand | path dirname | path join "demand.nuon"
}

# An image's SHA-256 as its record holds it, 64 lowercase hex digits.
def sha [image: path]: nothing -> string {
    open --raw $image | hash sha256
}

# When an image was last written, which a build that runs rewrites.
def written [image: path]: nothing -> datetime {
    ls -D $image | get 0.modified
}

# The demand recorded with an image (jab image-demand), or its refusal as
# text, `refused: ` and the message.
def read-recorded [image: path] {
    try { demand image $image } catch {|e| $"refused: ($e.msg)" }
}

# A program built again through the tool, held to have built whole: the
# build run, its image written afresh, and its record `whole`, `case`
# saying what the build stood beside.
def rebuilt [tool: path, dir: path, image: path, whole: record, case: string] {
    let before = (written $image)
    let made = (^nu $tool build $dir | complete)
    assert equal $made.exit_code 0 $"($case): the build runs: ($made.stderr)"
    assert ((written $image) > $before) $"($case) builds again"
    let after = (recorded $image)
    assert equal $after $whole $"($case) writes the record afresh: ($after | to nuon)"
}

# A text's letters and digits alone, so a message reads the same however
# an error report wraps it.
def bare [text: string]: nothing -> string {
    $text | str replace --all --regex '[^A-Za-z0-9]' ''
}
