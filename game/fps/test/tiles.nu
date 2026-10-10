# The tile pool's readers and oracles, lean: this module imports nothing,
# since code loaded into a nu slows its closures and its module calls in
# proportion, the test's own imports about 15 ms a call, so the test runs
# these in a nu of their own (`nu tiles.nu builder <api> <spec> <out>`)
# and keeps its heavy modules out of the per-texel loops.
#
# The builder's assertion: the tile dumps a capture holds, each closed by
# the console's answer to its D frame and held whole, every record in its
# place (`nu tiles.nu dumps <api> <out>` reads them alone), held texel by
# texel to the host's oracle, each texel the chain's at its tile's level
# lit by the light of its centre, bilinear over the lighting's nodes with
# the coordinate clamped to the last node, within the build's rounding.
#
# The handoff's statistics (`nu tiles.nu handoff <spec> <index> <out>`): captures
# of a wall seen head-on compared pixel by pixel over its rows and columns
# on the screen, each pixel's greatest channel difference, the pixels
# whose texel's light is clamped at the last node apart, and under partial
# residency each pixel's difference from the nearer of the tiled and the
# lit pictures.
#
# The lit loop's continuity (`nu tiles.nu lit-steps <capture> <rect>
# <crosshair> <out>`): the most a held-off picture of a white wall steps
# between two pixels side by side along its rows.

const RECORD = 64
const DUMP_KIND = 16
const TEXELS_KIND = 17
const CONSOLE_KIND = 11
const CONSOLE_D = 68
const SIDE = 64
# render.inc's DUMP_TEXELS and DUMP_RECORDS at 64: a tile's 4,096
# texels twelve a record, the last record's eight past them zero
const DUMP_TEXELS = 12
const DUMP_RECORDS = 342
# render.inc's REPORT_SCHEMA_VERSION and REPORT_SCHEMA, its offset
const SCHEMA = 5
const SCHEMA_AT = 60

# A tile's records closed: the problems its count and its padding raise,
# and the tile with its texels in rows when it is whole.
def close-tile [tile: record, payloads: list<binary>, at: int, dump: int, bad: bool]: nothing -> record<tile: any, problems: list<any>> {
    let count = ($payloads | length)
    let words = (if $count == 0 { [] } else { $payloads | bytes collect | chunks 4 | into int --endian little })
    let past = ($words | skip ($SIDE * $SIDE) | where {|w| $w != 0 })
    let problems = ([
        (if $count != $DUMP_RECORDS { { reason: "count", record: $at, dump: $dump, found: $"($count) texel records of ($DUMP_RECORDS)" } })
        (if $count == $DUMP_RECORDS and ($past | is-not-empty) { { reason: "padding", record: $at, dump: $dump, found: $"($past | length) texels past the tile's last not zero" } })
    ] | compact)
    { tile: (if (not $bad) and ($problems | is-empty) { $tile | insert texels ($words | first ($SIDE * $SIDE) | chunks $SIDE) } else { null }), problems: $problems }
}

# The tile dumps an API capture holds, each closed by the console's answer
# to its D frame, and every problem that breaks them. A record's kind and
# a console answer's command are the u32 words the program writes,
# little-endian. A dump is its tiles, each a header (kind 16) and then
# exactly DUMP_RECORDS texel records (kind 17), each record its tile's
# slot, its first texel twelve on from the record before's, and the
# schema, the texels past the tile's last zero, and every record 64
# bytes; after a tile's records, another header or the closing answer
# (kind 11, command 68), and nothing else. A header or the answer before
# a tile's records are whole leaves the tile short; any other record
# between a dump's first header and its answer is foreign, counting toward
# no tile, and outside a dump every record but a texel record is the
# game's own. Each tile read whole: its slot, key,
# surface, level, column, and row, its map's k, W, and H as the program
# holds them, and its texels in rows, each a texel's word as the program
# holds it, blue in its low byte, then green, red, and alpha. Each problem:
# its reason (header schema, slot, schema, first texel, missing, repeated,
# order, count, padding, foreign, orphan, truncated, or unfinished), the
# record's index in the capture, the dump's, and what was found; a tile
# with a problem is left out, and the problems stand whether or not any
# tile comes back.
export def dumps [api: binary]: nothing -> record<dumps: list<any>, problems: list<any>> {
    mut dumps = []
    mut problems = []
    mut tiles = []
    mut open = false
    mut tile: any = null
    mut header_at = 0
    mut payloads = []
    mut next = 0
    mut bad = false
    for e in ($api | chunks $RECORD | enumerate) {
        let r = $e.item
        let at = $e.index
        let dump = ($dumps | length)
        if ($r | bytes length) != $RECORD {
            $problems = ($problems | append { reason: "truncated", record: $at, dump: $dump, found: $"($r | bytes length) bytes of ($RECORD)" })
            break
        }
        let word = {|o: int| $r | bytes at $o..<($o + 4) | into int --endian little }
        let kind = (do $word 0)
        let command = (do $word 4)
        let answer = ($kind == $CONSOLE_KIND and $command == $CONSOLE_D)
        if ($kind == $DUMP_KIND or $answer) and $tile != null {
            let c = (close-tile $tile $payloads $header_at $dump $bad)
            $problems = ($problems | append $c.problems)
            if $c.tile != null { $tiles = ($tiles | append $c.tile) }
            $tile = null
        }
        if $kind == $DUMP_KIND {
            $tile = { slot: (do $word 4), key: (do $word 8), surface: (do $word 12), level: (do $word 16), tx: (do $word 20), ty: (do $word 24), k: (do $word 28), w: (do $word 32), h: (do $word 36) }
            $header_at = $at
            $payloads = []
            $next = 0
            $open = true
            $bad = ((do $word $SCHEMA_AT) != $SCHEMA)
            if $bad { $problems = ($problems | append { reason: "header schema", record: $at, dump: $dump, found: $"schema (do $word $SCHEMA_AT)" }) }
        } else if $kind == $TEXELS_KIND {
            if $tile == null {
                $problems = ($problems | append { reason: "orphan", record: $at, dump: $dump, found: "a texel record outside any tile" })
            } else {
                let slot = (do $word 4)
                let first = (do $word 8)
                let schema = (do $word $SCHEMA_AT)
                let order = (if ($first mod $DUMP_TEXELS) != 0 { "first texel" } else if $first == ($next - $DUMP_TEXELS) { "repeated" } else if $first > $next { "missing" } else if $first < $next { "order" } else { "" })
                let found = ([
                    (if $slot != $tile.slot { { reason: "slot", record: $at, dump: $dump, found: $"slot ($slot) in tile ($tile.slot)'s records" } })
                    (if $schema != $SCHEMA { { reason: "schema", record: $at, dump: $dump, found: $"schema ($schema)" } })
                    (if $order != "" { { reason: $order, record: $at, dump: $dump, found: $"first texel ($first) where ($next) was due" } })
                ] | compact)
                if ($found | is-not-empty) {
                    $problems = ($problems | append $found)
                    $bad = true
                }
                $payloads = ($payloads | append ($r | bytes at 12..<60))
                $next = (if ($first mod $DUMP_TEXELS) == 0 { $first + $DUMP_TEXELS } else { $next + $DUMP_TEXELS })
            }
        } else if $answer {
            $dumps = ($dumps | append [$tiles])
            $tiles = []
            $open = false
        } else if $open {
            let what = (if $kind == $CONSOLE_KIND { $"kind ($kind), command ($command)" } else { $"kind ($kind)" })
            $problems = ($problems | append { reason: "foreign", record: $at, dump: $dump, found: $"a record of ($what) inside the dump" })
            if $tile != null { $bad = true }
        }
    }
    let ending = ($api | bytes length) // $RECORD
    if $tile != null {
        let c = (close-tile $tile $payloads $header_at ($dumps | length) $bad)
        $problems = ($problems | append $c.problems)
    }
    if $open {
        $problems = ($problems | append { reason: "unfinished", record: $ending, dump: ($dumps | length), found: "a dump the capture ends inside, its D unanswered" })
    }
    { dumps: $dumps, problems: $problems }
}

# A capture's dumps and their problems, saved to out as NUON: the tiles
# read whole a dump, and every problem (dumps).
def "main dumps" [api: path, out: path] {
    let read = (dumps (open --raw $api | into binary))
    { tiles: ($read.dumps | each {|d| $d | length }), problems: $read.problems } | to nuon | save -f $out
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
# result, saved to out as NUON, the dumps' count, every problem `dumps`
# found, and each lighting's whole tiles with their headers and
# builder-tile's counts.
def "main builder" [api: path, spec: string, out: path] {
    let s = ($spec | from nuon)
    let read = (dumps (open --raw $api | into binary))
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

# A capture's bytes and where its pixels start, past the header's three
# lines.
def capture [file: path]: nothing -> record<bytes: binary, head: int> {
    let bytes = (open --raw $file | into binary)
    { bytes: $bytes, head: (($bytes | bytes index-of --all 0x[0a] | get 2) + 1) }
}

# A capture's pixels from x0 to x1 of row y, three bytes each.
def row-of [c: record<bytes: binary, head: int>, y: int, x0: int, x1: int]: nothing -> binary {
    let from = ($c.head + ((($y * 1920) + $x0) * 3))
    $c.bytes | bytes at $from..<($from + (($x1 - $x0) * 3))
}

# The most any channel differs, of 255, between each two pixels of two
# runs of pixels, three bytes each: the runs as integers at once and the
# arithmetic in one closure, a command called a pixel costing several
# times its work.
def apart [pa: binary, pb: binary]: nothing -> list<int> {
    apart-ints ($pa | chunks 3 | into int --endian little) ($pb | chunks 3 | into int --endian little)
}

# apart over two lists of pixels as integers, red in the low byte.
def apart-ints [ia: list<int>, ib: list<int>]: nothing -> list<int> {
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

# Each pixel of a run of `a` against the same of `b` and of `t`, three
# bytes a pixel, as one code: its difference from `b` (apart's) in bits 0
# to 7, its difference from the nearer of `t` and `b` in bits 8 to 15, and
# in bits 16 and up 1 where it lies nearer `t`, 2 where nearer `b`, 0
# where they tie or `t` and `b` are one colour there.
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

# The sum of a list of counts, 0 for none.
def total [counts: list<int>]: nothing -> int {
    $counts | reduce --fold 0 {|c, acc| $acc + $c }
}

# A histogram's statistics, each difference with its pixels: the pixels,
# those differing, and the most, the 99th, and the mean of the
# differences.
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

# Histograms merged, each difference with its pixels.
def merged [hists: list<any>]: nothing -> list<record<value: int, count: int>> {
    $hists | flatten | group-by value | items {|v, rows| { value: ($v | into int), count: (total ($rows | each {|r| $r.count })) } }
}

# The class of each pixel line from `from` to `to`, a column or a row of
# a wall seen head-on, whose texel coordinate of level 0 from the map's
# first node is `line.0 + line.1 i` at its centre: 1 where the texel of
# `level` holding it is centred past the node `last`, the light clamped
# there, 2 within a texel of level 0 of the first such texel's start,
# left out, and 0 before.
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

# The runs of equal values in a list whose first is at `base`: each run's
# first index, the index past its last, and its value.
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

# A run with the pixels from c0 to c1 taken out of it, none, one, or two
# runs.
def cut-run [run: record<from: int, to: int, value: int>, c0: int, c1: int]: nothing -> list<record<from: int, to: int, value: int>> {
    [
        { from: $run.from, to: ([$run.to, $c0] | math min), value: $run.value }
        { from: ([$run.from, $c1] | math max), to: $run.to, value: $run.value }
    ] | where {|r| $r.to > $r.from }
}

# A run of a row compared: its class, the histogram of its pixels'
# differences between `a` and `b`; and with `t`, a third capture, the
# histogram of each pixel's difference from the nearer of `t` and `b`,
# and its pixels nearer `t` and nearer `b` where those two differ.
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

# The handoff's differences, the spec a NUON file: the `rect` compared,
# [x0, y0, x1, y1] with the pixel past the last, the wall's own rows and
# columns on the screen; the `crosshair`'s half side, its square left
# out; the `stamp`'s cells, [x0, y0, x1, y1] as `rect`, left out; the
# map's `k`, `w`, and `h`; the texel coordinate of level 0 from
# the map's first node at the centre of pixel column x, `u.0 + u.1 x`,
# and of row y, `v.0 + v.1 y`, the wall head-on; and `pairs`, each a
# `name`, `lighting`, `kind`, and `level`, a capture `a` held to a
# capture `b`, and for partial residency a third, `t`, else empty; a pair
# with `whole` set reads its own `rect` with no texel map, every pixel
# of it inner, for a pose the wall's lines do not describe. The
# pair at `index`, its statistics saved to out as NUON with its own
# fields: the statistics of each pixel's greatest channel difference
# (spread-of) over the pixels whose texel lies wholly before the last
# node, `inner`, and over those whose texel is centred past it,
# `clamped`; the pixels left out, within a texel of level 0 of the
# boundary between those two, under the crosshair, or under the stamp;
# and with `t`, the
# statistics of each pixel's difference from the nearer of `t` and `b`,
# `residual`, and the rows taking pixels nearer each, `mixed_rows`. A pair
# a nu, the caller running them side by side: par-each within one nu
# under the system's build ran this work three times slower than each,
# all its threads busy.
def "main handoff" [spec: path, index: int, out: path] {
    let s = (open $spec)
    let ch = $s.crosshair
    let stamp = $s.stamp
    let p = ($s.pairs | get $index)
    let whole = ($p | get -o whole | default false)
    let rect = (if $whole { $p.rect } else { $s.rect })
    let cols = (if $whole { [{ from: $rect.0, to: $rect.2, value: 0 }] } else { runs-of (lines-of $rect.0 $rect.2 $s.u $p.level $s.k ($s.w - 1)) $rect.0 | where value != 2 })
    let rows = (if $whole { $rect.1..<$rect.3 | each {|y| 0 } } else { lines-of $rect.1 $rect.3 $s.v $p.level $s.k ($s.h - 1) })
    let a = (capture $p.a)
    let b = (capture $p.b)
    let t = (if $p.t == "" { null } else { capture $p.t })
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

# The lit loop's picture held continuous along its rows: over every row
# of `rect`, [x0, y0, x1, y1] with the pixel past the last, the
# crosshair's square of half side `crosshair` left out, the most any
# channel of two pixels side by side differs, with its row and the left
# pixel's column, and the rows read, saved to out as NUON. A lit span
# steps its brightness a pixel at a time and starts each interval from
# the one before's exact end sample, so on a white wall its steps are the
# light's change over a pixel and the rounding, where an interval
# starting from the light a block before steps by the light's change over
# a block.
def "main lit-steps" [capture: path, rect: string, crosshair: int, out: path] {
    let r = ($rect | from nuon)
    let c = (capture $capture)
    let ch = $crosshair
    let found = ($r.1..<$r.3 | each {|y|
        let whole = { from: $r.0, to: $r.2, value: 0 }
        let runs = (if (($y - 540) | math abs) <= $ch { cut-run $whole (960 - $ch) (961 + $ch) } else { [$whole] })
        $runs | where {|run| ($run.to - $run.from) >= 2 } | each {|run|
            let ints = (row-of $c $y $run.from $run.to | chunks 3 | into int --endian little)
            let steps = (apart-ints ($ints | drop 1) ($ints | skip 1))
            let most = ($steps | math max)
            { y: $y, x: ($run.from + ($steps | enumerate | where item == $most | get 0.index)), most: $most }
        }
    } | flatten)
    let worst = ($found | sort-by most | last)
    { most: $worst.most, x: $worst.x, y: $worst.y, rows: ($found | get y | uniq | length) } | to nuon | save -f $out
}

def main [] {
    print "nu tiles.nu builder <api> <spec> <out>; nu tiles.nu dumps <api> <out>; nu tiles.nu handoff <spec> <index> <out>; nu tiles.nu lit-steps <capture> <rect> <crosshair> <out>"
}
