# The census reader's own fixtures (census.nu), apart from the launch so
# they run on any capture a census build wrote; census-holds calls them on
# its run's log.
use ./census.nu
use std/assert

# The census reader's refusals (census.nu): a capture's log read whole,
# every frame valid but a last one the run's end cut; then one frame of
# it, with planes and walls demanded at every side and side 32's last
# context continued, altered each way a frame can break and read alone
# with the directory, each alteration refused with its own reason: the
# frame read without the directory; a continuation dropped, and one moved
# past the next side's line; a side's lines and a context's removed; the frame reduced to
# its frame and end lines; a side line and a context head repeated; a
# side's lines and a context's moved past the next one's; a side the
# directory does not name; a surface past the directory's, one twice in a
# list, and a count under 1; and one count moved past each relation
# census.S keeps among a side's counts. The log alone, no launch, so it
# runs on any capture a census build wrote.
export def census-reader-holds [serial: string]: nothing -> nothing {
    let read = (census frames $serial)
    let cut = ($read | enumerate | where {|e| not $e.item.ended } | get index)
    assert ($cut | all {|i| $i == (($read | length) - 1) }) $"only the log's last frame cut by the run's end: frames ($cut) of ($read | length)"
    let frames = ($read | where ended)
    let invalid = ($frames | where {|f| not $f.valid })
    assert ($invalid | is-empty) $"every census frame whole and accounting: ($invalid | first 3 | select frame reasons)"
    let directory = (census directory $serial)
    assert ($directory != null) "the census's directory after the load"
    let directory_line = ($serial | lines | where {|l| $l starts-with "fps: census directory: " } | first)
    let pick = ($frames | where {|f|
        let lit = ($f.sides | all {|s| $s.planes > 0 and $s.walls > 0 })
        let last = ($f.sides | where side == 32 | get 0.contexts | last)
        $lit and ($last.chunks > 1)
    } | get -o 0)
    assert ($pick != null) "a frame to break: planes and walls demanded at every side, side 32's last context continued"
    let lines = ($serial | lines | skip until {|l| $l starts-with $"fps: census frame ($pick.frame):" } | take until {|l| $l == $"fps: census end ($pick.frame)" } | append $"fps: census end ($pick.frame)")
    let s = ($pick.sides | where side == 32 | get 0)
    let busy = ($s.contexts | sort-by {|c| $c.pairs | length } | last)
    let side_line = ($lines | where {|l| $l starts-with "fps: census 32: " } | first)
    let busy_head = ($lines | where {|l| $l starts-with $"fps: census 32 context ($busy.context): " } | first)
    let requests = ($s.contexts | get requests | math sum)
    let distinct = ($s.contexts | get distinct | math sum)
    let greatest = ($s.contexts | get distinct | math max)
    let listed_planes = ($s.contexts | get pairs | flatten | where surface < $directory.planes_below | get count | math sum)
    let block = {|prefix: string| $lines | where {|l| $l starts-with $prefix } }
    let without = {|prefix: string| $lines | where {|l| not ($l starts-with $prefix) } }
    let at = {|line: string| $lines | enumerate | where {|e| $e.item == $line } | get 0.index }
    let side_set = {|field: string, v: int| $lines | each {|l| if $l == $side_line { census-side-set $l $field $v } else { $l } } }
    let frame_set = {|field: string, v: int| $lines | each {|l| if $l == ($lines | first) { census-side-set $l $field $v } else { $l } } }
    let head_set = {|field: string, v: int| $lines | each {|l| if $l == $busy_head { census-side-set $l $field $v } else { $l } } }
    let last_context = ($s.contexts | last | get context)
    let more_at = ($lines | enumerate | where {|e| $e.item starts-with $"fps: census 32 context ($last_context) more:" } | get 0.index)
    let first_line = ($lines | first)
    let end_line = ($lines | last)
    let moved = ($lines | drop nth $more_at)
    let next_side = ($moved | enumerate | where {|e| $e.item starts-with "fps: census 64: " } | get 0.index)
    let cases = [
        { name: "a frame read without the directory", bare: true, lines: $lines, reason: "no census directory" }
        { name: "a continuation dropped", lines: $moved, reason: "does not reassemble" }
        { name: "a continuation moved past the next side's line", lines: ($moved | insert ($next_side + 1) ($lines | get $more_at)), reason: "not after its head or its continuations" }
        { name: "a side's lines removed", lines: (do $without "fps: census 64"), reason: "missing: side 64" }
        { name: "a context's lines removed", lines: (do $without "fps: census 32 context 1"), reason: "missing: side 32 context 1" }
        { name: "the frame reduced to its frame and end lines", lines: [$first_line $end_line], reason: "missing: side 32" }
        { name: "a side line repeated", lines: ($lines | insert ((do $at $side_line) + 1) $side_line), reason: "repeated: side 32" }
        { name: "a context head repeated", lines: ($lines | insert ((do $at $side_line) + 1) ($lines | where {|l| $l starts-with "fps: census 32 context 0: " } | first)), reason: "repeated: side 32 context 0" }
        { name: "a side's lines moved past the next side's", lines: ([$first_line] | append (do $block "fps: census 64") | append (do $block "fps: census 32") | append (do $block "fps: census 128") | append $end_line), reason: "out of order" }
        { name: "a context's lines moved past the next context's", lines: ([$first_line $side_line] | append (do $block "fps: census 32 context 1") | append (do $block "fps: census 32 context 0") | append (do $block "fps: census 32 context 2") | append (do $block "fps: census 64") | append (do $block "fps: census 128") | append $end_line), reason: "out of order" }
        { name: "a side the directory does not name", lines: ($lines | each {|l| $l | str replace "fps: census 128" "fps: census 256" }), reason: "unexpected: side 256" }
        { name: "a surface past the directory's", lines: (census-pair-put $lines 32 $busy.context 0 {|surface, count| $"($directory.surfaces):($count)" }), reason: "past the directory's surfaces" }
        { name: "a surface twice in a list", lines: (census-pair-put $lines 32 $busy.context 1 {|surface, count| $"($busy.pairs.0.surface):($count)" }), reason: "twice" }
        { name: "a count under 1", lines: (census-pair-put $lines 32 $busy.context 0 {|surface, count| $"($surface):0" }), reason: "with a count under 1" }
        { name: "the blocks unsummed", lines: (do $side_set eligible ($s.eligible + 1)), reason: "not the frame's" }
        { name: "requests past the eligible", lines: (do $side_set eligible ($requests - 1)), reason: "eligible blocks" }
        { name: "requests past the passing", lines: (do $frame_set passing ($requests - 1)), reason: "past the frame's" }
        { name: "distinct tiles past requests", lines: (do $head_set requests ($busy.distinct - 1)), reason: "distinct tiles pass its" }
        { name: "requests and distinct tiles apart", lines: (do $head_set requests 0), reason: "not zero together" }
        { name: "the demand under a context's", lines: (do $side_set demand ($greatest - 1)), reason: "under a context's" }
        { name: "the demand past the contexts'", lines: (do $side_set demand ($distinct + 1)), reason: "past its contexts'" }
        { name: "the classes past the demand", lines: (do $side_set planes $s.demand), reason: "with the greater of walls and openings" }
        { name: "the demand past the classes", lines: (do $side_set demand ($s.planes + $s.walls + $s.openings + 1)), reason: "walls, and openings together" }
        { name: "the demand past the sampled", lines: (do $side_set sampled ($s.demand - 1)), reason: "sampled tiles" }
        { name: "checked past the demand", lines: (do $side_set checked ($s.demand + 1)), reason: "checked tiles past" }
        { name: "mismatches past checked", lines: (do $side_set mismatches ($s.checked + 1)), reason: "mismatches past" }
        { name: "uniform past the demand", lines: (do $side_set uniform ($s.demand + 1)), reason: "uniform tiles past" }
        { name: "uniform under checked less mismatches", lines: (do $side_set checked ($s.uniform + $s.mismatches + 1)), reason: "under its checked tiles less mismatches" }
        { name: "the surfaces not the lists'", lines: (do $side_set surfaces ($s.surfaces + 1)), reason: "requesting surfaces not the" }
        { name: "the whole working set not the demand", lines: (do $side_set w1 ($s.w1 + 1)), reason: "whole working set this frame" }
        { name: "the planes' working set not the planes", lines: (do $side_set p1 ($s.p1 + 1)), reason: "planes' working set this frame" }
        { name: "the walls' working set not the demand less the planes", lines: (do $side_set q1 ($s.q1 + 1)), reason: "walls' working set this frame" }
        { name: "a window not its classes' sum", lines: (do $side_set w30 ($s.w30 + 1)), reason: "not its planes' and walls'" }
        { name: "a window falling", lines: ($lines | each {|l| if $l == $side_line { census-side-set (census-side-set (census-side-set $l w30 ($s.w1 - 1)) p30 ($s.p1 - 1)) q30 $s.q1 } else { $l } }), reason: "falling over the windows" }
        { name: "the lists short of the windows", lines: (do $side_set p1 ($listed_planes + 1)), reason: "short of its working sets" }
        { name: "passing past the blocks", lines: (do $frame_set passing ($pick.blocks + 1)), reason: "passing blocks past its" }
    ]
    for c in $cases {
        let head = (if ($c.bare? | default false) { [] } else { [$directory_line] })
        let f = (census frames ($head | append $c.lines | str join (char nl)) | first)
        assert (not $f.valid) $"the census reader refuses ($c.name)"
        assert ($f.reasons | any {|r| $r | str contains $c.reason }) $"the census reader refuses ($c.name) for it: ($f.reasons | first 4)"
    }
}

# A census line with one of its counts set to `v`, the line otherwise as
# it was: a frame line's blocks or passing, a side line's counts, or a
# context head's requests or distinct tiles
def census-side-set [line: string, field: string, v: int]: nothing -> string {
    let patterns = {
        blocks: '(blocks )\d+(, passing)'
        passing: '(passing )\d+(, dropped)'
        requests: '(requests )\d+(, distinct)'
        eligible: '(eligible )\d+( blocks)'
        demand: '(demand )\d+(: planes)'
        planes: '(: planes )\d+(, walls \d+, openings)'
        sampled: '(sampled )\d+(, uniform)'
        uniform: '(uniform )\d+(, checked)'
        checked: '(checked )\d+(, mismatches)'
        mismatches: '(mismatches )\d+(, surfaces)'
        surfaces: '(, surfaces )\d+(; working)'
        w1: '(working )\d+(, \d+, \d+: planes)'
        w30: '(working \d+, )\d+(, \d+: planes)'
        p1: '(: planes )\d+(, \d+, \d+, walls)'
        p30: '(: planes \d+, )\d+(, \d+, walls)'
        q1: '(, walls )\d+(, \d+, \d+$)'
        q30: '(, walls \d+, )\d+(, \d+$)'
    }
    $line | str replace --regex ($patterns | get $field) ('${1}' + ($v | into string) + '${2}')
}

# A census frame's lines with the nth surface:count pair of a side and
# context's list, over its head and continuations, rewritten by `put`
# from its surface and count
def census-pair-put [lines: list<string>, side: int, context: int, nth: int, put: closure]: nothing -> list<string> {
    mut seen = 0
    mut out = []
    for line in $lines {
        if not ($line starts-with $"fps: census ($side) context ($context)") {
            $out = ($out | append $line)
            continue
        }
        let cut = (if ($line | str contains " more:") { ($line | str index-of " more:") + 6 } else { ($line | str index-of ";") + 1 })
        mut words = []
        for w in ($line | str substring $cut.. | split row " ") {
            if ($w =~ '^\d+:\d+$') and $seen == $nth {
                let p = ($w | split row ":")
                $words = ($words | append (do $put ($p.0 | into int) ($p.1 | into int)))
            } else {
                $words = ($words | append $w)
            }
            if ($w =~ '^\d+:\d+$') { $seen = $seen + 1 }
        }
        $out = ($out | append (($line | str substring 0..<$cut) + ($words | str join " ")))
    }
    $out
}
