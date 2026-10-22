use (path self ../../../../../nu/mod/build)
use (path self ./alpha)
use (path self ./census)
use (path self ./clock)
use (path self ./growth)
use (path self ./light)
use (path self ./load)
use (path self ./render_one)
use (path self ./render_zero)
use (path self ./service)
use (path self ./sound)
use (path self ./tiles)
use (path self ./workers)
use std/assert
use (path self ./light) [VIEW_YAWS]
use (path self ./render_one) [SPRITE_LEFT SPRITE_RIGHT]
use (path self ./render_zero) [FIRED]

# The workspace's root, resolved from this file's own path
const WORKSPACE = path self ../../../../..

# The suite whole: CENSUS and HANDOFF sets first, then every case, report last
export def main [--kernel: path, --image: path, --out: path, --set: string = "", --assets: path = ""]: nothing -> nothing {
    assert (($assets | path exists)) "the sdk built the assets image"
    let base = {kernel: $kernel, image: $image, out: $out, set: $set, assets: $assets, game: ($WORKSPACE | path join "kit" "fierce")}
    if ("CENSUS" in ($set | split row ",")) {
        census holds $base {}
        print "fps: ok"
        return
    }
    if ("HANDOFF" in ($set | split row ",")) {
        tiles handoff $base {}
        print "fps: ok"
        return
    }
    if ("SERVICE" in ($set | split row ",")) {
        let held = (service holds (context $base) {})
        print $"fps: the service: the ring's ($held.order.stores) index stores and ($held.order.loads) loads fenced; ($held.loads | columns | each {|n| let l = ($held.loads | get $n); $'($n) ($l.end.applied) applied and ($l.end.dropped) dropped of ($l.end.offered) over ($l.boundaries) boundaries' } | str join '; '); sequence ($held.corrupt.rejected) rejected at frame ($held.corrupt.frame); stopped mid-quota at ($held.cancel.offered) offered, ($held.cancel.skipped) quotas skipped; forced with ($held.forced.discarded) discarded; refused on three harts through ($held.refusal.frames) frames"
        print "fps: ok"
        return
    }
    mut results = {}
    $results = ($results | insert "load release" (load release $base {}))
    let ctx = (context $base)

    $results = ($results | insert "load title" (load title $ctx {}))
    $results = ($results | insert "render_one plain" (render_one plain $ctx {}))
    $results = ($results | insert "load first-frames" (load first-frames $ctx ($results | select "render_one plain")))
    $results = ($results | insert "workers started" (workers started $ctx ($results | select "render_one plain")))
    $results = ($results | insert "render_one sprite" (render_one sprite $ctx ($results | select "render_one plain")))
    $results = ($results | insert "alpha at-load" (alpha at-load $ctx ($results | select "render_one sprite")))
    $results = ($results | insert "render_one straddle" (render_one straddle $ctx ($results | select "render_one plain")))
    $results = ($results | insert "render_one poses" (render_one poses $ctx {}))
    $results = ($results | insert "sound assets" (sound assets $ctx ($results | select "render_one poses")))
    $results = ($results | insert "render_one launched" (render_one launched $ctx ($results | select "render_one poses")))
    $results = ($results | insert "clock receipts" (clock receipts $ctx ($results | select "render_one launched")))
    $results = ($results | insert "render_one loaded" (render_one loaded $ctx ($results | select "render_one launched" "render_one poses")))
    $results = ($results | insert "sound soundfont" (sound soundfont $ctx ($results | select "render_one loaded" "render_one launched")))
    $results = ($results | insert "sound heard" (sound heard $ctx ($results | select "render_one launched")))
    $results = ($results | insert "render_one frames" (render_one frames $ctx ($results | select "render_one loaded" "render_one poses" "render_one launched")))
    $results = ($results | insert "render_one spawn" (render_one spawn $ctx ($results | select "render_one frames" "render_one poses")))
    $results = ($results | insert "alpha grate" (alpha grate $ctx ($results | select "render_one loaded")))
    $results = ($results | insert "render_one mips" (render_one mips $ctx ($results | select "render_one loaded" "render_one poses")))
    $results = ($results | insert "render_one light" (render_one light $ctx ($results | select "render_one launched")))
    $results = ($results | insert "render_one stair" (render_one stair $ctx ($results | select "render_one launched" "render_one poses")))
    $results = ($results | insert "render_zero poses" (render_zero poses $ctx {}))
    $results = ($results | insert "render_zero launched" (render_zero launched $ctx ($results | select "render_zero poses")))
    $results = ($results | insert "render_zero traces" (render_zero traces $ctx ($results | select "render_zero launched" "render_zero poses")))
    $results = ($results | insert "render_zero crosshair" (render_zero crosshair $ctx ($results | select "render_zero launched" "render_zero poses")))
    $results = ($results | insert "alpha fence" (alpha fence $ctx ($results | select "render_zero launched")))
    $results = ($results | insert "render_zero mips" (render_zero mips $ctx ($results | select "render_zero launched" "render_zero poses")))
    $results = ($results | insert "render_zero walk" (render_zero walk $ctx ($results | select "render_zero launched" "render_zero poses")))
    $results = ($results | insert "clock walk" (clock walk $ctx ($results | select "render_zero walk")))
    $results = ($results | insert "clock cadences" (clock cadences $ctx {}))
    $results = ($results | insert "render_zero fight" (render_zero fight $ctx ($results | select "render_zero launched")))
    $results = ($results | insert "service regression" (service regression $ctx ($results | select "render_zero launched")))
    $results = ($results | insert "light independence" (light independence $ctx ($results | select "render_zero poses")))
    $results = ($results | insert "tiles block" (tiles block $ctx ($results | select "light independence")))
    $results = ($results | insert "tiles packet" (tiles packet $ctx ($results | select "light independence" "tiles block")))
    $results = ($results | insert "tiles frozen" (tiles frozen $ctx ($results | select "tiles packet")))
    $results = ($results | insert "tiles pool" (tiles pool $ctx ($results | select "light independence" "tiles block")))
    $results = ($results | insert "workers raster" (workers raster $ctx ($results | select "tiles block" "light independence")))
    $results = ($results | insert "workers machines" (workers machines $ctx ($results | select "light independence" "workers raster" "tiles block")))
    $results = ($results | insert "workers grant" (workers grant $ctx ($results | select "light independence" "workers raster")))
    $results = ($results | insert "workers jobs" (workers jobs $ctx ($results | select "light independence" "workers raster" "tiles block" "workers grant")))
    $results = ($results | insert "alpha fixture" (alpha fixture $ctx {}))
    $results = ($results | insert "light openings" (light openings $ctx ($results | select "alpha fixture")))
    $results = ($results | insert "alpha deep" (alpha deep $ctx {}))
    $results = ($results | insert "light room" (light room $ctx ($results | select "alpha fixture")))
    $results = ($results | insert "alpha centre" (alpha centre $ctx {}))
    $results = ($results | insert "light steps" (light steps $ctx ($results | select "alpha centre")))
    $results = ($results | insert "tiles builder" (tiles builder $ctx {}))
    $results = ($results | insert "growth flow" (growth flow $ctx ($results | select "load title")))
    $results = ($results | insert "load broken" (load broken $ctx {}))
    report $ctx $results
}

# What every case shares: the game, its trees, Render One's source and tree
def context [context: record]: nothing -> record {
    let game = $context.game
    let trees = (build program-shard $game "asset")
    let render_1_source = (open ($game | path join "content" "map" "render_1.nuon"))
    let render_1_tree = ($trees | path join "render_1")
    $context | merge {trees: $trees, render_1: {source: $render_1_source, tree: $render_1_tree}}
}

# Closing figures printed, from the load screen to the broken maps, then fps: ok
def report [context: record, records: record]: nothing -> nothing {
    let titles = $records."load title".titles
    let sprite_frame = $records."render_one sprite".sprite_frame
    let straddle_at = $records."render_one straddle".straddle_at
    let door_left = $records."render_one straddle".door_left
    let straddle_frame = $records."render_one straddle".straddle_frame
    let grow_sectors = $records."growth flow".grow_sectors
    let grow_frame = $records."growth flow".grow_frame
    let grow_at = $records."growth flow".grow_at
    let render_1_load = $records."render_one loaded".render_1_load
    let render_1_start = $records."render_one frames".render_1_start
    let shove = $records."render_one spawn".shove
    let render_1_poses = $records."render_one poses".render_1_poses
    let render_1_frames = $records."render_one frames".render_1_frames
    let render_1_sectors = $records."render_one frames".render_1_sectors
    let lit_near = $records."render_one light".lit_near
    let lit_far = $records."render_one light".lit_far
    let render_1_mips = $records."render_one mips".render_1_mips
    let stair_first = $records."render_one stair".stair_first
    let stair_last = $records."render_one stair".stair_last
    let stair_sectors = $records."render_one stair".stair_sectors
    let stair_states = $records."render_one stair".stair_states
    let render_0_load = $records."render_zero launched".render_0_load
    let render_0_start = $records."render_zero launched".render_0_start
    let render_0_poses = $records."render_zero poses".render_0_poses
    let render_0_frames = $records."render_zero launched".render_0_frames
    let render_0_sectors = $records."render_zero launched".render_0_sectors
    let render_0_mips = $records."render_zero mips".render_0_mips
    let render_0_walks = $records."render_zero walk".render_0_walks
    let fight_events = $records."render_zero fight".fight_events
    let fight_records = $records."render_zero fight".fight_records
    let struck = $records."render_zero fight".struck
    let fight_rounds = $records."render_zero fight".fight_rounds
    let pickups = $records."render_zero fight".pickups
    let shots = $records."render_zero fight".shots
    let fight_frames = $records."render_zero fight".fight_frames
    let view_spread = $records."light independence".view_spread
    let fixture_levels = $records."alpha fixture".fixture_levels
    let fixture_runs = $records."alpha fixture".fixture_runs
    let openings = $records."light openings".openings
    let bad_run = $records."load broken".bad_run
    let short_run = $records."load broken".short_run
    print $"fps: the load screen: ($titles | each {|t| $'($t.text) inked ($t.ink.left) to ($t.ink.right) on rows ($t.ink.top) to ($t.ink.bottom)' } | str join '; ')"
    print $"fps: the sprite drawn in ($sprite_frame.us) us, ($sprite_frame.sprites) sprites in ($sprite_frame.sprite_us) us, ($sprite_frame.uncovered) uncovered, red at ($SPRITE_RIGHT) and the wall at ($SPRITE_LEFT); the straddling sprite's near end at ($straddle_at) its texture, left of the doorway's column ($door_left), ($straddle_frame.sprites) sprites in ($straddle_frame.us) us"
    print $"fps: the growth map drew ($grow_sectors) in ($grow_frame.us) us with ($grow_frame.uncovered) uncovered, the far wall at ($grow_at) the backdrop"
    print $"fps: render_1 loaded in ($render_1_load.ms) ms; the spawn view in ($render_1_start.us) us with ($render_1_start.sprites) sprites, the eye ($shove | math round --precision 3) off the spawn; the poses ($render_1_poses | get name | str join ', ') in ($render_1_frames | slice 1.. | each {|p| $p.us } | str join ', ') us with ($render_1_frames | slice 1.. | each {|p| $p.uncovered } | str join ', ') uncovered, drawing ($render_1_sectors | slice 1.. | each {|s| $s | length } | str join ', ') sectors; the light's floor ($lit_near | math round --precision 1) against the far wall's ($lit_far | math round --precision 1); ($render_1_mips.chains) chains of ($render_1_mips.levels) levels, ($render_1_mips.texels) texels in ($render_1_mips.ms) ms"
    print $"fps: the stair from ($stair_first.x), ($stair_first.y), ($stair_first.z) in ($stair_first.sector) to ($stair_last.x), ($stair_last.y), ($stair_last.z) in ($stair_last.sector) through ($stair_sectors) over ($stair_states | length) frames"
    print $"fps: render_0 loaded in ($render_0_load.ms) ms; the spawn view in ($render_0_start.us) us over ($render_0_start.sectors) sectors, ($render_0_start.walls) walls, ($render_0_start.pieces) pieces, ($render_0_start.planes) planes \(clear ($render_0_start.clear), planes ($render_0_start.plane_us), walls ($render_0_start.wall_us), portals ($render_0_start.portal_us) us\); the poses ($render_0_poses | get name | str join ', ') in ($render_0_frames | slice 1.. | each {|p| $p.us } | str join ', ') us with ($render_0_frames | slice 1.. | each {|p| $p.uncovered } | str join ', ') uncovered, drawing ($render_0_sectors | slice 1.. | each {|s| $s | length } | str join ', ') sectors; ($render_0_mips.chains) chains of ($render_0_mips.levels) levels, ($render_0_mips.texels) texels in ($render_0_mips.ms) ms"
    for w in $render_0_walks {
        print $"fps: the ($w.name) walk from ($w.first.x), ($w.first.y), ($w.first.z) in ($w.first.sector) to ($w.last.x), ($w.last.y), ($w.last.z) in ($w.last.sector) through ($w.crossed) over ($w.frames) frames"
    }
    print $"fps: the fight: the android fired ($fight_events | where {|e| $e.fields.0 == $FIRED } | length) rounds, the frame struck ($fight_records | where kind == 4 | length) times; struck down through ($struck | each {|r| $r.fields.2 } | str join ', '), ($fight_rounds | length) rounds in all, the magazine taken with ($pickups | get 0.fields.0) rounds; the shots' window peaking at ($shots.peak); the pose's frame in ($fight_frames | last | get us) us with ($fight_frames | last | get sprites) sprites"
    print $"fps: the light from the spawn at yaws ($VIEW_YAWS): ($view_spread | each {|s| $'($s.point) ($s.light | each {|l| $l | math round --precision 1 } | str join ' and ') of 256, ($s.spread | math round --precision 1) apart' } | str join '; ')"
    print $"fps: the alpha fixture: coverage ($fixture_levels.coverage) of 10000 and scales ($fixture_levels.scale) of 65536 by level; ($fixture_runs | transpose name run | each {|r| $'($r.name) at level ($r.run.level) in ($r.run.frame.us) us, ($r.run.frame.tiles_built) tiles built, ($r.run.read | where shows | length) of ($r.run.read | length) patches shown' } | str join '; '); the openings ($openings) identical between the tiles and the lit loop at levels 0, 1, and 2"
    let service = $records."service regression".service
    print $"fps: the service under two workers: ($service.pad.accepted) of ($service.sent) pad events into the ring, ($service.pad.taken) taken, ($service.pad.dropped) dropped by the ring and ($service.queue_full) reports by the device; the sound ($service.sound.submitted) periods submitted, ($service.sound.exhausted) services finding the queue empty; every 50 ms window heard from ($service.heard_from) s, ($service.windows) windows"
    print $"fps: the wrong magic out with ($bad_run.status), the short file with ($short_run.status)"
    print "fps: ok"
}
