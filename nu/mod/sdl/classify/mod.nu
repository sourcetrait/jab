use (path self ../refusal)
use (path self ../symbols)

# The front-end function whose own make_current opens a drawn frame
const render_anchor = "sdl2_gl_render_surface"

# The front-end functions a render's or the scanout path's call may lie inlined in
const render_inliners = ["sdl2_gl_refresh" "sdl2_gl_redraw"]

# The window a render read by timing has its size call within, the gaps' bound
const size_window_us = 2000

# How a make_current's chain reached the window by its frames
def sdl-decide [frames: list, device_in: string, modules: list<int>, executable: oneof<record, nothing>, sources: record]: nothing -> record<kind: string, class: int, fault: string, at: oneof<record, nothing>> {
    let caller = ($frames | get -o 0)
    if $caller == null { return { kind: "refused", class: 5, fault: "anchor", at: null } }
    let caller_held = (symbols sdl-held $caller)
    if $caller_held != null { return $caller_held }
    let second = ($frames | get -o 1)
    let second_held = (if $second == null { null } else { symbols sdl-held $second })
    if $second_held != null { return $second_held }
    if $caller.overlap { return { kind: "refused", class: 5, fault: "overlap", at: $caller } }
    if $render_anchor in $caller.functions { return { kind: "render", class: 0, fault: "", at: null } }
    if ($render_inliners | any {|n| $n in $caller.functions }) { return { kind: "refused", class: 5, fault: "inlined", at: $caller } }
    let source = (if $caller.object == null { "" } else { $sources | get -o ($caller.object | into string) | default "" })
    if ($caller.functions | is-empty) and $caller.state == "read" and $source == "dynsym" { return { kind: "timed", class: 0, fault: "", at: $caller } }
    if not ($caller.functions | any {|n| $n | str starts-with "sdl2_" }) { return { kind: "refused", class: 5, fault: "anchor", at: $caller } }
    let switch = ("sdl2_gl_switch" in $caller.functions)
    let update = ("sdl2_gl_update" in $caller.functions)
    if $switch and (not $update) { return { kind: "switch", class: 0, fault: "", at: null } }
    if (not $update) or $switch { return { kind: "refused", class: 5, fault: "front_end", at: $caller } }
    if $second == null { return { kind: "refused", class: 6, fault: "absent", at: $caller } }
    if $second.object == null { return { kind: "refused", class: 6, fault: "nowhere", at: $second } }
    if $second.overlap { return { kind: "refused", class: 5, fault: "overlap", at: $second } }
    if (symbols sdl-device $second $device_in $modules) { return { kind: "refused", class: 5, fault: "device", at: $second } }
    if not ($second.functions | is-empty) {
        if not ($symbols.console_updates | flatten | any {|n| $n in $second.functions }) { return { kind: "console", class: 0, fault: "", at: null } }
        let later = ($frames | skip 2)
        if $device_in == "executable" {
            let later_held = ($later | where {|f| $f.object == 0 } | each {|f| symbols sdl-held $f } | get -o 0)
            if $later_held != null { return $later_held }
        }
        for f in $later {
            if $f.overlap { return { kind: "refused", class: 5, fault: "overlap", at: $f } }
            if (symbols sdl-device $f $device_in $modules) { return { kind: "upload", class: 0, fault: "", at: null } }
        }
        return { kind: "refused", class: 6, fault: "cut_short", at: $second }
    }
    if $second.object == 0 and $device_in == "module" and $executable != null and $executable.state == "read" and $executable.console {
        return { kind: "console", class: 0, fault: "", at: null }
    }
    { kind: "refused", class: 6, fault: "unanswered", at: $second }
}

# A make_current read from its chain's decision and its own size call's gap
def sdl-judge [decision: record, size_us: oneof<int, nothing>]: nothing -> record<kind: string, class: int, fault: string, at: oneof<record, nothing>, evidence: string> {
    if $decision.kind == "render" { return ($decision | insert evidence "anchor") }
    if $decision.kind != "timed" { return ($decision | insert evidence "") }
    if $size_us != null and $size_us < $size_window_us { return { kind: "render", class: 0, fault: "", at: null, evidence: "timing" } }
    { kind: "refused", class: 5, fault: (if $size_us == null { "anchor" } else { "late_size" }), at: $decision.at, evidence: "" }
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
        "overlap" => $"a frame's return address lies in the symbols of more than one function, which no reading tells apart, in ($path)",
        "inlined" => "a make_current comes from sdl2_gl_refresh or sdl2_gl_redraw, into which a render and the scanout path's flush can both be inlined, a front end the probe does not support",
        "late_size" => $"a make_current's immediate caller resolves in no symbol, and ($table); its size call comes past the 2 ms a render read by timing allows",
        "front_end" => "a make_current comes from a front-end function the probe does not model",
        "device" => "an upload's second frame is the device's own code, which the probe does not model",
        "absent" => "an upload's chain ends at its immediate caller",
        "nowhere" => "an upload's second frame lies in no object",
        "unanswered" => $"an upload's second frame resolves in no table, and ($table)",
        "cut_short" => "a console update has no device frame after it",
        _ => $fault,
    }
}

# A refusal's faults from the make_currents one class refused, each counted
def sdl-faults [cases: list<any>, objects: table]: nothing -> table<fault: string, held: int, unit: string, examples: list<string>> {
    let described = ($cases | each {|c| $c | insert text (sdl-fault-text $c.fault $c.at $objects) })
    $described | get text | uniq | each {|text|
        let group = ($described | where text == $text)
        {
            fault: $text,
            held: ($group | length),
            unit: "make_current",
            examples: ($group | each {|c| sdl-frame-text $c.at } | uniq | first 4),
        }
    }
}

# A log stamp, the shim's seconds and six digits, as whole microseconds
def stamp-us [stamp: string]: nothing -> int {
    let parts = ($stamp | split row ".")
    ($parts.0 | into int) * 1000000 + ($parts.1 | into int)
}

# Every render's gap to the window's size call, and each one past the window
def render-gaps [events: table]: nothing -> record<renders: int, by_timing: int, sizeless: int, median_ms: oneof<float, nothing>, p99_ms: oneof<float, nothing>, max_ms: oneof<float, nothing>, past: list<record<line: int, ms: float>>> {
    let renders = ($events | where kind == "render")
    let sized = ($renders | where size_us != null)
    let gaps = ($sized | get size_us | sort)
    let n = ($gaps | length)
    let rank = {|q: float| ($gaps | get ((([($q * $n | math ceil) 1] | math max) - 1) | into int)) / 1000.0 }
    {
        renders: ($renders | length),
        by_timing: ($renders | where evidence == "timing" | length),
        sizeless: (($renders | length) - $n),
        median_ms: (if $n == 0 { null } else { do $rank 0.5 }),
        p99_ms: (if $n < 100 { null } else { do $rank 0.99 }),
        max_ms: (if $n == 0 { null } else { ($gaps | last) / 1000.0 }),
        past: ($sized | where {|e| $e.size_us > $size_window_us } | each {|e| { line: ($e.at + 1), ms: ($e.size_us / 1000.0) } }),
    }
}

# The shim's log with each make_current read by where it came from
export def main [log: path, --tables: string = ""]: nothing -> record<objects: table, virtio_gpu_in: string, events: table, gaps: record> {
    let c = (sdl-classified $log $tables)
    { objects: $c.objects, virtio_gpu_in: $c.virtio_gpu_in, events: ($c.events | reject key), gaps: (render-gaps $c.events) }
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
    let sources = ($resolved.objects | reduce --fold {} {|o, all| $all | insert ($o.index | into string) $o.source })
    let nexts = ($events | skip 1 | each {|n| { name: $n.name, stamp: $n.stamp } } | append [null])
    let keyed = ($events | zip $nexts | each {|p|
        let e = $p.0
        let next = $p.1
        let gap = (if $e.name == "make_current" and $next != null and $next.name == "size" { (stamp-us $next.stamp) - (stamp-us $e.stamp) } else { null })
        $e | insert key (sdl-chain-key $e.frames) | insert size_us $gap
    })
    let made = ($keyed | where name == "make_current")
    let chains = ($made | uniq-by key)
    let decisions = ($chains | reduce --fold {} {|e, all| $all | insert $e.key (sdl-decide $e.frames $resolved.virtio_gpu_in $modules $executable $sources) })
    let refused = ($made | each {|e|
        let j = (sdl-judge ($decisions | get $e.key) $e.size_us)
        if $j.kind == "refused" { $j }
    })
    for class in [2 3 4 5 6] {
        let cases = ($refused | where class == $class)
        if not ($cases | is-empty) { error make {msg: (refusal sdl-refusal (sdl-faults $cases $resolved.objects))} }
    }
    let named = ($chains | reduce --fold {} {|e, all| $all | insert $e.key ($e.frames | each {|f| sdl-frame-name $f } | str join " < ") })
    let read = ($keyed | each {|e|
        if $e.name != "make_current" { $e | merge { kind: $e.name, callers: "", evidence: "" } } else {
            let j = (sdl-judge ($decisions | get $e.key) $e.size_us)
            $e | merge { kind: $j.kind, callers: ($named | get $e.key), evidence: $j.evidence }
        }
    })
    let decided_chains = ($chains | each {|e| { key: $e.key } | merge ($decisions | get $e.key | reject at) })
    { objects: $resolved.objects, virtio_gpu_in: $resolved.virtio_gpu_in, events: $read, decisions: $decided_chains, tables: $resolved.tables, process: $resolved.process, nonce: $resolved.nonce }
}
