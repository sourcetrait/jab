use (path self ../../../../../../../nu/mod/launch)
use (path self ../../../console)
use (path self ../../../map)
use (path self ../../../tree)
use std/assert
use (path self ../../../tree) [BUILDER_FIXTURE FIXTURE_MAP]

# When the builder's first lighting goes in
const BUILDER_AT = 1400ms

# The time between the builder's lighting, build, and dump frames
const BUILDER_STEP = 300ms

# The lumel lightings the builder runs under in turn
const BUILDER_LIGHTINGS = [bright gradient parity]

# The builder oracle's rounding slack, in a lane's 256ths
const BUILDER_TRUNCATIONS = 8

# render.inc's LUMAP_PLANES: a wall's surface is its index past these
const LUMAP_PLANES = 2048

# A tile's side as a power of two, 64 texels of its level
export const TILE_SHIFT = 6

# The builder wall built and dumped under three lightings, read by the oracle
export def builder-holds [kernel: path, image: path, out: path, set: string, source: record, game: path]: nothing -> record<tiles: int, levels: int, k: int, w: int, h: int, by_level: list<any>> {
    let tree = (tree builder-tree $source $game ($out | path join "builder"))
    let m = (map read ($tree | path join "map" $"($FIXTURE_MAP).jabfps.map"))
    let material = ($m.materials | enumerate | where {|e| $e.item.name == $BUILDER_FIXTURE.name } | get 0.index)
    let found = ($m.walls | enumerate | where {|e| $e.item.surface.material == $material })
    assert equal ($found | length) 1 $"one wall carries the builder fixture: ($found | length)"
    let wall = ($found | get 0.item)
    let surface = ($LUMAP_PLANES + ($found | get 0.index))
    let size = $BUILDER_FIXTURE.size
    let frame = (tree wall-lumap $m $wall $size $size)
    let levels = (tree chain-levels $size $size)
    assert ($frame.k > 0 and $frame.k < ($levels - 1)) $"the fixture's k, ($frame.k), leaves levels below, at, and above it in its chain of ($levels)"
    let grid = (0..<$levels | each {|l|
        let span = (1 bit-shl ($l + $TILE_SHIFT))
        let across = ((($frame.w bit-shl $frame.k) + $span - 1) // $span)
        let down = ((($frame.h bit-shl $frame.k) + $span - 1) // $span)
        0..<$down | each {|ty| 0..<$across | each {|tx| { level: $l, tx: $tx, ty: $ty } } } | flatten
    } | flatten | sort-by level ty tx)
    let sends = ($BUILDER_LIGHTINGS | enumerate | each {|e|
        let at = ($BUILDER_AT + ($BUILDER_STEP * (3 * $e.index)))
        let light = (match $e.item {
            "bright" => (console level true false),
            "gradient" => (console level false false --gradient),
            _ => (console level false false --parity),
        })
        [{ at: $at, bytes: $light }, { at: ($at + $BUILDER_STEP), bytes: (console build $surface) }, { at: ($at + (2 * $BUILDER_STEP)), bytes: (console dump $surface) }]
    } | flatten)
    let end = ($BUILDER_AT + ($BUILDER_STEP * (3 * ($BUILDER_LIGHTINGS | length) + 1)))
    let run_out = ($out | path join "builder_run")
    let run = (launch --kernel $kernel --image $image --out $run_out --set $set --sound --api --disk (tree romfs $tree ($out | path join "builder.romfs")) --serial "fps" --send $sends --capture $end --seconds 9)
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest on the builder's run"
    let spec = ({ size: $size, lightings: $BUILDER_LIGHTINGS, k: $frame.k, w: $frame.w, h: $frame.h, truncations: $BUILDER_TRUNCATIONS } | to nuon)
    let read_out = ($out | path join "builder.nuon")
    let oracle = (^nu ($game | path join "nu" "bin" "nuance" "tiles.nu") builder ($run_out | path join "api.out") $spec $read_out | complete)
    assert equal $oracle.exit_code 0 $"the builder's oracle read the run's dumps: ($oracle.stderr)"
    let read = (open $read_out)
    assert ($read.problems | is-empty) $"every dump whole, every record in its place: ($read.problems | first 3)"
    assert equal $read.dumps ($BUILDER_LIGHTINGS | length) $"a dump under each light: ($read.dumps) of ($BUILDER_LIGHTINGS | length)"
    mut dumped = []
    for e in $read.results {
        let keys = ($e.tiles | each {|t| { level: $t.level, tx: $t.tx, ty: $t.ty } } | sort-by level ty tx)
        assert equal $keys $grid $"every tile of the wall at every level dumped once under the ($e.lighting) lumels: ($keys | length) of ($grid | length)"
        let foreign = ($e.tiles | where {|t| $t.surface != $surface or $t.k != $frame.k or $t.w != $frame.w or $t.h != $frame.h })
        assert ($foreign | is-empty) $"every dumped tile the wall's, its map's k, W, and H ($frame.k), ($frame.w), and ($frame.h) as lumap_frame's rule gives them: ($foreign | first 2)"
        $dumped = ($dumped | append ($e.tiles | each {|t| $t | insert lighting $e.lighting }))
    }
    let held = $dumped
    let alpha = ($held | where {|r| $r.alpha > 0 })
    assert ($alpha | is-empty) $"every texel's alpha the chain's: ($alpha | first 3)"
    let bright = ($held | where {|r| $r.lighting == "bright" and $r.unlike > 0 })
    assert ($bright | is-empty) $"under the bright lumels every texel the chain's at its level: ($bright | first 3)"
    let past = ($held | where {|r| $r.past > 0 })
    assert ($past | is-empty) $"every texel within the build's rounding of its centre's light: ($past | first 3)"
    let by_level = (0..<$levels | each {|l|
        let these = ($held | where level == $l)
        let lit = ($these | where {|r| $r.lighting != "bright" })
        {
            level: $l, tiles: ($these | where lighting == "bright" | length),
            clamped: ($these | where lighting == "bright" | get clamped | math sum),
            telling: ($lit | get telling | math sum),
            gradient: ($these | where lighting == "gradient" | get most | math max),
            parity: ($these | where lighting == "parity" | get most | math max),
        }
    })
    let unclamped = ($by_level | where clamped == 0)
    assert ($unclamped | is-empty) $"texels past the last node at every level: none at levels ($unclamped | get level)"
    let untold = ($by_level | where telling == 0)
    assert ($untold | is-empty) $"texels where a light at the corner reads past twice the rounding at every level: none at levels ($untold | get level)"
    { tiles: ($grid | length), levels: $levels, k: $frame.k, w: $frame.w, h: $frame.h, by_level: $by_level }
}
