use ../../../../../nu/mod/capture
use ../../map.nu
use std/assert
use ../frame [RECORD]

# The clock's record kinds, which records leaves to the gauge's stream
const CLOCK_KINDS = [7 8 9 10 12 13 14 15 18]

# The pixels a compared opening is inset by from its edges
export const FIXTURE_INSET = 8

# The radius about the screen's centre a sample must lie outside
export const FIXTURE_CROSSHAIR = 6

# The frame number's low bits the HUD stamps, a cell each
export const STAMP_BITS = 16

# A stamp cell's side in pixels
export const STAMP_CELL = 4

# A stamp cell's colour for a one bit
export const STAMP_ONE = 0x[ff ff ff]

# A stamp cell's colour for a zero bit
export const STAMP_ZERO = 0x[00 00 00]

# A world point's pixel from an eye at a yaw, null behind or off screen
export def project [eye: record, yaw: int, point: list<float>]: nothing -> oneof<list<int>, nothing> {
    let rad = ($yaw * 3.141592653589793 / 180)
    let fx = ($rad | math cos)
    let fy = ($rad | math sin)
    let v = [($point.0 - $eye.x), ($point.1 - $eye.y), ($point.2 - $eye.z)]
    let depth = ($v.0 * $fx + $v.1 * $fy)
    if $depth <= 0.0625 { return null }
    let right = ($v.0 * $fy - $v.1 * $fx)
    let x = ((960 + $right / $depth * 960) | math round | into int)
    let y = ((540 - $v.2 / $depth * 960) | math round | into int)
    if $x < 1 or $x >= 1919 or $y < 1 or $y >= 1079 { return null }
    [$x, $y]
}

# A plan point's screen column from an eye at a yaw, null behind the near plane
export def project-x [eye: record, yaw: int, point: list<float>]: nothing -> oneof<int, nothing> {
    let rad = ($yaw * 3.141592653589793 / 180)
    let fx = ($rad | math cos)
    let fy = ($rad | math sin)
    let v = [($point.0 - $eye.x), ($point.1 - $eye.y)]
    let depth = ($v.0 * $fx + $v.1 * $fy)
    if $depth <= 0.0625 { return null }
    let right = ($v.0 * $fy - $v.1 * $fx)
    (960 + $right / $depth * 960) | math round | into int
}

# Every channel summed over the 3 by 3 pixels about a point of a capture
export def block-sum [bytes: binary, at: list<int>]: nothing -> int {
    let newlines = ($bytes | bytes index-of --all 0x[0a] | take 3)
    let head_len = ($newlines.2 + 1)
    [-1, 0, 1] | each {|dy|
        let o = ($head_len + (($at.1 + $dy) * 1920 + $at.0 - 1) * 3)
        $bytes | bytes at $o..<($o + 9) | encode hex | split chars | chunks 2 | each {|h| $h | str join "" | into int --radix 16 } | math sum
    } | math sum
}

# An API capture's records less the clock's: kind, sector, eye, times, fields
export def records [api: binary]: nothing -> table<kind: int, sector: int, x: float, y: float, z: float, yaw: float, pitch: float, roll: float, frame_us: int, game_us: int, fields: list<int>> {
    0..<(($api | bytes length) // $RECORD) | each {|i|
        let r = ($api | bytes at ($i * $RECORD)..<(($i + 1) * $RECORD))
        let kind = ($r | bytes at 0..<4 | into int --endian little)
        if $kind in $CLOCK_KINDS { null } else {
            {
                kind: $kind,
                sector: ($r | bytes at 4..<8 | into int --endian little --signed),
                x: (map float-at $r 8), y: (map float-at $r 12), z: (map float-at $r 16),
                yaw: (map float-at $r 20), pitch: (map float-at $r 24), roll: (map float-at $r 28),
                frame_us: ($r | bytes at 32..<36 | into int --endian little),
                game_us: ($r | bytes at 36..<40 | into int --endian little),
                fields: (0..<5 | each {|f| $r | bytes at (40 + $f * 4)..<(44 + $f * 4) | into int --endian little --signed }),
            }
        }
    } | compact
}

# The frame number a capture's HUD stamp carries, null when unreadable
export def stamp [bytes: binary]: nothing -> oneof<int, nothing> {
    let head = (ppm-head $bytes)
    mut value = 0
    for bit in 0..<$STAMP_BITS {
        let cell = (0..<$STAMP_CELL | each {|y| 0..<$STAMP_CELL | each {|x| pixel-at $bytes $head [(($bit * $STAMP_CELL) + $x), $y] } } | flatten | uniq)
        if $cell == [$STAMP_ONE] {
            $value = ($value bit-or (1 bit-shl $bit))
        } else if $cell != [$STAMP_ZERO] {
            return null
        }
    }
    $value
}

# How two captures differ over a rectangle: pixels, differing, largest
export def region-delta [p: binary, q: binary, rect: list<int>]: nothing -> record<pixels: int, differing: int, largest: int> {
    let hp = (ppm-head $p)
    let hq = (ppm-head $q)
    let y0 = $rect.1
    let y1 = $rect.3
    let rows = ($y0..<$y1 | each {|y|
        let from = ((($y * 1920) + $rect.0) * 3)
        let to = ((($y * 1920) + $rect.2) * 3)
        let a = ($p | bytes at ($hp + $from)..<($hp + $to))
        let b = ($q | bytes at ($hq + $from)..<($hq + $to))
        if $a == $b { { differing: 0, largest: 0 } } else {
            let deltas = ($a | chunks 3 | zip ($b | chunks 3) | where {|c| $c.0 != $c.1 } | each {|c|
                let u = ($c.0 | into int --endian little)
                let v = ($c.1 | into int --endian little)
                [((($u bit-and 255) - ($v bit-and 255)) | math abs) (((($u bit-shr 8) bit-and 255) - (($v bit-shr 8) bit-and 255)) | math abs) ((($u bit-shr 16) - ($v bit-shr 16)) | math abs)] | math max
            })
            { differing: ($deltas | length), largest: (if ($deltas | is-empty) { 0 } else { $deltas | math max }) }
        }
    })
    let pixels = (($rect.2 - $rect.0) * ($rect.3 - $rect.1))
    if ($rows | is-empty) { return { pixels: $pixels, differing: 0, largest: 0 } }
    { pixels: $pixels, differing: ($rows | get differing | math sum), largest: ($rows | get largest | math max) }
}

# The fixture wall's opening on the screen, inset by FIXTURE_INSET
export def fixture-opening [m: record, wall: record, eye: record]: nothing -> list<int> {
    let across = ($m.sectors | get ($m.portals | get $wall.first_portal | get sector))
    let corners = ([($m.vertices | get $wall.a), ($m.vertices | get $wall.b)] | each {|p|
        [(map plane-z $across.ceiling $p.x $p.y), (map plane-z $across.floor $p.x $p.y)] | each {|z|
            let depth = ($p.x - $eye.x)
            { x: (960 + (($eye.y - $p.y) / $depth) * 960), y: (540 - (($z - $eye.z) / $depth) * 960) }
        }
    } | flatten)
    let x0 = ((($corners | get x | math min) | math ceil | into int) + $FIXTURE_INSET)
    let x1 = ((($corners | get x | math max) | math floor | into int) - $FIXTURE_INSET)
    let top = ((($corners | get y | math min) | math ceil | into int) + $FIXTURE_INSET)
    let bottom = ((($corners | get y | math max) | math floor | into int) - $FIXTURE_INSET)
    let y0 = ([$top, 0] | math max)
    let y1 = ([$bottom, 1080] | math min)
    [$x0, $y0, $x1, $y1]
}

# The rows of a rectangle over which two captures differ
export def rows-differ [p: binary, q: binary, rect: list<int>]: nothing -> list<int> {
    let hp = (ppm-head $p)
    let hq = (ppm-head $q)
    let y0 = $rect.1
    let y1 = $rect.3
    $y0..<$y1 | each {|y|
        let from = ((($y * 1920) + $rect.0) * 3)
        let to = ((($y * 1920) + $rect.2) * 3)
        if ($p | bytes at ($hp + $from)..<($hp + $to)) == ($q | bytes at ($hq + $from)..<($hq + $to)) { null } else { $y }
    } | compact
}

# The rows two captures differ over, the HUD stamp's cells skipped
export def unstamped-differ [p: binary, q: binary]: nothing -> list<int> {
    let cells = ($STAMP_BITS * $STAMP_CELL)
    rows-differ $p $q [$cells 0 1920 $STAMP_CELL] | append (rows-differ $p $q [0 $STAMP_CELL 1920 1080])
}

# A recording's peak and mean level between two seconds, left channel
export def sound-level [wav: path, from: float, to: float]: nothing -> record<from: float, to: float, peak: int, mean: float> {
    let w = (capture wave $wav)
    let frame_bytes = ($w.channels * ($w.bits // 8))
    let a = (($from * $w.rate) | math round | into int)
    let b = ([(($to * $w.rate) | math round | into int), $w.frames] | math min)
    assert ($b > ($a + 97)) $"the recording reaches ($to) s: ($w.frames) frames at ($w.rate)"
    let picks = (seq $a 97 ($b - 1) | each {|f|
        $w.samples | bytes at ($f * $frame_bytes)..<($f * $frame_bytes + 2) | into int --endian little --signed | math abs
    })
    { from: $from, to: $to, peak: ($picks | math max), mean: ($picks | math avg) }
}

# The mean channel value over a capture's block, every fourth pixel
export def mean-brightness [ppm: path, block: list<int>]: nothing -> float {
    let bytes = (open --raw $ppm | into binary)
    let newlines = ($bytes | bytes index-of --all 0x[0a] | take 3)
    let head_len = ($newlines.2 + 1)
    let sums = (0..<($block.3 // 4) | each {|r|
        let y = ($block.1 + $r * 4)
        let row = ($bytes | bytes at ($head_len + ($y * 1920 + $block.0) * 3)..<($head_len + ($y * 1920 + $block.0 + $block.2) * 3))
        0..<($block.2 // 4) | each {|c| $row | bytes at ($c * 12)..<($c * 12 + 3) | encode hex | split chars | chunks 2 | each {|h| $h | str join "" | into int --radix 16 } | math sum } | math sum
    } | math sum)
    $sums / (($block.2 // 4) * ($block.3 // 4) * 3)
}

# A pixel of a capture file, read from its path, as its three bytes
export def pixel [ppm: path, at: list<int>]: nothing -> binary {
    let bytes = (open --raw $ppm | into binary)
    pixel-at $bytes (ppm-head $bytes) $at
}

# The bytes of a capture's three-line header
export def ppm-head [bytes: binary]: nothing -> int {
    let newlines = ($bytes | bytes index-of --all 0x[0a] | take 3)
    $newlines.2 + 1
}

# A pixel of a capture's bytes held whole, as its three bytes
export def pixel-at [bytes: binary, head: int, at: list<int>]: nothing -> binary {
    let o = ($head + (($at.1 * 1920) + $at.0) * 3)
    $bytes | bytes at $o..<($o + 3)
}
