# The census's lines, a CENSUS build's (census.S), read off a run's
# serial log: the directory after the load, the clamped edge's two
# verdicts, and every frame read against the directory as census_print
# writes it. A frame stands valid when it is whole and accounts: its frame
# line; each side the directory names, in its order, once, its side line
# followed by its contexts 0 to CONTEXTS less one in order, each a head
# and its continuations; the end line last; every context's list
# reassembled from its chunks, its surfaces the directory's, each once,
# each count at least 1; no block dropped; and each side's counts in the
# relations census.S keeps among them.

const FRAME = "fps: census frame {frame}: blocks {blocks}, passing {passing}, dropped {dropped}, lighting {lighting}, chunk {chunk}"
const SIDE = "fps: census {side}: eligible {eligible} blocks {eligible_pixels} pixels, straddling {straddling} blocks {straddling_pixels} pixels, outside {outside}; demand {demand}: planes {planes}, walls {walls}, openings {openings}; sampled {sampled}, uniform {uniform}, checked {checked}, mismatches {mismatches}, surfaces {surfaces}; working {w1}, {w30}, {w120}: planes {p1}, {p30}, {p120}, walls {q1}, {q30}, {q120}"
const HEAD = "fps: census {side} context {context}: requests {requests}, distinct {distinct}, surfaces {listed};{items}"
const MORE = "fps: census {side} context {context} more:{items}"
const DIRECTORY = "fps: census directory: {maps} maps, planes below {planes_below} of {surfaces}; {sides}"
const EDGE = "fps: census edge: nodes {nodes}, sampler {sampler}"
const END = "fps: census end {frame}"
# render.inc's CENSUS_CONTEXTS, WORKERS_MAX + 1: hart 0's context and a
# worker's each
const CONTEXTS = 3

# The directory the census sized at the load: the lumel maps it holds,
# the surface index the walls start at, the surfaces in all, and each
# tile side's entries and bytes; null when the log holds no directory
export def directory [serial: string]: nothing -> oneof<record, nothing> {
    let found = ($serial | lines | where {|l| $l starts-with "fps: census directory: " })
    if ($found | is-empty) { return null }
    let parsed = ($found | get 0 | parse $DIRECTORY)
    if ($parsed | is-empty) { return null }
    let d = ($parsed | get 0)
    let sides = ($d.sides | split row "; " | each {|s| $s | parse "{side}: entries {entries}, bytes {bytes}" })
    if ($sides | any {|s| $s | is-empty }) { return null }
    {
        maps: ($d.maps | into int),
        planes_below: ($d.planes_below | into int),
        surfaces: ($d.surfaces | into int),
        sides: ($sides | each {|s| $s | get 0 | update cells {|c| $c | into int } }),
    }
}

# The clamped edge's case at the load: whether a tile past a map's last
# node reads uniform by its nodes and by lumel_sample, 1 for uniform;
# skipped when a map fills the lumel arena's tail, null when the log
# holds no edge line
export def edge [serial: string]: nothing -> oneof<record, nothing> {
    let found = ($serial | lines | where {|l| $l starts-with "fps: census edge: " })
    if ($found | is-empty) { return null }
    let e = ($found | get 0 | parse $EDGE)
    if ($e | is-empty) { return { skipped: true, nodes: null, sampler: null } }
    let r = ($e | get 0)
    { skipped: false, nodes: ($r.nodes | into int), sampler: ($r.sampler | into int) }
}

# Every census frame of a serial log in order, read against the log's
# directory: its counts, the lighting's revision and the context lines'
# chunk in force, its sides with each context's list reassembled, and
# whether it stands valid, with the reasons it does not
export def frames [serial: string]: nothing -> list<record> {
    let dir = (directory $serial)
    let lines = ($serial | lines | where {|l| ($l starts-with "fps: census ") and not ($l starts-with "fps: census directory: ") and not ($l starts-with "fps: census edge: ") })
    let starts = ($lines | enumerate | where {|e| $e.item starts-with "fps: census frame " } | get index)
    $starts | enumerate | each {|s|
        let end = (if ($s.index + 1) < ($starts | length) { $starts | get ($s.index + 1) } else { $lines | length })
        frame-of ($lines | slice $s.item..<$end) $dir
    }
}

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
            if ($mine | get context) == (0..<$CONTEXTS | each {|c| $c }) { accounting $frame $s $mine $dir.planes_below } else { [] }
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

# The records a whole frame holds between its frame and end lines, in
# order: each side the directory names, its line, then its contexts
def expected-shape [dir: record]: nothing -> list<string> {
    $dir.sides | each {|d| [$"side ($d.side)"] | append (0..<$CONTEXTS | each {|c| $"side ($d.side) context ($c)" }) } | flatten
}

# What keeps a frame's records from the whole frame's: those missing,
# those repeated, those the directory does not name, else the first out of
# its order
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

# A context's list against the directory: each surface one it holds, once
# in the list, its count at least 1
def surface-reasons [l: record, surfaces: int]: nothing -> list<string> {
    let ids = ($l.pairs | get surface)
    [
        ($l.pairs | where surface >= $surfaces | each {|p| $"side ($l.side) context ($l.context) lists surface ($p.surface), past the directory's surfaces ($surfaces)" })
        ($ids | uniq --repeated | each {|s| $"side ($l.side) context ($l.context) lists surface ($s) twice" })
        ($l.pairs | where count < 1 | each {|p| $"side ($l.side) context ($l.context) lists surface ($p.surface) with a count under 1" })
    ] | flatten
}

# A side's counts against the relations census.S keeps among them, for a
# frame with nothing dropped and the side's contexts whole: every block
# eligible, straddling, or outside; a request an eligible passing block; a
# context's distinct tiles among its requests; the demand within its
# contexts' distinct tiles; a tile of one surface, its classes its
# surface's, a plane's one and a wall's the walls or the openings or both;
# a demanded tile sampled; a check, a mismatch, and a uniform verdict once
# a demanded tile, a checked tile the sampler kept uniform counted
# uniform; the side's surfaces its contexts'; the window this frame the
# demand, by the surface's class, each window the planes' and walls' sum,
# a longer window holding a shorter's; the listed tiles of each class
# covering its window this frame
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

# A list's surface:count pairs, the text after a head's semicolon or a
# continuation's colon, and every item that is no such pair
def pairs-of [items: string]: nothing -> record<pairs: list<record<surface: int, count: int>>, bad: list<string>> {
    let words = ($items | split row " " | where {|w| $w != "" })
    let bad = ($words | where {|w| not ($w =~ '^\d+:\d+$') })
    let pairs = ($words | where {|w| $w =~ '^\d+:\d+$' } | each {|w|
        let p = ($w | split row ":")
        { surface: ($p.0 | into int), count: ($p.1 | into int) }
    })
    { pairs: $pairs, bad: ($bad | each {|w| $"an item that is no surface:count pair: ($w)" }) }
}

def total [pairs: list<record<surface: int, count: int>>]: nothing -> int {
    if ($pairs | is-empty) { 0 } else { $pairs | get count | math sum }
}

def total-of [values: list<int>]: nothing -> int {
    if ($values | is-empty) { 0 } else { $values | math sum }
}
