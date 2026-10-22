use (path self ..)

# A capture's pixels from x0 to x1 of row y, three bytes each
export def row-of [c: record<bytes: binary, head: int>, y: int, x0: int, x1: int]: nothing -> binary {
    let from = ($c.head + ((($y * 1920) + $x0) * 3))
    $c.bytes | bytes at $from..<($from + (($x1 - $x0) * 3))
}

# The most any channel differs, of 255, between each two pixels of two runs
def apart [pa: binary, pb: binary]: nothing -> list<int> {
    apart-ints ($pa | chunks 3 | into int --endian little) ($pb | chunks 3 | into int --endian little)
}

# The most any channel differs per pixel pair, the pixels as integers
export def apart-ints [ia: list<int>, ib: list<int>]: nothing -> list<int> {
    $ia | zip $ib | each {|c|
        let u = $c.0
        let v = $c.1
        if $u == $v { 0 } else {
            let r = (($u bit-and 255) - ($v bit-and 255))
            let g = ((($u bit-shr 8) bit-and 255) - (($v bit-shr 8) bit-and 255))
            let b = (($u bit-shr 16) - ($v bit-shr 16))
            let r = (if $r < 0 { 0 - $r } else { $r })
            let g = (if $g < 0 { 0 - $g } else { $g })
            let b = (if $b < 0 { 0 - $b } else { $b })
            if $r > $g { if $r > $b { $r } else { $b } } else { if $g > $b { $g } else { $b } }
        }
    }
}

# Each pixel of `a` against `b` and `t` as one code: differences and the nearer
def apart3 [pa: binary, pb: binary, pt: binary]: nothing -> list<int> {
    let ia = ($pa | chunks 3 | into int --endian little)
    let ib = ($pb | chunks 3 | into int --endian little)
    let it = ($pt | chunks 3 | into int --endian little)
    $ia | zip $ib | zip $it | each {|c|
        let u = $c.0.0
        let v = $c.0.1
        let w = $c.1
        let db = (if $u == $v { 0 } else {
            let r = (($u bit-and 255) - ($v bit-and 255))
            let g = ((($u bit-shr 8) bit-and 255) - (($v bit-shr 8) bit-and 255))
            let b = (($u bit-shr 16) - ($v bit-shr 16))
            let r = (if $r < 0 { 0 - $r } else { $r })
            let g = (if $g < 0 { 0 - $g } else { $g })
            let b = (if $b < 0 { 0 - $b } else { $b })
            if $r > $g { if $r > $b { $r } else { $b } } else { if $g > $b { $g } else { $b } }
        })
        let dt = (if $u == $w { 0 } else {
            let r = (($u bit-and 255) - ($w bit-and 255))
            let g = ((($u bit-shr 8) bit-and 255) - (($w bit-shr 8) bit-and 255))
            let b = (($u bit-shr 16) - ($w bit-shr 16))
            let r = (if $r < 0 { 0 - $r } else { $r })
            let g = (if $g < 0 { 0 - $g } else { $g })
            let b = (if $b < 0 { 0 - $b } else { $b })
            if $r > $g { if $r > $b { $r } else { $b } } else { if $g > $b { $g } else { $b } }
        })
        let side = (if $v == $w { 0 } else if $dt < $db { 1 } else if $db < $dt { 2 } else { 0 })
        $db bit-or ((if $dt < $db { $dt } else { $db }) bit-shl 8) bit-or ($side bit-shl 16)
    }
}

# The sum of a list of counts, 0 for none
def total [counts: list<int>]: nothing -> int {
    $counts | reduce --fold 0 {|c, acc| $acc + $c }
}

# A histogram's statistics: pixels, those differing, most, 99th, and mean
def spread-of [hist: list<record<value: int, count: int>>]: nothing -> record<pixels: int, differing: int, most: int, p99: int, mean: float> {
    let pixels = (total ($hist | each {|h| $h.count }))
    if $pixels == 0 { return { pixels: 0, differing: 0, most: 0, p99: 0, mean: 0.0 } }
    let sorted = ($hist | sort-by value)
    let target = (0.99 * $pixels)
    let p99 = ($sorted | reduce --fold { at: 0, p99: -1 } {|h, acc|
        if $acc.p99 >= 0 { $acc } else {
            let at = ($acc.at + $h.count)
            { at: $at, p99: (if $at >= $target { $h.value } else { -1 }) }
        }
    } | get p99)
    {
        pixels: $pixels, differing: (total ($sorted | where value > 0 | each {|h| $h.count })),
        most: ($sorted | last | get value), p99: $p99,
        mean: ((total ($sorted | each {|h| $h.value * $h.count })) / $pixels),
    }
}

# Histograms merged, each difference with its pixels
def merged [hists: list<any>]: nothing -> list<record<value: int, count: int>> {
    $hists | flatten | group-by value | items {|v, rows| { value: ($v | into int), count: (total ($rows | each {|r| $r.count })) } }
}

# Each pixel line's class: 1 centred past the last node, 2 left out, 0 before
def lines-of [from: int, to: int, line: list<float>, level: int, k: int, last: int]: nothing -> list<int> {
    let span = (2.0 ** $level)
    let ratio = (2.0 ** ($level - $k))
    let start = ((((($last / $ratio) - 0.5) | math floor) + 1) * $span)
    $from..<$to | each {|i|
        let t = ($line.0 + ($line.1 * $i))
        let x = (($t / $span) | math floor)
        if (($t - $start) | math abs) < 1.0 { 2 } else if ((($x + 0.5) * $ratio) > $last) { 1 } else { 0 }
    }
}

# The runs of equal values in a list: each run's first, past-last, and value
def runs-of [values: list<int>, base: int]: nothing -> list<record<from: int, to: int, value: int>> {
    let n = ($values | length)
    mut runs = []
    mut from = 0
    for i in 1..$n {
        if $i == $n or ($values | get $i) != ($values | get $from) {
            $runs = ($runs | append { from: ($base + $from), to: ($base + $i), value: ($values | get $from) })
            $from = $i
        }
    }
    $runs
}

# A run with the pixels from c0 to c1 taken out: none, one, or two runs
export def cut-run [run: record<from: int, to: int, value: int>, c0: int, c1: int]: nothing -> list<record<from: int, to: int, value: int>> {
    [
        { from: $run.from, to: ([$run.to, $c0] | math min), value: $run.value }
        { from: ([$run.from, $c1] | math max), to: $run.to, value: $run.value }
    ] | where {|r| $r.to > $r.from }
}

# A run of a row compared: its class and its pixels' difference histograms
def segment [a: record, b: record, t: any, y: int, run: record<from: int, to: int, value: int>]: nothing -> record<y: int, value: int, hist: list<any>, residual: list<any>, near_t: int, near_b: int> {
    let pa = (row-of $a $y $run.from $run.to)
    let pb = (row-of $b $y $run.from $run.to)
    if $t == null {
        let hist = (if $pa == $pb { [{ value: 0, count: ($run.to - $run.from) }] } else { apart $pa $pb | uniq --count })
        return { y: $y, value: $run.value, hist: $hist, residual: [], near_t: 0, near_b: 0 }
    }
    let codes = (apart3 $pa $pb (row-of $t $y $run.from $run.to) | uniq --count)
    let side = {|s: int| total ($codes | where {|c| ($c.value bit-shr 16) == $s } | each {|c| $c.count }) }
    {
        y: $y, value: $run.value,
        hist: ($codes | each {|c| { value: ($c.value bit-and 255), count: $c.count } }),
        residual: ($codes | each {|c| { value: (($c.value bit-shr 8) bit-and 255), count: $c.count } }),
        near_t: (do $side 1), near_b: (do $side 2),
    }
}

# The handoff pair at `index` compared, its statistics saved to `out` as NUON
export def main [spec: path, index: int, out: path]: nothing -> nothing {
    let s = (open $spec)
    let ch = $s.crosshair
    let stamp = $s.stamp
    let p = ($s.pairs | get $index)
    let whole = ($p | get -o whole | default false)
    let rect = (if $whole { $p.rect } else { $s.rect })
    let cols = (if $whole { [{ from: $rect.0, to: $rect.2, value: 0 }] } else { runs-of (lines-of $rect.0 $rect.2 $s.u $p.level $s.k ($s.w - 1)) $rect.0 | where value != 2 })
    let rows = (if $whole { $rect.1..<$rect.3 | each {|y| 0 } } else { lines-of $rect.1 $rect.3 $s.v $p.level $s.k ($s.h - 1) })
    let a = (tiles capture $p.a)
    let b = (tiles capture $p.b)
    let t = (if $p.t == "" { null } else { tiles capture $p.t })
    let segments = ($rows | enumerate | each {|r|
        let y = ($rect.1 + $r.index)
        if $r.item == 2 { [] } else {
            let runs = ($cols | each {|c| if $r.item == 1 { $c | update value 1 } else { $c } })
            let crossed = (if (($y - 540) | math abs) <= $ch { $runs | each {|c| cut-run $c (960 - $ch) (961 + $ch) } | flatten } else { $runs })
            let kept = (if $y >= $stamp.1 and $y < $stamp.3 { $crossed | each {|c| cut-run $c $stamp.0 $stamp.2 } | flatten } else { $crossed })
            $kept | each {|c| segment $a $b $t $y $c }
        }
    } | flatten)
    let counted = (total ($segments | each {|g| total ($g.hist | each {|h| $h.count }) }))
    {
        name: $p.name, pose: ($p | get -o pose | default ""), lighting: $p.lighting, kind: $p.kind, level: $p.level,
        inner: (spread-of (merged ($segments | where value == 0 | each {|g| $g.hist }))),
        clamped: (spread-of (merged ($segments | where value == 1 | each {|g| $g.hist }))),
        left_out: ((($rect.2 - $rect.0) * ($rect.3 - $rect.1)) - $counted),
        residual: (spread-of (merged ($segments | each {|g| $g.residual }))),
        mixed_rows: ($segments | group-by y | items {|y, gs| ((total ($gs | each {|g| $g.near_t })) > 0) and ((total ($gs | each {|g| $g.near_b })) > 0) } | where {|m| $m } | length),
    } | to nuon | save -f $out
}
