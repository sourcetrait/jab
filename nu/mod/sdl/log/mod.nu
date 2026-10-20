use (path self ../refusal)

# Every line the sdl shim writes, its stamp first
const sdl_line = (
    '^[0-9]+\.[0-9]{6} (?:'
    + 'object [0-9]+ (?:[0-9]+ [0-9]+ -?[0-9]+|- - -) .*'
    + '|process(?: .*)?|nonce(?: .*)?'
    + '|make_current(?: (?:[0-9]+|\?)\+[0-9a-f]+)*'
    + '|size|swap|poll'
    + '|libSDL2 not found|symbol not found'
    + ')$'
)

# The notices the shim writes as it aborts QEMU, SDL out of its reach
const sdl_notices = ["libSDL2 not found" "symbol not found"]

# The shim's log as written: its objects and events, every line held first
export def main [log: path]: nothing -> record<objects: table, events: table, process: oneof<int, nothing>, nonce: oneof<string, nothing>> {
    let text = (open --raw $log | into binary | decode)
    let whole = ($text | split row (char nl) | drop 1)
    if ($whole | is-empty) { error make {msg: "the shim log is empty; the window made no SDL calls"} }
    let unwritten = ($whole | enumerate | where {|l| not ($l.item =~ $sdl_line) })
    if not ($unwritten | is-empty) {
        let shown = ($unwritten | first 4 | each {|l| $"line ($l.index + 1): ($l.item | str substring --grapheme-clusters 0..<80)" })
        error make {msg: (refusal sdl-refusal [{ fault: "the log has a line the shim does not write", held: ($unwritten | length), unit: "line", examples: $shown }])}
    }
    let notices = ($whole | each {|l| $l | str replace --regex '^[0-9]+\.[0-9]{6} ' '' } | where {|l| $l in $sdl_notices })
    if not ($notices | is-empty) {
        let stops = ($notices | uniq --count | each {|n| { fault: $"the shim stopped the run: ($n.value)", held: $n.count, unit: "line", examples: [] } })
        error make {msg: (refusal sdl-refusal $stops)}
    }
    let run = (sdl-run-lines ($whole | enumerate | each {|l| { line: ($l.index + 1), text: ($l.item | str replace --regex '^[0-9]+\.[0-9]{6} ' '') } } | where {|l| not ($l.text | str starts-with "object ") }))
    if $run.fault != "" { error make {msg: (refusal sdl-refusal [{ fault: $run.fault, held: $run.held, unit: "line", examples: $run.examples }])} }
    let rows = ($whole
        | parse --regex '^(?P<ts>\d+\.\d+) (?P<name>\S+) ?(?P<rest>.*)$'
        | enumerate
        | each {|r| { at: $r.index, stamp: $r.item.ts, ts: ($r.item.ts | into float), name: $r.item.name, rest: $r.item.rest } })
    let objects = ($rows | where name == "object" | each {|r|
        let o = ($r.rest | parse --regex '^(?P<index>\d+) (?P<inode>\d+|-) (?P<size>\d+|-) (?P<mtime>-?\d+|-) (?P<path>.*)$' | first)
        {
            at: $r.at,
            index: ($o.index | into int),
            inode: (if $o.inode == "-" { null } else { $o.inode | into int }),
            size: (if $o.size == "-" { null } else { $o.size | into int }),
            mtime: (if $o.mtime == "-" { null } else { $o.mtime | into int }),
            path: $o.path,
        }
    })
    let first = ($objects | reduce --fold {} {|o, seen|
        let key = ($o.index | into string)
        if ($seen | get -o $key) == null { $seen | insert $key $o.at } else { $seen }
    })
    let happened = ($rows | where name != "object")
    let events = ($happened | enumerate | each {|r|
        let e = $r.item
        if $e.name != "make_current" {
            { at: $e.at, stamp: $e.stamp, ts: $e.ts, name: $e.name, render: false, shim_frames: 0, frames: [], fault: "", example: "" }
        } else {
            let frames = ($e.rest
                | str trim
                | split row " "
                | compact --empty
                | parse --regex '^(?P<object>\d+|\?)\+(?P<hex>[0-9a-f]+)$'
                | each {|f| { object: (if $f.object == "?" { null } else { $f.object | into int }), hex: $f.hex, address: ($"0x($f.hex)" | into int) } })
            let shim = ($frames | take while {|f| $f.object == 1 } | length)
            let next = ($happened | get -o ($r.index + 1))
            let render = ($next != null and $next.name == "size" and ($next.ts - $e.ts) < 0.002)
            let unnamed = ($frames | where {|f| $f.object != null and (($first | get -o ($f.object | into string)) == null or ($first | get ($f.object | into string)) > $e.at) })
            let fault = (if not ($unnamed | is-empty) { "unnamed" } else if $shim == 0 { "outside" } else { "" })
            let example = (if $fault == "unnamed" {
                let f = ($unnamed | first)
                $"($f.object)+($f.hex)"
            } else if $fault == "outside" and ($frames | is-empty) {
                "no frames"
            } else if $fault == "outside" {
                let f = ($frames | first)
                let file = (if $f.object == null { "?" } else { $objects | where index == $f.object | get -o 0.path | default "" | path basename })
                $"($file)+($f.hex)"
            } else { "" })
            { at: $e.at, stamp: $e.stamp, ts: $e.ts, name: $e.name, render: $render, shim_frames: $shim, frames: ($frames | skip $shim), fault: $fault, example: $example }
        }
    })
    let made = ($events | where name == "make_current")
    let total = ($made | length)
    if ($objects | is-empty) { error make {msg: (refusal sdl-refusal [{ fault: "the log has no object table", held: $total, unit: "make_current", examples: [] }])} }
    let twice = ($objects | get index | uniq --repeated)
    if not ($twice | is-empty) { error make {msg: (refusal sdl-refusal [{ fault: "the object table gives an index twice", held: $total, unit: "make_current", examples: ($twice | each {|i| $"object ($i)" }) }])} }
    for fault in [
        ["unnamed" "a frame names an object the table has no line for ahead of it"]
        ["outside" "a make_current's frames do not start in the shim's own library"]
    ] {
        let held = ($made | where fault == $fault.0)
        if not ($held | is-empty) { error make {msg: (refusal sdl-refusal [{ fault: $fault.1, held: ($held | length), unit: "make_current", examples: ($held | get example | uniq) }])} }
    }
    { objects: ($objects | reject at), events: ($events | reject fault example), process: $run.process, nonce: $run.nonce }
}

# A shim log's run lines: QEMU's pid and the nonce, or the first fault in them
def sdl-run-lines [events: list<record<line: int, text: string>>]: nothing -> record<process: oneof<int, nothing>, nonce: oneof<string, nothing>, fault: string, held: int, examples: list<string>> {
    let process = ($events | enumerate | where {|e| $e.item.text =~ '^process(?: |$)' })
    let nonce = ($events | enumerate | where {|e| $e.item.text =~ '^nonce(?: |$)' })
    let refused = {|fault: string, rows: list<any>|
        { process: null, nonce: null, fault: $fault, held: ($rows | length), examples: ($rows | first 4 | each {|r| $"line ($r.item.line): ($r.item.text | str substring --grapheme-clusters 0..<80)" }) }
    }
    if ($process | length) > 1 { return (do $refused "the log gives its process line twice" $process) }
    if ($nonce | length) > 1 { return (do $refused "the log gives its nonce line twice" $nonce) }
    let bad_process = ($process | where {|e| not ($e.item.text =~ '^process [1-9][0-9]{0,9}$') })
    if not ($bad_process | is-empty) { return (do $refused "the log's process line is malformed, where `process` and a pid in ASCII digits are wanted" $bad_process) }
    let bad_nonce = ($nonce | where {|e| not ($e.item.text =~ '^nonce [0-9a-f]{16}$') or $e.item.text == "nonce 0000000000000000" })
    if not ($bad_nonce | is-empty) { return (do $refused "the log's nonce line is malformed, where `nonce` and sixteen lowercase hex digits, not all zero, are wanted" $bad_nonce) }
    let ahead = ($nonce | where {|e| ($process | is-empty) or $e.index < ($process | first | get index) })
    if not ($ahead | is-empty) { return (do $refused "the log's nonce line comes with no process line ahead of it" $ahead) }
    let early = ($process | where {|e| $e.index != 0 })
    if not ($early | is-empty) { return (do $refused "the log's process line is out of its place, the first event" $early) }
    let astray = ($nonce | where {|e| $e.index != 1 })
    if not ($astray | is-empty) { return (do $refused "the log's nonce line is out of its place, the second event after the process line" $astray) }
    {
        process: (if ($process | is-empty) { null } else { $process | first | get item.text | str substring 8.. | into int }),
        nonce: (if ($nonce | is-empty) { null } else { $nonce | first | get item.text | str substring 6.. }),
        fault: "",
        held: 0,
        examples: [],
    }
}
