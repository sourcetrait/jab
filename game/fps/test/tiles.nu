# The tile pool's readers and oracles, lean: this module imports nothing,
# since code loaded into a nu slows its closures and its module calls in
# proportion, the test's own imports about 15 ms a call, so the test runs
# these in a nu of their own (`nu tiles.nu builder <api> <spec> <out>`)
# and keeps its heavy modules out of the per-texel loops.
#
# The builder's assertion: the tile dumps a capture holds, each closed by
# the console's answer to its D frame, held texel by texel to the host's
# oracle, each texel the chain's at its tile's level lit by the light of
# its centre, bilinear over the lighting's nodes with the coordinate
# clamped to the last node, within the build's rounding.

const RECORD = 64
const DUMP_KIND = 16
const TEXELS_KIND = 17
const CONSOLE_KIND = 11
const CONSOLE_D = 68
const SIDE = 64

# The tile dumps an API capture holds, each closed by the console's answer
# to its D frame: each tile's slot, key, surface, level, column, and row,
# its map's k, W, and H as the program holds them, the slots its texel
# records named, and its texels in rows, each a texel's word as the
# program holds it, blue in its low byte, then green, red, and alpha.
export def dumps [api: binary]: nothing -> list<any> {
    mut dumps = []
    mut tiles = []
    mut texels = []
    mut named = []
    let close = {|ts: list<binary>, slots: list<int>, tile: record|
        let words = ($ts | bytes collect | chunks 4 | first ($SIDE * $SIDE) | each {|t| $t | into int --endian little })
        $tile | insert texel_slots ($slots | uniq) | insert texels ($words | chunks $SIDE)
    }
    for r in ($api | chunks $RECORD | where {|c| ($c | bytes length) == $RECORD }) {
        let kind = ($r | bytes at 0..<1 | into int)
        let ending = ($kind == $DUMP_KIND) or ($kind == $CONSOLE_KIND and ($r | bytes at 4..<5 | into int) == $CONSOLE_D)
        if $ending and ($tiles | is-not-empty) and ($texels | is-not-empty) {
            let ts = $texels
            let ns = $named
            $tiles = ($tiles | update (($tiles | length) - 1) {|t| do $close $ts $ns $t })
            $texels = []
            $named = []
        }
        if $kind == $DUMP_KIND {
            let word = {|at: int| $r | bytes at $at..<($at + 4) | into int --endian little }
            $tiles = ($tiles | append { slot: (do $word 4), key: (do $word 8), surface: (do $word 12), level: (do $word 16), tx: (do $word 20), ty: (do $word 24), k: (do $word 28), w: (do $word 32), h: (do $word 36) })
        } else if $kind == $TEXELS_KIND {
            $texels = ($texels | append ($r | bytes at 12..<60))
            $named = ($named | append ($r | bytes at 4..<8 | into int --endian little))
        } else if $ending {
            $dumps = ($dumps | append [$tiles])
            $tiles = []
        }
    }
    $dumps
}

# A texel of the builder fixture's texture, [red, green, blue, alpha]:
# every channel varied over both axes, opaque.
export def builder-texel [x: int, y: int]: nothing -> list<int> {
    [((17 * $x + 5 * $y) mod 256), ((3 * $x + 13 * $y) mod 256), ((7 * $x + 11 * $y + 64) mod 256), 255]
}

# The builder fixture's chain, a level a list of rows of [red, green,
# blue, alpha]: level 0 the texture's texels, each coarser level the floor
# of the mean of the two by two under it a channel, the shrink's rule for
# alike alphas, the texture opaque, its alpha kept at a full coverage's
# scale of one; one level more for every halving while both sides are two
# or more, ten at most, as the engine builds it.
export def builder-chain [size: int]: nothing -> list<any> {
    mut levels = 1
    mut side = $size
    while $levels < 10 and $side >= 2 {
        $side = ($side // 2)
        $levels += 1
    }
    let first = (0..<$size | each {|y| 0..<$size | each {|x| [((17 * $x + 5 * $y) mod 256), ((3 * $x + 13 * $y) mod 256), ((7 * $x + 11 * $y + 64) mod 256), 255] } })
    1..<$levels | reduce --fold [$first] {|l, chain|
        let prev = ($chain | last)
        let w = (($prev | length) // 2)
        let next = (0..<$w | each {|y|
            let top = ($prev | get (2 * $y))
            let bottom = ($prev | get (2 * $y + 1))
            0..<$w | each {|x|
                let a = ($top | get (2 * $x))
                let b = ($top | get (2 * $x + 1))
                let c = ($bottom | get (2 * $x))
                let d = ($bottom | get (2 * $x + 1))
                [(($a.0 + $b.0 + $c.0 + $d.0) // 4), (($a.1 + $b.1 + $c.1 + $d.1) // 4), (($a.2 + $b.2 + $c.2 + $d.2) // 4), $a.3]
            }
        })
        $chain | append [$next]
    }
}

# A map's nodes under one of the builder's lightings, a row a list of
# [red, green, blue] in a lane's 256ths, as the console sets them: bright
# every lane one; the gradient red 256 c / (W - 1), green 256 r / (H -
# 1), and blue 256 (c + r) / (W + H - 2), each floored; the parity a
# quarter where c and r sum even and one where odd.
export def builder-nodes [lighting: string, cols: int, rows: int]: nothing -> list<any> {
    if $lighting not-in [bright gradient parity] { error make { msg: $"no builder lighting ($lighting)" } }
    0..<$rows | each {|r| 0..<$cols | each {|c|
        if $lighting == "bright" { [256, 256, 256] } else if $lighting == "gradient" {
            [((256 * $c) // ($cols - 1)), ((256 * $r) // ($rows - 1)), ((256 * ($c + $r)) // ($cols + $rows - 2))]
        } else if (($c + $r) mod 2) == 0 { [64, 64, 64] } else { [256, 256, 256] }
    } }
}

# A dumped tile held to the oracle under a lighting: each texel against
# the chain's texel at the tile's level, the texel's column and row masked
# to the level's size, lit by the light of the texel's centre, (X + 1/2)
# 2^m texels of level 0 from the map's first node, bilinear over the
# lighting's nodes with the coordinate clamped to the last node. A
# channel c lit by L reads c L / 256 within 1 + c (256 + truncations) /
# 65536: one for the multiply's floor and c over 256 times one lane and
# the build's truncations. Counted: the texels past that, those other than
# the chain's under the bright, those whose alpha is not the chain's,
# those whose centre lies past the last node, and those where the light of
# the texel's corner reads past twice the rounding; with the most any
# channel lies from its light. Under the bright a row is held whole to the
# chain's words, the light one.
export def builder-tile [tile: record, lighting: string, nodes: list<any>, chain: list<any>, frame: record]: nothing -> record<level: int, past: int, unlike: int, alpha: int, clamped: int, telling: int, most: float> {
    let scale = (2.0 ** ($tile.level - $frame.k))
    let level = ($chain | get $tile.level)
    let lw = ($level | length)
    let wmax = ($frame.w - 1)
    let wlast = ($frame.w - 2)
    let hmax = ($frame.h - 1)
    let hlast = ($frame.h - 2)
    let trunc = ((256 + $frame.truncations) / 65536.0)
    let along = {|v: float|
        let cv = (if $v < $hmax { $v } else { $hmax })
        let rf = ($cv | into int)
        let r0 = (if $rf < $hlast { $rf } else { $hlast })
        let fv = ($cv - $r0)
        $nodes | get $r0 | zip ($nodes | get ($r0 + 1)) | each {|p| [($p.0.0 + (($p.1.0 - $p.0.0) * $fv)), ($p.0.1 + (($p.1.1 - $p.0.1) * $fv)), ($p.0.2 + (($p.1.2 - $p.0.2) * $fv))] }
    }
    let x0 = ($tile.tx * $SIDE)
    let cols = (0..<$SIDE | each {|i|
        let x = ($x0 + $i)
        let u = (($x + 0.5) * $scale)
        let cu = (if $u < $wmax { $u } else { $wmax })
        let cf = ($cu | into int)
        let ci = (if $cf < $wlast { $cf } else { $wlast })
        let ux = ($x * $scale)
        let du = (if $ux < $wmax { $ux } else { $wmax })
        let df = ($du | into int)
        let di = (if $df < $wlast { $df } else { $wlast })
        { ci: $ci, fu: ($cu - $ci), di: $di, fd: ($du - $di), cx: ($x mod $lw), past: ($u > $wmax) }
    })
    let past_columns = ($cols | where past | length)
    let rows = ($tile.texels | enumerate | each {|row|
        let y = (($tile.ty * $SIDE) + $row.index)
        let v = (($y + 0.5) * $scale)
        let texels = ($level | get ($y mod $lw))
        let clamped = (if $v > $hmax { $SIDE } else { $past_columns })
        if $lighting == "bright" {
            let want = ($cols | each {|k| let c = ($texels | get $k.cx); ($c.3 bit-shl 24) bit-or ($c.0 bit-shl 16) bit-or ($c.1 bit-shl 8) bit-or $c.2 })
            if $row.item == $want {
                { past: 0, unlike: 0, alpha: 0, clamped: $clamped, telling: 0, most: 0.0 }
            } else {
                let pairs = ($row.item | zip $want)
                { past: 0, unlike: ($pairs | where {|p| ($p.0 bit-and 0xffffff) != ($p.1 bit-and 0xffffff) } | length), alpha: ($pairs | where {|p| ($p.0 bit-shr 24) != ($p.1 bit-shr 24) } | length), clamped: $clamped, telling: 0, most: 0.0 }
            }
        } else {
            let centre = (do $along $v)
            let corner = (do $along ($y * $scale))
            let cells = ($row.item | zip $cols | each {|z|
                let w = $z.0
                let k = $z.1
                let a = ($centre | get $k.ci)
                let b = ($centre | get ($k.ci + 1))
                let p = ($corner | get $k.di)
                let q = ($corner | get ($k.di + 1))
                let c = ($texels | get $k.cx)
                let e0 = (($c.0 * ($a.0 + (($b.0 - $a.0) * $k.fu))) / 256.0)
                let e1 = (($c.1 * ($a.1 + (($b.1 - $a.1) * $k.fu))) / 256.0)
                let e2 = (($c.2 * ($a.2 + (($b.2 - $a.2) * $k.fu))) / 256.0)
                let n0 = ((($c.0 * ($p.0 + (($q.0 - $p.0) * $k.fd))) / 256.0) - $e0)
                let n1 = ((($c.1 * ($p.1 + (($q.1 - $p.1) * $k.fd))) / 256.0) - $e1)
                let n2 = ((($c.2 * ($p.2 + (($q.2 - $p.2) * $k.fd))) / 256.0) - $e2)
                let d0 = ((($w bit-shr 16) bit-and 255) - $e0)
                let d1 = ((($w bit-shr 8) bit-and 255) - $e1)
                let d2 = (($w bit-and 255) - $e2)
                let r0 = (if $d0 < 0 { 0 - $d0 } else { $d0 })
                let r1 = (if $d1 < 0 { 0 - $d1 } else { $d1 })
                let r2 = (if $d2 < 0 { 0 - $d2 } else { $d2 })
                let b0 = (1.0 + ($c.0 * $trunc))
                let b1 = (1.0 + ($c.1 * $trunc))
                let b2 = (1.0 + ($c.2 * $trunc))
                {
                    past: ($r0 >= $b0 or $r1 >= $b1 or $r2 >= $b2),
                    alpha: (($w bit-shr 24) != $c.3),
                    telling: ($n0 > (2 * $b0) or $n0 < (-2 * $b0) or $n1 > (2 * $b1) or $n1 < (-2 * $b1) or $n2 > (2 * $b2) or $n2 < (-2 * $b2)),
                    most: (if $r0 > $r1 { if $r0 > $r2 { $r0 } else { $r2 } } else { if $r1 > $r2 { $r1 } else { $r2 } }),
                }
            })
            {
                past: ($cells | where past | length), unlike: 0, alpha: ($cells | where alpha | length),
                clamped: $clamped, telling: ($cells | where telling | length), most: ($cells | get most | math max),
            }
        }
    })
    {
        level: $tile.level,
        past: ($rows | get past | math sum), unlike: ($rows | get unlike | math sum), alpha: ($rows | get alpha | math sum),
        clamped: ($rows | get clamped | math sum), telling: ($rows | get telling | math sum), most: ($rows | get most | math max),
    }
}

# The builder's oracle over a capture: the spec a NUON record of the
# texture's size, the lightings in the order the dumps came, the map's k,
# W, and H as the host lays them out, and the build's truncations; the
# result, saved to out as NUON, each lighting's tiles with their headers
# and builder-tile's counts.
def "main builder" [api: path, spec: string, out: path] {
    let s = ($spec | from nuon)
    let found = (dumps (open --raw $api | into binary))
    let chain = (builder-chain $s.size)
    let results = ($s.lightings | enumerate | each {|e|
        let tiles = ($found | get -o $e.index | default [])
        let nodes = (builder-nodes $e.item $s.w $s.h)
        {
            lighting: $e.item,
            tiles: ($tiles | each {|t| builder-tile $t $e.item $nodes $chain $s | merge { slot: $t.slot, surface: $t.surface, tx: $t.tx, ty: $t.ty, k: $t.k, w: $t.w, h: $t.h, texel_slots: $t.texel_slots } }),
        }
    })
    { dumps: ($found | length), results: $results } | to nuon | save -f $out
}

def main [] {
    print "nu tiles.nu builder <api> <spec> <out>"
}
