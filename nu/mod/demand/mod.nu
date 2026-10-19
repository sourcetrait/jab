use ../spec
use ../word
use ../workspace

# The code's offset in an image, its second page
const image_code = 4096

# The image header's length from the window's base
const image_header = 64

# The image header's magic, `JABD` as a little-endian word
const image_magic = 0x4442414a

# The image header's version
const image_version = 1

# The header's flag bit marking a declared image
const image_declared = 1

# The first page's jump to the code a page on, `jal x0`, as its four bytes
const image_jump = 0x0000106f

# The declaration's offset in an image's first page
const decl_offset = 64

# The most specs a declaration lists
const decl_specs_max = 16

# A declaration's entry for one spec, in bytes
const decl_spec_bytes = 32

# A spec's name in a declaration entry, zero padded, in bytes
const decl_name_bytes = 8

# The ISA numbers a declaration names, by the spec data's profile
const decl_isas = { RVA23: 1 }

# The roles a manifest's `[reserved]` may reserve, each a count of harts
const reserved_roles = [gfx_harts]

# The roles a manifest's `[feature.<name>]` may demand, each a count of harts
const feature_roles = [io_harts]

# A program's declared demand from its manifest; null for the legacy path
export def of [dir: path] {
    let here = ($dir | path expand)
    let manifest = (open ($here | path join "program.jab.toml"))
    program-demand $manifest (workspace workspace-of $here $manifest)
}

# A manifest's declared demand, validated against the spec data; null for legacy
export def program-demand [m: record, ws: oneof<string, nothing>] {
    let name = $m.name
    let specs = ($m | get -o specs)
    if $specs == null {
        let sections = ([reserved feature] | where {|k| ($m | get -o $k) != null } | each {|k| $"[($k)]" })
        if not ($sections | is-empty) { error make {msg: $"($name): ($sections | str join ' and ') beside no `specs`; a reservation or a feature's demand holds only on the specs a program lists"} }
        return null
    }
    if not ($specs | describe | str starts-with "list") { error make {msg: $"($name): `specs` is a list of spec names, not ($specs | describe)"} }
    if ($specs | is-empty) { error make {msg: $"($name): `specs` names no spec; list the specs it supports, or leave `specs` out for the legacy path"} }
    let unnamed = ($specs | where {|s| ($s | describe) != "string" or ($s | str trim) == "" })
    if not ($unnamed | is-empty) { error make {msg: $"($name): `specs` holds ($unnamed | each {|u| $u | to nuon } | str join ', '), no spec's name"} }
    if $ws == null { error make {msg: $"($name) lists specs and has no workspace, whose asset/spec.nuon defines them"} }
    let table = (spec data $ws)
    let picked = ($specs | each {|s| { asked: $s, row: ($table | where {|r| ($r.name | str trim | str lowercase) == ($s | str trim | str lowercase) } | get -o 0) } })
    let unknown = ($picked | where {|p| $p.row == null } | each {|p| $p.asked })
    if not ($unknown | is-empty) { error make {msg: $"($name): `specs` names ($unknown | str join ', '), which its workspace's asset/spec.nuon does not define; it defines ($table | get name | str join ', ')"} }
    let twice = ($picked | group-by {|p| $p.row.name } | transpose spec asked | where {|g| ($g.asked | length) > 1 } | each {|g| $g.spec })
    if not ($twice | is-empty) { error make {msg: $"($name): `specs` names ($twice | str join ', ') twice, without regard to case"} }
    let uncounted = ($picked | where {|p| ($p.row | get -o cores | describe) != "int" } | each {|p| $p.row.name })
    if not ($uncounted | is-empty) { error make {msg: $"($name): ($uncounted | str join ', ') gives no `cores: int`, the harts a base demand is held against"} }
    let held = (section-counts $name "reserved" ($m | get -o reserved) $reserved_roles)
    let feature = ($m | get -o feature)
    if $feature != null and not ($feature | describe | str starts-with "record") { error make {msg: $"($name): `feature` holds a [feature.<name>] table for each feature, not ($feature | describe)"} }
    mut features = []
    for f in (if $feature == null { [] } else { $feature | transpose feature demand }) {
        if not ($f.feature =~ '^[a-z][a-z0-9_]*$') { error make {msg: $"($name): [feature.($f.feature)]: a feature's name is snake_case, a lowercase letter, then lowercase letters, digits, and underscores"} }
        let counts = (section-counts $name $"feature.($f.feature)" $f.demand $feature_roles)
        if ($counts | is-empty) { error make {msg: $"($name): [feature.($f.feature)] demands no hart; it names ($feature_roles | str join ' or ')"} }
        $features = ($features | append ({ name: $f.feature } | merge $counts))
    }
    let reservation = ($reserved_roles | reduce --fold {} {|r, acc| $acc | insert $r ($held | get -o $r | default 0) })
    let reserving = ($reservation | values | math sum)
    let base = (1 + $reserving)
    let short = ($picked | where {|p| $p.row.cores < $base } | each {|p| $"($p.row.name)'s ($p.row.cores)" })
    if not ($short | is-empty) { error make {msg: $"($name): its base demand, the main hart and the ($reserving) its [reserved] holds, is ($base) harts, more than ($short | str join ' and ')"} }
    { specs: ($picked | each {|p| $p.row.name }), reserved: $reservation, features: $features, base: $base }
}

# A manifest section's counts by role, each a whole number of one or more
def section-counts [name: string, section: string, value: any, roles: list<string>] {
    if $value == null { return {} }
    if not ($value | describe | str starts-with "record") { error make {msg: $"($name): [($section)] is a table of roles and their harts, not ($value | describe)"} }
    for k in ($value | columns) {
        if $k not-in $roles { error make {msg: $"($name): [($section)] names ($k); it names ($roles | str join ' or ')"} }
        let n = ($value | get $k)
        if ($n | describe) != "int" or $n < 1 { error make {msg: $"($name): ($section).($k) is ($n | to nuon), where a whole number of harts, one or more, is wanted"} }
    }
    $value
}

# jab_manifest.inc, a declared demand's constants for the assembly: its path
export def demand-include [d: record, out: path]: nothing -> string {
    let reserved = ($d.reserved | transpose role harts | each {|r| $".set JAB_RESERVED_($r.role | str uppercase), ($r.harts)" })
    let features = ($d.features | each {|f| $f | reject name | transpose role harts | each {|r| $".set JAB_FEATURE_($f.name | str uppercase)_($r.role | str uppercase), ($r.harts)" } } | flatten)
    let file = ($out | path join "jab_manifest.inc")
    let text = (([$".set JAB_BASE_HARTS, ($d.base)"] ++ $reserved ++ $features | str join "\n") + "\n")
    let held = (if ($file | path exists) { open --raw $file | into binary | decode } else { "" })
    if $held != $text { $text | save -f $file }
    $file
}

# An image's declaration bytes and its header's fields, from a declared demand
export def image-declaration [d: any, ws: any, program: string] {
    if $d == null { return { flags: 0, offset: 0, length: 0, crc: 0, bytes: 0x[] } }
    let count = ($d.specs | length)
    if $count > $decl_specs_max { error make {msg: $"($program) lists ($count) specs, and an image declares ($decl_specs_max) at most"} }
    let table = (spec data $ws)
    let entries = ($d.specs | each {|listed|
        let r = ($table | where {|row| ($row.name | str lowercase) == ($listed | str lowercase) } | first)
        let name = ($r.name | str lowercase)
        if not ($name =~ '^[a-z0-9]+$') or ($name | str length) > $decl_name_bytes { error make {msg: $"($program) lists ($r.name), whose name an image declares in ($decl_name_bytes) letters and digits at most"} }
        if $r.display != $spec.display_size { error make {msg: $"($program) lists ($r.name), whose display is ($r.display.width) by ($r.display.height), and an image renders at the ABI's ($spec.display_size.width) by ($spec.display_size.height)"} }
        let isa = ($decl_isas | get -o $r.isa_profile)
        if $isa == null { error make {msg: $"($program) lists ($r.name), whose ISA profile ($r.isa_profile) an image cannot declare; it declares ($decl_isas | columns | str join ', ')"} }
        if ($r.ram mod 1GiB) != 0B { error make {msg: $"($program) lists ($r.name), whose RAM, ($r.ram), is no whole number of GiB"} }
        let fields = [$r.cores ($r.ram / 1GiB | into int) $r.display.width $r.display.height $r.fps $isa]
        if ($fields | any {|f| $f < 0 or $f > 0xffff }) { error make {msg: $"($program) lists ($r.name), a count of which an image's u16 cannot hold: ($fields | str join ', ')"} }
        let named = ($name | into binary)
        $named ++ (word zeros ($decl_name_bytes - ($named | bytes length))) ++ ($fields | each {|f| word le $f 2 } | bytes collect) ++ (word zeros ($decl_spec_bytes - $decl_name_bytes - 2 * ($fields | length)))
    })
    let bytes = ((word le $d.base 2) ++ (word le $count 1) ++ 0x[00] ++ ($entries | bytes collect))
    { flags: $image_declared, offset: $decl_offset, length: ($bytes | bytes length), crc: (crc32 $bytes), bytes: $bytes }
}

# The CRC-32 of gzip and PNG over bytes, as the kernel's gz.S computes it
export def crc32 [bytes: binary]: nothing -> int {
    let table = (0..255 | each {|n|
        mut c = $n
        for _ in 1..8 {
            $c = (if ($c bit-and 1) == 1 { ($c bit-shr 1) bit-xor 0xedb88320 } else { $c bit-shr 1 })
        }
        $c
    })
    mut crc = 0xffffffff
    for b in ($bytes | chunks 1) {
        let i = (($crc bit-xor ($b | into int)) bit-and 0xff)
        $crc = (($table | get $i) bit-xor ($crc bit-shr 8))
    }
    $crc bit-xor 0xffffffff
}

# jab_header.S, an image's first page for the assembly, written on change
export def header-source [decl: record, out: path]: nothing -> string {
    let hex = {|v: int| $v | format number | get lowerhex }
    let rows = ($decl.bytes | chunks 16 | each {|row| "    .byte " + ($row | chunks 1 | each {|b| $"0x($b | encode hex | str lowercase)" } | str join ", ") })
    # the jump and six words, then zeros to the header's end
    let text = (([
        ".section .jab.header, \"ax\""
        ".option push"
        ".option norvc"
        ".option norelax"
        "    jal x0, __jab_code"
        ".option pop"
        $"    .4byte (do $hex $image_magic), ($image_version), ($decl.flags), ($decl.offset), ($decl.length), (do $hex $decl.crc)"
        $"    .zero ($image_header - 7 * 4)"
        ".section .jab.decl, \"a\""
    ] ++ $rows | str join "\n") + "\n")
    let file = ($out | path join "jab_header.S")
    let there = (if ($file | path exists) { open --raw $file | into binary | decode } else { "" })
    if $there != $text { $text | save -f $file }
    $file
}

# An image's first page read as the kernel reads it: legacy, undeclared, declared
export def check-image [image: path] {
    let image = ($image | path expand)
    let b = (open --raw $image | into binary)
    let size = ($b | bytes length)
    let word = {|at: int| $b | bytes at $at..<($at + 4) | into int --endian little }
    let half = {|at: int| $b | bytes at $at..<($at + 2) | into int --endian little }
    let hex = {|v: int| $"0x($v | into binary --endian big | encode hex | str lowercase)" }
    if $size < 8 or (do $word 4) != $image_magic { return { kind: "legacy", header: null, declaration: null } }
    if $size < $image_header { error make {msg: $"($image): its header ends at ($size) bytes, short of ($image_header)"} }
    let header = { magic: (do $word 4), version: (do $word 8), flags: (do $word 12), offset: (do $word 16), length: (do $word 20), crc: (do $word 24) }
    let refused = {|why: string| $"($image): declaration refused: ($why)" }
    if $header.version != $image_version { error make {msg: (do $refused $"version ($header.version)")} }
    if ($header.flags bit-and (bit-not-of $image_declared)) != 0 { error make {msg: (do $refused $"flags (do $hex $header.flags)")} }
    if $header.flags == 0 {
        if $header.length != 0 { error make {msg: (do $refused "flags 0 with a length")} }
        if $header.offset != 0 { error make {msg: (do $refused "flags 0 with an offset")} }
        if $header.crc != 0 { error make {msg: (do $refused "flags 0 with a CRC")} }
    } else {
        if $header.length == 0 { error make {msg: (do $refused "flags 1 with length 0")} }
        if $header.offset != $decl_offset { error make {msg: (do $refused $"offset ($header.offset)")} }
        let least = (4 + $decl_spec_bytes)
        if $header.length < $least or $header.length > ($image_code - $decl_offset) { error make {msg: (do $refused $"length ($header.length)")} }
        if $size < ($decl_offset + $header.length) { error make {msg: $"($image): its declaration ends at ($decl_offset + $header.length) bytes, past the image's ($size)"} }
        let computed = (crc32 ($b | bytes at $decl_offset..<($decl_offset + $header.length)))
        if $computed != $header.crc { error make {msg: (do $refused $"CRC (do $hex $computed) computed, the header's (do $hex $header.crc)")} }
        let count = ($b | bytes at ($decl_offset + 2)..<($decl_offset + 3) | into int)
        if $count == 0 or $count > $decl_specs_max { error make {msg: (do $refused $"spec count ($count)")} }
        if $header.length != (4 + $count * $decl_spec_bytes) { error make {msg: (do $refused $"length ($header.length) for ($count) specs")} }
    }
    let jump = (do $word 0)
    if $jump != $image_jump { error make {msg: $"($image): the jump at offset 0 is (do $hex $jump), where jal x0 to the code, (do $hex $image_jump), belongs"} }
    if $size <= $image_code { error make {msg: $"($image): it ends at ($size) bytes, where its code begins at ($image_code)"} }
    let zeroed = {|from: int, to: int| ($b | bytes at $from..<$to | bytes index-of --all 0x[00] | length) == ($to - $from) }
    if not (do $zeroed 28 $image_header) { error make {msg: $"($image): its header past the CRC is not zero"} }
    if $header.flags == 0 { return { kind: "undeclared", header: $header, declaration: null } }
    let count = ($b | bytes at ($decl_offset + 2)..<($decl_offset + 3) | into int)
    if ($b | bytes at ($decl_offset + 3)..<($decl_offset + 4) | into int) != 0 { error make {msg: $"($image): the declaration's byte after its count is not zero"} }
    let isas = ($decl_isas | transpose name code)
    let specs = (0..<$count | each {|k|
        let at = ($decl_offset + 4 + $k * $decl_spec_bytes)
        let raw = ($b | bytes at $at..<($at + $decl_name_bytes))
        let end = ($raw | bytes index-of 0x[00])
        let used = (if $end < 0 { $decl_name_bytes } else { $end })
        let name = ($raw | bytes at 0..<$used | decode)
        if not ($name =~ '^[a-z0-9]+$') { error make {msg: $"($image): spec ($k)'s name, ($name | to nuon), is no lowercase letters and digits"} }
        if not (do $zeroed ($at + $used) ($at + $decl_name_bytes)) { error make {msg: $"($image): spec ($k)'s name, ($name), is not zero padded"} }
        let f = ($at + $decl_name_bytes)
        let isa = (do $half ($f + 10))
        if ($isas | where code == $isa | is-empty) { error make {msg: $"($image): spec ($name)'s ISA, ($isa), is none a declaration names"} }
        if not (do $zeroed ($f + 12) ($at + $decl_spec_bytes)) { error make {msg: $"($image): spec ($name)'s entry past its fields is not zero"} }
        { name: $name, cores: (do $half $f), ram_gib: (do $half ($f + 2)), display: { width: (do $half ($f + 4)), height: (do $half ($f + 6)) }, fps: (do $half ($f + 8)), isa: ($isas | where code == $isa | first | get name) }
    })
    { kind: "declared", header: $header, declaration: { base: (do $half $decl_offset), specs: $specs } }
}

# Every bit of a 32-bit word but those of `mask`
def bit-not-of [mask: int]: nothing -> int {
    0xffffffff bit-xor $mask
}

# The demand recorded with an image, held to its rules; null where none is
export def image [image: path] {
    let image = ($image | path expand)
    let file = (demand-record-of $image)
    if not ($file | path exists) { return null }
    if not ($image | path exists) { error make {msg: $"($file) is the record of an image, and there is none at ($image)"} }
    let record = (try { open --raw $file | decode | from nuon } catch {|e| error make {msg: $"($file): not NUON the tools can read: ($e.msg)"} })
    let problems = (demand-record-problems $record (open --raw $image | hash sha256))
    if not ($problems | is-empty) { error make {msg: ([$"($file) does not hold for ($image):"] ++ ($problems | each {|p| $"  ($p)" }) | str join "\n")} }
    $record.demand
}

# Where an image's demand record lies: demand.nuon beside it
export def demand-record-of [image: path]: nothing -> string {
    $image | path expand | path dirname | path join "demand.nuon"
}

# A demand record's problems for an image of that hash, a line each
def demand-record-problems [record: any, hash: string]: nothing -> list<string> {
    let got = ($record | describe)
    if not ($got | str starts-with "record") { return [$"a record of `image` and `demand` expected, ($got) found"] }
    let fields = ($record | columns)
    let missing = ([image demand] | where {|f| $f not-in $fields } | each {|f| $"($f): missing" })
    let others = ($fields | where {|f| $f not-in [image demand] } | each {|f| $"($f): a field the record does not hold" })
    let image = (if "image" not-in $fields { [] } else {
        let i = $record.image
        if ($i | describe) != "string" { [$"image: string expected, ($i | describe) found"] } else if not ($i =~ '^[0-9a-f]{64}$') { [$"image: ($i | to nuon), no SHA-256"] } else if $i != $hash { [$"image: ($i), where the image's SHA-256 is ($hash)"] } else { [] }
    })
    let demand = (if "demand" not-in $fields { [] } else { demand-shape-problems $record.demand })
    $missing ++ $others ++ $image ++ $demand
}

# A recorded demand's problems against program-demand's shape, a line each
def demand-shape-problems [d: any]: nothing -> list<string> {
    if $d == null { return [] }
    let got = ($d | describe)
    if not ($got | str starts-with "record") { return [$"demand: a record or null expected, ($got) found"] }
    let fields = ($d | columns)
    let missing = ([specs reserved features base] | where {|f| $f not-in $fields } | each {|f| $"demand.($f): missing" })
    let others = ($fields | where {|f| $f not-in [specs reserved features base] } | each {|f| $"demand.($f): a field the demand does not hold" })
    let specs = (if "specs" not-in $fields { [] } else {
        let s = $d.specs
        let kind = ($s | describe)
        if not ($kind | str starts-with "list") { [$"demand.specs: a list of names expected, ($kind) found"] } else if ($s | is-empty) { ["demand.specs: empty"] } else {
            $s | enumerate | where {|e| ($e.item | describe) != "string" or ($e.item | str trim) == "" } | each {|e| $"demand.specs.($e.index): ($e.item | to nuon), no spec's name" }
        }
    })
    let reserved = (if "reserved" not-in $fields { [] } else {
        let r = $d.reserved
        if not ($r | describe | str starts-with "record") { [$"demand.reserved: a record expected, ($r | describe) found"] } else {
            let roles = ($r | columns)
            let absent = ($reserved_roles | where {|k| $k not-in $roles } | each {|k| $"demand.reserved.($k): missing" })
            let foreign = ($roles | where {|k| $k not-in $reserved_roles } | each {|k| $"demand.reserved.($k): a role no program reserves" })
            let counts = ($roles | where {|k| $k in $reserved_roles and (($r | get $k | describe) != "int" or ($r | get $k) < 0) } | each {|k| $"demand.reserved.($k): ($r | get $k | to nuon), where a whole number of harts, 0 or more, is wanted" })
            $absent ++ $foreign ++ $counts
        }
    })
    let features = (if "features" not-in $fields { [] } else {
        let fs = $d.features
        let kind = ($fs | describe)
        if not (($kind | str starts-with "list") or ($kind | str starts-with "table")) { [$"demand.features: a list expected, ($kind) found"] } else {
            $fs | enumerate | each {|e|
                let f = $e.item
                let at = $"demand.features.($e.index)"
                if not ($f | describe | str starts-with "record") { [$"($at): a record expected, ($f | describe) found"] } else {
                    let keys = ($f | columns)
                    let named = (if "name" not-in $keys { [$"($at).name: missing"] } else if ($f.name | describe) != "string" or not ($f.name =~ '^[a-z][a-z0-9_]*$') { [$"($at).name: ($f.name | to nuon), no snake_case name"] } else { [] })
                    let roles = ($keys | where {|k| $k != "name" })
                    let foreign = ($roles | where {|k| $k not-in $feature_roles } | each {|k| $"($at).($k): a role no feature demands" })
                    let none = (if ($roles | where {|k| $k in $feature_roles } | is-empty) { [$"($at): demands no hart"] } else { [] })
                    let counts = ($roles | where {|k| $k in $feature_roles and (($f | get $k | describe) != "int" or ($f | get $k) < 1) } | each {|k| $"($at).($k): ($f | get $k | to nuon), where a whole number of harts, 1 or more, is wanted" })
                    $named ++ $foreign ++ $none ++ $counts
                }
            } | flatten
        }
    })
    let base = (if "base" not-in $fields { [] } else {
        let b = $d.base
        let r = ($d | get -o reserved)
        let summed = (if ($r | describe | str starts-with "record") and ($reserved_roles | all {|k| ($r | get -o $k | describe) == "int" }) { 1 + ($reserved_roles | each {|k| $r | get $k } | math sum) } else { null })
        if ($b | describe) != "int" { [$"demand.base: int expected, ($b | describe) found"] } else if $summed != null and $b != $summed { [$"demand.base: ($b), where 1 plus the reserved harts is ($summed)"] } else { [] }
    })
    $missing ++ $others ++ $specs ++ $reserved ++ $features ++ $base
}

# Whether an image's demand record holds and names the demand a build resolved
export def record-holds [image: path, demand: any]: nothing -> bool {
    if not (demand-record-of $image | path exists) { return false }
    try { (image $image) == $demand } catch { false }
}

# Refuses a named spec the image's recorded demand does not list
export def spec-listed [m: record, demand: oneof<record, nothing>, program: string] {
    if $m.spec == null or $demand == null { return }
    if $m.spec.name in ($demand.specs | each {|s| $s | str lowercase }) { return }
    error make {msg: $"($program) does not list ($m.spec.name), the spec this launch names; it lists ($demand.specs | str join ', ')"}
}
