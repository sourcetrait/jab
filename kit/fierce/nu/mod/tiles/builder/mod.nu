use (path self ..)
use (path self ..) [SIDE]

# The builder fixture's mip chain, each coarser level its 2 by 2's floored mean
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

# A map's nodes under a builder lighting: bright, gradient, or parity
export def builder-nodes [lighting: string, cols: int, rows: int]: nothing -> list<any> {
    if $lighting not-in [bright gradient parity] { error make { msg: $"no builder lighting ($lighting)" } }
    0..<$rows | each {|r| 0..<$cols | each {|c|
        if $lighting == "bright" { [256, 256, 256] } else if $lighting == "gradient" {
            [((256 * $c) // ($cols - 1)), ((256 * $r) // ($rows - 1)), ((256 * ($c + $r)) // ($cols + $rows - 2))]
        } else if (($c + $r) mod 2) == 0 { [64, 64, 64] } else { [256, 256, 256] }
    } }
}

# A dumped tile held texel by texel to the oracle under a lighting; its counts
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

# The builder's oracle over a capture: each lighting's tiles held, as NUON
export def main [api: path, spec: string, out: path]: nothing -> nothing {
    let s = ($spec | from nuon)
    let read = (tiles read (open --raw $api | into binary))
    let found = $read.dumps
    let chain = (builder-chain $s.size)
    let results = ($s.lightings | enumerate | each {|e|
        let tiles = ($found | get -o $e.index | default [])
        let nodes = (builder-nodes $e.item $s.w $s.h)
        {
            lighting: $e.item,
            tiles: ($tiles | each {|t| builder-tile $t $e.item $nodes $chain $s | merge { slot: $t.slot, surface: $t.surface, tx: $t.tx, ty: $t.ty, k: $t.k, w: $t.w, h: $t.h } }),
        }
    })
    { dumps: ($found | length), problems: $read.problems, results: $results } | to nuon | save -f $out
}
