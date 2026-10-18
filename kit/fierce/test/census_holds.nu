# The census fixture's reading of a census build's log (census.nu), apart
# from the launch so it runs on any capture a census build wrote;
# census-holds calls it on its run's log in a nu of its own, since
# test.nu's modules loaded around it slow every closure about tenfold.
use ./census.nu
use std/assert

# The census fixture's reading of its run's log (test.nu's census-holds),
# its line returned: the clamped edge's case at the load, a tile past a
# map's last node read shaded by its nodes and by lumel_sample, where nodes
# clamped to the last column alone read it uniform; every frame valid as
# census.nu reads it, whole and accounting; the directory counting hart 0's
# context and a slot's each, `slots` of them, and every worker's context
# drawn into, hart 0's not; the `shrunk` chunk splitting every list of two
# surfaces or more and the build's own bound splitting none; planes and
# walls both demanded; the lighting's revisions in order, no tile uniform
# by its nodes and not by lumel_sample, the ordinary light's uniform tiles
# checked, every demanded tile uniform and checked in a full bright
# revision's first frame and uniform through it, none uniform or checked
# under the parity; and the log read whole (census-reader-holds).
export def census-fixture-holds [serial: string, shrunk: int, slots: int]: nothing -> string {
    # the clamped edge: a 3 by 3 map whose last column's nodes are alike
    # and whose penultimate column's last node is a level under, a tile at
    # level 1 past the last node, which lumel_sample reads through the
    # penultimate cell; its nodes from the sampler's clamp and the sampler
    # itself both find it shaded
    let edge = (census edge $serial)
    assert ($edge != null) "the clamped edge's line after the load"
    assert (not $edge.skipped) $"the clamped edge's case ran: ($edge)"
    assert equal $edge.nodes 0 $"the tile past the last node shaded by its nodes, the penultimate column's in reach as lumel_sample clamps: ($edge)"
    assert equal $edge.sampler 0 $"the tile past the last node shaded at lumel_sample's texel centres: ($edge)"

    let directory = (census directory $serial)
    assert ($directory != null) "the census's directory after the load"
    assert ($directory.maps > 0 and $directory.planes_below > 0 and $directory.surfaces > $directory.planes_below) $"the directory's maps and surfaces: ($directory)"
    let read = (census frames $serial)
    let cut = ($read | enumerate | where {|e| not $e.item.ended } | get index)
    assert ($cut | all {|i| $i == (($read | length) - 1) }) $"only the log's last frame cut by the run's end: frames ($cut) of ($read | length)"
    let frames = ($read | where ended)
    assert (($frames | length) > 50) $"census frames through the run: ($frames | length)"
    let invalid = ($frames | where {|f| not $f.valid })
    assert ($invalid | is-empty) $"every census frame whole and accounting: ($invalid | first 3 | select frame reasons)"
    let lists = {|fs: list| $fs | each {|f| $f.sides | each {|s| $s.contexts } | flatten } | flatten }

    # the contexts: the directory counting hart 0's and a slot's each, and
    # every worker's drawn into
    assert equal $directory.contexts ($slots + 1) $"the directory counting hart 0's context and a slot's each: ($directory.contexts)"
    let drawing = (do $lists $frames | where requests > 0 | get context | uniq | sort)
    assert equal $drawing (1..$slots | each {|c| $c }) $"the workers' contexts drawn into, hart 0's not: ($drawing)"

    # the line's bound: the shrunk chunk splits every list of two surfaces
    # or more, each reassembled whole, and the build's own bound none here
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

    # the lighting: the revisions in order, no tile its nodes call uniform
    # that lumel_sample does not, the ordinary light's uniform tiles
    # checked, every demanded tile uniform and checked in a full bright
    # revision's first frame and uniform through it, none under the parity
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

# The census reader on a capture's log (census.nu): the log read whole,
# every frame valid but a last one the run's end cut, and the directory
# present. The log alone, no launch, so it runs on any capture a census
# build wrote, of either directory format.
export def census-reader-holds [serial: string]: nothing -> nothing {
    let read = (census frames $serial)
    let cut = ($read | enumerate | where {|e| not $e.item.ended } | get index)
    assert ($cut | all {|i| $i == (($read | length) - 1) }) $"only the log's last frame cut by the run's end: frames ($cut) of ($read | length)"
    let frames = ($read | where ended)
    let invalid = ($frames | where {|f| not $f.valid })
    assert ($invalid | is-empty) $"every census frame whole and accounting: ($invalid | first 3 | select frame reasons)"
    let directory = (census directory $serial)
    assert ($directory != null) "the census's directory after the load"
}
