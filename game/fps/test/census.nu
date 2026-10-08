# The census's lines, a CENSUS build's (census.S), read off a run's
# serial log: the directory after the load, the clamped edge's two
# verdicts, and every frame with its sides and each context's requesting
# surfaces reassembled from its chunks. A frame stands valid when none of
# its blocks was dropped and every context's list reassembles: its chunks
# in order after its head, as many surfaces as the head lists, their
# counts summing to its distinct tiles.

const FRAME = "fps: census frame {frame}: blocks {blocks}, passing {passing}, dropped {dropped}, lighting {lighting}, chunk {chunk}"
const SIDE = "fps: census {side}: eligible {eligible} blocks {eligible_pixels} pixels, straddling {straddling} blocks {straddling_pixels} pixels, outside {outside}; demand {demand}: planes {planes}, walls {walls}, openings {openings}; sampled {sampled}, uniform {uniform}, checked {checked}, mismatches {mismatches}, surfaces {surfaces}; working {w1}, {w30}, {w120}: planes {p1}, {p30}, {p120}, walls {q1}, {q30}, {q120}"
const HEAD = "fps: census {side} context {context}: requests {requests}, distinct {distinct}, surfaces {listed};{items}"
const MORE = "fps: census {side} context {context} more:{items}"
const DIRECTORY = "fps: census directory: {maps} maps, planes below {planes_below} of {surfaces}; {sides}"
const EDGE = "fps: census edge: nodes {nodes}, sampler {sampler}"
const END = "fps: census end {frame}"

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

# Every census frame of a serial log in order: its counts, the lighting's
# revision and the context lines' chunk in force, its sides with each
# context's list reassembled, and whether it stands valid, with the
# reasons it does not
export def frames [serial: string]: nothing -> list<record> {
    let lines = ($serial | lines | where {|l| ($l starts-with "fps: census ") and not ($l starts-with "fps: census directory: ") and not ($l starts-with "fps: census edge: ") })
    let starts = ($lines | enumerate | where {|e| $e.item starts-with "fps: census frame " } | get index)
    $starts | enumerate | each {|s|
        let end = (if ($s.index + 1) < ($starts | length) { $starts | get ($s.index + 1) } else { $lines | length })
        frame-of ($lines | slice $s.item..<$end)
    }
}

def frame-of [lines: list<string>] {
    let parsed = ($lines | first | parse $FRAME)
    if ($parsed | is-empty) {
        return { frame: null, blocks: null, passing: null, dropped: null, lighting: null, chunk: null, sides: [], ended: false, valid: false, reasons: [$"a frame line the census does not write: ($lines | first)"] }
    }
    let frame = ($parsed | get 0 | update cells {|c| $c | into int })
    mut sides = []
    mut listings = []
    mut problems = []
    mut ended = false
    for line in ($lines | skip 1) {
        let end = ($line | parse $END)
        if not ($end | is-empty) {
            if (($end | get 0.frame) != ($frame.frame | into string)) or $ended {
                $problems = ($problems | append $"an end line not this frame's: ($line)")
            }
            $ended = true
            continue
        }
        if $ended {
            $problems = ($problems | append $"a line after the frame's end: ($line)")
            continue
        }
        let side = ($line | parse $SIDE)
        if not ($side | is-empty) {
            $sides = ($sides | append ($side | get 0 | update cells {|c| $c | into int }))
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
            continue
        }
        let more = ($line | parse $MORE)
        if not ($more | is-empty) {
            let m = ($more | get 0)
            let side = ($m.side | into int)
            let context = ($m.context | into int)
            let items = (pairs-of $m.items)
            $problems = ($problems | append $items.bad)
            let open = (if ($listings | is-empty) { null } else { $listings | last })
            let continues = (if $open == null { false } else { ($open.side == $side) and ($open.context == $context) })
            if $continues {
                let joined = ($open | update pairs ($open.pairs | append $items.pairs) | update chunks ($open.chunks + 1))
                $listings = ($listings | drop 1 | append $joined)
            } else {
                $problems = ($problems | append $"a continuation of side ($side) context ($context) with no head before it")
            }
            continue
        }
        $problems = ($problems | append $"a line the census does not write: ($line)")
    }
    let unassembled = ($listings | where {|l| (($l.pairs | length) != $l.listed) or ((total $l.pairs) != $l.distinct) })
    let dropped = (if $frame.dropped > 0 { [$"($frame.dropped) blocks dropped, the frame incomplete evidence"] } else { [] })
    let cut = (if $ended { [] } else { ["the log ends inside the frame, its end line missing"] })
    let reasons = ($problems
        | append $cut
        | append $dropped
        | append ($unassembled | each {|l| $"the list of side ($l.side) context ($l.context) does not reassemble: ($l.pairs | length) surfaces against ($l.listed) listed, counts summing to (total $l.pairs) against ($l.distinct) distinct" }))
    let listed = $listings
    {
        frame: $frame.frame,
        blocks: $frame.blocks,
        passing: $frame.passing,
        dropped: $frame.dropped,
        lighting: $frame.lighting,
        chunk: $frame.chunk,
        sides: ($sides | each {|s| $s | insert contexts ($listed | where side == $s.side) }),
        ended: $ended,
        valid: ($reasons | is-empty),
        reasons: $reasons,
    }
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
