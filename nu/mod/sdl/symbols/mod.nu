use (path self ../log)

# The console's rectangle update in QEMU's two families, 11.1.2's then 10.2.2's
export const console_updates = [
    ["qemu_console_update" "qemu_console_update_full"]
    ["dpy_gfx_update" "dpy_gfx_update_full"]
]

# How a modular QEMU's virtio-gpu module's file name starts
export const device_module = "hw-display-virtio-gpu"

# An object's table left unread, with the state that kept it so
def sdl-unread [state: string, why: string]: nothing -> record {
    { state: $state, why: $why, source: "", starts: [], ends: [], reach: [], names: [], console: false, nm: "" }
}

# A file's inode, size, and mtime in ns as `ls -l` gives them now; null if none
export def sdl-stat [path: string]: nothing -> oneof<record<inode: int, size: int, mtime: int>, nothing> {
    let now = (try { ls -l $path | get -o 0 } catch { null })
    if $now == null { return null }
    { inode: $now.inode, size: ($now.size | into int), mtime: ($now.modified | into int) }
}

# An object's sized function symbols as nm reads them, with its table's state
def sdl-table [object: record, nm: bool]: nothing -> record {
    if $object.inode == null or $object.size == null or $object.mtime == null { return (sdl-unread "no_file" "") }
    if not $nm { return (sdl-unread "nm_absent" "") }
    if $object.index == 0 and ($object.path | str ends-with " (deleted)") { return (sdl-unread "deleted" "") }
    let now = (try { ls -l $object.path | get -o 0 } catch { null })
    if $now == null { return (sdl-unread "changed" "no file is there now") }
    if $now.inode != $object.inode or ($now.size | into int) != $object.size or ($now.modified | into int) != $object.mtime {
        return (sdl-unread "changed" "its inode, size, or modification time is not its line's")
    }
    let full = (^nm -P -t x --defined-only $object.path | complete)
    let dynamic = ($full.exit_code == 0 and ($full.stdout | str trim) == "" and ($full.stderr | str contains "no symbols"))
    let run = (if $dynamic { ^nm -P -t x --defined-only -D $object.path | complete } else { $full })
    if $run.exit_code != 0 { return (sdl-unread "unreadable" ($run.stderr | str trim | split row $"($object.path): " | last)) }
    let source = (if not $dynamic { "symtab" } else if ($run.stdout | str trim) == "" { "none" } else { "dynsym" })
    sdl-table-from $run.stdout $source
}

# A symbol table from nm's POSIX text, as sdl-table reads it
def sdl-table-from [text: string, source: string]: nothing -> record {
    let functions = ($text | lines
        | parse --regex '^(?P<name>\S+) (?P<type>[tTwW]) (?P<value>[0-9a-f]+) (?P<size>[0-9a-f]+)$'
        | into int --radix 16 value size
        | where size > 0
        | str replace --regex '^([^.]+)\..*$' '$1' name
        | sort-by value)
    let spans = ($functions | generate {|f, most|
        let end = ($f.value + $f.size)
        let reach = (if $end > $most { $end } else { $most })
        { out: { end: $end, reach: $reach }, next: $reach }
    } 0)
    let names = ($functions | get name)
    let console = ($console_updates | any {|family| $family | all {|n| $n in $names } })
    { state: "read", why: "", source: $source, starts: ($functions | get value), ends: ($spans | get end), reach: ($spans | get reach), names: $names, console: $console, nm: $text }
}

# A needed object's table out of a bundle, taken only at its manifest's SHA-256
def sdl-bundled-table [object: record, manifest: record, bundle: path]: nothing -> record {
    let entry = ($manifest.objects | where index == $object.index | get -o 0)
    if $entry == null { return (sdl-unread "unbundled" "the manifest has no entry for it") }
    if $entry.state != "read" { return (sdl-unread $entry.state $entry.why) }
    let file = ($bundle | path join $entry.table)
    if not ($file | path exists) { return (sdl-unread "unbundled" "its table is not in the bundle") }
    let bytes = (open --raw $file | into binary)
    if ($bytes | hash sha256) != $entry.table_sha256 { return (sdl-unread "unbundled" "its table's bytes are not those the manifest names") }
    sdl-table-from ($bytes | decode) $entry.source
}

# The functions of a table holding an address, aliases included, and whether
# symbols of more than one extent hold it
def sdl-functions-at [table: record, address: int]: nothing -> record<functions: list<string>, overlap: bool> {
    let starts = $table.starts
    let ends = $table.ends
    let reach = $table.reach
    let names = $table.names
    mut low = 0
    mut high = ($starts | length)
    while $low < $high {
        let middle = (($low + $high) // 2)
        if ($starts | get $middle) <= $address { $low = $middle + 1 } else { $high = $middle }
    }
    mut at = $low - 1
    mut found: list<string> = []
    mut extents: list<string> = []
    while $at >= 0 and ($reach | get $at) > $address {
        if ($ends | get $at) > $address {
            $found = ($found ++ [($names | get $at)])
            $extents = ($extents ++ [$"($starts | get $at)-($ends | get $at)"])
        }
        $at -= 1
    }
    { functions: ($found | uniq | sort), overlap: (($extents | uniq | length) > 1) }
}

# The shim's log with its make_currents' frames resolved to their functions
export def resolve [log: path, --every, --tables: string = ""]: nothing -> record<objects: table, virtio_gpu_in: string, events: table> {
    sdl-resolved $log $every $tables | reject tables process nonce
}

# sdl-resolve's reading, with each object's table whole and the run's lines
export def sdl-resolved [log: path, every: bool, bundle: string]: nothing -> record<objects: table, virtio_gpu_in: string, events: table, tables: record, process: oneof<int, nothing>, nonce: oneof<string, nothing>> {
    let read = (log $log)
    let modules = ($read.objects | where {|o| $o.path | path basename | str starts-with $device_module } | get index)
    let device_in = (if ($modules | is-empty) { "executable" } else { "module" })
    let made = ($read.events | where name == "make_current")
    let needed = (if $every {
        $made | each {|e| $e.frames | each {|f| $f.object } } | flatten | uniq
    } else {
        let callers = ($made | each {|e| $e.frames | first 2 | each {|f| $f.object } } | flatten)
        let executable = (if $device_in == "executable" and (not ($made | is-empty)) { [0] } else { [] })
        $callers ++ $executable | uniq
    })
    let manifest = (if $bundle == "" { null } else { open --raw ($bundle | path join "bundle.nuon") | into binary | decode | from nuon })
    let nm = ($manifest == null and (which nm | where type == "external" | is-not-empty))
    let tables = ($read.objects | reduce --fold {} {|o, all|
        let table = (if $o.index not-in $needed { sdl-unread "unread" "" } else if $manifest == null { sdl-table $o $nm } else { sdl-bundled-table $o $manifest $bundle })
        $all | insert ($o.index | into string) $table
    })
    let pairs = ($made | each {|e| $e.frames } | flatten | where object != null | uniq-by object hex)
    let found = ($pairs | reduce --fold {} {|f, all|
        let table = ($tables | get ($f.object | into string))
        let held = (if $table.state == "read" { sdl-functions-at $table ($f.address - 1) } else { { functions: [], overlap: false } })
        $all | insert $"($f.object)+($f.hex)" $held
    })
    let objects = ($read.objects | each {|o|
        let table = ($tables | get ($o.index | into string))
        $o | merge { file: ($o.path | path basename), state: $table.state, source: $table.source, functions: ($table.names | length), console: $table.console, why: $table.why }
    })
    let places = ($objects | reduce --fold {} {|o, all| $all | insert ($o.index | into string) { file: $o.file, state: $o.state } })
    let events = ($read.events | each {|e|
        if $e.name != "make_current" { $e } else {
            $e | update frames ($e.frames | each {|f|
                if $f.object == null { $f | merge { file: "", state: "no_object", functions: [], overlap: false } } else {
                    let place = ($places | get ($f.object | into string))
                    let held = ($found | get $"($f.object)+($f.hex)")
                    $f | merge { file: $place.file, state: $place.state, functions: $held.functions, overlap: $held.overlap }
                }
            })
        }
    })
    { objects: $objects, virtio_gpu_in: $device_in, events: $events, tables: $tables, process: $read.process, nonce: $read.nonce }
}

# The refusal a frame's object holds before its symbols can answer, or null
export def sdl-held [frame: record]: nothing -> oneof<record, nothing> {
    match $frame.state {
        "nm_absent" => ({ kind: "refused", class: 2, fault: "nm_absent", at: $frame }),
        "deleted" => ({ kind: "refused", class: 3, fault: "deleted", at: $frame }),
        "changed" => ({ kind: "refused", class: 3, fault: "changed", at: $frame }),
        "unbundled" => ({ kind: "refused", class: 3, fault: "unbundled", at: $frame }),
        "unreadable" => ({ kind: "refused", class: 4, fault: "unreadable", at: $frame }),
        _ => null,
    }
}

# Whether a frame lies in the virtio-gpu device's code
export def sdl-device [frame: record, device_in: string, modules: list<int>]: nothing -> bool {
    if $device_in == "module" { $frame.object in $modules } else { $frame.object == 0 and ($frame.functions | any {|n| $n | str starts-with "virtio_gpu_" }) }
}
