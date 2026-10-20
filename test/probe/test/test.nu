# probe's integration test: the SDK's sdl probe, `sdl resolve` and
# `sdl report`, held to shim logs of the test's own over objects of
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
# own, a switch, a redraw, and a render by its anchor, its size call on
# time or 3 ms late with the gap reported; a render read by timing
# through a front end's dynamic symbols alone, labelled so; a log ending
# in a fragment its run's end cut short, read without it; a return
# address at a function's end, an address in the gap, a .cold part, and
# an alias; a modular QEMU's flip, its executable's exception, and its
# front end read through .dynsym; lines the shim does not write, among
# them that fragment given its newline, and the notices the shim writes
# as it stops a run, each refused ahead of the rest; every refusal in
# turn, a render in no object, the inlined renders, a return address in
# two functions' symbols, a render read by timing with its size call
# late, and a render's table gone, unreadable, or changed among them, and
# the first refusal alone when two are held; a valid zero; and the
# record's fields. The run's lines, the process and the nonce,
# read apart, and each refused by name given twice, malformed, or out of
# its place; a probing launch's machine as plan makes it, no QEMU run: its
# port and its sends as its caller asks, the nonce handed in reaching the
# shim and the identity, plan minting none and a launch alone one; the
# probe's own plan in each profile, the nonce's frame, and a QEMU without
# the flush trace refused; the build's fields the probe's identity and
# walk's wrapper write, and a replay stream refused by each of its rules;
# the present sequence's rules and K's, K held
# to the all-pairs check over a generated set; the pairing over synthetic
# runs, each read admitted, ambiguous, or refused by its rule or by its
# bracket, the stalls named and the uploads placed in their calls. A
# paired capture bundled, the fixture relinked at its path so the raw log
# is refused as changed, and the bundle admitted by its check's replay;
# then each stage's negatives, copies of the bundle altered and rehashed
# where they must pass the inventory, each refused at its own stage, the
# exchanged streams of two captures by the nonce. Then the shim preloaded
# into a harness built non-PIE, its premises checked before its reading:
# an EXEC whose first segment sits above 0, its make_current's frames one
# or two in the shim's library and the next in the harness, which
# sdl-resolve must name as the harness's own function. Linux only, as the
# probe is.
use ../../../nu/mod/nonce
use ../../../nu/mod/present
use ../../../nu/mod/target
use ../../../nu/mod/sdl
use ../../../nu/mod/tool
use ../../../nu/mod/launch
use ../../../nu/mod/probe
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
    $read.stdout | lines | parse --regex '^(?P<name>\S+) (?P<type>\S) (?P<value>[0-9a-f]+) (?P<size>[0-9a-f]+)$' | update value {|r| $"0x($r.value)" | into int } | update size {|r| $"0x($r.size)" | into int }
}

# What the report made of a log: the counts that tell its make_currents
# apart, or the refusal it raised.
def reading [log: path]: nothing -> record<flips: int, console: int, switches: int, renders: int, refused: string> {
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
def first-made [log: path]: nothing -> record<shim_frames: int, functions: list<any>, virtio_gpu_in: string, sources: record> {
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

# What a bundle's check made of a bundle: the stage that refused it, with
# its words, or stage 0 and its reading where it was admitted.
def checked [bundle: path, guest: closure]: nothing -> record<stage: int, refused: string, result: any> {
    try {
        { stage: 0, refused: "", result: (sdl bundle-check $bundle --guest $guest) }
    } catch {|e|
        { stage: ($e.msg | parse --regex 'refused at stage (?P<n>\d+)' | get -o 0.n | default "-1" | into int), refused: $e.msg, result: null }
    }
}

# A bundle's manifest rewritten with each file it lists that lies there,
# its SHA-256 and size as they are now, and each object's table_sha256 its
# table's, so a negative past the inventory reaches its own stage.
def rehash [bundle: path]: nothing -> nothing {
    let file = ($bundle | path join "bundle.nuon")
    let m = (open --raw $file | into binary | decode | from nuon)
    let files = ($m.files | where {|f| $bundle | path join $f.path | path exists } | each {|f|
        let p = ($bundle | path join $f.path)
        { path: $f.path, sha256: (open --raw $p | hash sha256), size: (ls -D $p | get 0.size | into int) }
    })
    let objects = ($m.objects | each {|o| if $o.table == null { $o } else { $o | update table_sha256 ($files | where path == $o.table | get -o 0.sha256) } })
    $m | update files $files | update objects $objects | to nuon --indent 1 | save --raw -f $file
}

# A text in a file replaced, held to occur there exactly once first, so a
# negative is the fault it names and no other.
def swap-once [file: path, find: string, put: string]: nothing -> nothing {
    let text = (open --raw $file | into binary | decode)
    let n = (($text | split row $find | length) - 1)
    assert equal $n 1 $"negative: ($find) occurs once in ($file | path basename), not ($n) times"
    $text | str replace $find $put | save --raw -f $file
}

# The one line of a file holding a text taken out.
def drop-line [file: path, holding: string]: nothing -> nothing {
    let lines = (open --raw $file | into binary | decode | lines)
    let kept = ($lines | where {|l| not ($l | str contains $holding) })
    assert equal (($lines | length) - ($kept | length)) 1 $"negative: one line of ($file | path basename) holds ($holding)"
    ($kept | str join "\n") + "\n" | save --raw -f $file
}

# A NUON file rewritten through `change`.
def nuon-edit [file: path, change: closure]: nothing -> nothing {
    let value = (open --raw $file | into binary | decode | from nuon)
    do $change $value | to nuon --indent 1 | save --raw -f $file
}

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    if $nu.os-info.name != "linux" {
        print "probe: the sdl probe preloads a library into QEMU, which is Linux only, so nothing is tested here"
        return
    }
    let here = ($env.FILE_PWD | path join ".." | path expand)
    let ws = ($here | path join ".." ".." | path expand)
    let dir = ($out | path join "fixture")
    target retire $dir
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
    let gone = ($dir | path join "gone.so")

    # nm reads the fixture's names back: every function once and sized, the
    # hidden ones in .symtab alone, the rest in the stripped copy's .dynsym
    let exported = ["sdl2_gl_update" "sdl2_gl_switch" "qemu_console_update" "dpy_gfx_update" "qemu_console_register_listener" "displaychangelistener_gfx_switch" "virtio_gpu_simple_process_cmd" "virtio_gpu_process_cmdq" "virtio_gpu_ctrl_bh" "gpu_ctrl_entry"]
    let hidden = ["sdl2_gl_render_surface" "qemu_console_update_full" "dpy_gfx_update_full" "virtio_gpu_reset_bh" "virtio_gpu_process_cmdq.cold" "sdl2_gl_refresh" "sdl2_gl_redraw" "sdl2_gl_scanout_flush" "overlap_outer" "overlap_inner"]
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

    # the renders' gaps to their size calls and their evidence: the late
    # render's 3 ms reported past the 2 ms window with its line, and the one
    # read by timing labelled so
    let late = (sdl classify ($dir | path join "render_late.log"))
    assert equal $late.gaps { renders: 1, by_timing: 0, sizeless: 0, median_ms: 3.0, p99_ms: null, max_ms: 3.0, past: [{ line: 3, ms: 3.0 }] } $"render_late: its gap reported past the window with its line: ($late.gaps | to nuon)"
    let timed = (sdl classify ($dir | path join "render_timed.log"))
    assert equal ($timed.events | where kind == "render" | get evidence) ["timing"] $"render_timed: the render labelled read by timing: ($timed.events | where kind == 'render' | to nuon)"
    assert equal [$timed.gaps.renders $timed.gaps.by_timing] [1 1] $"render_timed: the gaps count it read by timing: ($timed.gaps | to nuon)"

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
        { name: "unmodelled", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_scanout_flush")]) "size"]), says: "a make_current comes from a front-end function the probe does not model" }
        { name: "render_nowhere", lines: ($exe ++ [(do $made [$shim "?+7f0000001000" "?+7f0000002000"]) "size"]), says: "a make_current's immediate caller is not in the SDL front end, and it lies in no object" }
        { name: "inlined_refresh", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_refresh")]) "size"]), says: "a make_current comes from sdl2_gl_refresh or sdl2_gl_redraw" }
        { name: "inlined_redraw", lines: ($exe ++ [(do $made [$shim (do $inside 0 "sdl2_gl_redraw")]) "size"]), says: "a make_current comes from sdl2_gl_refresh or sdl2_gl_redraw" }
        { name: "overlap", lines: ($exe ++ [(do $made [$shim (do $inside 0 "overlap_inner")]) "size"]), says: $"a frame's return address lies in the symbols of more than one function, which no reading tells apart, in ($fixture)" }
        { name: "timed_late", lines: ($modular ++ [$front_render { written: "1792000000.053000 size" }]), says: "its size call comes past the 2 ms a render read by timing allows" }
        { name: "render_changed", lines: [(object-line 0 $fixture --later 1) $shim_line $render_chain "size"], says: $"($fixture) is not the file its line in the object table names" }
        { name: "render_unreadable", lines: [(object-line 0 $text) $shim_line (do $made [$shim "0+10"]) "size"], says: $"nm cannot read ($text)" }
        { name: "render_gone", lines: [$"object 0 1 100 1000 ($gone)" $shim_line $render_chain "size"], says: $"($gone) is not the file its line in the object table names" }
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
    let record = (try { sdl report $mixed } catch {|e| { refused: $e.msg } })
    assert equal ($record | get -o run.binary) $fixture $"record: run.binary is the executable's path: ($record | to nuon)"
    assert equal ($record | get -o virtio_gpu_in) "executable" "record: virtio_gpu_in reads executable"
    assert equal ($record | select -o flips switches other_uploads renders) { flips: 1, switches: 1, other_uploads: 1, renders: 1 } "record: one flip, one switch, one of the console's own, one render"
    assert equal ($record | get -o upload_callers) [{ callers: "sdl2_gl_update < qemu_console_update < virtio_gpu_simple_process_cmd < virtio_gpu_process_cmdq", count: 1 }] "record: upload_callers by function, the immediate caller first"
    assert equal ($record | get -o other_upload_callers) [{ callers: "sdl2_gl_update < qemu_console_register_listener", count: 1 }] "record: other_upload_callers holds the console's own"
    assert equal ($record | get -o switch_callers) [{ callers: "sdl2_gl_switch < displaychangelistener_gfx_switch", count: 1 }] "record: switch_callers holds the switch"
    assert equal ($record | get -o render_callers) [{ callers: "sdl2_gl_render_surface < sdl2_gl_refresh", count: 1 }] "record: render_callers by function, the render's anchor first"
    assert equal ($record | get -o render_gaps) { renders: 1, by_timing: 0, sizeless: 0, median_ms: 0.5, p99_ms: null, max_ms: 0.5, past: [] } $"record: render_gaps, the one render's size call half a millisecond on: ($record | get -o render_gaps | to nuon)"

    # the run's lines, the shim's first two events, its process and then
    # its nonce: read apart, each refused by name given twice, malformed,
    # or out of its place; a log with neither read as it always was
    let nonce = 0x1234_5678_9abc_def0
    let nonce_text = (nonce hex $nonce)
    assert equal $nonce_text "123456789abcdef0" "nonce_hex: a nonce as sixteen lowercase hex digits"
    let run_lines = ["process 4242" $"nonce ($nonce_text)"]
    let lined = (do $log "lined" ($exe ++ $run_lines ++ [$flip_chain]))
    assert equal (reading $lined) $flip "lined: the run's lines beside a flip's upload, read as one"
    assert equal (sdl log $lined | select process nonce) { process: 4242, nonce: $nonce_text } "lined: the log's process and nonce read apart"
    assert equal (sdl log (do $log "unlined" ($exe ++ [$flip_chain])) | select process nonce) { process: null, nonce: null } "unlined: a log with neither line, written before them, reads none"
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
    for c in $run_refusals {
        let said = (reading (do $log $c.name $c.lines))
        assert (($said.refused | str starts-with "the sdl probe refuses the log: ") and ($said.refused | str contains $c.says)) $"($c.name): refused, saying ($c.says): ($said | to nuon)"
    }

    # the plumbing, no QEMU run: a probing launch's machine as plan makes
    # it, the port and the sends as its caller asks and never for itself,
    # the nonce handed in reaching the shim and the identity
    let plumbing = ($dir | path join "plumbing")
    mkdir $plumbing
    let probe_log = ($plumbing | path join "sdl.log")
    let generic = (launch plan --kernel $kernel --image $image --out ($plumbing | path join "generic") --sdl-probe $probe_log --capture-nonce $nonce)
    assert equal $generic.api_in "" "plumbing_generic: a probing launch asking nothing carries no API port"
    assert ($generic.sends | is-empty) "plumbing_generic: and nothing to send"
    assert equal $generic.profile "generic" "plumbing_generic: a probe naming no profile is generic"
    assert equal $generic.window "sdl,gl=on" "plumbing_generic: under sdl,gl=on"
    assert equal ($generic.env | get -o SDL_SHIM_LOG) $probe_log "plumbing_generic: the shim logging where the probe asks"
    assert ($generic.env | get -o LD_PRELOAD | default "" | str ends-with "libjabshim_sdl.so") $"plumbing_generic: the shim preloaded: ($generic.env | to nuon)"
    assert equal ($generic.capture | select api sends) { api: false, sends: [] } "plumbing_generic: its identity records no port and nothing sent"
    assert equal [$generic.capture_nonce ($generic.env | get -o SDL_SHIM_NONCE) $generic.capture.capture_nonce] [$nonce $nonce_text $nonce] "plumbing_nonce: the nonce handed in is the plan's, the shim's environment's in hex, and the identity's"
    let asked_api = (launch plan --kernel $kernel --image $image --out ($plumbing | path join "api") --api --sdl-probe $probe_log --capture-nonce $nonce)
    assert ($asked_api.api_in != "") "plumbing_api: a generic probing launch with --api carries the port"
    assert ($asked_api.sends | is-empty) "plumbing_api: and sends nothing, no nonce frame among its sends"
    assert equal ($asked_api.capture | select api sends) { api: true, sends: [] } "plumbing_api: its identity records the port and nothing sent"
    let frame = 0x[49 f0 de bc 9a 78 56 34 12]
    let asked_send = (launch plan --kernel $kernel --image $image --out ($plumbing | path join "send") --send [[at bytes]; [1sec $frame]] --sdl-probe $probe_log --capture-nonce $nonce)
    assert ($asked_send.api_in != "") "plumbing_send: a caller's --send puts the port on"
    assert equal ($asked_send.sends | each {|s| $s.bytes }) [$frame] "plumbing_send: exactly the caller's entries to send, none prepended"
    assert equal $asked_send.capture.sends [{ at: 1.0, length: 9, sha256: ($frame | hash sha256) }] "plumbing_send: its identity records each entry's time, length, and SHA-256"
    let paired = (launch plan --kernel $kernel --image $image --out ($plumbing | path join "paired") --profile paired --capture-nonce $nonce --send [[at bytes]; [200ms $frame]])
    assert equal [$paired.profile ($paired.api_in != "") ($paired.sends | each {|s| $s.bytes }) $paired.capture.capture_nonce] ["paired" true [$frame] $nonce] "plumbing_paired: a paired run's port, the nonce's frame its caller sends, and its nonce"
    let unminted = (launch plan --kernel $kernel --image $image --out ($plumbing | path join "unminted") --sdl-probe $probe_log)
    assert equal [$unminted.capture_nonce ("SDL_SHIM_NONCE" in ($unminted.env | columns))] [null false] "plumbing_unminted: plan given no nonce mints none and hands the shim none"
    let unnonced = (try { launch plan --kernel $kernel --image $image --out ($plumbing | path join "unnonced") --profile paired | ignore; "" } catch {|e| $e.msg })
    assert ($unnonced | str contains "--profile paired needs the run's --capture-nonce") $"plumbing_unnonced: a paired run given no nonce is refused: ($unnonced)"
    let minted = (nonce mint 0 true)
    assert ($minted >= 1) $"plumbing_minted: a probing launch given none mints one, 1 or more: ($minted)"
    assert equal (nonce mint $nonce true) $nonce "plumbing_given: a probing launch given one mints none"
    assert equal (nonce mint 0 false) 0 "plumbing_unprobed: a launch neither probing nor given one claims none"

    # the probe's own plan, its profile, its port, and its sends: generic
    # with nothing asked, with --api, and with --send; paired where the
    # build sets the manifest's `paired`, the nonce's frame first; a
    # manifest naming `paired` with a build that does not set it generic
    let pairing = { name: "walk", paired: "cadence" }
    let wnon = (0x[57 4e 4f 4e 00 00 00 00] ++ ($nonce | into binary --endian little))
    assert equal (probe wnon-frame $nonce) $wnon "probe_frame: WNON, a zero word, the nonce as a le64"
    let zero_frame = (try { probe wnon-frame 0 | ignore; "" } catch {|e| $e.msg })
    assert ($zero_frame | str contains "a capture nonce is 1 to 2^63 - 1") $"probe_frame_zero: a nonce of 0 has no frame: ($zero_frame)"
    let plans = [
        { name: "probe_generic", manifest: {}, names: [], api: false, send: 0x[], wanted: { profile: "generic", api: false, sends: [] } }
        { name: "probe_api", manifest: {}, names: [], api: true, send: 0x[], wanted: { profile: "generic", api: true, sends: [] } }
        { name: "probe_send", manifest: {}, names: [], api: false, send: $frame, wanted: { profile: "generic", api: true, sends: [{ at: 200ms, bytes: $frame }] } }
        { name: "probe_paired", manifest: $pairing, names: ["CADENCE" "TIMING"], api: false, send: 0x[], wanted: { profile: "paired", api: true, sends: [{ at: 200ms, bytes: $wnon }] } }
        { name: "probe_paired_send", manifest: $pairing, names: ["CADENCE" "REPLAY"], api: false, send: $frame, wanted: { profile: "paired", api: true, sends: [{ at: 200ms, bytes: $wnon } { at: 200ms, bytes: $frame }] } }
        { name: "probe_unset", manifest: $pairing, names: [], api: false, send: 0x[], wanted: { profile: "generic", api: false, sends: [] } }
    ]
    for p in $plans {
        assert equal (probe plan $p.manifest $p.names $nonce --api=$p.api --send $p.send) $p.wanted $"($p.name): the probe's profile, port, and sends"
    }
    let untraced = (try { probe trace-args "true" ($plumbing | path join "trace.log") | ignore; "" } catch {|e| $e.msg })
    assert ($untraced | str contains "lists no trace event virtio_gpu_cmd_res_flush or virtio_gpu_cmd_set_scanout") $"probe_untraced: a QEMU listing neither trace event is refused: ($untraced)"

    # the build's fields, the one producer of the probe's identity and
    # walk's wrapper: the flags beside the image, the CADENCE symbols among
    # them in the header's order, the loop order by PREPARE, the files'
    # SHA-256, a REPLAY build's stream with its frames and bound; and each
    # refusal by name
    let fields_dir = ($dir | path join "fields")
    let toolchain = "-march=rva23u64 riscv64-unknown-linux-gnu-"
    let build_dir = {|name: string, flags: string|
        let d = ($fields_dir | path join $name)
        mkdir $d
        $"($flags)\n" | save --raw ($d | path join "flags")
        0x[6a 61 62] | save --raw ($d | path join "walk.jab")
        0x[6b 65 72 6e] | save --raw ($d | path join "jab.elf")
        $d
    }
    let timed_flags = $"-I ../../sdk/src --defsym CADENCE=1 --defsym DEBUG=1 --defsym PREPARE=1 --defsym TIMING=1 ($toolchain)"
    let timed_dir = (do $build_dir "timed" $timed_flags)
    let timed = (probe build-fields "example/walk" ($timed_dir | path join "walk.jab") ($timed_dir | path join "jab.elf"))
    assert equal $timed.cadence [CADENCE TIMING PREPARE] "fields_cadence: the CADENCE symbols its flags carry, in the header's order"
    assert equal $timed.workload { program: "example/walk", order: "prepare" } "fields_order: the program, and PREPARE's loop order"
    assert equal [$timed.image.sha256 $timed.kernel.sha256] [(0x[6a 61 62] | hash sha256) (0x[6b 65 72 6e] | hash sha256)] "fields_files: the image's and the kernel's SHA-256"
    assert equal $timed.flags $timed_flags "fields_flags: the flags file's first line"
    assert equal $timed.replay null "fields_unreplayed: no stream for a build without REPLAY"
    let plain_dir = (do $build_dir "plain" $"-I ../../sdk/src --defsym DEBUG=1 ($toolchain)")
    let plain = (probe build-fields "test/probe" ($plain_dir | path join "walk.jab") ($plain_dir | path join "jab.elf"))
    assert equal [$plain.cadence $plain.workload.order] [[] "await"] "fields_plain: no CADENCE symbol, the await order"
    let replayed_dir = (do $build_dir "replayed" $"-I ../../sdk/src --defsym CADENCE=1 --defsym REPLAY=1 --defsym TIMING=1 ($toolchain)")
    let word = {|v: int, n: int| $v | into binary --endian little | bytes at 0..<$n }
    let stream = ([(do $word 0x4c505257 4) (do $word 1 4) (do $word 3 4) (do $word 0 4) (do $word 7 8) (do $word 0 8) (0..<32 | each { 0x[00] } | bytes collect) (do $word 166666 4) (do $word 166667 4) (do $word 1000000 4)] | bytes collect)
    let stream_file = ($fields_dir | path join "stream.wrpl")
    $stream | save --raw $stream_file
    let replayed = (probe build-fields "example/walk" ($replayed_dir | path join "walk.jab") ($replayed_dir | path join "jab.elf") --replay $stream_file)
    assert equal $replayed.replay { file: $stream_file, sha256: ($stream | hash sha256), frames: 3, window_s: 0.1333333, bound: 61 } "fields_replay: the stream's file, SHA-256, frames, dt summed, and bound"
    let refused = {|run: closure| try { do $run | ignore; "" } catch {|e| $e.msg } }
    let refusals = [
        { name: "fields_no_flags", run: {|| probe build-fields "example/walk" ($fields_dir | path join "stream.wrpl") ($timed_dir | path join "jab.elf") }, says: "the image has no build flags beside it" }
        { name: "fields_replay_unsent", run: {|| probe build-fields "example/walk" ($replayed_dir | path join "walk.jab") ($replayed_dir | path join "jab.elf") }, says: "the image is a REPLAY build and no replay stream was given" }
        { name: "fields_replay_unwanted", run: {|| probe build-fields "example/walk" ($timed_dir | path join "walk.jab") ($timed_dir | path join "jab.elf") --replay $stream_file }, says: "a replay stream was given and the image is no REPLAY build" }
    ]
    for c in $refusals {
        let said = (do $refused $c.run)
        assert ($said | str contains $c.says) $"($c.name): refused, saying ($c.says): ($said)"
    }
    let stream_cases = [
        { name: "stream_magic", bytes: ((do $word 0x4c505258 4) ++ ($stream | bytes at 4..)), says: "the replay stream's magic is not WRPL" }
        { name: "stream_short", bytes: ($stream | bytes at 0..<60), says: "the replay stream is shorter than its header" }
        { name: "stream_frames", bytes: ($stream | bytes at 0..<72), says: "holds 72 bytes where its 3 frames need 76" }
        { name: "stream_none", bytes: (($stream | bytes at 0..<8) ++ (do $word 0 4) ++ ($stream | bytes at 12..<64)), says: "the replay stream's frames are 1 to 8192, not 0" }
    ]
    for c in $stream_cases {
        let file = ($fields_dir | path join $"($c.name).wrpl")
        $c.bytes | save --raw $file
        let said = (do $refused {|| probe replay-stream $file })
        assert ($said | str contains $c.says) $"($c.name): refused, saying ($c.says): ($said)"
    }

    # the bundle: a paired capture bundled where it was taken, the fixture
    # then relinked at its path, a new inode, so the raw log is refused as
    # changed while the bundle's check admits it by replay; each negative a
    # copy of the bundle altered, rehashed where it must pass the
    # inventory, refused at its own stage
    let bundles = ($dir | path join "bundles")
    mkdir $bundles
    let guest = {|api_out: path| open --raw $api_out | into binary | into int --endian little }
    let capture = {|name: string, run_nonce: int, pid: int|
        let probe = ($bundles | path join $"($name)_probe")
        mkdir $probe
        let sdl = ($probe | path join "sdl.log")
        write-log $sdl ($exe ++ [$"process ($pid)" $"nonce (nonce hex $run_nonce)" $flip_chain $registration_chain $switch_chain $render_chain "size"])
        let upload = (sdl log $sdl | get events | where name == "make_current" | first)
        let flushed = (($upload.ts - 0.002) * 1e9 | into int | into datetime | format date "%Y-%m-%dT%H:%M:%S%.6fZ")
        $"($flushed) virtio_gpu_cmd_res_flush res 0x1, x 0, y 0, w 1920, h 1080\n" | save --raw ($probe | path join "trace.log")
        $run_nonce | into binary --endian little | save --raw ($probe | path join "api.out")
        { profile: "paired", capture_nonce: $run_nonce, qemu_pid: $pid, sdl_log: $sdl, shim: "", window: "sdl,gl=on", api: true, sends: [] } | to nuon | save --raw ($probe | path join "identity.nuon")
        let bundle = ($bundles | path join $name)
        let manifest = (sdl bundle $probe $bundle)
        # the fixture object 0 is no QEMU, so its manifest names the one the
        # trace bracket rests on
        nuon-edit ($bundle | path join "bundle.nuon") {|m| $m | update host.qemu.version "QEMU emulator version 11.1.2" }
        { probe: $probe, bundle: $bundle, manifest: $manifest }
    }
    let first = (do $capture "paired_a" $nonce 4242)
    let second = (do $capture "paired_b" ($nonce + 1) 4343)
    assert equal [$first.manifest.profile ($first.manifest.files | get path)] ["paired" ["api.out" "classified.nuon" "identity.nuon" "sdl.log" "tables/0.nm" "trace.log"]] $"bundle_made: a paired bundle of the log, its table, the classification, and the run's files: ($first.manifest.files | get path)"
    assert equal ($first.manifest.objects | where index == 0 | get 0 | select state sha256) { state: "read", sha256: (open --raw $fixture | hash sha256) } "bundle_made: the executable read, its SHA-256 its file's"
    let inode = (ls -l $fixture | get 0.inode)
    let relinked = (^$"($prefix)ld" -shared $object -o $"($fixture).next" | complete)
    assert equal $relinked.exit_code 0 $"bundle_rebuilt: the toolchain relinks the fixture: ($relinked.stderr)"
    mv -f $"($fixture).next" $fixture
    assert ((ls -l $fixture | get 0.inode) != $inode) "bundle_rebuilt: the fixture relinked at its path is a new inode"
    let raw = (reading ($first.probe | path join "sdl.log"))
    assert ($raw.refused | str contains "is not the file its line in the object table names") $"bundle_raw_changed: the raw log is refused as changed: ($raw | to nuon)"
    let admitted = (checked $first.bundle $guest)
    assert equal $admitted.stage 0 $"bundle_admitted: the check admits the bundle by replay: ($admitted.refused)"
    assert equal [$admitted.result.profile $admitted.result.run.process $admitted.result.run.guest_nonce $admitted.result.trace.flushes ($admitted.result.events | where kind == "upload" | length)] ["paired" 4242 $nonce 1 1] "bundle_admitted: paired, bound by its pid and its nonce, the trace's one flush paired with its upload"
    assert equal ($admitted.result.events | where kind == "render" | get evidence) ["anchor"] "bundle_admitted: the render carries the replay's evidence, its anchor"
    let switch_frame = (do $inside 0 "displaychangelistener_gfx_switch")
    let moved_frame = $"0+(hex ((do $symbol 'displaychangelistener_gfx_switch').value + 8))"
    let registration_frame = (do $inside 0 "qemu_console_register_listener")
    let negatives = [
        { name: "bundle_log_byte", stage: 1, rehash: false, change: {|b| swap-once ($b | path join "sdl.log") "process 4242" "process 4243" } }
        { name: "bundle_file_added", stage: 1, rehash: false, change: {|b| "a file the manifest does not list\n" | save --raw ($b | path join "added.txt") } }
        { name: "bundle_hash_altered", stage: 1, rehash: false, change: {|b| nuon-edit ($b | path join "bundle.nuon") {|m| $m | update files ($m.files | each {|f| if $f.path == "classified.nuon" { $f | update sha256 ("0" | fill --character "0" --width 64) } else { $f } }) } } }
        { name: "bundle_inode", stage: 2, rehash: false, change: {|b| nuon-edit ($b | path join "bundle.nuon") {|m| $m | update objects ($m.objects | each {|o| if $o.index == 0 { $o | update inode ($o.inode + 1) } else { $o } }) } } }
        { name: "bundle_table_removed", stage: 2, rehash: true, change: {|b| rm ($b | path join "tables" "0.nm") } }
        { name: "bundle_event_altered", stage: 3, rehash: true, change: {|b| swap-once ($b | path join "sdl.log") $switch_frame $moved_frame } }
        { name: "bundle_event_removed", stage: 3, rehash: true, change: {|b| drop-line ($b | path join "sdl.log") $registration_frame } }
        { name: "bundle_classified_dropped", stage: 3, rehash: true, change: {|b| nuon-edit ($b | path join "classified.nuon") {|c| $c | update events ($c.events | drop 1) } } }
        { name: "bundle_kind_altered", stage: 4, rehash: true, change: {|b| nuon-edit ($b | path join "classified.nuon") {|c| $c | update events ($c.events | each {|e| if $e.kind == "upload" { $e | update kind "console" } else { $e } }) } } }
        { name: "bundle_table_renamed", stage: 4, rehash: true, change: {|b| swap-once ($b | path join "tables" "0.nm") "sdl2_gl_update " "sdl2_gl_updatf " } }
        { name: "bundle_evidence_altered", stage: 4, rehash: true, change: {|b| nuon-edit ($b | path join "classified.nuon") {|c| $c | update events ($c.events | each {|e| if $e.kind == "render" { $e | update evidence "timing" } else { $e } }) } } }
        { name: "bundle_pid_altered", stage: 5, rehash: true, change: {|b| swap-once ($b | path join "sdl.log") "process 4242" "process 4243" } }
        { name: "bundle_flush_removed", stage: 5, rehash: true, change: {|b| drop-line ($b | path join "trace.log") "virtio_gpu_cmd_res_flush" } }
        { name: "bundle_pid_unrecorded", stage: 5, rehash: true, change: {|b| nuon-edit ($b | path join "identity.nuon") {|i| $i | reject qemu_pid } } }
        { name: "bundle_guest_zero", stage: 5, rehash: true, change: {|b| 0 | into binary --endian little | save --raw -f ($b | path join "api.out") } }
        { name: "bundle_exchanged", stage: 5, rehash: true, change: {|b| cp -f ($second.bundle | path join "api.out") ($b | path join "api.out") } }
        { name: "bundle_qemu_unsupported", stage: 5, rehash: false, change: {|b| nuon-edit ($b | path join "bundle.nuon") {|m| $m | update host.qemu.version "QEMU emulator version 10.2.2" } } }
        { name: "bundle_flush_after", stage: 5, rehash: true, change: {|b| let up = (open --raw ($b | path join "classified.nuon") | decode | from nuon | get events | where kind == "upload" | first | get stamp | split row "."); let us = (($up.0 | into int) * 1000000 + ($up.1 | into int) + 1); $"((($us * 1000) | into datetime | format date "%Y-%m-%dT%H:%M:%S%.6fZ")) virtio_gpu_cmd_res_flush res 0x1, x 0, y 0, w 1920, h 1080\n" | save --raw -f ($b | path join "trace.log") } }
    ]
    for n in $negatives {
        let copy = ($bundles | path join $n.name)
        cp -r $first.bundle $copy
        do $n.change $copy
        if $n.rehash { rehash $copy }
        let got = (checked $copy $guest)
        assert equal $got.stage $n.stage $"($n.name): refused at stage ($n.stage): ($got.refused)"
    }
    let other = (checked $second.bundle $guest)
    assert equal $other.stage 0 $"bundle_second: the second capture's own bundle is admitted: ($other.refused)"

    # the trace's bracket (TraceBracket), on the real clock's microseconds:
    # each flip upload at or after its flush and at or before the next
    # traced command, flush or set_scanout, an equal stamp admitted on
    # either side, the last flush's bracket open, the lags reported; three
    # flushes a period apart from a whole second, whose stamp has no
    # fraction
    let t0 = 1792000000000000
    let flush = {|us: int| { name: "virtio_gpu_cmd_res_flush", us: ($t0 + $us) } }
    let scanout = {|us: int| { name: "virtio_gpu_cmd_set_scanout", us: ($t0 + $us) } }
    let traced = {|cmds: list<any>| $cmds | each {|c| $"(($c.us * 1000) | into datetime | format date (if ($c.us mod 1000000) == 0 { '%Y-%m-%dT%H:%M:%SZ' } else { '%Y-%m-%dT%H:%M:%S%.6fZ' })) ($c.name) res 0x1" } | str join (char nl) }
    let bracketed = {|cmds: list<any>, uploads: list<int>| try { { ok: true, trace: (sdl trace-bracket (do $traced $cmds) ($uploads | each {|u| $t0 + $u })), refused: "" } } catch {|e| { ok: false, trace: null, refused: $e.msg } } }
    let three = [(do $flush 0) (do $flush 16667) (do $flush 33333)]
    assert equal ((do $traced $three) | lines | first | split row " " | first) "2026-10-14T17:46:40Z" "trace_whole_second: the first stamp on a whole second, written with no fraction"
    let held = (do $bracketed $three [74 16740 33410])
    assert equal [$held.ok $held.trace.flushes $held.trace.open_last $held.trace.slow $held.trace.median_lag_us $held.trace.resolution_us] [true 3 true [] 74 1] $"trace_held: three uploads in their brackets, the last open: ($held | to nuon)"
    let equal = (do $bracketed $three [0 33333 33333])
    assert equal $equal.ok true $"trace_equal: an upload equal to its own flush's stamp and one equal to the next command's admitted: ($equal.refused)"
    let stall = (do $bracketed $three [74 23314 33410])
    assert equal [$stall.ok $stall.trace.slow] [true [{ upload: 2, lag_us: 6647 }]] $"trace_stall: a stall inside its flush admitted and reported slow: ($stall | to nuon)"
    let long = (do $bracketed $three [74 16740 900000])
    assert equal [$long.ok $long.trace.open_last ($long.trace.slow | get upload)] [true true [3]] $"trace_open: the last flush's upload long after it, its bracket open: ($long | to nuon)"
    let scanned = [(do $flush 0) (do $scanout 5000) (do $flush 16667) (do $flush 33333)]
    let before = (do $bracketed $scanned [4000 16740 33410])
    assert equal [$before.ok $before.trace.set_scanouts] [true 1] $"trace_scanout_before: an upload before an intervening set_scanout admitted: ($before.refused)"
    let refusals = [
        { name: "trace_upload_early", says: "flip upload 1 lies outside its flush's bracket, 5 us before its flush", cmds: $three, uploads: [-5 16740 33410] }
        { name: "trace_upload_late", says: "flip upload 1 lies outside its flush's bracket, 1 us past the next traced command", cmds: $three, uploads: [16668 16740 33410] }
        { name: "trace_upload_past_scanout", says: "flip upload 1 lies outside its flush's bracket, 1000 us past the next traced command", cmds: $scanned, uploads: [6000 16740 33410] }
        { name: "trace_stamp_back", says: "the trace's stamps step back at its traced command 3", cmds: [(do $flush 0) (do $flush 16667) (do $flush 16000)], uploads: [74 16740 33410] }
        { name: "trace_log_back", says: "the log's upload stamps step back at flip upload 3", cmds: $three, uploads: [74 33410 33400] }
        { name: "trace_counts", says: "the trace holds 3 flushes and the log 2 flip uploads", cmds: $three, uploads: [74 16740] }
    ]
    for c in $refusals {
        let got = (do $bracketed $c.cmds $c.uploads)
        assert ((not $got.ok) and ($got.refused | str starts-with $c.says)) $"($c.name): refused, saying ($c.says): ($got.refused)"
    }

    # the receipt stage's function: each present one past the last, every
    # other frame the last, the first held to the anchor, one fault one
    # violation, each rule its own case
    let p = {|ordinal: int| { presented: true, ordinal: $ordinal } }
    let n = {|ordinal: int| { presented: false, ordinal: $ordinal } }
    let violations = [
        { name: "ordinals_held", frames: [(do $p 4) (do $n 4) (do $p 5) (do $n 5) (do $p 6)], wanted: [] }
        { name: "ordinals_skip", frames: [(do $p 4) (do $p 6) (do $p 7)], wanted: [{ index: 1, rule: "skip", ordinal: 6, wanted: 5 }] }
        { name: "ordinals_repeat", frames: [(do $p 4) (do $p 4)], wanted: [{ index: 1, rule: "repeat", ordinal: 4, wanted: 5 }] }
        { name: "ordinals_backward", frames: [(do $p 4) (do $p 3)], wanted: [{ index: 1, rule: "backward", ordinal: 3, wanted: 5 }] }
        { name: "ordinals_advance", frames: [(do $p 4) (do $n 5)], wanted: [{ index: 1, rule: "advance", ordinal: 5, wanted: 4 }] }
        { name: "ordinals_first", frames: [(do $p 5) (do $p 6)], wanted: [{ index: 0, rule: "skip", ordinal: 5, wanted: 4 }] }
    ]
    for v in $violations {
        assert equal (present ordinal-violations 3 $v.frames) $v.wanted $"($v.name): the violations as the rules name them"
    }

    # K over presented acceptances: a zero-delay sequence, every flip
    # exactly a period on, passes at eps 100 and fails every pair at eps 0;
    # and over a generated set, jitter, stalls, and catch-ups from a fixed
    # seed, the linear check names exactly the flips the all-pairs one does
    let period = 166666
    let exact = (0..<10 | each {|i| 5000000 + $i * $period })
    assert equal (present k-violations $exact $period 100) [] "k_zero_delay: exact periods pass at eps 100"
    assert equal (present k-violations $exact $period 0) (1..<10 | each {|j| { index: $j, witness: 0, gap: ($j * $period), bound: ($j * $period) } }) "k_zero_delay_strict: every pair fails at eps 0, each against the first"
    let draws = (generate {|x|
        let a = ($x bit-xor (($x bit-shl 13) bit-and 0xffffffff))
        let b = ($a bit-xor ($a bit-shr 17))
        let c = ($b bit-xor (($b bit-shl 5) bit-and 0xffffffff))
        { out: $c, next: $c }
    } 2463534242 | take 6000)
    let sequences = (0..<100 | each {|k|
        let d = ($draws | skip ($k * 60) | take 60)
        $d | take 30 | enumerate | reduce --fold [] {|r, acc|
            let roll = ($r.item mod 100)
            let step = (if $roll < 6 { 3 * $period } else if $roll < 12 { $period // 4 } else { $period + (($d | get ($r.index + 30)) mod 6001) - 3000 })
            $acc | append (if ($acc | is-empty) { 1000000 } else { ($acc | last) + $step })
        }
    })
    for eps in [100 10000] {
        let found = ($sequences | each {|s| present k-violations $s $period $eps | length } | math sum)
        assert ($found > 100) $"k_all_pairs: the generated set breaks K at eps ($eps), so the comparison holds something: ($found) violations"
        for s in ($sequences | enumerate) {
            let pairs = (1..<($s.item | length) | each {|j| $j } | where {|j| 0..<$j | each {|i| $i } | any {|i| (($s.item | get $j) - ($s.item | get $i)) <= (($j - $i) * $period - $eps) } })
            assert equal (present k-violations $s.item $period $eps | get index) $pairs $"k_all_pairs: sequence ($s.index) at eps ($eps), the linear check's flips the all-pairs check's"
        }
    }

    # the pairing over synthetic runs: the load's two presents, ordinals 2
    # and 3, then 120 frames a period apart from 1.6 s, each present's call
    # 1.5 ms from its start with its upload 0.3 ms in, on a host clock
    # 1792000000 s on logged by the microsecond, the open's upload first, a
    # render after each upload, and a poll 1.5 s past the last; each case
    # the regular run changed
    let period_ms = (1000.0 / 60.0)
    let base = 1792000000.0
    let starts = ([100.0 1500.0] ++ (0..<120 | each {|i| 1600.0 + $i * $period_ms }))
    let stamped = {|ms: float, name: string, kind: string, key: string| { ts: ($base + ($ms * 1000.0 | math floor) / 1000000.0), name: $name, kind: $kind, key: $key } }
    let upload = {|ms: float| do $stamped $ms "make_current" "upload" "chain:0+10" }
    let render = {|ms: float| do $stamped ($ms + 5.0) "make_current" "render" "chain:?+20" }
    let poll = {|ms: float| do $stamped $ms "poll" "poll" "chain:" }
    let made_at = {|times: list<float>, offsets: list<float>, after: float| [(do $upload 50.0)] ++ ($times | zip $offsets | each {|t| [(do $upload ($t.0 + $t.1)) (do $render $t.0)] } | flatten) ++ [(do $poll (($times | last) + $after))] }
    let made = {|times: list<float>, after: float| do $made_at $times ($times | each { 0.3 }) $after }
    let ticks = {|ms: float| $ms * 10000.0 | math round | into int }
    let flipped_at = {|times: list<float>, lengths: list<float>| $times | zip $lengths | enumerate | each {|e| { status: 0, ordinal: ($e.index + 2), lo: (do $ticks $e.item.0), hi: (do $ticks ($e.item.0 + $e.item.1)) } } }
    let flipped = {|times: list<float>| do $flipped_at $times ($times | each { 1.5 }) }
    let regular = { events: (do $made $starts 1500.0), flips: (do $flipped $starts) }
    let paired = (sdl pair $regular.events $regular.flips)
    assert equal [$paired.verdict ($paired.pairs | length) $paired.window.first $paired.window.last $paired.bracket.status] ["admitted" 122 2 123 "feasible"] $"pair_regular: the regular run paired whole, its bracket feasible: ($paired.refusals | to nuon)"
    assert equal ($paired.shifts | get status) ["infeasible" "infeasible"] $"pair_regular: the load's gap rules out either shift: ($paired.shifts | to nuon)"
    assert (($paired.stalls | is-empty) and ($paired.pairs | all {|p| $p.place.first_ms <= 0.3 and $p.place.last_ms >= 0.3 })) "pair_regular: no stall, every upload's place holding its 0.3 ms"
    assert ((($paired.fit.drift - 1.0) | math abs) < 0.0001) $"pair_regular: the fit a diagnostic, drift 1: ($paired.fit | to nuon)"
    # a refused flip and a frame with no flip after frame 10, both unpaired
    let unpaired = (sdl pair $regular.events ($regular.flips | take 12 | append [{ status: 1, ordinal: 13, lo: 0, hi: 0 } { status: 255, ordinal: 13, lo: 0, hi: 0 }] | append ($regular.flips | skip 12)))
    assert equal [$unpaired.verdict ($unpaired.pairs | length)] ["admitted" 122] $"pair_unpaired: a refused flip and a frame with no flip go unpaired: ($unpaired.refusals | to nuon)"
    # the window after a loading silence longer than any of its own gaps
    let quiet = ([100.0 1500.0] ++ (0..<120 | each {|i| 6000.0 + $i * $period_ms }))
    let silence = (sdl pair (do $made $quiet 1500.0) (do $flipped $quiet))
    assert equal [$silence.verdict ($silence.pairs | length)] ["admitted" 122] $"pair_silence: the ordinals place a window after a silence: ($silence.refusals | to nuon)"
    # a stall, one call 14 ms with its upload in place, admitted and named
    # with its upload's place early in it; then two, each named
    let stalled = {|indices: list<int>| $regular.flips | enumerate | each {|e| if $e.index in $indices { $e.item | update hi ($e.item.lo + 140440) } else { $e.item } } }
    let stall = (sdl pair $regular.events (do $stalled [42]))
    assert equal [$stall.verdict ($stall.stalls | get ordinal)] ["admitted" [44]] $"pair_stall: admitted, the stall named: ($stall.stalls | to nuon)"
    assert (($stall.stalls | first | get place.last_ms) < 2.0) $"pair_stall: its upload placed early in its call: ($stall.stalls | to nuon)"
    let stalls = (sdl pair $regular.events (do $stalled [42 80]))
    assert equal [$stalls.verdict ($stalls.stalls | get ordinal)] ["admitted" [44 82]] $"pair_stalls: each stall named: ($stalls.stalls | to nuon)"
    # mixed long and short calls, the long ones' uploads early and the short
    # ones' late: the fit's residuals large, the bracket holding
    let lengths = ($starts | enumerate | each {|e| if $e.index >= 2 and ($e.index mod 2) == 1 { 10.0 } else { 1.5 } })
    let mixed = (sdl pair (do $made_at $starts ($lengths | each {|l| if $l > 2.0 { 0.3 } else { 1.4 } }) 1500.0) (do $flipped_at $starts $lengths))
    assert equal [$mixed.verdict $mixed.bracket.status] ["admitted" "feasible"] $"pair_mixed: the bracket holds: ($mixed.refusals | to nuon)"
    assert ($mixed.fit.max_residual_ms > 4.0) $"pair_mixed: the fit's residuals large: ($mixed.fit | to nuon)"
    # a retried frame, its final attempt's call after an await of 8 ms and
    # its upload in that call, admitted; its upload in the await between the
    # two attempts, refused by the bracket and named
    let retried_starts = ($starts | enumerate | each {|e| if $e.index == 50 { $e.item + 8.0 } else { $e.item } })
    let retried = (sdl pair (do $made $retried_starts 1500.0) (do $flipped $retried_starts))
    assert equal $retried.verdict "admitted" $"pair_retried: the final attempt's bounds hold its upload: ($retried.refusals | to nuon)"
    let awaited = (sdl pair $regular.events (do $flipped $retried_starts))
    assert equal [$awaited.verdict $awaited.bracket.binding.ceiling] ["refused" [52]] $"pair_await: an upload in the await refused, its present named: ($awaited.bracket | to nuon)"
    # drift on narrow calls, 20 us with each upload 10 us in: at the
    # declared 50 ppm admitted; at 100 ppm refused as drift past the bound
    let drifted = {|ppm: float|
        let scale = (1.0 + $ppm / 1000000.0)
        let events = ([(do $upload 50.0)] ++ ($starts | each {|ms| [(do $upload (($ms + 0.01) * $scale)) (do $render ($ms * $scale))] } | flatten) ++ [(do $poll ((($starts | last) + 1500.0) * $scale))])
        sdl pair $events (do $flipped_at $starts ($starts | each { 0.02 }))
    }
    let bound = (do $drifted 50.0)
    assert equal $bound.verdict "admitted" $"pair_drift_bound: drift at the declared bound admitted: ($bound.refusals | to nuon)"
    let past = (do $drifted 100.0)
    assert equal [$past.verdict ($past.refusals | get refusal)] ["refused" ["the bracket: no drift within the declared bound holds every upload in its call, and one past it does"]] $"pair_drift_past: refused as drift past the bound: ($past.refusals | to nuon)"
    # regular presents with short calls and no load gap: the stream shifted
    # by one upload is feasible too, so the reading is ambiguous and the
    # binding decides
    let frames = ($starts | skip 2)
    let open = (sdl pair (do $made $frames 1500.0) (do $flipped $frames))
    assert equal [$open.verdict ($open.shifts | where status == "feasible" | get name)] ["ambiguous" ["later"]] $"pair_ambiguous: the shifted mapping feasible too: ($open.shifts | to nuon)"
    # Astra's compensating loss and addition: frame 60's upload lost and one
    # added; a quarter period on, past its call, refused and named; inside
    # its call, passing
    let swapped = {|at: float| do $made $frames 1500.0 | enumerate | each {|e| if $e.index == 121 { do $upload (($frames | get 60) + $at) } else { $e.item } } }
    let past_call = (sdl pair (do $swapped 4.1667) (do $flipped $frames))
    assert equal [$past_call.verdict $past_call.bracket.binding.floor] ["refused" [62]] $"pair_compensated: an addition past its call refused and named: ($past_call.bracket | to nuon)"
    let in_call = (sdl pair (do $swapped 1.0) (do $flipped $frames))
    assert equal $in_call.verdict "ambiguous" $"pair_compensated_inside: an addition inside its call passes: ($in_call.refusals | to nuon)"
    # the refusals, each at its own rule
    let late = ($starts | skip 2 | last 10 | each {|ms| $ms + 10 * $period_ms })
    let tail = {|times: list<float>| $times | each {|ms| [(do $upload ($ms + 0.3)) (do $render $ms)] } | flatten }
    let extra = {|at: float, count: int| 1..$count | each {|i| do $upload ($at + 5.0 + $i) } }
    let model = "the bracket: the clock model holds at no drift, a pause, a real-clock step, or an upload outside its call"
    let refusals = [
        { name: "pair_three_uploads", says: $model, events: ((do $made ($starts | take 50) 0.0 | drop 1) ++ (do $extra ($starts | get 49) 2) ++ (do $tail (($starts | skip 50) ++ $late)) ++ [(do $poll (($late | last) + 1500.0))]), flips: $regular.flips }
        { name: "pair_upload_missing", says: $model, events: ((do $made ($starts | take 60) 0.0 | drop 1) ++ (do $tail (($starts | skip 61) ++ $late)) ++ [(do $poll (($late | last) + 1500.0))]), flips: $regular.flips }
        { name: "pair_duplicated", says: "a duplicated event", events: ($regular.events | take 41 | append ($regular.events | get 40) | append ($regular.events | skip 41)), flips: $regular.flips }
        { name: "pair_gap", says: "an ordinal gap in the guest's presents", events: ((do $made ($starts | take 30) 0.0 | drop 1) ++ [(do $upload (($starts | get 29) + 5.5))] ++ (do $tail ($starts | skip 30)) ++ [(do $poll (($starts | last) + 1500.0))]), flips: ($regular.flips | take 30 | append ($regular.flips | skip 30 | each {|f| $f | update ordinal ($f.ordinal + 1) })) }
        { name: "pair_shifted", says: $model, events: ([(do $upload 10.0)] ++ $regular.events), flips: $regular.flips }
        { name: "pair_slip", says: $model, events: ((do $made ($starts | take 62) 0.0 | drop 1) ++ [(do $upload (($starts | get 61) + 8.0))] ++ (do $tail (($starts | skip 62) ++ $late)) ++ [(do $poll (($late | last) + 1500.0))]), flips: $regular.flips }
        { name: "pair_backwards", says: "a stamp going backwards", events: ($regular.events | update 82 {|e| $e | update ts ($e.ts - 0.5) }), flips: $regular.flips }
        { name: "pair_device", says: "a device error in the window", events: $regular.events, flips: ($regular.flips | take 70 | append { status: 3, ordinal: 71, lo: 0, hi: 0 } | append ($regular.flips | skip 70)) }
        { name: "pair_cut", says: "the log ending under 1 s past the window's last upload", events: (do $made $starts 500.0), flips: $regular.flips }
        { name: "pair_short", says: "the log short of an ordinal", events: (do $made ($starts | drop 3) 1500.0), flips: $regular.flips }
    ]
    for c in $refusals {
        let read = (sdl pair $c.events $c.flips)
        assert (($read.verdict == "refused") and (($read.refusals | get refusal) == [$c.says])) $"($c.name): refused, saying ($c.says) and nothing else: ($read.refusals | to nuon)"
    }

    # the shim's capture, on a binary built non-PIE: the premises first
    let library = (tool shim $ws "jabshim_sdl")
    let harness = (tool shim $ws "jabshim_sdl_harness" --static)
    let header = (^readelf -h $harness | complete | get stdout)
    assert ($header =~ 'Type:\s+EXEC') $"harness: an EXEC: ($header | lines | where {|l| $l =~ 'Type:' } | str join '')"
    let loads = (^readelf -lW $harness | complete | get stdout | lines | parse --regex '^\s+LOAD\s+0x[0-9a-f]+\s+0x(?P<vaddr>[0-9a-f]+)' | update vaddr {|r| $"0x($r.vaddr)" | into int })
    assert ((not ($loads | is-empty)) and (($loads | first | get vaddr) > 0)) $"harness: its first segment sits above 0: ($loads | to nuon)"
    let harness_log = ($dir | path join "harness.log")
    let ran = (with-env { LD_PRELOAD: $library, SDL_SHIM_LOG: $harness_log } { ^$harness | complete })
    assert equal $ran.exit_code 0 $"harness: it runs under the shim: ($ran.stdout)($ran.stderr)"
    let read = (sdl resolve $harness_log)
    let captured = ($read.events | where name == "make_current")
    assert equal ($captured | length) 1 $"harness: the shim logs its one make_current: ($read.events | to nuon)"
    let caller = ($captured | first | get frames | get -o 0)
    assert ($captured | first | get shim_frames | $in in [1 2]) $"harness: its frames start with one or two in the shim's library: ($captured | first | to nuon)"
    assert equal ($caller | get -o object) 0 $"harness: the frame after the shim's lies in the harness, object 0: ($caller | to nuon)"
    assert equal ($caller | get -o functions) ["harness_make_current"] $"harness: sdl-resolve names the harness's own function as the immediate caller: ($caller | to nuon)"
    print "probe: ok"
}
