use (path self ../../../../../../nu/mod/launch)
use (path self ../../console)
use (path self ../../map)
use (path self ../../picture)
use (path self ../../tree)
use std/assert
use (path self ../../frame) [CRACKS FRAME LOAD]
use (path self ../../picture) [FIXTURE_CROSSHAIR]
use (path self ../../tree) [ALPHA_CASES ALPHA_FIXTURE CENTRE_FIXTURE EYE_HEIGHT FIXTURE_BACKDROP FIXTURE_GRID FIXTURE_KINDS FIXTURE_MAP FIXTURE_POSES]

# The engine's alpha line form: coverage by level, scale by coarser level
const ALPHA_LINE = "fps: alpha {name}: coverage {coverage} of 10000, scale {scale} of 65536"

# The alpha a texel passes at, of 255
const ALPHA_PASS = 128

# The coverage slack in 10000ths for the fence's and grate's coarser levels
const ALPHA_SLACKS = { "texture/fence": 300, "texture/grate": 1200 }

# The alpha search's scratch in bytes, past which a texture keeps scale one
const ALPHA_PLANE_BYTES = 262144

# The texture repeats over the wall whose patches are sampled
const FIXTURE_REPEATS = [[1, 1], [2, 2]]

# The deep alpha fixture: its scale and poses reading levels 3 to 6
const FIXTURE_DEEP = { scale: 32.0, poses: [
    { name: "deep3", distance: 1.33, level: 3 },
    { name: "deep4", distance: 2.65, level: 4 },
    { name: "deep5", distance: 5.3, level: 5 },
    { name: "deep6", distance: 10.6, level: 6 },
] }

# The parity lumels' light at an even node and at an odd one
const CENTRE_LIGHTS = [0.25, 1.0]

# The texel-centre pose's distance from the wall, in metres
const CENTRE_DISTANCE = 2.0

# The most a centre sample may read from its expected light, of 255
const CENTRE_SLACK = 2

# The pixels each way about a sample's centre held to one colour
const CENTRE_FOOTPRINT = 3

# A material's alpha line, its first three coarser levels within its slack
def alpha-held [lines: list<string>, name: string]: nothing -> nothing {
    let line = ($lines | where {|l| $l starts-with $"fps: alpha ($name): " })
    assert equal ($line | length) 1 $"one alpha line for ($name): ($lines | where {|l| $l starts-with 'fps: alpha' })"
    let got = (alpha-line ($line | get 0))
    let slack = ($ALPHA_SLACKS | get $name)
    let c0 = ($got.coverage | get 0)
    for c in ($got.coverage | slice 1..3) {
        assert ((($c - $c0) | math abs) <= $slack) $"($name)'s coverage holds by level within ($slack) of 10000: ($line | get 0)"
    }
}

# An alpha line parsed: material, coverage by level, scale by coarser level
def alpha-line [line: string]: nothing -> record<name: string, coverage: list<int>, scale: list<int>> {
    let got = ($line | parse $ALPHA_LINE | get 0)
    {
        name: $got.name,
        coverage: ($got.coverage | split row " " | each {|v| $v | into int }),
        scale: ($got.scale | split row " " | each {|v| $v | into int }),
    }
}

# The engine's alpha policy on the host: coverage, scales, planes by level
def levels [alphas: list<int>, w: int, h: int]: nothing -> record<line: bool, coverage: list<int>, scale: list<int>, planes: list<list<int>>> {
    let n0 = ($w * $h)
    let levels = (tree chain-levels $w $h)
    let c0 = ($alphas | where {|a| $a >= $ALPHA_PASS } | length)
    if $levels <= 1 or ($n0 // 4) > $ALPHA_PLANE_BYTES or $c0 == $n0 { return { line: false, coverage: [], scale: [], planes: [] } }
    mut coverage = [(($c0 * 10000) // $n0)]
    mut scale = []
    mut planes = [$alphas]
    mut plane = $alphas
    mut pw = $w
    mut ph = $h
    for level in 1..<$levels {
        let sw = $pw
        let lw = ($pw // 2)
        let lh = ($ph // 2)
        let src = $plane
        let means = (0..<$lh | each {|y| 0..<$lw | each {|x|
            let i = (2 * $y * $sw + 2 * $x)
            (($src | get $i) + ($src | get ($i + 1)) + ($src | get ($i + $sw)) + ($src | get ($i + $sw + 1))) // 4
        } } | flatten)
        let nl = ($lw * $lh)
        if $c0 == 0 {
            $coverage = ($coverage | append 0)
            $scale = ($scale | append 65536)
            $plane = $means
            $planes = ($planes | append [$means])
            $pw = $lw
            $ph = $lh
            continue
        }
        let hist = ($means | reduce --fold (0..255 | each {|i| 0 }) {|v, acc| $acc | update $v {|n| $n + 1 } })
        mut best: any = null
        mut cov = 0
        for t in 256..1 {
            if $t <= 255 { $cov = ($cov + ($hist | get $t)) }
            let err = ((($cov * $n0) - ($c0 * $nl)) | math abs)
            let dist = (($t - $ALPHA_PASS) | math abs)
            let take = (if $best == null { true } else if $err < $best.err { true } else if $err == $best.err and $cov == $best.cov and $dist < $best.dist { true } else { false })
            if $take { $best = { err: $err, t: $t, cov: $cov, dist: $dist } }
        }
        let s = ((8388608 + $best.t - 1) // $best.t)
        $plane = ($means | each {|v| [(($v * $s) bit-shr 16), 255] | math min })
        $planes = ($planes | append [$plane])
        $pw = $lw
        $ph = $lh
        $coverage = ($coverage | append (($best.cov * 10000) // $nl))
        $scale = ($scale | append $s)
    }
    { line: true, coverage: $coverage, scale: $scale, planes: $planes }
}

# The tile shrink's colour for a texel from four: alpha-weighted unless alike
def shrink-colour [texels: list<record<colour: binary, alpha: int>>]: nothing -> binary {
    let alphas = ($texels | get alpha)
    let channels = (0..<3 | each {|c| $texels | each {|t| $t.colour | bytes at $c..<($c + 1) | into int } })
    let means = (if ($alphas | uniq | length) == 1 {
        $channels | each {|vs| ($vs | math sum) // 4 }
    } else {
        let recip = (16777216 // ($alphas | math sum))
        $channels | each {|vs|
            let weighted = ($vs | zip $alphas | each {|p| $p.0 * $p.1 } | math sum)
            (($weighted * $recip) + 8388608) // 16777216
        }
    })
    $means | each {|v| $v | into binary | bytes at 0..<1 } | bytes collect
}

# The alpha fixture's samples: each patch's centre, point, colours, passes
def fixture-samples [wall: record, a: record, e: list<float>, levels: record]: nothing -> table<kind: string, colours: list<binary>, uniform: bool, point: list<float>, pass: list<bool>> {
    let patch = $ALPHA_FIXTURE.patch
    $FIXTURE_REPEATS | each {|rep|
        0..<($ALPHA_FIXTURE.h // $patch) | each {|j|
            0..<($ALPHA_FIXTURE.w // $patch) | each {|i|
                let kind = ($FIXTURE_GRID | get $j | get $i)
                let k = ($FIXTURE_KINDS | get $kind)
                let coarse = (shrink-colour (0..<4 | each {|t| { colour: ($k.colours | get $t), alpha: ($k.alphas | get $t) } }))
                let u = (($i * $patch) + ($patch // 2))
                let v = (($j * $patch) + ($patch // 2))
                let along = ((((($rep.0 * $ALPHA_FIXTURE.w) + $u) + 0.5) / $ALPHA_FIXTURE.w - $wall.surface.u_offset) / $wall.surface.u_scale)
                let down = ((((($rep.1 * $ALPHA_FIXTURE.h) + $v) + 0.5) / $ALPHA_FIXTURE.h - $wall.surface.v_offset) / $wall.surface.v_scale)
                {
                    kind: $kind, colours: [($k.colours | get 0), $coarse, $coarse, $coarse],
                    uniform: ((($k.alphas | uniq | length) == 1) and (($k.colours | each {|c| $c | encode hex } | uniq | length) == 1)),
                    point: [($a.x + $e.0 * $along), ($a.y + $e.1 * $along), ($wall.anchor - $down)],
                    pass: (0..3 | each {|l| ($levels.planes | get $l | get ((($v bit-shr $l) * ($ALPHA_FIXTURE.w bit-shr $l)) + ($u bit-shr $l))) >= $ALPHA_PASS }),
                }
            }
        } | flatten
    } | flatten
}

# The alpha fixture's samples read from a capture at a level
def fixture-read [bytes: binary, eye: record, samples: table<kind: string, colours: list<binary>, uniform: bool, point: list<float>, pass: list<bool>>, level: int]: nothing -> table<kind: string, colour: binary, uniform: bool, at: list<int>, pixel: binary, shows: bool> {
    let head = (picture ppm-head $bytes)
    mut read = []
    for s in $samples {
        let at = (picture project $eye 0 $s.point)
        assert ($at != null) $"the ($s.kind) patch at ($s.point) is on screen from ($eye)"
        assert (((($at.0 - 960) ** 2) + (($at.1 - 540) ** 2)) > ($FIXTURE_CROSSHAIR * $FIXTURE_CROSSHAIR)) $"the ($s.kind) patch at ($at) lies clear of the crosshair's disc"
        $read = ($read | append { kind: $s.kind, colour: ($s.colours | get $level), uniform: $s.uniform, at: $at, pixel: (picture pixel-at $bytes $head $at), shows: ($s.pass | get $level) })
    }
    $read
}

# The texel-centre samples: texels about each node, their expected light
def centre-samples [m: record, wall: record, eye: record, opening: list<int>]: nothing -> table<node: list<int>, parity: int, texel: list<int>, at: list<int>, expected: float, corner: float> {
    let size = $CENTRE_FIXTURE.size
    let s = $wall.surface
    assert equal ($size * $s.u_scale / 2) ($size * 1.0) $"a lumel cell is one repeat: ($size * $s.u_scale / 2) texels in half a metre against ($size)"
    let a = ($m.vertices | get $wall.a)
    let b = ($m.vertices | get $wall.b)
    let len = ((($b.x - $a.x) ** 2 + ($b.y - $a.y) ** 2) | math sqrt)
    let e = [(($b.x - $a.x) / $len), (($b.y - $a.y) / $len)]
    let sector = ($m.sectors | get $wall.sector)
    let top = ([(map plane-z $sector.ceiling $a.x $a.y), (map plane-z $sector.ceiling $b.x $b.y)] | math max)
    let bottom = ([(map plane-z $sector.floor $a.x $a.y), (map plane-z $sector.floor $b.x $b.y)] | math min)
    let us = [($s.u_offset * $size), ((($s.u_scale * $len) + $s.u_offset) * $size)]
    let vs = [(((($wall.anchor - $top) * $s.v_scale) + $s.v_offset) * $size), (((($wall.anchor - $bottom) * $s.v_scale) + $s.v_offset) * $size)]
    let u0 = (((($us | math min | math floor | into int) - 1) // $size) * $size)
    let v0 = (((($vs | math min | math floor | into int) - 1) // $size) * $size)
    let cols = (((($us | math max | math ceil | into int) - $u0) // $size) + 2)
    let rows = (((($vs | math max | math ceil | into int) - $v0) // $size) + 2)
    assert ($cols >= 3 and $rows >= 3) $"the wall's map has a node inside it: ($cols) columns, ($rows) rows"
    let light = {|c: int, r: int| $CENTRE_LIGHTS | get (($c + $r) mod 2) }
    let lit = {|c: int, r: int, fx: float, fy: float|
        let upper = (((do $light $c $r) * (1.0 - $fx)) + ((do $light ($c + 1) $r) * $fx))
        let lower = (((do $light $c ($r + 1)) * (1.0 - $fx)) + ((do $light ($c + 1) ($r + 1)) * $fx))
        ($upper * (1.0 - $fy)) + ($lower * $fy)
    }
    let f = $CENTRE_FOOTPRINT
    let clear = ($FIXTURE_CROSSHAIR + (2 * $f))
    1..<($cols - 1) | each {|c|
        1..<($rows - 1) | each {|r|
            [[-1, -1], [0, -1], [-1, 0], [0, 0]] | each {|d|
                let tu = ($u0 + ($c * $size) + $d.0)
                let tv = ($v0 + ($r * $size) + $d.1)
                let along = (((($tu + 0.5) / $size) - $s.u_offset) / $s.u_scale)
                let down = (((($tv + 0.5) / $size) - $s.v_offset) / $s.v_scale)
                let at = (picture project $eye 0 [($a.x + ($e.0 * $along)), ($a.y + ($e.1 * $along)), ($wall.anchor - $down)])
                let inside = ($at != null and ($at.0 - $f) >= $opening.0 and ($at.0 + $f) < $opening.2 and ($at.1 - $f) >= $opening.1 and ($at.1 + $f) < $opening.3)
                if not $inside or (((($at.0 - 960) ** 2) + (($at.1 - 540) ** 2)) <= ($clear * $clear)) { null } else {
                    let cc = (($tu - $u0) // $size)
                    let cr = (($tv - $v0) // $size)
                    let iu = (($tu - $u0) mod $size)
                    let iv = (($tv - $v0) mod $size)
                    {
                        node: [$c, $r], parity: (($c + $r) mod 2), texel: [$tu, $tv], at: $at,
                        expected: (255.0 * (do $lit $cc $cr (($iu + 0.5) / $size) (($iv + 0.5) / $size))),
                        corner: (255.0 * (do $lit $cc $cr ($iu / $size) ($iv / $size))),
                    }
                }
            }
        } | flatten
    } | flatten | compact
}

# The texel-centre samples read: pixel, error from expected, uniformity
def centre-read [bytes: binary, samples: table<node: list<int>, parity: int, texel: list<int>, at: list<int>, expected: float, corner: float>]: nothing -> table<node: list<int>, light: float, texel: list<int>, at: list<int>, expected: float, corner: float, pixel: binary, off: float, uniform: bool> {
    let head = (picture ppm-head $bytes)
    let f = $CENTRE_FOOTPRINT
    let width = ((2 * $f) + 1)
    $samples | each {|s|
        let pixel = (picture pixel-at $bytes $head $s.at)
        let off = (0..<3 | each {|c| (($pixel | bytes at $c..<($c + 1) | into int) - $s.expected) | math abs } | math max)
        let run = (0..<$width | each {|i| $pixel } | bytes collect)
        let uniform = ((-1 * $f)..$f | each {|dy|
            let o = ($head + (((($s.at.1 + $dy) * 1920) + ($s.at.0 - $f)) * 3))
            ($bytes | bytes at $o..<($o + ($width * 3))) == $run
        } | all {|same| $same })
        { node: $s.node, light: ($CENTRE_LIGHTS | get $s.parity), texel: $s.texel, at: $s.at, expected: $s.expected, corner: $s.corner, pixel: $pixel, off: $off, uniform: $uniform }
    }
}

# Alpha at load: each case's line, coverage, and scales as the host rule gives
export def at-load [context: record, records: record]: nothing -> record {
    let sprite_lines = $records."render_one sprite".sprite_lines
    let alpha_lines = ($sprite_lines | where {|l| $l starts-with "fps: alpha " })
    for c in $ALPHA_CASES {
        let alphas = (0..<$c.h | each {|y| 0..<$c.w | each {|x| (tree case-texel $c $x $y).alpha } } | flatten)
        let want = (levels $alphas $c.w $c.h)
        let line = ($alpha_lines | where {|l| $l starts-with $"fps: alpha ($c.name): " })
        if $want.line {
            assert equal ($line | length) 1 $"one alpha line for ($c.name): ($alpha_lines)"
            let got = (alpha-line ($line | get 0))
            assert equal $got.coverage $want.coverage $"($c.name)'s coverage at every level of its chain as the rule gives it: ($line | get 0)"
            assert equal $got.scale $want.scale $"($c.name)'s scales at every coarser level as the rule gives them: ($line | get 0)"
        } else {
            assert ($line | is-empty) $"no alpha line for ($c.name), full at the pass: ($line)"
        }
    }
    {}
}

# The grate as authored: its coarser levels' coverage within the slack
export def grate [context: record, records: record]: nothing -> record {
    let render_1_lines = $records."render_one loaded".render_1_lines
    alpha-held $render_1_lines "texture/grate"
    {}
}

# The fence as authored: each coarser level's coverage within its slack
export def fence [context: record, records: record]: nothing -> record {
    let render_0_lines = $records."render_zero launched".render_0_lines
    alpha-held $render_0_lines "texture/fence"
    {}
}

# The alpha policy rendered: each patch its colour where it passes, else backdrop
export def fixture [context: record, records: record]: nothing -> record {
    let render_1_source = $context.render_1.source
    let game = $context.game
    let out = $context.out
    let kernel = $context.kernel
    let image = $context.image
    let set = $context.set
    let fixture_alphas = (0..<$ALPHA_FIXTURE.h | each {|y| (tree fixture-row $y).alphas } | flatten)
    let fixture_levels = (levels $fixture_alphas $ALPHA_FIXTURE.w $ALPHA_FIXTURE.h)
    assert $fixture_levels.line "the fixture is under full coverage, so the engine names a line for it"
    assert equal ($fixture_levels.scale | get 0) ((8388608 + 126) // 127) $"the fixture's search moves to 127 at level 1, so the scale lifts the pass less one over it: ($fixture_levels.scale)"
    let fixture_tree = (tree alpha-tree $render_1_source $game ($out | path join "alpha"))
    let fixture_read = (map read ($fixture_tree | path join "map" $"($FIXTURE_MAP).jabfps.map"))
    let fixture_expected = (open ($fixture_tree | path join "map.nuon"))
    let fixture_material = ($fixture_read.materials | enumerate | where {|m| $m.item.name == $ALPHA_FIXTURE.name } | get 0.index)
    let fixture_wall = ($fixture_read.walls | where {|w| $w.surface.material == $fixture_material } | get 0)
    let wall_a = ($fixture_read.vertices | get $fixture_wall.a)
    let wall_b = ($fixture_read.vertices | get $fixture_wall.b)
    let wall_len = ((($wall_b.x - $wall_a.x) ** 2 + ($wall_b.y - $wall_a.y) ** 2) | math sqrt)
    let wall_e = [(($wall_b.x - $wall_a.x) / $wall_len), (($wall_b.y - $wall_a.y) / $wall_len)]
    let fixture_samples = (fixture-samples $fixture_wall $wall_a $wall_e $fixture_levels)
    let fixture_disk = (tree romfs $fixture_tree ($out | path join "alpha.romfs"))
    let fixture_texels = ($fixture_wall.surface.u_scale * $ALPHA_FIXTURE.w)
    mut fixture_runs = {}
    for fp in $FIXTURE_POSES {
        let step = ($fixture_texels * $fp.distance / 960)
        let level = (if $step < 2 { 0 } else if $step < 4 { 1 } else if $step < 8 { 2 } else { 3 })
        assert equal $level $fp.level $"the ($fp.name) pose reads level ($fp.level) by the block's rule at ($step) texels a pixel"
        let eye = { x: ($wall_a.x - $fp.distance), y: (($wall_a.y + $wall_b.y) / 2), z: $EYE_HEIGHT }
        let placed = { name: $"alpha_($fp.name)", x: $eye.x, y: $eye.y, z: $eye.z, yaw: 0, pitch: 0 }
        for mode in [tiled lit] {
            let sends = ([{ at: 1400ms, bytes: (console level true ($mode == "lit")) }] | append (console settled $placed))
            let run = (launch --kernel $kernel --image $image --out ($out | path join $"alpha_($fp.name)_($mode)") --set $set --sound --api --disk $fixture_disk --serial "fps" --send $sends --capture 3500ms --seconds 5)
            let label = $"the ($fp.name) pose with the tiles ($mode)"
            assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on ($label)"
            let lines = ($run.serial | lines)
            let loads = ($lines | where {|l| $l starts-with $"fps: ($FIXTURE_MAP) loaded" })
            assert equal ($loads | length) 1 $"the fixture loaded once on ($label): ($run.serial)"
            let load = ($loads | get 0 | parse $LOAD | get 0 | update cells {|c| if $c =~ '^\d+$' { $c | into int } else { $c } })
            assert equal $load.missing 0 $"every material of the fixture in its tree on ($label): ($loads | get 0)"
            assert equal $load.textures $fixture_expected.materials $"the fixture's materials all textures on ($label): ($loads | get 0)"
            let alpha_line = ($lines | where {|l| $l starts-with $"fps: alpha ($ALPHA_FIXTURE.name): " })
            assert equal ($alpha_line | length) 1 $"one alpha line for the fixture on ($label): ($lines | where {|l| $l starts-with 'fps: alpha' })"
            let got = (alpha-line ($alpha_line | get 0))
            assert equal $got.coverage $fixture_levels.coverage $"the fixture's coverage at every level as the rule gives it: ($alpha_line | get 0)"
            assert equal $got.scale $fixture_levels.scale $"the fixture's scales at every coarser level as the rule gives them: ($alpha_line | get 0)"
            let frames = ($lines | where {|l| $l starts-with "fps: frame in" })
            assert equal ($frames | length) 3 $"the first frame and the pose's two placements reported on ($label): ($run.serial)"
            let frame = ($frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
            assert ($frame.uncovered < $CRACKS) $"no pixel uncovered on ($label): ($frame)"
            assert equal $frame.resets 1 $"the pool forgotten once, by the L frame, on ($label): ($frame)"
            if $mode == "tiled" {
                assert ($frame.tiles_built == 0 and $frame.tiled > 0) $"the view settled on its tiles on ($label): ($frame)"
            } else {
                assert ($frame.tiles_built == 0 and $frame.tiled == 0) $"no tile built or read with the tiles held off on ($label): ($frame)"
            }
            assert ($run.screen != "") $"a screen was taken on ($label)"
            let bytes = (open --raw $run.screen | into binary)
            let read_level = $level
            let read = (fixture-read $bytes $eye $fixture_samples $read_level)
            for r in ($read | where {|r| $r.uniform or $read_level > 0 }) {
                if $r.shows {
                    assert equal $r.pixel $r.colour $"the ($r.kind) patch at ($r.at) shows its colour at level ($read_level) on ($label): ($r.pixel | encode hex)"
                } else {
                    assert equal $r.pixel $FIXTURE_BACKDROP.colour $"the ($r.kind) patch at ($r.at) is absent at level ($read_level) on ($label), the backdrop behind it: ($r.pixel | encode hex)"
                }
            }
            $fixture_runs = ($fixture_runs | insert $"($fp.name)_($mode)" { bytes: $bytes, eye: $eye, frame: $frame, read: $read, level: $read_level })
        }
    }
    {
        fixture_levels: $fixture_levels,
        fixture_read: $fixture_read,
        fixture_wall: $fixture_wall,
        fixture_disk: $fixture_disk,
        fixture_runs: $fixture_runs,
    }
}

# Levels 3 to 6 at FIXTURE_DEEP's scale, tiled and held off identical
export def deep [context: record, records: record]: nothing -> record {
    let render_1_source = $context.render_1.source
    let game = $context.game
    let out = $context.out
    let kernel = $context.kernel
    let image = $context.image
    let set = $context.set
    let deep_tree = (tree alpha-tree $render_1_source $game ($out | path join "alpha_deep") --scale $FIXTURE_DEEP.scale)
    let deep_read = (map read ($deep_tree | path join "map" $"($FIXTURE_MAP).jabfps.map"))
    let deep_material = ($deep_read.materials | enumerate | where {|m| $m.item.name == $ALPHA_FIXTURE.name } | get 0.index)
    let deep_wall = ($deep_read.walls | where {|w| $w.surface.material == $deep_material } | get 0)
    let deep_a = ($deep_read.vertices | get $deep_wall.a)
    let deep_b = ($deep_read.vertices | get $deep_wall.b)
    let deep_disk = (tree romfs $deep_tree ($out | path join "alpha_deep.romfs"))
    let deep_texels = ($deep_wall.surface.u_scale * $ALPHA_FIXTURE.w)
    mut deep_levels = []
    for fp in $FIXTURE_DEEP.poses {
        let step = ($deep_texels * $fp.distance / 960)
        mut octave = 0
        mut s = $step
        while $s >= 2 { $s = $s / 2; $octave += 1 }
        assert equal $octave $fp.level $"the ($fp.name) pose reads level ($fp.level) by the block's rule at ($step) texels a pixel"
        let eye = { x: ($deep_a.x - $fp.distance), y: (($deep_a.y + $deep_b.y) / 2), z: $EYE_HEIGHT }
        let placed = { name: $"alpha_($fp.name)", x: $eye.x, y: $eye.y, z: $eye.z, yaw: 0, pitch: 0 }
        mut deep_captures = {}
        for mode in [tiled lit] {
            let sends = ([{ at: 1400ms, bytes: (console level true ($mode == "lit")) }] | append (console settled $placed))
            let run = (launch --kernel $kernel --image $image --out ($out | path join $"alpha_($fp.name)_($mode)") --set $set --sound --api --disk $deep_disk --serial "fps" --send $sends --capture 3500ms --seconds 5)
            let label = $"the ($fp.name) pose with the tiles ($mode)"
            assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on ($label)"
            let frames = ($run.serial | lines | where {|l| $l starts-with "fps: frame in" })
            assert equal ($frames | length) 3 $"the first frame and the pose's two placements reported on ($label): ($run.serial)"
            let frame = ($frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
            assert ($frame.uncovered < $CRACKS) $"no pixel uncovered on ($label): ($frame)"
            if $mode == "tiled" {
                assert ($frame.tiles_built == 0 and $frame.tiled > 0) $"the view settled on its tiles on ($label): ($frame)"
            } else {
                assert ($frame.tiles_built == 0 and $frame.tiled == 0) $"no tile built or read with the tiles held off on ($label): ($frame)"
            }
            assert ($run.screen != "") $"a screen was taken on ($label)"
            $deep_captures = ($deep_captures | insert $mode (open --raw $run.screen | into binary))
        }
        let opening = (picture fixture-opening $deep_read $deep_wall $eye)
        let differing = (picture rows-differ $deep_captures.tiled $deep_captures.lit $opening)
        assert ($differing | is-empty) $"the tiled and the lit pictures agree over the opening ($opening) at level ($fp.level), past the old four: rows ($differing | first 5) differ, ($differing | length) in all"
        $deep_levels = ($deep_levels | append $fp.level)
    }
    {}
}

# The texel-centre rule: texels by each node read from tiles at centre light
export def centre [context: record, records: record]: nothing -> record {
    let render_1_source = $context.render_1.source
    let game = $context.game
    let out = $context.out
    let kernel = $context.kernel
    let image = $context.image
    let set = $context.set
    let centre_tree = (tree centre-tree $render_1_source $game ($out | path join "centre"))
    let centre_read = (map read ($centre_tree | path join "map" $"($FIXTURE_MAP).jabfps.map"))
    let centre_material = ($centre_read.materials | enumerate | where {|m| $m.item.name == $CENTRE_FIXTURE.name } | get 0.index)
    let centre_wall = ($centre_read.walls | where {|w| $w.surface.material == $centre_material } | get 0)
    let centre_a = ($centre_read.vertices | get $centre_wall.a)
    let centre_b = ($centre_read.vertices | get $centre_wall.b)
    let centre_eye = { x: ($centre_a.x - $CENTRE_DISTANCE), y: (($centre_a.y + $centre_b.y) / 2), z: $EYE_HEIGHT }
    let centre_step = ($CENTRE_FIXTURE.size * $centre_wall.surface.u_scale * $CENTRE_DISTANCE / 960)
    assert ($centre_step < 2) $"the centre pose reads level 0 by the block's rule at ($centre_step) texels a pixel"
    let centre_opening = (picture fixture-opening $centre_read $centre_wall $centre_eye)
    let centre_samples = (centre-samples $centre_read $centre_wall $centre_eye $centre_opening)
    let telling = ($centre_samples | where {|s| (($s.corner - $s.expected) | math abs) > (2 * $CENTRE_SLACK) })
    assert equal ($telling | get parity | uniq | sort) [0, 1] $"texels beside dark and bright nodes alike where the corner rule reads past twice the slack: ($telling | length) of ($centre_samples | length) samples"
    let centre_disk = (tree romfs $centre_tree ($out | path join "centre.romfs"))
    let centre_placed = { name: "centre", x: $centre_eye.x, y: $centre_eye.y, z: $centre_eye.z, yaw: 0, pitch: 0 }
    mut centre_runs = {}
    mut centre_screens = {}
    for mode in [tiled held] {
        let sends = ([{ at: 1400ms, bytes: (console level false ($mode == "held") --parity) }] | append (console settled $centre_placed))
        let run = (launch --kernel $kernel --image $image --out ($out | path join $"centre_($mode)") --set $set --sound --api --disk $centre_disk --serial "fps" --send $sends --capture 3500ms --seconds 5)
        let label = $"the white wall under the parity lumels with the tiles ($mode)"
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on ($label)"
        let frames = ($run.serial | lines | where {|l| $l starts-with "fps: frame in" })
        assert equal ($frames | length) 3 $"the first frame and the pose's two placements reported on ($label): ($run.serial)"
        let frame = ($frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
        assert ($frame.uncovered < $CRACKS) $"no pixel uncovered on ($label): ($frame)"
        if $mode == "tiled" {
            assert ($frame.tiles_built == 0 and $frame.tiled > 0) $"the view settled on its tiles on ($label): ($frame)"
        } else {
            assert ($frame.tiles_built == 0 and $frame.tiled == 0) $"no tile built or read with the tiles held off on ($label): ($frame)"
        }
        assert ($run.screen != "") $"a screen was taken on ($label)"
        $centre_runs = ($centre_runs | insert $mode (open --raw $run.screen | into binary))
        $centre_screens = ($centre_screens | insert $mode $run.screen)
    }
    let centre_tiled = (centre-read $centre_runs.tiled $centre_samples)
    for r in $centre_tiled {
        assert ($r.off <= $CENTRE_SLACK) $"the texel ($r.texel) beside the node ($r.node) lit ($r.light) reads the light of its centre from its tile, ($r.expected | math round --precision 2) of 255 within ($CENTRE_SLACK), at ($r.at): ($r.pixel | encode hex), where lit at its corner it would read ($r.corner | math round --precision 2)"
        assert $r.uniform $"the texel ($r.texel) beside the node ($r.node) lit ($r.light) is one colour over the pixels about its centre at ($r.at), as a tile holds it"
    }
    let centre_held = (centre-read $centre_runs.held $centre_samples)
    let varied = ($centre_held | where {|r| not $r.uniform } | length)
    assert ($varied > (($centre_held | length) // 2)) $"the lit loop's picture varies over most sampled texels' pixels, so one colour there tells a tile: ($varied) of ($centre_held | length)"
    {
        centre_opening: $centre_opening,
        centre_samples: $centre_samples,
        telling: $telling,
        centre_screens: $centre_screens,
        centre_tiled: $centre_tiled,
        varied: $varied,
    }
}
