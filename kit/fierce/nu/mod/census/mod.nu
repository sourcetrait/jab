use std/assert

# The census frame line's form: blocks, passing, dropped, lighting, chunk
const FRAME = "fps: census frame {frame}: blocks {blocks}, passing {passing}, dropped {dropped}, lighting {lighting}, chunk {chunk}"

# A census side line's form: blocks by class, demand, checks, working sets
const SIDE = "fps: census {side}: eligible {eligible} blocks {eligible_pixels} pixels, straddling {straddling} blocks {straddling_pixels} pixels, outside {outside}; demand {demand}: planes {planes}, walls {walls}, openings {openings}; sampled {sampled}, uniform {uniform}, checked {checked}, mismatches {mismatches}, surfaces {surfaces}; working {w1}, {w30}, {w120}: planes {p1}, {p30}, {p120}, walls {q1}, {q30}, {q120}"

# A census context list's head line's form: requests, distinct, surfaces, items
const HEAD = "fps: census {side} context {context}: requests {requests}, distinct {distinct}, surfaces {listed};{items}"

# A census context list's continuation line's form, more items
const MORE = "fps: census {side} context {context} more:{items}"

# The census directory line's form: maps, planes below, contexts, sides
const DIRECTORY = "fps: census directory: {maps} maps, planes below {planes_below} of {surfaces}, contexts {contexts}; {sides}"

# The census directory line's first form, naming no contexts
const DIRECTORY_FIRST = "fps: census directory: {maps} maps, planes below {planes_below} of {surfaces}; {sides}"

# The contexts the first directory form's census kept: hart 0's, two workers'
const FIRST_CONTEXTS = 3

# The census edge line's form: the nodes' and the sampler's verdicts
const EDGE = "fps: census edge: nodes {nodes}, sampler {sampler}"

# The census end line's form, naming its frame
const END = "fps: census end {frame}"

# The directory the census sized at the load, null when the log holds none
export def directory [serial: string]: nothing -> oneof<record, nothing> {
    let found = ($serial | lines | where {|l| $l starts-with "fps: census directory: " })
    if ($found | is-empty) { return null }
    let line = ($found | get 0)
    let current = ($line | parse $DIRECTORY)
    let parsed = (if not ($current | is-empty) { $current } else { $line | parse $DIRECTORY_FIRST | each {|d| $d | insert contexts $"($FIRST_CONTEXTS)" } })
    if ($parsed | is-empty) { return null }
    let d = ($parsed | get 0)
    let sides = ($d.sides | split row "; " | each {|s| $s | parse "{side}: entries {entries}, bytes {bytes}" })
    if ($sides | any {|s| $s | is-empty }) { return null }
    {
        maps: ($d.maps | into int),
        planes_below: ($d.planes_below | into int),
        surfaces: ($d.surfaces | into int),
        contexts: ($d.contexts | into int),
        sides: ($sides | each {|s| $s | get 0 | update cells {|c| $c | into int } }),
    }
}

# The clamped edge's case at the load, 1 for uniform; null with no edge line
export def edge [serial: string]: nothing -> oneof<record, nothing> {
    let found = ($serial | lines | where {|l| $l starts-with "fps: census edge: " })
    if ($found | is-empty) { return null }
    let e = ($found | get 0 | parse $EDGE)
    if ($e | is-empty) { return { skipped: true, nodes: null, sampler: null } }
    let r = ($e | get 0)
    { skipped: false, nodes: ($r.nodes | into int), sampler: ($r.sampler | into int) }
}

# Every census frame of a serial log in order, read against its directory
export def frames [serial: string]: nothing -> list<record> {
    let dir = (directory $serial)
    let lines = ($serial | lines | where {|l| ($l starts-with "fps: census ") and not ($l starts-with "fps: census directory: ") and not ($l starts-with "fps: census edge: ") })
    let starts = ($lines | enumerate | where {|e| $e.item starts-with "fps: census frame " } | get index)
    $starts | enumerate | each {|s|
        let end = (if ($s.index + 1) < ($starts | length) { $starts | get ($s.index + 1) } else { $lines | length })
        frame-of ($lines | slice $s.item..<$end) $dir
    }
}

# A census frame read from its lines against the directory, valid or why not
def frame-of [lines: list<string>, dir: oneof<record, nothing>]: nothing -> record {
    let parsed = ($lines | first | parse $FRAME)
    if ($parsed | is-empty) {
        return { frame: null, blocks: null, passing: null, dropped: null, lighting: null, chunk: null, sides: [], ended: false, valid: false, reasons: [$"a frame line the census does not write: ($lines | first)"] }
    }
    let frame = ($parsed | get 0 | update cells {|c| $c | into int })
    mut sides = []
    mut listings = []
    mut tags = []
    mut problems = []
    mut ended = false
    mut open = false
    for line in ($lines | skip 1) {
        let end = ($line | parse $END)
        if not ($end | is-empty) {
            if (($end | get 0.frame) != ($frame.frame | into string)) or $ended {
                $problems = ($problems | append $"an end line not this frame's: ($line)")
            }
            $ended = true
            $open = false
            continue
        }
        if $ended {
            $problems = ($problems | append $"a line after the frame's end: ($line)")
            continue
        }
        let side = ($line | parse $SIDE)
        if not ($side | is-empty) {
            let s = ($side | get 0 | update cells {|c| $c | into int })
            $sides = ($sides | append $s)
            $tags = ($tags | append $"side ($s.side)")
            $open = false
            continue
        }
        let head = ($line | parse $HEAD)
        if not ($head | is-empty) {
            let h = ($head | get 0)
            let items = (pairs-of $h.items)
            $problems = ($problems | append $items.bad)
            $listings = ($listings | append {
                side: ($h.side | into int),
                context: ($h.context | into int),
                requests: ($h.requests | into int),
                distinct: ($h.distinct | into int),
                listed: ($h.listed | into int),
                pairs: $items.pairs,
                chunks: 1,
            })
            $tags = ($tags | append $"side ($h.side) context ($h.context)")
            $open = true
            continue
        }
        let more = ($line | parse $MORE)
        if not ($more | is-empty) {
            let m = ($more | get 0)
            let side = ($m.side | into int)
            let context = ($m.context | into int)
            let items = (pairs-of $m.items)
            $problems = ($problems | append $items.bad)
            let last = (if ($listings | is-empty) { null } else { $listings | last })
            let continues = (if $last == null or not $open { false } else { ($last.side == $side) and ($last.context == $context) })
            if $continues {
                let joined = ($last | update pairs ($last.pairs | append $items.pairs) | update chunks ($last.chunks + 1))
                $listings = ($listings | drop 1 | append $joined)
            } else {
                $problems = ($problems | append $"a continuation of side ($side) context ($context) not after its head or its continuations")
            }
            continue
        }
        $problems = ($problems | append $"a line the census does not write: ($line)")
        $open = false
    }
    let read_sides = $sides
    let listed = $listings
    let unassembled = ($listed | where {|l| (($l.pairs | length) != $l.listed) or ((total $l.pairs) != $l.distinct) })
    let dropped = (if $frame.dropped > 0 { [$"($frame.dropped) blocks dropped, the frame incomplete evidence"] } else { [] })
    let cut = (if $ended { [] } else { ["the log ends inside the frame, its end line missing"] })
    let shape = (if $dir == null { ["no census directory to read the frame against"] } else { shape-reasons (expected-shape $dir) $tags })
    let surfaces = (if $dir == null { [] } else { $listed | each {|l| surface-reasons $l $dir.surfaces } | flatten })
    let accounted = (if $dir == null or $frame.dropped > 0 { [] } else {
        let per_side = ($read_sides | each {|s|
            let mine = ($listed | where side == $s.side)
            if ($mine | get context) == (0..<$dir.contexts | each {|c| $c }) { accounting $frame $s $mine $dir.planes_below } else { [] }
        } | flatten)
        $per_side | append (if $frame.passing > $frame.blocks { [$"the frame's ($frame.passing) passing blocks past its ($frame.blocks) blocks"] } else { [] })
    })
    let reasons = ($problems
        | append $cut
        | append $dropped
        | append ($unassembled | each {|l| $"the list of side ($l.side) context ($l.context) does not reassemble: ($l.pairs | length) surfaces against ($l.listed) listed, counts summing to (total $l.pairs) against ($l.distinct) distinct" })
        | append $shape
        | append $surfaces
        | append $accounted)
    {
        frame: $frame.frame,
        blocks: $frame.blocks,
        passing: $frame.passing,
        dropped: $frame.dropped,
        lighting: $frame.lighting,
        chunk: $frame.chunk,
        sides: ($read_sides | each {|s| $s | insert contexts ($listed | where side == $s.side) }),
        ended: $ended,
        valid: ($reasons | is-empty),
        reasons: $reasons,
    }
}

# The records a whole frame holds between its frame and end lines, in order
def expected-shape [dir: record]: nothing -> list<string> {
    $dir.sides | each {|d| [$"side ($d.side)"] | append (0..<$dir.contexts | each {|c| $"side ($d.side) context ($c)" }) } | flatten
}

# What keeps a frame's records from the whole frame's: missing, repeated, order
def shape-reasons [expected: list<string>, read: list<string>]: nothing -> list<string> {
    let missing = ($expected | where {|t| $t not-in $read } | each {|t| $"missing: ($t)" })
    let repeated = ($read | uniq --repeated | each {|t| $"repeated: ($t)" })
    let unexpected = ($read | where {|t| $t not-in $expected } | uniq | each {|t| $"unexpected: ($t)" })
    let found = ($missing | append $repeated | append $unexpected)
    if not ($found | is-empty) { return $found }
    if $read == $expected { return [] }
    let span = ([($expected | length) ($read | length)] | math max)
    let at = (0..<$span | each {|i| $i } | where {|i| ($read | get -o $i) != ($expected | get -o $i) } | first)
    [$"out of order: ($read | get -o $at | default 'nothing') where ($expected | get -o $at | default 'nothing') belongs"]
}

# A context's list against the directory: each surface held, once, counted
def surface-reasons [l: record, surfaces: int]: nothing -> list<string> {
    let ids = ($l.pairs | get surface)
    [
        ($l.pairs | where surface >= $surfaces | each {|p| $"side ($l.side) context ($l.context) lists surface ($p.surface), past the directory's surfaces ($surfaces)" })
        ($ids | uniq --repeated | each {|s| $"side ($l.side) context ($l.context) lists surface ($s) twice" })
        ($l.pairs | where count < 1 | each {|p| $"side ($l.side) context ($l.context) lists surface ($p.surface) with a count under 1" })
    ] | flatten
}

# A side's counts against the relations the census keeps among them
def accounting [frame: record, s: record, contexts: list<record>, below: int]: nothing -> list<string> {
    let n = $s.side
    let requests = (total-of ($contexts | get requests))
    let distincts = ($contexts | get distinct)
    let greatest = ($distincts | math max)
    let pairs = ($contexts | get pairs | flatten)
    let union = ($pairs | get surface | uniq | length)
    let listed_planes = (total-of ($pairs | where surface < $below | get count))
    let listed_walls = (total-of ($pairs | where surface >= $below | get count))
    [
        (if ($s.eligible + $s.straddling + $s.outside) != $frame.blocks { $"side ($n)'s eligible, straddling, and outside blocks sum to ($s.eligible + $s.straddling + $s.outside), not the frame's ($frame.blocks) blocks" })
        (if $requests > $s.eligible { $"side ($n)'s contexts request ($requests) times, past its ($s.eligible) eligible blocks" })
        (if $requests > $frame.passing { $"side ($n)'s contexts request ($requests) times, past the frame's ($frame.passing) passing blocks" })
        ($contexts | where {|c| $c.distinct > $c.requests } | each {|c| $"side ($n) context ($c.context)'s ($c.distinct) distinct tiles pass its ($c.requests) requests" })
        ($contexts | where {|c| ($c.requests == 0) != ($c.distinct == 0) } | each {|c| $"side ($n) context ($c.context)'s requests ($c.requests) and distinct tiles ($c.distinct) not zero together" })
        (if $s.demand < $greatest { $"side ($n)'s demand ($s.demand) under a context's ($greatest) distinct tiles" })
        (if $s.demand > (total-of $distincts) { $"side ($n)'s demand ($s.demand) past its contexts' (total-of $distincts) distinct tiles" })
        (if ($s.planes + ([$s.walls $s.openings] | math max)) > $s.demand { $"side ($n)'s planes ($s.planes) with the greater of walls and openings pass its demand ($s.demand)" })
        (if $s.demand > ($s.planes + $s.walls + $s.openings) { $"side ($n)'s demand ($s.demand) past its planes, walls, and openings together" })
        (if $s.demand > $s.sampled { $"side ($n)'s demand ($s.demand) past its ($s.sampled) sampled tiles" })
        (if $s.checked > $s.demand { $"side ($n)'s ($s.checked) checked tiles past its demand ($s.demand)" })
        (if $s.mismatches > $s.checked { $"side ($n)'s ($s.mismatches) mismatches past its ($s.checked) checked tiles" })
        (if $s.uniform > $s.demand { $"side ($n)'s ($s.uniform) uniform tiles past its demand ($s.demand)" })
        (if $s.uniform < ($s.checked - $s.mismatches) { $"side ($n)'s ($s.uniform) uniform tiles under its checked tiles less mismatches" })
        (if $s.surfaces != $union { $"side ($n)'s ($s.surfaces) requesting surfaces not the ($union) its contexts list" })
        (if $s.w1 != $s.demand { $"side ($n)'s whole working set this frame ($s.w1) not its demand ($s.demand)" })
        (if $s.p1 != $s.planes { $"side ($n)'s planes' working set this frame ($s.p1) not its demand's planes ($s.planes)" })
        (if $s.q1 != ($s.demand - $s.planes) { $"side ($n)'s walls' working set this frame ($s.q1) not its demand less its planes" })
        ([[w p q]; [$s.w1 $s.p1 $s.q1] [$s.w30 $s.p30 $s.q30] [$s.w120 $s.p120 $s.q120]] | where {|x| $x.w != ($x.p + $x.q) } | each {|x| $"side ($n)'s working set ($x.w) not its planes' and walls' ($x.p) and ($x.q)" })
        ([[class a b c]; [whole $s.w1 $s.w30 $s.w120] [planes $s.p1 $s.p30 $s.p120] [walls $s.q1 $s.q30 $s.q120]] | where {|x| $x.a > $x.b or $x.b > $x.c } | each {|x| $"side ($n)'s ($x.class) working sets falling over the windows: ($x.a), ($x.b), ($x.c)" })
        (if $listed_planes < $s.p1 or $listed_walls < $s.q1 { $"side ($n)'s listed tiles by class, planes ($listed_planes) and walls ($listed_walls), short of its working sets this frame" })
    ] | flatten | compact
}

# A list's surface:count pairs, and every item that is no such pair
def pairs-of [items: string]: nothing -> record<pairs: list<record<surface: int, count: int>>, bad: list<string>> {
    let words = ($items | split row " " | where {|w| $w != "" })
    let bad = ($words | where {|w| not ($w =~ '^\d+:\d+$') })
    let pairs = ($words | where {|w| $w =~ '^\d+:\d+$' } | each {|w|
        let p = ($w | split row ":")
        { surface: ($p.0 | into int), count: ($p.1 | into int) }
    })
    { pairs: $pairs, bad: ($bad | each {|w| $"an item that is no surface:count pair: ($w)" }) }
}

# The sum of surface:count pairs' counts, 0 for none
def total [pairs: list<record<surface: int, count: int>>]: nothing -> int {
    if ($pairs | is-empty) { 0 } else { $pairs | get count | math sum }
}

# A list's sum, 0 for none
def total-of [values: list<int>]: nothing -> int {
    if ($values | is-empty) { 0 } else { $values | math sum }
}

# The census fixture's reading of its run's log held, its line returned
export def census-fixture-holds [serial: string, shrunk: int, slots: int]: nothing -> string {
    let edge = (edge $serial)
    assert ($edge != null) "the clamped edge's line after the load"
    assert (not $edge.skipped) $"the clamped edge's case ran: ($edge)"
    assert equal $edge.nodes 0 $"the tile past the last node shaded by its nodes, the penultimate column's in reach as lumel_sample clamps: ($edge)"
    assert equal $edge.sampler 0 $"the tile past the last node shaded at lumel_sample's texel centres: ($edge)"

    let directory = (directory $serial)
    assert ($directory != null) "the census's directory after the load"
    assert ($directory.maps > 0 and $directory.planes_below > 0 and $directory.surfaces > $directory.planes_below) $"the directory's maps and surfaces: ($directory)"
    let read = (frames $serial)
    let cut = ($read | enumerate | where {|e| not $e.item.ended } | get index)
    assert ($cut | all {|i| $i == (($read | length) - 1) }) $"only the log's last frame cut by the run's end: frames ($cut) of ($read | length)"
    let frames = ($read | where ended)
    assert (($frames | length) > 50) $"census frames through the run: ($frames | length)"
    let invalid = ($frames | where {|f| not $f.valid })
    assert ($invalid | is-empty) $"every census frame whole and accounting: ($invalid | first 3 | select frame reasons)"
    let lists = {|fs: list| $fs | each {|f| $f.sides | each {|s| $s.contexts } | flatten } | flatten }

    assert equal $directory.contexts ($slots + 1) $"the directory counting hart 0's context and a slot's each: ($directory.contexts)"
    let drawing = (do $lists $frames | where requests > 0 | get context | uniq | sort)
    assert equal $drawing (1..$slots | each {|c| $c }) $"the workers' contexts drawn into, hart 0's not: ($drawing)"

    let shrunk_frames = ($frames | where chunk == $shrunk)
    assert (not ($shrunk_frames | is-empty)) $"frames under the shrunk chunk: ($frames | get chunk | uniq)"
    let unsplit = (do $lists $shrunk_frames | where {|l| ($l.pairs | length) >= 2 and $l.chunks < 2 })
    assert ($unsplit | is-empty) $"every list of two surfaces or more split under the shrunk chunk: ($unsplit | first 3 | select side context listed chunks)"
    let split = (do $lists $shrunk_frames | where {|l| $l.chunks > 1 })
    assert (not ($split | is-empty)) "lists split under the shrunk chunk"
    let whole = (do $lists ($frames | where chunk != $shrunk) | where {|l| $l.chunks > 1 })
    assert ($whole | is-empty) $"no list split under the build's own bound: ($whole | first 3 | select side context listed chunks)"

    let sides = ($frames | each {|f| $f.sides | each {|s| $s | insert frame $f.frame | insert lighting $f.lighting } } | flatten)
    assert (($sides | where {|s| $s.p1 > 0 and $s.q1 > 0 } | length) > 0) "planes and walls both demanded from the spawn view"

    assert equal ($frames | get lighting | uniq) [0 1 2 3] $"the lighting's revisions in order, one an L: ($frames | get lighting | uniq)"
    let mismatched = ($sides | where mismatches > 0)
    assert ($mismatched | is-empty) $"no tile uniform by its nodes and not by lumel_sample: ($mismatched | first 3 | select frame side uniform checked mismatches)"
    let ordinary = ($sides | where lighting == 0)
    assert (not ($ordinary | is-empty)) "frames under the ordinary light"
    let ordinary_checked = ($ordinary | get checked | math sum)
    assert ($ordinary_checked > 0) $"the ordinary light's uniform tiles checked by lumel_sample: ($ordinary_checked)"
    for revision in [1 3] {
        let lit = ($frames | where lighting == $revision)
        assert (not ($lit | is-empty)) $"frames under full bright, revision ($revision)"
        let first = ($lit | first)
        let unchecked = ($first.sides | where {|s| $s.demand == 0 or $s.uniform != $s.demand or $s.checked != $s.demand })
        assert ($unchecked | is-empty) $"under full bright every demanded tile uniform and checked in revision ($revision)'s first frame ($first.frame): ($unchecked | select side demand uniform checked)"
        let shaded = ($sides | where {|s| $s.lighting == $revision and $s.uniform != $s.demand })
        assert ($shaded | is-empty) $"every demanded tile uniform through revision ($revision): ($shaded | first 3 | select frame side demand uniform)"
    }
    let parity = ($sides | where lighting == 2)
    assert (not ($parity | is-empty)) "frames under the parity"
    let even = ($parity | where {|s| $s.uniform > 0 or $s.checked > 0 })
    assert ($even | is-empty) $"under the parity no tile uniform and none checked: ($even | first 3 | select frame side demand uniform checked)"

    census-reader-holds $serial
    $"fps: the census's ($frames | length) frames, ($shrunk_frames | length) under the shrunk chunk, revisions ($frames | get lighting | uniq | str join ' '), the edge's verdicts ($edge.nodes) and ($edge.sampler), contexts ($directory.contexts)"
}

# The census reader held on a capture's log: read whole, frames valid
export def census-reader-holds [serial: string]: nothing -> nothing {
    let read = (frames $serial)
    let cut = ($read | enumerate | where {|e| not $e.item.ended } | get index)
    assert ($cut | all {|i| $i == (($read | length) - 1) }) $"only the log's last frame cut by the run's end: frames ($cut) of ($read | length)"
    let frames = ($read | where ended)
    let invalid = ($frames | where {|f| not $f.valid })
    assert ($invalid | is-empty) $"every census frame whole and accounting: ($invalid | first 3 | select frame reasons)"
    let directory = (directory $serial)
    assert ($directory != null) "the census's directory after the load"
}
