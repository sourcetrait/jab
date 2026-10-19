use (path self ../handoff)
use (path self ..)

# The most the lit loop's picture steps between side-by-side pixels, as NUON
export def main [capture: path, rect: string, crosshair: int, out: path] {
    let r = ($rect | from nuon)
    let c = (tiles capture $capture)
    let ch = $crosshair
    let found = ($r.1..<$r.3 | each {|y|
        let whole = { from: $r.0, to: $r.2, value: 0 }
        let runs = (if (($y - 540) | math abs) <= $ch { handoff cut-run $whole (960 - $ch) (961 + $ch) } else { [$whole] })
        $runs | where {|run| ($run.to - $run.from) >= 2 } | each {|run|
            let ints = (handoff row-of $c $y $run.from $run.to | chunks 3 | into int --endian little)
            let steps = (handoff apart-ints ($ints | drop 1) ($ints | skip 1))
            let most = ($steps | math max)
            { y: $y, x: ($run.from + ($steps | enumerate | where item == $most | get 0.index)), most: $most }
        }
    } | flatten)
    let worst = ($found | sort-by most | last)
    { most: $worst.most, x: $worst.x, y: $worst.y, rows: ($found | get y | uniq | length) } | to nuon | save -f $out
}
