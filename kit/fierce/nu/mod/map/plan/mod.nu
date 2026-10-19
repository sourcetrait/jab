use (path self ..)

# The plan view's scale in SVG pixels a metre
const plan_scale = 24

# The plan view's margin about a storey's bounds, in metres
const plan_margin = 1.0

# The kernel's console font source, whose glyphs draw the plan's labels
const font_path = path self ../../../../../../kernel/src/font.S

# A console font glyph's width in pixels
const glyph_width = 12

# A console font glyph's height in pixels
const glyph_height = 24

# The kernel's console font from its glyph table, each character's rows
def font-glyphs []: nothing -> record {
    let text = (open --raw $font_path | decode)
    mut glyphs = {}
    mut code = -1
    mut rows = []
    for l in ($text | lines) {
        let t = ($l | str trim)
        if ($t | str starts-with "# ") and ($t =~ '^# \d+ ') {
            if $code >= 0 { $glyphs = ($glyphs | insert ($code | into string) $rows) }
            $code = ($t | parse --regex '^# (?P<code>\d+) ' | get 0.code | into int)
            $rows = []
        } else if ($t | str starts-with ".2byte ") {
            $rows = ($rows ++ ($t | str substring 7.. | split row "," | each {|v| $v | str trim | str substring 2.. | into int --radix 16 }))
        }
    }
    if $code >= 0 { $glyphs = ($glyphs | insert ($code | into string) $rows) }
    $glyphs
}

# A label as SVG rects of the console font's pixels, centred on a point
def label-svg [glyphs: record, text: string, cx: float, cy: float, colour: string]: nothing -> string {
    let chars = ($text | split chars)
    let x0 = ($cx - (($chars | length) * $glyph_width) / 2.0)
    let y0 = ($cy - $glyph_height / 2.0)
    mut out = []
    for c in ($chars | enumerate) {
        let code = ($c.item | into binary | bytes at 0..<1 | into int)
        let rows = ($glyphs | get -o ($code | into string) | default [])
        let gx = ($x0 + $c.index * $glyph_width)
        for r in ($rows | enumerate) {
            mut col = 0
            while $col < $glyph_width {
                let bit = (15 - $col)
                if (($r.item bit-shr $bit) bit-and 1) == 1 {
                    mut run = 1
                    while ($col + $run) < $glyph_width and (($r.item bit-shr ($bit - $run)) bit-and 1) == 1 { $run = ($run + 1) }
                    $out = ($out | append $"<rect x=\"($gx + $col)\" y=\"($y0 + $r.index)\" width=\"($run)\" height=\"1\" fill=\"($colour)\"/>")
                    $col = ($col + $run)
                } else {
                    $col = ($col + 1)
                }
            }
        }
    }
    $out | str join ""
}

# A storey's plan view as SVG: sectors by floor height, walls, entities
export def plan-svg [src: record, m: record, storey: string]: nothing -> string {
    let members = ($src.sectors | enumerate | where {|s| $s.item.storey == $storey } | get index)
    let secs = ($members | each {|i| $m.sectors | get $i })
    let min_x = (($secs | get bounds.min_x | math min) - $plan_margin)
    let min_y = (($secs | get bounds.min_y | math min) - $plan_margin)
    let max_x = (($secs | get bounds.max_x | math max) + $plan_margin)
    let max_y = (($secs | get bounds.max_y | math max) + $plan_margin)
    let w = (($max_x - $min_x) * $plan_scale)
    let h = (($max_y - $min_y) * $plan_scale)
    let px = {|x: float| ($x - $min_x) * $plan_scale }
    let py = {|y: float| ($max_y - $y) * $plan_scale }
    let heights = ($members | each {|i| let s = ($m.sectors | get $i); map plane-z $s.floor (($s.bounds.min_x + $s.bounds.max_x) / 2.0) (($s.bounds.min_y + $s.bounds.max_y) / 2.0) })
    let lo = ($heights | math min)
    let hi = ($heights | math max)
    let glyphs = (font-glyphs)
    mut out = [$"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"($w)\" height=\"($h)\" viewBox=\"0 0 ($w) ($h)\">", $"<rect width=\"($w)\" height=\"($h)\" fill=\"white\"/>"]
    for k in ($members | enumerate) {
        let i = $k.item
        let s = ($m.sectors | get $i)
        let t = (if $hi > $lo { (($heights | get $k.index) - $lo) / ($hi - $lo) } else { 0.5 })
        let hue = ((240.0 - 240.0 * $t) | math round)
        mut d = ""
        for li in $s.first_loop..<($s.first_loop + $s.loop_count) {
            let lp = ($m.loops | get $li)
            for wi in $lp.first_wall..<($lp.first_wall + $lp.wall_count) {
                let wall = ($m.walls | get $wi)
                let a = ($m.vertices | get $wall.a)
                $d = ($d + (if $wi == $lp.first_wall { "M" } else { "L" }) + $"(do $px $a.x) (do $py $a.y) ")
            }
            $d = ($d + "Z ")
        }
        $out = ($out | append $"<path d=\"($d)\" fill=\"hsl\(($hue), 60%, 75%\)\" fill-rule=\"evenodd\" stroke=\"none\"/>")
    }
    for k in $members {
        let s = ($m.sectors | get $k)
        for li in $s.first_loop..<($s.first_loop + $s.loop_count) {
            let lp = ($m.loops | get $li)
            for wi in $lp.first_wall..<($lp.first_wall + $lp.wall_count) {
                let wall = ($m.walls | get $wi)
                let a = ($m.vertices | get $wall.a)
                let b = ($m.vertices | get $wall.b)
                let colour = (if $wall.tag != 0 { "red" } else if $wall.portal_count > 0 { "#999" } else { "black" })
                let width = (if $wall.portal_count > 0 { 1 } else { 2 })
                $out = ($out | append $"<line x1=\"(do $px $a.x)\" y1=\"(do $py $a.y)\" x2=\"(do $px $b.x)\" y2=\"(do $py $b.y)\" stroke=\"($colour)\" stroke-width=\"($width)\"/>")
            }
        }
        let name = ($src.sectors | get $k | get name)
        let cx = (do $px (($s.bounds.min_x + $s.bounds.max_x) / 2.0))
        let cy = (do $py (($s.bounds.min_y + $s.bounds.max_y) / 2.0))
        $out = ($out | append (label-svg $glyphs $name $cx $cy "#333"))
    }
    for e in ($m.entities | enumerate) {
        let ent = $e.item
        if not ($ent.sector in $members) { continue }
        let cx = (do $px $ent.x)
        let cy = (do $py $ent.y)
        let r = ($plan_scale * 0.15)
        match $ent.class {
            0 => {
                let yaw = ($ent.yaw * 3.14159265358979 / 180.0)
                let ex = ($cx + ($yaw | math cos) * $plan_scale)
                let ey = ($cy - ($yaw | math sin) * $plan_scale)
                $out = ($out | append $"<circle cx=\"($cx)\" cy=\"($cy)\" r=\"($r)\" fill=\"green\"/><line x1=\"($cx)\" y1=\"($cy)\" x2=\"($ex)\" y2=\"($ey)\" stroke=\"green\" stroke-width=\"2\"/>")
            }
            1 => {
                $out = ($out | append $"<circle cx=\"($cx)\" cy=\"($cy)\" r=\"($ent.radius * $plan_scale)\" fill=\"none\" stroke=\"gold\" stroke-width=\"1\"/><circle cx=\"($cx)\" cy=\"($cy)\" r=\"($r)\" fill=\"gold\"/>")
            }
            3 => {
                $out = ($out | append $"<circle cx=\"($cx)\" cy=\"($cy)\" r=\"($r)\" fill=\"blue\"/>")
                if $ent.target >= 0 {
                    let t = ($m.entities | get $ent.target)
                    $out = ($out | append $"<line x1=\"($cx)\" y1=\"($cy)\" x2=\"(do $px $t.x)\" y2=\"(do $py $t.y)\" stroke=\"blue\" stroke-width=\"1\" stroke-dasharray=\"4 2\"/>")
                }
            }
            _ => {
                $out = ($out | append $"<circle cx=\"($cx)\" cy=\"($cy)\" r=\"($r)\" fill=\"purple\"/>")
            }
        }
    }
    $out = ($out | append "</svg>")
    $out | str join (char nl)
}
