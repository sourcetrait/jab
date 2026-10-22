use (path self ../../../../../../nu/mod/launch)
use (path self ../../console)
use (path self ../../picture)
use (path self ../../gauge/stream)
use std/assert
use (path self ../../console) [SPAWN_POSE]
use (path self ../../frame) [CRACKS FRAME]
use (path self ./handoff) [HANDOFF_EARLY]
use (path self ./pool) [PACKET_CAPS POOL_STALE_SLOTS pool-holds]
export use (path self ./builder) [builder-holds]
export use (path self ./handoff) [handoff-holds]

# A HANDOFF build's tiled-to-lit measurement run alone, its figures printed
export def handoff [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
        let game = $context.game
        let held = (handoff-holds $kernel $image $out $set (open ($game | path join "content" "map" "render_1.nuon")) $game)
        for r in $held.comparisons {
            let i = $r.inner
            let partial = (if $r.kind == "partial" { $", from the nearer of the tiled and the lit ($r.residual.most) at most, ($r.residual.p99) at the 99th, ($r.mixed_rows) rows taking both" } else { "" })
            print $"fps: the handoff ($r.pose), ($r.kind) against lit at level ($r.level) under the ($r.lighting) lumels: ($i.differing) of ($i.pixels) pixels differ, by ($i.most) at most, ($i.p99) at the 99th, ($i.mean | math round --precision 3) on average; past the last node ($r.clamped.pixels) pixels, by ($r.clamped.most) at most; ($r.left_out) left out($partial)"
        }
        for lighting in ($held.reentries | get lighting | uniq) {
            let counted = ($held.reentries | where lighting == $lighting | each {|c| $"level ($c.level) ($c.two) in two blocks, ($c.four) in four, ($c.cut) cut short" } | str join "; ")
            print $"fps: the handoff oblique under the ($lighting) lumels, re-entries on the reported frame: ($counted)"
        }
        let past = ($held.windows | each {|w| $w.stamp - $w.from })
        let e = $held.early
        let lead = ((($e.started - $e.placed) * 1000) | math round --precision 1)
        print $"fps: the handoff's screens: each of ($held.windows | length) runs shows a frame of its settled window, ($past | math min) to ($past | math max) frames past its second placement's, its E after it; the placement due ($HANDOFF_EARLY) before the screen written ($lead) ms before it was asked, its screen (if $e.accepted { 'accepted' } else { 'refused' }) by its stamp, frame ($e.stamp) against the window from ($e.from) to ($e.final)"
    {}
}

# One level a block: the tiled spawn view identical to the tiles held off
export def block [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let still_disk = $records."light independence".still_disk
    mut spawn_captures = {}
    for v in [{ name: "tiled", held: false }, { name: "held", held: true }] {
        let sends = ([{ at: 1400ms, bytes: (console level true $v.held) }] | append (console settled $SPAWN_POSE))
        let run = (launch --kernel $kernel --image $image --out ($out | path join $"spawn_($v.name)") --set $set --sound --api --disk $still_disk --serial "fps" --send $sends --capture 3000ms --seconds 5)
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on the spawn view with the tiles ($v.name)"
        let frames = ($run.serial | lines | where {|l| $l starts-with "fps: frame in" })
        assert equal ($frames | length) 3 $"the first frame and the pose's two placements reported on the spawn view with the tiles ($v.name): ($run.serial)"
        let frame = ($frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
        assert ($frame.uncovered < $CRACKS) $"the spawn view with the tiles ($v.name) has no pixel uncovered: ($frame)"
        assert ($run.screen != "") $"a screen was taken on the spawn view with the tiles ($v.name)"
        $spawn_captures = ($spawn_captures | insert $v.name { bytes: (open --raw $run.screen | into binary), frame: $frame })
    }
    assert ($spawn_captures.tiled.frame.tiled > 0) $"the spawn view read its tiles: ($spawn_captures.tiled.frame)"
    assert ($spawn_captures.held.frame.tiles_built == 0 and $spawn_captures.held.frame.tiled == 0) $"no tile built or read with the tiles held off: ($spawn_captures.held.frame)"
    let spawn_rows = (picture rows-differ $spawn_captures.tiled.bytes $spawn_captures.held.bytes [0 0 1920 1080])
    assert ($spawn_rows | is-empty) $"the spawn view the same whether its tiles are built or held off: rows ($spawn_rows | first 5) differ, ($spawn_rows | length) in all"
    {spawn_captures: $spawn_captures}
}

# Packets capped to a few commands and spans, the picture the uncapped one's
export def packet [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let still_disk = $records."light independence".still_disk
    let spawn_captures = $records."tiles block".spawn_captures
    let capped_sends = ([
        { at: 1300ms, bytes: (console packet $PACKET_CAPS.commands $PACKET_CAPS.spans) }
        { at: 1400ms, bytes: (console level true false) }
    ] | append (console settled $SPAWN_POSE))
    let capped_run = (launch --kernel $kernel --image $image --out ($out | path join "spawn_capped") --set $set --sound --api --disk $still_disk --serial "fps" --send $capped_sends --capture 3000ms --seconds 5)
    assert equal (open --raw $capped_run.qemu_log) "" "QEMU has no complaint about the guest on the spawn view in capped packets"
    let capped_frames = ($capped_run.serial | lines | where {|l| $l starts-with "fps: frame in" })
    assert equal ($capped_frames | length) 3 $"the first frame and the pose's two placements reported on the spawn view in capped packets: ($capped_run.serial)"
    let capped_frame = ($capped_frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
    assert ($capped_frame.flushes > 0) $"the spawn view's packets flushed under the caps: ($capped_frame)"
    assert ($capped_run.screen != "") "a screen was taken on the spawn view in capped packets"
    let capped_rows = (picture rows-differ (open --raw $capped_run.screen | into binary) $spawn_captures.tiled.bytes [0 0 1920 1080])
    assert ($capped_rows | is-empty) $"the spawn view drawn in packets of ($PACKET_CAPS.commands) commands and ($PACKET_CAPS.spans) spans, ($capped_frame.flushes) flushed, the uncapped one's: rows ($capped_rows | first 5) differ, ($capped_rows | length) in all"
    assert equal $capped_frame.rounds ($capped_frame.flushes + 1) $"every render of the capped frame a round of the workers: ($capped_frame)"
    {capped_run: $capped_run}
}

# The pool unchanged across flushes in frames whose boundary built tiles
export def frozen [context: record, records: record]: nothing -> record {
    let capped_run = $records."tiles packet".capped_run
    let capped_stream = (stream $capped_run.api)
    let capped_built = ($capped_stream.draws | where {|d| $d.tiles_built > 0 } | get frame)
    let capped_flushed = ($capped_stream.packets | where {|k| $k.flushes > 0 and $k.frame in $capped_built })
    assert (($capped_flushed | length) > 0) $"frames whose boundary built tiles drawn in flushed packets, the pool held unchanged at every render: tiles built in ($capped_built | length) frames"
    {}
}

# The pool's own fixtures run: the rotation, first sight, the rings
export def pool [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let still_disk = $records."light independence".still_disk
    let spawn_captures = $records."tiles block".spawn_captures
    let pool = (pool-holds $kernel $image $out $set $still_disk $spawn_captures.held.bytes)
    print $"fps: the tile pool: under a tier of one and a ring of four, ($pool.rotation_surfaces) surfaces requesting each built within ($pool.rotation_wait) frames of its first request; first sight settled under the ordinary budget in ($pool.sight_frames) frames on ($pool.sight_slots) slots; the warming frame merged ($pool.rings_merged) keys past tiers of one; ($pool.stale_evicted) tiles evicted on ($POOL_STALE_SLOTS) slots with their entries left, the picture the lit loop's"
    {}
}

# Every builder tile at every level held texel by texel to the host's oracle
export def builder [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let render_1_source = $context.render_1.source
    let game = $context.game
    let builder = (builder-holds $kernel $image $out $set $render_1_source $game)
    print $"fps: the builder: ($builder.tiles) tiles of the fixture's wall at levels 0 to ($builder.levels - 1) about k ($builder.k), its map ($builder.w) by ($builder.h) nodes, every texel the chain's under the bright and within the build's rounding of its centre's light under the gradient and the parity, by level the most a channel lies from it ($builder.by_level | each {|l| $'($l.level): ($l.gradient | math round --precision 2) and ($l.parity | math round --precision 2)' } | str join ', ')"
    {}
}
