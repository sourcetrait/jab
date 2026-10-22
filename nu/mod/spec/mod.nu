use (path self ../nutype)

# The display's size in pixels, jab.inc's JAB_DISPLAY_WIDTH by _HEIGHT
export const display_size = { width: 1920, height: 1080 }

# The harts a machine takes: one to JAB_HARTS_MAX's eight
export const harts_allowed = [1 2 3 4 5 6 7 8]

# A spec's row, its name in any case, refused where a launch cannot provision it
export def row [ws: path, name: string]: nothing -> record {
    let rows = (data $ws)
    let found = ($rows | where {|r| ($r.name | str lowercase) == ($name | str lowercase) })
    if ($found | is-empty) { error make {msg: $"no spec ($name) in the spec data, which defines ($rows | get name | str join ', ')"} }
    let r = ($found | first)
    if $r.cores not-in $harts_allowed { error make {msg: $"($r.name) has ($r.cores) cores, past the ($harts_allowed | last) harts a machine takes; the launcher cannot provision it"} }
    if $r.display != $display_size { error make {msg: $"($r.name)'s display is ($r.display.width) by ($r.display.height), and the ABI's ($display_size.width) by ($display_size.height); the launcher cannot provision it yet"} }
    $r
}

# The default spec: JAB_SPEC, else jab/config.toml's, its file seeded if absent
export def configured [ws: path]: nothing -> string {
    let forced = ($env.JAB_SPEC? | default "")
    if $forced != "" { return $forced }
    let given = ($env.XDG_CONFIG_HOME? | default "")
    let home = (if $given == "" { $nu.home-dir | path join ".config" } else { $given })
    if ($home | path type) != "dir" { error make {msg: $"the XDG config home ($home) is not there, where jab/config.toml names the default spec; set JAB_SPEC or pass --spec"} }
    let dir = ($home | path join "jab")
    mkdir $dir
    let file = ($dir | path join "config.toml")
    if ($file | path type) == null {
        let seed = ($ws | path join "asset" "default" "config.toml")
        if not ($seed | path exists) { error make {msg: $"no ($seed) to seed ($file) from"} }
        cp $seed $file
    }
    let cfg = (try { open --raw $file | into binary | decode | from toml } catch {|e| error make {msg: $"($file) is no TOML the tools read: ($e.msg)"} })
    let spec = ($cfg | get -o spec)
    if ($spec | describe) != "string" or ($spec | str trim) == "" { error make {msg: $"($file) names no `spec`, the default spec a launch runs"} }
    $spec
}

# A spec table held to its type and its meaning, every problem named a line each
export def read [data: path, type: path]: nothing -> table {
    for f in [$type $data] { if not ($f | path exists) { error make {msg: $"($f): no such file"} } }
    let text = (try { open --raw $type | decode } catch {|e| error make {msg: $"($type): unreadable: ($e.msg)"} })
    let schema = (nutype model $text $type)
    if $schema.kind != "table" { error make {msg: $"($type): the tools read a table of specs, table<...>, not (nutype type-name $schema)"} }
    let name_field = ($schema.fields | where name == "name" | get -o 0)
    if $name_field == null or $name_field.schema != { kind: "scalar", name: "string" } { error make {msg: $"($type): `name: string` is the field the tools match a spec by, and the type has none"} }
    let rows = (try { open --raw $data | decode | from nuon } catch {|e| error make {msg: $"($data): not NUON the tools can read: ($e.msg)"} })
    let got = ($rows | describe)
    if not (($got | str starts-with "table") or ($got | str starts-with "list")) { error make {msg: $"($data): a table of specs expected, ($got) found"} }
    if ($rows | is-empty) { error make {msg: $"($data): no spec in it"} }
    let typed = ($rows | enumerate | each {|r|
        let label = (spec-label $r.index $r.item)
        nutype record-problems $r.item $schema.fields "" | each {|p| $"  ($label): ($p)" }
    } | flatten)
    if not ($typed | is-empty) { error make {msg: ([$"($data) does not hold to ($type):"] ++ $typed | str join "\n")} }
    let meant = (spec-meaning $rows ($schema.fields | get name))
    if not ($meant | is-empty) { error make {msg: ([$"($data): its specs do not hold:"] ++ ($meant | each {|m| $"  ($m)" }) | str join "\n")} }
    $rows
}

# The workspace's spec data, asset/spec.nuon held to asset/spec.nutype
export def data [ws: path]: nothing -> table {
    let asset = ($ws | path expand | path join "asset")
    read ($asset | path join "spec.nuon") ($asset | path join "spec.nutype")
}

# A spec row as a problem names it: its place, and its name when it has one
def spec-label [index: int, row: any]: nothing -> string {
    let name = (if ($row | describe | str starts-with "record") { $row | get -o name } else { null })
    if ($name | describe) == "string" and $name != "" { $"row ($index + 1) \(($name)\)" } else { $"row ($index + 1)" }
}

# What a spec table means past its type: names unique, counts above zero
def spec-meaning [rows: list<any>, named: list<string>]: nothing -> list<string> {
    let labelled = ($rows | enumerate | each {|r| { label: (spec-label $r.index $r.item), row: $r.item } })
    let unnamed = ($labelled | where {|r| ($r.row.name | str trim) == "" } | each {|r| $"($r.label): name empty" })
    let twice = ($labelled
        | where {|r| ($r.row.name | str trim) != "" }
        | group-by {|r| $r.row.name | str trim | str lowercase }
        | transpose key rows
        | where {|g| ($g.rows | length) > 1 }
        | each {|g| $"($g.rows | get label | str join ' and ') name one spec, ($g.key) in any case" })
    let numbers = {|v| ($v | describe) in ["int" "float"] }
    let sizes = {|v| ($v | describe) == "filesize" }
    let below = ($labelled | each {|r|
        let counts = ([cores clock_ghz fps] | where {|f| $f in $named and (do $numbers ($r.row | get $f)) and ($r.row | get $f) <= 0 } | each {|f| $"($r.label): ($f) ($r.row | get $f), above zero wanted" })
        let ram = (if "ram" in $named and (do $sizes $r.row.ram) and $r.row.ram <= 0B { [$"($r.label): ram ($r.row.ram), above zero wanted"] } else { [] })
        let display = (if "display" in $named and ($r.row.display | describe | str starts-with "record") {
            [width height] | where {|s| (do $numbers ($r.row.display | get -o $s)) and ($r.row.display | get $s) <= 0 } | each {|s| $"($r.label): display.($s) ($r.row.display | get $s), above zero wanted" }
        } else { [] })
        let vram = (if "vram" in $named and (do $sizes $r.row.vram) and $r.row.vram <= 0B { [$"($r.label): vram ($r.row.vram), above zero wanted where a spec gives one"] } else { [] })
        $counts ++ $ram ++ $display ++ $vram
    } | flatten)
    $unnamed ++ $twice ++ $below
}
