# probe's integration test: the SDK's sdl probe, `jab sdl-resolve` and
# `jab sdl-report`, held to shim logs of the test's own over objects of
# its own, and then the shim's capture held to a binary of its own. The
# objects are assembled by the workspace's toolchain, the prefix from the
# flags stamp beside this program's image, from test/fixture.S: a shared
# object whose functions carry the SDL front end's, the console's, and
# the virtio-gpu device's names, sized and spaced exactly, with a gap, an
# alias pair, and a .cold part, the hidden ones in .symtab alone; a copy
# stripped by the toolchain's strip, .dynsym left; and copies named
# hw-display-virtio-gpu.so and ui-sdl.so for a modular QEMU's modules.
# Every address comes from nm's reading of the fixture, which is checked
# first. Each log is read against its own assertion: the shim's own
# leading frames, one and two, dropped; a flip's upload, the console's
# own, a switch, a redraw, and a render whose callers resolve nowhere; a
# log ending in a fragment its run's end cut short, read without it; a
# return address at a function's end, an address in the gap, a .cold
# part, and an alias; a modular QEMU's flip, its executable's exception,
# and its front end read through .dynsym; lines the shim does not write,
# among them that fragment given its newline, and the notices the shim
# writes as it stops a run, each refused ahead of the rest; every refusal
# in turn, and the first refusal alone when two are held; a valid zero;
# and the record's fields. Then the shim preloaded into a harness built
# non-PIE, its premises checked before its reading: an EXEC whose first
# segment sits above 0, its make_current's frames one or two in the shim's
# library and the next in the harness, which sdl-resolve must name as the
# harness's own function. Linux only, as the probe is.
use ../../../sdk/nu/jab.nu
use std/assert

# An address as the shim writes one, in lowercase hex.
def hex [n: int]: nothing -> string { $n | format number | get lowerhex | str replace "0x" "" }

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
def write-log [
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
def symbols-of [file: path, flags: list<string>]: nothing -> table<name: string, type: string, value: int, size: int> {
    let read = (^nm -P -t x --defined-only ...$flags $file | complete)
    assert equal $read.exit_code 0 $"fixture: nm reads ($file | path basename): ($read.stderr)"
    $read.stdout | lines | parse --regex '^(?P<name>\S+) (?P<type>\S) (?P<value>[0-9a-f]+) (?P<size>[0-9a-f]+)$' | into int --radix 16 value size
}

# What the report made of a log: the counts that tell its make_currents
# apart, or the refusal it raised.
def reading [log: path]: nothing -> record<flips: int, console: int, switches: int, renders: int, refused: string> {
    try {
        let r = (jab sdl-report $log)
        { flips: $r.flips, console: $r.other_uploads, switches: $r.switches, renders: $r.renders, refused: "" }
    } catch {|e|
        { flips: 0, console: 0, switches: 0, renders: 0, refused: $e.msg }
    }
}

# What sdl-resolve made of a log's first make_current: how many of the
# shim's frames it dropped, the functions of each frame after them, where
# the device's code reads, and each object's table by index.
def first-made [log: path]: nothing -> record<shim_frames: int, functions: list<any>, virtio_gpu_in: string, sources: record> {
    try {
        let read = (jab sdl-resolve $log)
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

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    if $nu.os-info.name != "linux" {
        print "probe: the sdl probe preloads a library into QEMU, which is Linux only, so nothing is tested here"
        return
    }
    let here = ($env.FILE_PWD | path join ".." | path expand)
    let ws = ($here | path join ".." ".." | path expand)
    let dir = ($out | path join "fixture")
    jab retire $dir
    mkdir $dir

    # the fixture, by the workspace's toolchain
    let prefix = (open --raw ($image | path dirname | path join "flags") | lines | first | split row " " | last)
    let object = ($dir | path join "fixture.o")
    let fixture = ($dir | path join "fixture.so")
    let stripped = ($dir | path join "stripped.so")
    let assembled = (^$"($prefix)as" ($env.FILE_PWD | path join "fixture.S") -o $object | complete)
    assert equal $assembled.exit_code 0 $"fixture: the toolchain assembles it: ($assembled.stderr)"
    let linked = (^$"($prefix)ld" -shared $object -o $fixture | complete)
    assert equal $linked.exit_code 0 $"fixture: the toolchain links it as a shared object: ($linked.stderr)"
    let strip = (^$"($prefix)strip" --strip-all $fixture -o $stripped | complete)
    assert equal $strip.exit_code 0 $"fixture: the toolchain strips a copy: ($strip.stderr)"
    let module = ($dir | path join "hw-display-virtio-gpu.so")
    let front = ($dir | path join "ui-sdl.so")
    cp $fixture $module
    cp $stripped $front
    let text = ($dir | path join "text.so")
    "a text file, no object\n" | save -f $text

    # nm reads the fixture's names back: every function once and sized, the
    # hidden ones in .symtab alone, the rest in the stripped copy's .dynsym
    let exported = ["sdl2_gl_update" "sdl2_gl_switch" "qemu_console_update" "dpy_gfx_update" "qemu_console_register_listener" "displaychangelistener_gfx_switch" "virtio_gpu_simple_process_cmd" "virtio_gpu_process_cmdq" "virtio_gpu_ctrl_bh" "gpu_ctrl_entry"]
    let hidden = ["sdl2_gl_render_surface" "qemu_console_update_full" "dpy_gfx_update_full" "virtio_gpu_reset_bh" "virtio_gpu_process_cmdq.cold"]
    let full = (symbols-of $fixture [])
    let dynamic = (symbols-of $stripped ["-D"] | get name)
    for name in ($exported ++ $hidden) {
        let found = ($full | where name == $name)
        assert equal ($found | length) 1 $"fixture: nm reads ($name) back once: ($found | to nuon)"
        assert (($found | first | get size) > 0) $"fixture: ($name) carries a size"
    }
    for name in $exported { assert ($name in $dynamic) $"fixture: ($name) is exported, in the stripped copy's .dynsym" }
    for name in $hidden { assert ($name not-in $dynamic) $"fixture: ($name) is hidden, in .symtab alone" }
    let symbol = {|name: string| $full | where name == $name | first }
    let update = (do $symbol "qemu_console_update")
    let update_end = ($update.value + $update.size)
    let next = ($full | where {|s| $s.value >= $update_end } | sort-by value | first)
    assert (($next.value - $update_end) >= 0x20) $"fixture: a gap follows qemu_console_update, the next function ($next.name) at ($next.value | format number | get lowerhex)"
    let gap = ($update_end + 0x10)

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
    let render_chain = (do $made [$shim "?+7f0000001000" "?+7f0000002000"])
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

    # decided logs, each read as one make_current, some with sdl-resolve's
    # reading of a frame checked beside it
    let decided = [
        { name: "shim_one", what: "the console's own", read: $console, lines: ($exe ++ [$registration_chain]), resolve: { shim_frames: 1, frame: 0, functions: ["sdl2_gl_update"] } }
        { name: "shim_two", what: "the console's own", read: $console, lines: ($exe ++ [(do $made [$shim "1+1100" (do $inside 0 "sdl2_gl_update") (do $inside 0 "qemu_console_register_listener")])]), resolve: { shim_frames: 2, frame: 0, functions: ["sdl2_gl_update"] } }
        { name: "flip", what: "a flip's upload", read: $flip, lines: ($exe ++ [$flip_chain]) }
        { name: "fragment_accepted", what: "a flip's upload, the fragment after it left out", read: $flip, lines: ($exe ++ [$flip_chain { fragment: "make_current 1+" }]) }
        { name: "registration", what: "the console's own", read: $console, lines: ($exe ++ [$registration_chain]) }
        { name: "switch", what: "a switch", read: $switched, lines: ($exe ++ [$switch_chain]) }
        { name: "redraw", what: "the console's own", read: $console, lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 0 "displaychangelistener_gfx_switch") (do $inside 0 "virtio_gpu_reset_bh")])]) }
        { name: "render_nowhere", what: "a render", read: $rendered, lines: ($exe ++ [$render_chain "size"]) }
        { name: "function_end", what: "a flip's upload", read: $flip, lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $ending 0 "qemu_console_update") (do $inside 0 "virtio_gpu_simple_process_cmd")])]), resolve: { frame: 1, functions: ["qemu_console_update"] } }
        { name: "gap", what: "a flip's upload", read: $flip, lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 0 "qemu_console_update") (do $at 0 $gap) (do $inside 0 "virtio_gpu_simple_process_cmd")])]), resolve: { frame: 2, functions: [] } }
        { name: "cold", what: "a flip's upload", read: $flip, lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 0 "qemu_console_update") (do $inside 0 "virtio_gpu_process_cmdq.cold")])]), resolve: { frame: 2, functions: ["virtio_gpu_process_cmdq"] } }
        { name: "alias", what: "a flip's upload", read: $flip, lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 0 "qemu_console_update") (do $inside 0 "gpu_ctrl_entry")])]), resolve: { frame: 2, functions: ["gpu_ctrl_entry" "virtio_gpu_ctrl_bh"] } }
        { name: "module_flip", what: "a flip's upload", read: $flip, lines: ($modular ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 0 "dpy_gfx_update") (do $inside 3 "virtio_gpu_simple_process_cmd")])]), resolve: { virtio_gpu_in: "module" } }
        { name: "module_exception", what: "the console's own", read: $console, lines: ($modular ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $at 0 $gap)])]) }
        { name: "module_dynsym", what: "a flip's upload", read: $flip, lines: ($modular ++ [(do $made [$shim (do $inside 2 "sdl2_gl_update") (do $inside 0 "dpy_gfx_update") (do $inside 3 "virtio_gpu_process_cmdq")])]), resolve: { frame: 0, functions: ["sdl2_gl_update"], source: { object: "2", is: "dynsym" } } }
    ]
    for c in $decided {
        let file = (do $log $c.name $c.lines)
        assert equal (reading $file) $c.read $"($c.name): read as ($c.what)"
        let wanted = ($c | get -o resolve)
        if $wanted != null {
            let got = (first-made $file)
            if ($wanted | get -o shim_frames) != null { assert equal $got.shim_frames $wanted.shim_frames $"($c.name): sdl-resolve drops ($wanted.shim_frames) of the shim's frames" }
            if ($wanted | get -o frame) != null { assert equal ($got.functions | get -o $wanted.frame) $wanted.functions $"($c.name): sdl-resolve gives frame ($wanted.frame) as [($wanted.functions | str join ', ')]" }
            if ($wanted | get -o virtio_gpu_in) != null { assert equal $got.virtio_gpu_in $wanted.virtio_gpu_in $"($c.name): the device's code reads in the ($wanted.virtio_gpu_in)" }
            if ($wanted | get -o source) != null { assert equal ($got.sources | get -o $wanted.source.object) $wanted.source.is $"($c.name): object ($wanted.source.object)'s table is its ($wanted.source.is)" }
        }
    }

    # refused logs, each naming its fault, in the order the probe checks:
    # the lines the shim writes and its stop notices first, the third line
    # here stamped 1792000000.030000
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
        { name: "unmodelled", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_render_surface")])]), says: "a make_current comes from a front-end function the probe does not model" }
        { name: "device_after", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 0 "virtio_gpu_simple_process_cmd")])]), says: "an upload's second frame is the device's own code" }
        { name: "exe_unresolved", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $at 0 $gap)])]), says: "an upload's second frame resolves in no table" }
        { name: "absent", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update")])]), says: "an upload's chain ends at its immediate caller" }
        { name: "nowhere", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") "?+7f0000003000"])]), says: "an upload's second frame lies in no object" }
        { name: "other_object", lines: ($modular ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 2 "sdl2_gl_render_surface")])]), says: $"an upload's second frame resolves in no table, and ($front) keeps no symbol table" }
        { name: "exe_lacking", lines: ($stripped_exe ++ [(do $made [$shim (do $inside 3 "sdl2_gl_update") (do $at 0 $gap)])]), says: $"an upload's second frame resolves in no table, and the executable at ($stripped) keeps no symbol table" }
        { name: "cut_short", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $inside 0 "qemu_console_update") (do $inside 0 "qemu_console_register_listener")])]), says: "a console update has no device frame after it: 1 make_current" }
        { name: "first_refusal", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_update") (do $at 0 $gap)]) (do $made [$shim (do $inside 0 "qemu_console_update")])]), says: "a make_current's immediate caller is not in the SDL front end", unsaid: "resolves in no table" }
    ]
    for c in $refusals {
        let file = (do $log $c.name $c.lines)
        let accepted = ($c | get -o newline_of)
        if $accepted != null {
            let completed = (open --raw $file | into binary | decode)
            let cut = (open --raw ($dir | path join $"($accepted).log") | into binary | decode)
            assert equal $completed ($cut + "\n") $"($c.name): the log is ($accepted)'s with its last newline added and nothing else"
        }
        let said = (if ($c | get -o path) == null { reading $file } else { with-env { PATH: $c.path } { reading $file } })
        assert (($said.refused | str starts-with "the sdl probe refuses the log: ") and ($said.refused | str contains $c.says)) $"($c.name): refused, saying ($c.says): ($said | to nuon)"
        let unsaid = ($c | get -o unsaid | default "")
        if $unsaid != "" { assert (not ($said.refused | str contains $unsaid)) $"($c.name): the first refusal alone, ($unsaid) unsaid: ($said.refused)" }
    }

    # a valid zero: renders and the console's own alone make no flip
    let zero = (do $log "valid_zero" ($exe ++ [$render_chain "size" $registration_chain]))
    assert equal (reading $zero) ($none | update console 1 | update renders 1) "valid_zero: a render and the console's own, no flip"

    # the record's fields, over one of each
    let mixed = (do $log "record" ($exe ++ [$flip_chain $registration_chain $switch_chain $render_chain "size"]))
    let record = (try { jab sdl-report $mixed } catch {|e| { refused: $e.msg } })
    assert equal ($record | get -o run.binary) $fixture $"record: run.binary is the executable's path: ($record | to nuon)"
    assert equal ($record | get -o virtio_gpu_in) "executable" "record: virtio_gpu_in reads executable"
    assert equal ($record | select -o flips switches other_uploads renders) { flips: 1, switches: 1, other_uploads: 1, renders: 1 } "record: one flip, one switch, one of the console's own, one render"
    assert equal ($record | get -o upload_callers) [{ callers: "sdl2_gl_update < qemu_console_update < virtio_gpu_simple_process_cmd < virtio_gpu_process_cmdq", count: 1 }] "record: upload_callers by function, the immediate caller first"
    assert equal ($record | get -o other_upload_callers) [{ callers: "sdl2_gl_update < qemu_console_register_listener", count: 1 }] "record: other_upload_callers holds the console's own"
    assert equal ($record | get -o switch_callers) [{ callers: "sdl2_gl_switch < displaychangelistener_gfx_switch", count: 1 }] "record: switch_callers holds the switch"
    assert equal ($record | get -o render_callers) [{ callers: "?+7f0000001000 < ?+7f0000002000", count: 1 }] "record: render_callers by address where nothing resolves"

    # the shim's capture, on a binary built non-PIE: the premises first
    let library = (jab shim-build $ws "jabshim_sdl")
    let harness = (jab shim-build $ws "jabshim_sdl_harness" --static)
    let header = (^readelf -h $harness | complete | get stdout)
    assert ($header =~ 'Type:\s+EXEC') $"harness: an EXEC: ($header | lines | where {|l| $l =~ 'Type:' } | str join '')"
    let loads = (^readelf -lW $harness | complete | get stdout | lines | parse --regex '^\s+LOAD\s+0x[0-9a-f]+\s+0x(?P<vaddr>[0-9a-f]+)' | into int --radix 16 vaddr)
    assert ((not ($loads | is-empty)) and (($loads | first | get vaddr) > 0)) $"harness: its first segment sits above 0: ($loads | to nuon)"
    let harness_log = ($dir | path join "harness.log")
    let ran = (with-env { LD_PRELOAD: $library, SDL_SHIM_LOG: $harness_log } { ^$harness | complete })
    assert equal $ran.exit_code 0 $"harness: it runs under the shim: ($ran.stdout)($ran.stderr)"
    let read = (jab sdl-resolve $harness_log)
    let captured = ($read.events | where name == "make_current")
    assert equal ($captured | length) 1 $"harness: the shim logs its one make_current: ($read.events | to nuon)"
    let caller = ($captured | first | get frames | get -o 0)
    assert ($captured | first | get shim_frames | $in in [1 2]) $"harness: its frames start with one or two in the shim's library: ($captured | first | to nuon)"
    assert equal ($caller | get -o object) 0 $"harness: the frame after the shim's lies in the harness, object 0: ($caller | to nuon)"
    assert equal ($caller | get -o functions) ["harness_make_current"] $"harness: sdl-resolve names the harness's own function as the immediate caller: ($caller | to nuon)"
    print "probe: ok"
}
