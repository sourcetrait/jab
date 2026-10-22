use (path self ../../../../../../../nu/mod/launch)
use (path self ../../../console)
use (path self ../../../gauge/measure)
use (path self ../../../picture)
use (path self ../../../pose)
use (path self ../../../gauge/stream)
use std/assert
use (path self ../../../console) [SPAWN_POSE]
use (path self ../../../gauge/stream) [CLOCK_SCHEMA]

# The packet caps the K frame sets: commands and spans
export const PACKET_CAPS = { commands: 7, spans: 500 }

# The O frame's lifted mode bit: quota, allowance, merge share lifted
export const POOL_LIFTED = 1

# The O frame's stale mode bit: an eviction leaving its entries
const POOL_STALE = 4

# The O frame's once mode bit: tiles built at one boundary alone
export const POOL_ONCE = 8

# When the pool fixtures place the view and make their cold start
const POOL_PLACE_AT = 1500ms

# When the pool fixtures' E closes the measurement
const POOL_END_AT = 4500ms

# The rotation's admission: tier, ring, merge share, workers, grain
const POOL_ROTATION = { guarantee: 1, ring: 4, merge_us: 1, workers: 2, grain: 16 }

# The contexts a tier admits in: hart 0's and each secondary slot's
const TILE_CONTEXTS = 8

# The stale fixture's slot cap, under the 272 tiles the view asks
export const POOL_STALE_SLOTS = 64

# When the pool fixtures' capture ends the run, past the E
const POOL_CAPTURE_AT = 5000ms

# The pool's traced passes by frame: surfaces requesting, merged, built
def pool-trace [serial: string]: nothing -> table<frame: int, requesting: list<int>, merged: list<record<surface: int, keys: int>>, built: list<int>> {
    let parsed = ($serial | lines | where {|l| $l starts-with "fps: tile pass " } | parse "fps: tile pass {frame} {kind}:{items}" | update frame {|r| $r.frame | into int })
    $parsed | group-by frame | items {|frame, rows|
        let of = {|kind: string| $rows | where kind == $kind | get items | each {|i| $i | str trim | split row " " | where {|w| $w != "" } } | flatten }
        {
            frame: ($frame | into int),
            requesting: (do $of "requesting" | each {|w| $w | into int }),
            merged: (do $of "merged" | each {|w| let p = ($w | split row ":"); { surface: ($p.0 | into int), keys: ($p.1 | into int) } }),
            built: (do $of "built" | each {|w| $w | into int }),
        }
    } | sort-by frame
}

# Pool fixtures from cold starts: rotation, first sight, rings, stale entries
export def pool-holds [kernel: path, image: path, out: path, set: string, disk: path, lit: binary]: nothing -> record<rotation_surfaces: int, rotation_wait: int, sight_frames: int, sight_slots: int, rings_merged: int, stale_evicted: int> {
    let launch = {|name: string, sends: list<any>|
        let all = ($sends | append [{ at: $POOL_PLACE_AT, bytes: (pose pose-frame $SPAWN_POSE) }, { at: $POOL_END_AT, bytes: (pose command-frame "E") }] | sort-by at)
        let run = (launch --kernel $kernel --image $image --out ($out | path join $"pool_($name)") --set $set --sound --api --disk $disk --serial "fps" --send $all --capture $POOL_CAPTURE_AT --seconds 7)
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on the pool's ($name)"
        let m = (measure $run.api [{ name: "start", places: [], pad: [] }, { name: "sight", places: [$SPAWN_POSE], pad: [] }])
        assert ($m.complete and $m.valid and $m.schema == $CLOCK_SCHEMA) $"the pool's ($name) complete and valid at schema ($CLOCK_SCHEMA): ($m.problems | str join '; ') ($m.invalid | str join '; ')"
        assert ($m.rows | any {|r| $r.leg == "sight" }) $"the pool's ($name) placed its view"
        let cold = ((stream $run.api).configs | last | get from)
        assert ($cold > 0) $"the pool's ($name) cold start a configuration of its own: from ($cold)"
        { run: $run, rows: ($m.rows | where {|r| $r.frame >= $cold }), cold: $cold }
    }
    let settled = {|r| $r.missed_blocks == 0 and $r.building == 0 and $r.admitted == 0 and $r.dropped == 0 and $r.filtered == 0 and $r.tiles_built == 0 }

    let rotation = (do $launch "rotation" [
        { at: 1300ms, bytes: (console workers $POOL_ROTATION.workers $POOL_ROTATION.grain) }
        { at: 1300ms, bytes: (console packet $PACKET_CAPS.commands $PACKET_CAPS.spans) }
        { at: $POOL_PLACE_AT, bytes: (console pool --trace --cold --guarantee $POOL_ROTATION.guarantee --ring $POOL_ROTATION.ring --merge-us $POOL_ROTATION.merge_us) }
    ])
    let passes = (pool-trace $rotation.run.serial | where {|p| $p.frame > $rotation.cold })
    assert (($passes | length) > 0) $"the pool's trace printed the rotation's passes: ($rotation.run.serial | lines | last 3)"
    let most = ($passes | each {|p| $p.requesting | length } | math max)
    let last_pass = ($passes | last | get frame)
    let waits = ($passes | get requesting | flatten | uniq | each {|s|
        let asked = ($passes | where {|p| $s in $p.requesting } | get 0.frame)
        let built = ($passes | where {|p| $p.frame >= $asked and $s in $p.built } | get -o 0.frame)
        { surface: $s, asked: $asked, built: $built }
    } | where {|w| $w.asked + $most < $last_pass })
    let late = ($waits | where {|w| $w.built == null or ($w.built - $w.asked) > $most })
    assert ($late | is-empty) $"every surface requesting under the rotation built within ($most) frames of its first request, the most one pass found: ($late | first 5)"
    let starts = ($passes | where {|p| ($p.merged | length) > 0 })
    let repeated = ($starts | window 2 | where {|w|
        let left = ($w.0.requesting | where {|s| $s not-in ($w.0.merged | get surface) })
        ($w.1.requesting | length) >= 2 and $w.0.merged.0.surface == $w.1.merged.0.surface and ($left | is-not-empty)
    })
    assert ($repeated | is-empty) $"the merge's start moved on at every pass after one that left a requesting surface unmerged: ($repeated | first 2 | each {|w| $w.1.frame })"
    let over = ($passes | each {|p| $p.merged | where {|m| $m.keys > ($POOL_ROTATION.guarantee * $TILE_CONTEXTS) } | each {|m| { frame: $p.frame, merged: $m } } } | flatten)
    assert ($over | is-empty) $"no surface merged past its tier of ($POOL_ROTATION.guarantee) in every context across the bands and the flushes: ($over | first 3)"
    let rotated = ($rotation.rows | where {|r| $r.frame > $rotation.cold })
    assert ($rotated | any {|r| $r.dropped > 0 }) "the rotation's open ring of four overflowed"
    assert ($rotated | any {|r| $r.unprocessed > 0 }) "the rotation's merge stopped short at its share"

    let sight = (do $launch "sight" [{ at: $POOL_PLACE_AT, bytes: (console pool --cold) }])
    let first = ($sight.rows | first)
    assert ($first.missed_blocks > 0 and $first.admitted > 0 and $first.tiles_built == 0 and $first.slots_used == 0) $"first sight drew blocks without their tiles from an empty pool and asked for them: ($first | select frame missed_blocks admitted tiles_built slots_used)"
    let settled_at = ($sight.rows | where {|r| do $settled $r } | get -o 0.frame)
    assert ($settled_at != null) $"first sight settled under the ordinary budget: ($sight.rows | last | select frame missed_blocks admitted building tiles_built)"
    let unsettled = ($sight.rows | where {|r| $r.frame >= $settled_at and not (do $settled $r) })
    assert ($unsettled | is-empty) $"the view settled from frame ($settled_at) on: ($unsettled | first 3 | select frame missed_blocks admitted tiles_built)"
    let holds = ($sight.rows | where frame == $settled_at | get 0.slots_used)
    let built = ($sight.rows | where {|r| $r.frame <= $settled_at } | get tiles_built | math sum)
    assert ($built == $holds and ($sight.rows | all {|r| $r.evicted == 0 })) $"the ($built) tiles built to settling the ($holds) slots the view holds, none evicted"

    let rings = (do $launch "rings" [{ at: $POOL_PLACE_AT, bytes: (console pool --modes $POOL_LIFTED --cold --guarantee 1) }])
    let cold = ($rings.rows | get 0)
    let warming = ($rings.rows | get 1)
    let after = ($rings.rows | get 2)
    assert ($cold.missed_blocks > 0 and $cold.admitted > 0) $"the rings' cold start asked for the view's tiles: ($cold | select frame missed_blocks admitted)"
    assert ($warming.batch_admitted == $cold.admitted and $warming.unprocessed == 0 and $warming.tiles_built == $warming.merged and $warming.merged > 0) $"the warming frame merged every request the frame before made and built every key merged: ($warming | select frame batch_admitted merged unprocessed tiles_built)"
    assert ($warming.merged > ($warming.requesting * $TILE_CONTEXTS)) $"the warming frame merged past what tiers of one request hold, the open rings merged: ($warming.merged) keys for ($warming.requesting) surfaces"
    assert ($warming.admitted == 0 and $warming.missed_blocks == 0) $"the warming frame drew every block from its tile and asked for none: ($warming | select frame admitted missed_blocks)"
    assert (do $settled $after) $"the view settled at the frame after the warming frame: ($after | select frame missed_blocks admitted building tiles_built)"

    let stale = (do $launch "stale" [
        { at: 1400ms, bytes: (console level true false) }
        { at: $POOL_PLACE_AT, bytes: (console pool --modes ($POOL_LIFTED + $POOL_STALE) --cold --slots $POOL_STALE_SLOTS) }
    ])
    let held = ($stale.rows | where {|r| $r.frame > $stale.cold })
    assert ($held | all {|r| $r.config_flags == ($POOL_LIFTED + $POOL_STALE) and $r.slots_effective == $POOL_STALE_SLOTS }) $"the stale entries' run under the lift and the stale mode on ($POOL_STALE_SLOTS) slots: ($held | first | select config_flags slots_effective)"
    let evicted = ($held | get evicted | math sum)
    assert ($evicted > 0) $"the stale entries' run evicted under its cap: ($held | first 3 | select frame tiles_built evicted slots_used)"
    assert ($stale.run.screen != "") "a screen was taken on the stale entries' run"
    let stale_rows = (picture rows-differ (open --raw $stale.run.screen | into binary) $lit [0 0 1920 1080])
    assert ($stale_rows | is-empty) $"the stale entries read no tile: the bright spawn view on ($POOL_STALE_SLOTS) slots, ($evicted) tiles evicted with their entries left, the lit loop's picture: rows ($stale_rows | first 5) differ, ($stale_rows | length) in all"
    {
        rotation_surfaces: $most, rotation_wait: ($waits | each {|w| $w.built - $w.asked } | math max),
        sight_frames: ($settled_at - $sight.cold), sight_slots: $holds, rings_merged: $warming.merged,
        stale_evicted: $evicted,
    }
}
