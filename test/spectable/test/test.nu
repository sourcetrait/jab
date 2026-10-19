# spectable's integration test: the SDK's spec data loader, `spec read` and
# `spec data`, on the host; the program itself is never launched. First the
# positive control: the workspace's asset/spec.nuon through `spec data`,
# every spec and every field of it equal to
# doc/SPEC.md's, a section a spec and a line a field, its GB read as GiB,
# its GHz an int, its None as null, and the display's pixels from its
# parenthesis, so a definition the NUON has lost, gained, or left behind
# SPEC.md fails here. Then copies of the data, each wrong one way, held to
# the workspace's type and refused naming the row and the field: a field
# missing, at a row and inside `display`; a value of another type, at a
# row and inside `display`; a field the type does not name, at a row and
# inside `display`; a name given twice, and again in another case; a field
# given twice in one record, which NUON's own parse refuses, named by its
# file; no spec; a name empty; each count, clock, rate, and size at zero,
# and the VRAM at zero where a spec gives one; and a record where the table
# belongs. A spec with a GPU named and its VRAM sized holds. Then copies of
# the type the loader cannot read, one unclosed and one naming `any`, each
# refused naming its file; and the checker the data models share, `nutype
# problems`, over a record holding its type and one with a field of another
# type. Last, the build: a workspace of the test's own,
# a copy of the spec data in its asset/ and two programs, one listing specs
# and one not; a second build of each does nothing, a change to the type
# alone builds the one listing specs again and leaves the other as it was,
# and so does a change to the data alone.
use ../../../nu/mod/target
use ../../../nu/mod/spec
use ../../../nu/mod/build
use ../../../nu/mod/nutype
use std/assert

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let ws = ($env.FILE_PWD | path join ".." ".." ".." | path expand)
    let asset = ($ws | path join "asset")
    let type = ($asset | path join "spec.nutype")

    # the positive control: the workspace's data as SPEC.md defines it
    let specs = (spec data $ws)
    let wanted = (spec-md ($ws | path join "doc" "SPEC.md"))
    assert equal ($specs | get name) ($wanted | get name) $"every spec SPEC.md defines, in its order: ($specs | get name)"
    for w in $wanted {
        let got = ($specs | where name == $w.name | first)
        assert equal ($got | columns | sort) ($w | columns | sort) $"($w.name)'s fields SPEC.md's: ($got | columns)"
        for field in ($w | columns) {
            assert equal ($got | get $field) ($w | get $field) $"($w.name)'s ($field) as SPEC.md has it: ($got | get $field | to nuon) against ($w | get $field | to nuon)"
        }
    }

    # copies of the data, each wrong one way
    let real = (open --raw ($asset | path join "spec.nuon") | decode | from nuon)
    let first = ($real | first)
    let label = $"row 1 \(($first.name)\)"
    let twin = $"row (($real | length) + 1)"
    let fixtures = ($out | path join "fixtures")
    target retire $fixtures
    mkdir $fixtures
    let with = {|f: closure| $real | enumerate | each {|r| if $r.index == 0 { do $f $r.item } else { $r.item } } }
    let cases = [
        { name: "missing", data: (do $with {|r| $r | reject fps }), says: [$"($label): fps: missing"] }
        { name: "missing_nested", data: (do $with {|r| $r | update display ($r.display | reject height) }), says: [$"($label): display.height: missing"] }
        { name: "typed", data: (do $with {|r| $r | update cores ($r.cores | into string) }), says: [$"($label): cores: int expected, string found"] }
        { name: "typed_nested", data: (do $with {|r| $r | update display ($r.display | update width ($r.display.width | into string)) }), says: [$"($label): display.width: int expected, string found"] }
        { name: "unknown", data: (do $with {|r| $r | insert storage 64GiB }), says: [$"($label): storage: a field the type does not name"] }
        { name: "unknown_nested", data: (do $with {|r| $r | update display ($r.display | insert depth 32) }), says: [$"($label): display.depth: a field the type does not name"] }
        { name: "twice", data: ($real | append $first), says: [$"($label) and ($twin) \(($first.name)\) name one spec"] }
        { name: "twice_case", data: ($real | append ($first | update name ($first.name | str lowercase))), says: [$"($label) and ($twin) \(($first.name | str lowercase)\) name one spec, ($first.name | str lowercase) in any case"] }
        { name: "none", data: [], says: ["no spec in it"] }
        { name: "unnamed", data: (do $with {|r| $r | update name "" }), says: ["row 1: name empty"] }
        { name: "zeroes", data: (do $with {|r| $r | update cores 0 | update clock_ghz 0 | update fps 0 | update ram 0B | update display { width: 0, height: 0 } }), says: [$"($label): cores 0, above zero wanted" $"($label): clock_ghz 0, above zero wanted" $"($label): fps 0, above zero wanted" $"($label): ram 0 B, above zero wanted" $"($label): display.width 0, above zero wanted" $"($label): display.height 0, above zero wanted"] }
        { name: "vram_zero", data: (do $with {|r| $r | update gpu "fixture" | update vram 0B }), says: [$"($label): vram 0 B, above zero wanted where a spec gives one"] }
        { name: "record", data: $first, says: ["a table of specs expected, record<"] }
    ]
    for c in $cases {
        let file = ($fixtures | path join $"($c.name).nuon")
        $c.data | to nuon | save -f $file
        let said = (try { spec read $file $type; "" } catch {|e| $e.msg })
        assert ($said != "") $"($c.name): refused: the loader took it"
        for s in $c.says { assert ($said | str contains $s) $"($c.name): ($s): ($said)" }
    }
    # a field given twice in one record, which NUON's parse refuses
    let doubled = ($fixtures | path join "doubled.nuon")
    $"[{name: '($first.name)', cores: ($first.cores), cores: ($first.cores)}]" | save -f $doubled
    let said = (try { spec read $doubled $type; "" } catch {|e| $e.msg })
    assert ($said | str starts-with $"($doubled): not NUON the tools can read") $"doubled: refused naming its file: ($said)"
    # a GPU named and its VRAM sized holds
    let gpu_file = ($fixtures | path join "gpu.nuon")
    do $with {|r| $r | update gpu "fixture" | update vram 2GiB } | to nuon | save -f $gpu_file
    let gpu = (spec read $gpu_file $type | first)
    assert equal [$gpu.gpu $gpu.vram] ["fixture" 2GiB] $"a GPU named and its VRAM sized hold: ($gpu)"

    # copies of the type the loader cannot read
    let types = [
        { name: "unclosed", text: "table<name: string", says: "a field and its type expected in table<...>, the end found" }
        { name: "any", text: "table<name: any>", says: "any is no type the tools read" }
    ]
    for t in $types {
        let file = ($fixtures | path join $"($t.name).nutype")
        $t.text | save -f $file
        let said = (try { spec read ($asset | path join "spec.nuon") $file; "" } catch {|e| $e.msg })
        assert ($said | str starts-with $"($file): ($t.says)") $"($t.name): refused naming its file: ($said)"
    }

    # the checker the data models share: a value held to a type's text alone
    let model = "record<name: string, cores: int>"
    assert equal (nutype problems { name: "fixture", cores: 3 } $model "inline") [] "nutype problems: a record holding its type has none"
    assert equal (nutype problems { name: "fixture", cores: "3" } $model "inline") ["cores: int expected, string found"] "nutype problems: a field of another type named"

    # the build: the spec data an input of a build listing specs alone
    let built = (spec-builds $ws $asset ($out | path join "build"))

    print $"spectable: ($specs | length) specs as SPEC.md defines them; ($cases | length) wrong copies of the data and ($types | length) of the type refused, each naming its row and field or its file; ($built)"
    print "spectable: ok"
}

# doc/SPEC.md's specs as asset/spec.nuon writes them: a section a spec,
# named by its heading, and a line a field, `- Key: Value`. A key the test
# reads into no field of the NUON fails here, so a field SPEC.md gains
# reaches the data and its type. Untyped because it ends in an error.
def spec-md [file: path] {
    let lines = (open --raw $file | decode | lines)
    let heads = ($lines | enumerate | where {|r| $r.item =~ '^#{2,}\s+\S+\s*$' })
    $heads | enumerate | each {|h|
        let start = ($h.item.index + 1)
        let stop = (if ($h.index + 1) < ($heads | length) { $heads | get ($h.index + 1) | get index } else { $lines | length })
        let fields = ($lines | slice $start..<$stop | where {|l| $l starts-with "- " } | each {|l|
            let parts = ($l | str substring 2.. | split row ": ")
            { key: ($parts | first), value: ($parts | skip 1 | str join ": ") }
        })
        if ($fields | is-empty) { null } else {
            spec-row ($h.item.item | str replace --regex '^#+\s*' '' | str trim) ($fields | reduce --fold {} {|it, acc| $acc | insert $it.key $it.value })
        }
    } | compact
}

# A SPEC.md section's fields as the NUON's row. Untyped because it ends in
# an error.
def spec-row [name: string, f: record] {
    let read = ["ISA" "ISA Profile" "Cores" "Clock" "RAM" "GPU" "VRAM" "Display" "FPS"]
    let unread = ($f | columns | where {|k| $k not-in $read })
    if not ($unread | is-empty) { error make {msg: $"SPEC.md's ($name) has ($unread | str join ', '), which this test reads into no field of asset/spec.nuon"} }
    let size = {|v: string| if $v == "None" { null } else { ($v | str replace "GB" "" | into int) * 1GiB } }
    let pixels = ($f.Display | parse --regex '\((?<w>\d+)x(?<h>\d+)' | first)
    {
        name: $name,
        isa: $f.ISA,
        isa_profile: ($f | get "ISA Profile"),
        cores: ($f.Cores | into int),
        clock_ghz: ($f.Clock | str lowercase | str replace "ghz" "" | into int),
        ram: (do $size $f.RAM),
        gpu: (if $f.GPU == "None" { null } else { $f.GPU }),
        vram: (do $size $f.VRAM),
        display: { width: ($pixels.w | into int), height: ($pixels.h | into int) },
        fps: ($f.FPS | into int),
    }
}

# A workspace of the test's own under `home`: a copy of the spec data in
# its asset/ and two programs, `listed` with specs and `unlisted` with
# none, each built through the SDK's tool with the workspace's toolchain:
# built once, then again with nothing changed, then after a change to the
# type alone, then after a change to the data alone. The one listing specs
# builds again after each change and the other never does. Its account,
# a line.
def spec-builds [ws: path, asset: path, home: path]: nothing -> string {
    target retire $home
    mkdir ($home | path join "asset")
    let data = ($home | path join "asset" "spec.nuon")
    let type = ($home | path join "asset" "spec.nutype")
    cp ($asset | path join "spec.nuon") $data
    cp ($asset | path join "spec.nutype") $type
    "kernel = 'kernel'\nprograms = ['listed', 'unlisted']\n" | save -f ($home | path join "workspace.jab.toml")
    let sdk = ($ws | path join "sdk")
    for p in [listed unlisted] {
        let dir = ($home | path join $p)
        mkdir ($dir | path join "src")
        let specs = (if $p == "listed" { "specs = ['1ka1']\n" } else { "" })
        $"name = '($p)'\nsdk = '($sdk)'\nincludes = ['($sdk | path join src)']\nlink = '($sdk | path join src program.ld)'\n($specs)" | save -f ($dir | path join "program.jab.toml")
        ".include \"jab.inc\"\n\n.section .text\n.global _start\n_start:\n    jab.sys.exit 0\n" | save -f ($dir | path join "src" "main.S")
    }
    let local = ($ws | path join "extern" "riscv")
    let toolchain = ($env.RISCV_TOOLCHAIN? | default (if ($local | path exists) { $local } else { "" }))
    let tool = ($sdk | path join ".." "nu" "bin" "do.nu" | path expand)
    let build = {||
        [listed unlisted] | each {|p|
            let dir = ($home | path join $p)
            let r = (with-env (if $toolchain == "" { {} } else { { RISCV_TOOLCHAIN: $toolchain } }) { ^nu $tool build $dir | complete })
            if $r.exit_code != 0 { error make {msg: $"building ($p) failed: ($r.stderr)"} }
            let image = (build program-out $dir release | path join $"($p).jab")
            { program: $p, modified: (ls -D $image | get 0.modified) }
        }
    }
    let first = (do $build)
    let again = (do $build)
    assert equal $again $first $"a second build with nothing changed does nothing: ($again)"
    $"\n# the type changed alone\n" | save --append $type
    let typed = (do $build)
    assert (($typed | where program == listed | get 0.modified) > ($again | where program == listed | get 0.modified)) $"the program listing specs builds again after a change to the type alone: ($typed)"
    assert equal ($typed | where program == unlisted) ($again | where program == unlisted) $"the program listing none is left as it was: ($typed)"
    open --raw $data | decode | from nuon | to nuon --indent 2 | save -f $data
    let dated = (do $build)
    assert (($dated | where program == listed | get 0.modified) > ($typed | where program == listed | get 0.modified)) $"the program listing specs builds again after a change to the data alone: ($dated)"
    assert equal ($dated | where program == unlisted) ($typed | where program == unlisted) $"the program listing none is left as it was: ($dated)"
    "the build: a change to the type alone and to the data alone each built the program listing specs again and left the other"
}
