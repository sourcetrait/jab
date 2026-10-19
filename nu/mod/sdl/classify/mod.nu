use (path self ../refusal)
use (path self ../symbols)

# How a make_current reached the window by its frames: switch, upload, console
def sdl-decide [frames: list, device_in: string, modules: list<int>, executable: oneof<record, nothing>]: nothing -> record<kind: string, class: int, fault: string, at: oneof<record, nothing>> {
    let caller = ($frames | get -o 0)
    if $caller == null { return { kind: "refused", class: 5, fault: "anchor", at: null } }
    let caller_held = (symbols sdl-held $caller)
    if $caller_held != null { return $caller_held }
    if not ($caller.functions | any {|n| $n | str starts-with "sdl2_" }) { return { kind: "refused", class: 5, fault: "anchor", at: $caller } }
    let switch = ("sdl2_gl_switch" in $caller.functions)
    let update = ("sdl2_gl_update" in $caller.functions)
    if $switch and (not $update) { return { kind: "switch", class: 0, fault: "", at: null } }
    if (not $update) or $switch { return { kind: "refused", class: 5, fault: "front_end", at: $caller } }
    let second = ($frames | get -o 1)
    if $second == null { return { kind: "refused", class: 6, fault: "absent", at: $caller } }
    if $second.object == null { return { kind: "refused", class: 6, fault: "nowhere", at: $second } }
    let second_held = (symbols sdl-held $second)
    if $second_held != null { return $second_held }
    if (symbols sdl-device $second $device_in $modules) { return { kind: "refused", class: 5, fault: "device", at: $second } }
    if not ($second.functions | is-empty) {
        if not ($symbols.console_updates | flatten | any {|n| $n in $second.functions }) { return { kind: "console", class: 0, fault: "", at: null } }
        let later = ($frames | skip 2)
        if $device_in == "executable" {
            let later_held = ($later | where {|f| $f.object == 0 } | each {|f| symbols sdl-held $f } | get -o 0)
            if $later_held != null { return $later_held }
        }
        if ($later | any {|f| symbols sdl-device $f $device_in $modules }) { return { kind: "upload", class: 0, fault: "", at: null } }
        return { kind: "refused", class: 6, fault: "cut_short", at: $second }
    }
    if $second.object == 0 and $device_in == "module" and $executable != null and $executable.state == "read" and $executable.console {
        return { kind: "console", class: 0, fault: "", at: null }
    }
    { kind: "refused", class: 6, fault: "unanswered", at: $second }
}

# A frame as the record's callers name it: its function, else file and address
def sdl-frame-name [frame: record]: nothing -> string {
    if not ($frame.functions | is-empty) { $frame.functions | str join "/" } else if $frame.object == null { $"?+($frame.hex)" } else { $"($frame.file)+($frame.hex)" }
}

# A frame at fault for a refusal: its file and address, with its functions
def sdl-frame-text [frame: oneof<record, nothing>]: nothing -> string {
    if $frame == null { return "the shim's own frames alone" }
    let place = (if $frame.object == null { $"?+($frame.hex)" } else { $"($frame.file)+($frame.hex)" })
    if ($frame.functions | is-empty) { $place } else { $"($place) \(($frame.functions | str join '/'))" }
}

# What an object's symbol table holds, for a refusal
def sdl-table-text [object: record]: nothing -> string {
    let who = (if $object.index == 0 { $"the executable at ($object.path)" } else { $object.path })
    if $object.state == "no_file" { return $"($who) has no file to read" }
    if $object.state != "read" { return $"($who) went unread" }
    match $object.source {
        "symtab" => $"($who) keeps a symbol table of ($object.functions) sized functions",
        "dynsym" => $"($who) keeps no symbol table, only dynamic symbols, ($object.functions) sized functions among them",
        _ => $"($who) keeps no symbol table and no dynamic symbols",
    }
}

# A fault's words for a refusal, naming the object it lies in
def sdl-fault-text [fault: string, at: oneof<record, nothing>, objects: table]: nothing -> string {
    let object = (if $at == null or $at.object == null { null } else { $objects | where index == $at.object | get -o 0 })
    let table = (if $at == null { "its frames end in the shim's own library" } else if $object == null { "it lies in no object" } else { sdl-table-text $object })
    let path = (if $object == null { "" } else { $object.path | str replace --regex ' \(deleted\)$' '' })
    match $fault {
        "nm_absent" => "binutils' nm is not on PATH, and the frames' symbol tables are read with it",
        "deleted" => $"the executable at ($path) was deleted after it started",
        "changed" => $"($path) is not the file its line in the object table names, rebuilt or replaced since the run",
        "unbundled" => (if $object.why == "" { $"the bundle holds no table for ($path)" } else { $"the bundle holds no table for ($path): ($object.why)" }),
        "unreadable" => (if $object.why == "" { $"nm cannot read ($path)" } else { $"nm cannot read ($path): ($object.why)" }),
        "anchor" => $"a make_current's immediate caller is not in the SDL front end, and ($table)",
        "front_end" => "a make_current comes from a front-end function the probe does not model",
        "device" => "an upload's second frame is the device's own code, which the probe does not model",
        "absent" => "an upload's chain ends at its immediate caller",
        "nowhere" => "an upload's second frame lies in no object",
        "unanswered" => $"an upload's second frame resolves in no table, and ($table)",
        "cut_short" => "a console update has no device frame after it",
        _ => $fault,
    }
}

# A refusal's faults from the chains one class refused, each counted
def sdl-faults [cases: table, counts: record, objects: table]: nothing -> table<fault: string, held: int, unit: string, examples: list<string>> {
    let described = ($cases | each {|c| $c | insert text (sdl-fault-text $c.fault $c.at $objects) })
    $described | get text | uniq | each {|text|
        let group = ($described | where text == $text)
        {
            fault: $text,
            held: ($group | each {|c| $counts | get $c.key } | math sum),
            unit: "make_current",
            examples: ($group | each {|c| sdl-frame-text $c.at } | uniq | first 4),
        }
    }
}

# The shim's log with each make_current read by where it came from
export def main [log: path, --tables: string = ""]: nothing -> record<objects: table, virtio_gpu_in: string, events: table> {
    let c = (sdl-classified $log $tables)
    { objects: $c.objects, virtio_gpu_in: $c.virtio_gpu_in, events: ($c.events | reject key) }
}

# A make_current's chain as the reading keys it, its frames past the shim's
export def sdl-chain-key [frames: list<any>]: nothing -> string {
    let chain = ($frames | each {|f| $"(if $f.object == null { '?' } else { $f.object })+($f.hex)" } | str join " ")
    $"chain:($chain)"
}

# sdl-classify's reading with its chain keys, decisions, tables, and run lines
export def sdl-classified [log: path, bundle: string]: nothing -> record<objects: table, virtio_gpu_in: string, events: table, decisions: list<any>, tables: record, process: oneof<int, nothing>, nonce: oneof<string, nothing>> {
    let resolved = (symbols sdl-resolved $log false $bundle)
    let events = $resolved.events
    if ($events | is-empty) { error make {msg: "the shim log holds no events; the window made no SDL calls"} }
    let executable = ($resolved.objects | where index == 0 | get -o 0)
    let modules = ($resolved.objects | where {|o| $o.file | str starts-with $symbols.device_module } | get index)
    let keyed = ($events | each {|e| $e | insert key (sdl-chain-key $e.frames) })
    let made = ($keyed | where name == "make_current")
    let decided = ($made | where render == false)
    let chains = ($decided | uniq-by key)
    let decisions = ($chains | reduce --fold {} {|e, all| $all | insert $e.key (sdl-decide $e.frames $resolved.virtio_gpu_in $modules $executable) })
    let counts = ($decided | get key | uniq --count | reduce --fold {} {|c, all| $all | insert $c.value $c.count })
    let refused = ($chains | each {|e|
        let d = ($decisions | get $e.key)
        if $d.kind == "refused" { $d | insert key $e.key }
    })
    for class in [2 3 4 5 6] {
        let cases = ($refused | where class == $class)
        if not ($cases | is-empty) { error make {msg: (refusal sdl-refusal (sdl-faults $cases $counts $resolved.objects))} }
    }
    let named = ($made | uniq-by key | reduce --fold {} {|e, all| $all | insert $e.key ($e.frames | each {|f| sdl-frame-name $f } | str join " < ") })
    let read = ($keyed | each {|e|
        if $e.name != "make_current" { $e | merge { kind: $e.name, callers: "" } } else {
            let kind = (if $e.render { "render" } else { $decisions | get $e.key | get kind })
            $e | merge { kind: $kind, callers: ($named | get $e.key) }
        }
    })
    let decided_chains = ($chains | each {|e| { key: $e.key } | merge ($decisions | get $e.key | reject at) })
    { objects: $resolved.objects, virtio_gpu_in: $resolved.virtio_gpu_in, events: $read, decisions: $decided_chains, tables: $resolved.tables, process: $resolved.process, nonce: $resolved.nonce }
}
