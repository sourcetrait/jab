use ../../../nu/mod/sdl
use std/assert

# An address as the shim writes one, in lowercase hex.
export def hex [n: int]: nothing -> string { $n | format number | get lowerhex | str replace "0x" "" }

# A file's object-table line as the shim writes it, from the file as it
# stands: `later` moves its modification time on, `named` writes another
# path in its place.
def object-line [index: int, file: path, --later: int = 0, --named: string = ""]: nothing -> string {
    let f = (ls -l $file | first)
    let path = (if $named == "" { $file } else { $named })
    $"object ($index) ($f.inode) ($f.size | into int) (($f.modified | into int) + $later) ($path)"
}

# A shim log of the test's own: each line stamped 10 ms after the last,
# a window-size call half a millisecond after its make_current, so the
# timing rule reads that make_current as a render. A `written` line goes
# in as given, its stamp its own, and a closing `fragment` is stamped as
# the next line and written with no newline after it, a write the run's
# end cut short.
export def write-log [
    file: path,
    lines: list<oneof<string, record<written: string>, record<fragment: string>>>,
]: nothing -> nothing {
    mut us = 1792000000000000
    mut out: list<string> = []
    mut tail = ""
    for l in $lines {
        let given = ($l | describe | str starts-with "record")
        if $given and ($l | get -o written) != null {
            $out = ($out ++ [$l.written])
            continue
        }
        let event = (if $given { $l.fragment } else { $l })
        $us += (if $event == "size" { 500 } else { 10000 })
        let fraction = ($us mod 1000000 | into string | fill --alignment right --character "0" --width 6)
        let line = $"($us // 1000000).($fraction) ($event)"
        if $given { $tail = $line } else { $out = ($out ++ [$line]) }
    }
    ($out | str join "\n") + "\n" + $tail | save -f $file
}

# A file's defined symbols that carry a size, as nm's POSIX form gives
# them; `flags` holds -D for the dynamic table.
export def symbols-of [file: path, flags: list<string>]: nothing -> table<name: string, type: string, value: int, size: int> {
    let read = (^nm -P -t x --defined-only ...$flags $file | complete)
    assert equal $read.exit_code 0 $"fixture: nm reads ($file | path basename): ($read.stderr)"
    $read.stdout | lines | parse --regex '^(?P<name>\S+) (?P<type>\S) (?P<value>[0-9a-f]+) (?P<size>[0-9a-f]+)$' | update value {|r| $"0x($r.value)" | into int } | update size {|r| $"0x($r.size)" | into int }
}

# What the report made of a log: the counts that tell its make_currents
# apart, or the refusal it raised.
export def reading [log: path]: nothing -> record<flips: int, console: int, switches: int, renders: int, refused: string> {
    try {
        let r = (sdl report $log)
        { flips: $r.flips, console: $r.other_uploads, switches: $r.switches, renders: $r.renders, refused: "" }
    } catch {|e|
        { flips: 0, console: 0, switches: 0, renders: 0, refused: $e.msg }
    }
}

# What sdl-resolve made of a log's first make_current: how many of the
# shim's frames it dropped, the functions of each frame after them, where
# the device's code reads, and each object's table by index.
export def first-made [log: path]: nothing -> record<shim_frames: int, functions: list<any>, virtio_gpu_in: string, sources: record> {
    try {
        let read = (sdl resolve $log)
        let made = ($read.events | where name == "make_current" | first)
        {
            shim_frames: $made.shim_frames,
            functions: ($made.frames | each {|f| $f.functions }),
            virtio_gpu_in: $read.virtio_gpu_in,
            sources: ($read.objects | reduce --fold {} {|o, all| $all | insert ($o.index | into string) $o.source }),
        }
    } catch {|e|
        { shim_frames: -1, functions: [], virtio_gpu_in: $"raised: ($e.msg)", sources: {} }
    }
}

# The shim logs' frames, chains, writer, and readings, from the fixture's symbols
export def frames [symbol: closure, fixture: path, front: path, module: path, dir: path]: nothing -> record {
    # frames: a function's at a return address 4 bytes in, at its end, or
    # an address outright, each in an object of the table by index
    let inside = {|index: int, name: string| $"($index)+(hex ((do $symbol $name).value + 4))" }
    let ending = {|index: int, name: string| let s = (do $symbol $name); $"($index)+(hex ($s.value + $s.size))" }
    let at = {|index: int, address: int| $"($index)+(hex $address)" }
    let made = {|frames: list<string>| $"make_current ($frames | str join ' ')" }
    let shim = "1+1000"
    let shim_line = "object 1 - - - libjabshim_sdl.so"
    let exe = [(object-line 0 $fixture) $shim_line]
    let modular = ($exe ++ [(object-line 2 $front) (object-line 3 $module)])
    let flip_chain = (do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 0 "qemu_console_update") (do $inside 0 "virtio_gpu_simple_process_cmd") (do $inside 0 "virtio_gpu_process_cmdq")])
    let registration_chain = (do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 0 "qemu_console_register_listener")])
    let switch_chain = (do $made [$shim (do $inside 0 "sdl2_gl_switch") (do $inside 0 "displaychangelistener_gfx_switch")])
    let render_chain = (do $made [$shim (do $inside 0 "sdl2_gl_render_surface") (do $inside 0 "sdl2_gl_refresh")])
    let front_render = (do $made [$shim (do $inside 2 "sdl2_gl_render_surface") (do $inside 0 "sdl2_gl_refresh")])
    let log = {|name: string, lines: list<oneof<string, record<written: string>, record<fragment: string>>>|
        let file = ($dir | path join $"($name).log")
        write-log $file $lines
        $file
    }
    let none = { flips: 0, console: 0, switches: 0, renders: 0, refused: "" }
    let flip = ($none | update flips 1)
    let console = ($none | update console 1)
    let switched = ($none | update switches 1)
    let rendered = ($none | update renders 1)
    { inside: $inside, ending: $ending, at: $at, made: $made, shim: $shim, shim_line: $shim_line, exe: $exe, modular: $modular, flip_chain: $flip_chain, registration_chain: $registration_chain, switch_chain: $switch_chain, render_chain: $render_chain, front_render: $front_render, log: $log, none: $none, flip: $flip, console: $console, switched: $switched, rendered: $rendered }
}

# The decided logs, each read as one make_current, some resolved besides
export def decided [shim_logs: record, gap: int]: nothing -> list<any> {
    let console = $shim_logs.console
    let exe = $shim_logs.exe
    let registration_chain = $shim_logs.registration_chain
    let made = $shim_logs.made
    let shim = $shim_logs.shim
    let inside = $shim_logs.inside
    let flip = $shim_logs.flip
    let flip_chain = $shim_logs.flip_chain
    let switched = $shim_logs.switched
    let switch_chain = $shim_logs.switch_chain
    let rendered = $shim_logs.rendered
    let render_chain = $shim_logs.render_chain
    let modular = $shim_logs.modular
    let front_render = $shim_logs.front_render
    let ending = $shim_logs.ending
    let at = $shim_logs.at
    let decided = [
        { name: "shim_one", what: "the console's own", read: $console, lines: ($exe ++ [$registration_chain]), resolve: { shim_frames: 1, frame: 0, functions: ["sdl2_gl_update"] } }
        { name: "shim_two", what: "the console's own", read: $console, lines: ($exe ++ [(do $made [$shim "1+1100" (do $inside 0 "sdl2_gl_update") (do $inside 0 "qemu_console_register_listener")])]), resolve: { shim_frames: 2, frame: 0, functions: ["sdl2_gl_update"] } }
        { name: "flip", what: "a flip's upload", read: $flip, lines: ($exe ++ [$flip_chain]) }
        { name: "fragment_accepted", what: "a flip's upload, the fragment after it left out", read: $flip, lines: ($exe ++ [$flip_chain { fragment: "make_current 1+" }]) }
        { name: "registration", what: "the console's own", read: $console, lines: ($exe ++ [$registration_chain]) }
        { name: "switch", what: "a switch", read: $switched, lines: ($exe ++ [$switch_chain]) }
        { name: "redraw", what: "the console's own", read: $console, lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 0 "displaychangelistener_gfx_switch") (do $inside 0 "virtio_gpu_reset_bh")])]) }
        { name: "render_anchor", what: "a render by its anchor", read: $rendered, lines: ($exe ++ [$render_chain "size"]) }
        { name: "render_late", what: "a render by its anchor, its size call 3 ms late", read: $rendered, lines: ($exe ++ [$render_chain { written: "1792000000.033000 size" }]) }
        { name: "render_timed", what: "a render read by timing through a front end's dynamic symbols alone", read: $rendered, lines: ($modular ++ [$front_render "size"]), resolve: { frame: 0, functions: [], source: { object: "2", is: "dynsym" } } }
        { name: "function_end", what: "a flip's upload", read: $flip, lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $ending 0 "qemu_console_update") (do $inside 0 "virtio_gpu_simple_process_cmd")])]), resolve: { frame: 1, functions: ["qemu_console_update"] } }
        { name: "gap", what: "a flip's upload", read: $flip, lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 0 "qemu_console_update") (do $at 0 $gap) (do $inside 0 "virtio_gpu_simple_process_cmd")])]), resolve: { frame: 2, functions: [] } }
        { name: "cold", what: "a flip's upload", read: $flip, lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 0 "qemu_console_update") (do $inside 0 "virtio_gpu_process_cmdq.cold")])]), resolve: { frame: 2, functions: ["virtio_gpu_process_cmdq"] } }
        { name: "alias", what: "a flip's upload", read: $flip, lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 0 "qemu_console_update") (do $inside 0 "gpu_ctrl_entry")])]), resolve: { frame: 2, functions: ["gpu_ctrl_entry" "virtio_gpu_ctrl_bh"] } }
        { name: "module_flip", what: "a flip's upload", read: $flip, lines: ($modular ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 0 "dpy_gfx_update") (do $inside 3 "virtio_gpu_simple_process_cmd")])]), resolve: { virtio_gpu_in: "module" } }
        { name: "module_exception", what: "the console's own", read: $console, lines: ($modular ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $at 0 $gap)])]) }
        { name: "module_dynsym", what: "a flip's upload", read: $flip, lines: ($modular ++ [(do $made [$shim (do $inside 2 "sdl2_gl_update") (do $inside 0 "dpy_gfx_update") (do $inside 3 "virtio_gpu_process_cmdq")])]), resolve: { frame: 0, functions: ["sdl2_gl_update"], source: { object: "2", is: "dynsym" } } }
    ]
    $decided
}

# The refused logs, each naming its fault, in the order the probe checks
export def refusals [shim_logs: record, gap: int, fixture: path, stripped: path, front: path, module: path, text: path, gone: path]: nothing -> list<any> {
    let shim_line = $shim_logs.shim_line
    let exe = $shim_logs.exe
    let flip_chain = $shim_logs.flip_chain
    let made = $shim_logs.made
    let shim = $shim_logs.shim
    let inside = $shim_logs.inside
    let registration_chain = $shim_logs.registration_chain
    let modular = $shim_logs.modular
    let front_render = $shim_logs.front_render
    let render_chain = $shim_logs.render_chain
    let at = $shim_logs.at
    let stripped_exe = [(object-line 0 $stripped) $shim_line (object-line 2 $front) (object-line 3 $module)]
    let unwritten = "the log has a line the shim does not write: 1 line, among them"
    let fixture_stat = (ls -l $fixture | first)
    let mixed_line = $"object 0 ($fixture_stat.inode) - ($fixture_stat.modified | into int) ($fixture)"
    let refusals = [
        { name: "timestamp_malformed", lines: ($exe ++ [{ written: $"1792000000.03x000 ($flip_chain)" }]), says: $"($unwritten) line 3: 1792000000.03x000 make_current " }
        { name: "event_unknown", lines: ($exe ++ [($flip_chain | str replace "make_current" "make_currenx")]), says: $"($unwritten) line 3: 1792000000.030000 make_currenx " }
        { name: "fragment_complete", lines: ($exe ++ [$flip_chain "make_current 1+"]), newline_of: "fragment_accepted", says: $"($unwritten) line 4: 1792000000.040000 make_current 1+" }
        { name: "object_mixed", lines: [$mixed_line $shim_line $flip_chain], says: $"($unwritten) line 1: 1792000000.010000 object 0 " }
        { name: "stopped_libsdl", lines: ($exe ++ [$flip_chain "libSDL2 not found"]), says: "the shim stopped the run: libSDL2 not found: 1 line" }
        { name: "stopped_symbol", lines: ($exe ++ [$flip_chain "symbol not found"]), says: "the shim stopped the run: symbol not found: 1 line" }
        { name: "no_table", lines: [(do $made [$shim (do $inside 0 "sdl2_gl_update")])], says: "the log has no object table: 1 make_current" }
        { name: "table_line", lines: ["object 0 x y z table.so" $shim_line $registration_chain], says: $"($unwritten) line 1: 1792000000.010000 object 0 x y z table.so" }
        { name: "index_twice", lines: ($exe ++ [(object-line 0 $module) $registration_chain]), says: "the object table gives an index twice" }
        { name: "frame_written", lines: ($exe ++ [(do $made [$shim "0+zz"])]), says: $"($unwritten) line 3: 1792000000.030000 make_current 1+1000 0+zz" }
        { name: "absent_index", lines: ($exe ++ [(do $made [$shim "7+10"])]), says: "a frame names an object the table has no line for ahead of it: 1 make_current, among them 7+10" }
        { name: "outside", lines: ($exe ++ [(do $made [(do $inside 0 "sdl2_gl_update") (do $inside 0 "qemu_console_register_listener")])]), says: "a make_current's frames do not start in the shim's own library" }
        { name: "nm_absent", path: [], lines: ($exe ++ [$flip_chain]), says: "binutils' nm is not on PATH" }
        { name: "changed", lines: [(object-line 0 $fixture --later 1) $shim_line $flip_chain], says: $"($fixture) is not the file its line in the object table names" }
        { name: "deleted", lines: [(object-line 0 $fixture --named $"($fixture) \(deleted)") $shim_line $flip_chain], says: $"the executable at ($fixture) was deleted after it started" }
        { name: "unreadable", lines: [(object-line 0 $text) $shim_line (do $made [$shim "0+10"])], says: $"nm cannot read ($text)" }
        { name: "anchor_console", lines: ($exe ++ [(do $made [$shim (do $inside 0 "qemu_console_update") (do $inside 0 "virtio_gpu_simple_process_cmd")])]), says: "a make_current's immediate caller is not in the SDL front end" }
        { name: "anchor_stripped", lines: [(object-line 0 $stripped) $shim_line (do $made [$shim (do $inside 0 "sdl2_gl_render_surface")])], says: $"the executable at ($stripped) keeps no symbol table" }
        { name: "unmodelled", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_scanout_flush")]) "size"]), says: "a make_current comes from a front-end function the probe does not model" }
        { name: "render_nowhere", lines: ($exe ++ [(do $made [$shim "?+7f0000001000" "?+7f0000002000"]) "size"]), says: "a make_current's immediate caller is not in the SDL front end, and it lies in no object" }
        { name: "inlined_refresh", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_refresh")]) "size"]), says: "a make_current comes from sdl2_gl_refresh or sdl2_gl_redraw" }
        { name: "inlined_redraw", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_redraw")]) "size"]), says: "a make_current comes from sdl2_gl_refresh or sdl2_gl_redraw" }
        { name: "overlap", lines: ($exe ++ [(do $made [$shim (do $inside 0 "overlap_inner")]) "size"]), says: $"a frame's return address lies in the symbols of more than one function, which no reading tells apart, in ($fixture)" }
        { name: "timed_late", lines: ($modular ++ [$front_render { written: "1792000000.053000 size" }]), says: "its size call comes past the 2 ms a render read by timing allows" }
        { name: "render_changed", lines: [(object-line 0 $fixture --later 1) $shim_line $render_chain "size"], says: $"($fixture) is not the file its line in the object table names" }
        { name: "render_unreadable", lines: [(object-line 0 $text) $shim_line (do $made [$shim "0+10"]) "size"], says: $"nm cannot read ($text)" }
        { name: "render_gone", lines: [$"object 0 1 100 1000 ($gone)" $shim_line $render_chain "size"], says: $"($gone) is not the file its line in the object table names" }
        { name: "render_caller_unreadable", lines: [(object-line 0 $fixture) $shim_line (object-line 2 $text) (do $made [$shim (do $inside 0 "sdl2_gl_render_surface") (do $at 2 16)]) "size"], says: $"nm cannot read ($text)" }
        { name: "render_caller_changed", lines: [(object-line 0 $fixture) $shim_line (object-line 2 $front --later 1) (do $made [$shim (do $inside 0 "sdl2_gl_render_surface") (do $at 2 16)]) "size"], says: $"($front) is not the file its line in the object table names" }
        { name: "device_after", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 0 "virtio_gpu_simple_process_cmd")])]), says: "an upload's second frame is the device's own code" }
        { name: "exe_unresolved", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $at 0 $gap)])]), says: "an upload's second frame resolves in no table" }
        { name: "absent", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update")])]), says: "an upload's chain ends at its immediate caller" }
        { name: "nowhere", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") "?+7f0000003000"])]), says: "an upload's second frame lies in no object" }
        { name: "other_object", lines: ($modular ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 2 "sdl2_gl_render_surface")])]), says: $"an upload's second frame resolves in no table, and ($front) keeps no symbol table" }
        { name: "exe_lacking", lines: ($stripped_exe ++ [(do $made [$shim (do $inside 3 "sdl2_gl_update") (do $at 0 $gap)])]), says: $"an upload's second frame resolves in no table, and the executable at ($stripped) keeps no symbol table" }
        { name: "cut_short", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 0 "qemu_console_update") (do $inside 0 "qemu_console_register_listener")])]), says: "a console update has no device frame after it: 1 make_current" }
        { name: "first_refusal", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $at 0 $gap)]) (do $made [$shim (do $inside 0 "qemu_console_update")])]), says: "a make_current's immediate caller is not in the SDL front end", unsaid: "resolves in no table" }
    ]
    $refusals
}

# The run's lines refused, each given twice, malformed, or out of its place
export def run-refusals [shim_logs: record, run_lines: list<string>, nonce_text: string]: nothing -> list<any> {
    let exe = $shim_logs.exe
    let flip_chain = $shim_logs.flip_chain
    let run_refusals = [
        { name: "process_twice", lines: ($exe ++ ["process 4242" "process 4243" $flip_chain]), says: "the log gives its process line twice: 2 lines" }
        { name: "nonce_twice", lines: ($exe ++ $run_lines ++ [$"nonce ($nonce_text)" $flip_chain]), says: "the log gives its nonce line twice: 2 lines" }
        { name: "process_malformed", lines: ($exe ++ ["process 42x" $flip_chain]), says: "the log's process line is malformed" }
        { name: "nonce_malformed", lines: ($exe ++ ["process 4242" "nonce 123456789ABCDEF0" $flip_chain]), says: "the log's nonce line is malformed" }
        { name: "nonce_zero", lines: ($exe ++ ["process 4242" "nonce 0000000000000000" $flip_chain]), says: "the log's nonce line is malformed" }
        { name: "nonce_ahead", lines: ($exe ++ [$"nonce ($nonce_text)" "process 4242" $flip_chain]), says: "the log's nonce line comes with no process line ahead of it" }
        { name: "process_late", lines: ($exe ++ [$flip_chain "process 4242"]), says: "the log's process line is out of its place, the first event" }
        { name: "nonce_late", lines: ($exe ++ ["process 4242" $flip_chain $"nonce ($nonce_text)"]), says: "the log's nonce line is out of its place, the second event" }
    ]
    $run_refusals
}
