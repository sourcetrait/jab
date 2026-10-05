# walk's integration test: the SDK built the repository's image
# directory into this program's romfs, the walker's sixteen frames
# among it, and after a few seconds every lane has walkers on the
# screen. The program's records over the API say which: one per walker
# that entered, with its lane, its side, its size, and its colour, and
# one per walker that left. Every lane entered a walker; every size is
# from five feet to seven; every colour is bright enough; and on the
# screen each lane shows at least one of its walkers by its colour,
# with its pixels inside its lane and its feet on the lane's floor. A
# walker's pixels are those of its colour that touch another of it, so a
# lone pixel another walker's shading made in that colour by chance
# stays out of its box; a small screen of a block and a lone pixel holds
# the rule first.
use ../../../sdk/nu/jab.nu
use std/assert

const lanes = 8
const lane_h = 135
const frame_h = 640
const scale_min = 53
const scale_max = 75

def main [--kernel: path, --image: path, --out: path, --assets: path, --set: string = ""] {
    # a 2 by 2 block at 1, 1 and a lone pixel at 6, 6, one colour, on an
    # 8 by 8 screen: the block's box alone
    let lone = (0..<64 | each {|p| if $p in [9 10 17 18 54] { 0x[a7 77 82] } else { 0x[00 00 00] } } | bytes collect)
    let small = (joined-ink { width: 8, height: 8, pixels: $lone } "a77782")
    assert equal $small { count: 4, left: 1, top: 1, right: 2, bottom: 2 } $"a lone pixel stays out of the box: ($small)"

    assert ($assets | path exists) "the sdk built the assets image"
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --disk $assets --serial "walk" --api --capture 8sec --seconds 30)
    assert equal $run.serial "" $"the UART stays silent: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    assert ($run.screen != "") "a screen was taken"
    let screen = (jab screen $run.screen)

    # the records: kind, lane, side, scale, then the tint as a word
    let bytes = $run.api
    let count = (($bytes | bytes length) // 8)
    assert ($count >= $lanes) $"at least one walker per lane entered: ($count) records"
    let records = (0..<$count | each {|i|
        let r = ($bytes | bytes at ($i * 8)..<($i * 8 + 8))
        {
            kind: ($r | bytes at 0..<1 | into int),
            lane: ($r | bytes at 1..<2 | into int),
            side: ($r | bytes at 2..<3 | into int),
            scale: ($r | bytes at 3..<4 | into int),
            tint: ($r | bytes at 4..<8 | into int --endian little),
        }
    })
    let entered = ($records | where kind == 1)
    assert equal ($entered | get lane | uniq | sort) (0..<$lanes | each {|l| $l }) "every lane took a walker"
    for r in $entered {
        assert ($r.side == 0 or $r.side == 1) $"a side is left or right: ($r)"
        assert ($r.scale >= $scale_min and $r.scale <= $scale_max) $"a size from five feet to seven: ($r)"
        for c in [16 8 0] {
            assert ((($r.tint bit-shr $c) bit-and 0xff) >= 64) $"a colour bright enough to see: ($r)"
        }
    }

    # the walkers on the screen: in every lane at least one of those
    # that entered is found by its colour, inside its lane, its feet on
    # the floor; a walker that entered just before the screen was taken
    # may still be off the edge
    mut seen = 0
    for lane in 0..<$lanes {
        let floor = (($lane + 1) * $lane_h)
        let found = ($entered | where lane == $lane | each {|walker|
            let hex = ($walker.tint | format number | get lowerhex | str substring 2.. | fill -a right -c "0" -w 6)
            let ink = (joined-ink $screen $hex)
            let dh = (($frame_h * $walker.scale) bit-shr 8)
            if $ink.count > 100 {
                assert ($ink.bottom < $floor) $"lane ($lane)'s walker ($hex) stands on its floor at ($floor): bottom ($ink.bottom)"
                assert ($ink.top >= ($floor - $dh)) $"lane ($lane)'s walker ($hex) is no taller than its size ($dh): top ($ink.top)"
                1
            } else { 0 }
        } | math sum)
        assert ($found > 0) $"lane ($lane) shows a walker"
        $seen += $found
    }
    print $"walk: ($entered | length) walkers entered over ($run.wall_seconds | math round -p 2) seconds, ($seen) on the screen in their lanes; QEMU used ($run.cpu_seconds) CPU seconds"
    print "walk: ok"
}

# Where a colour is on a screen, as `jab ink` says, over the pixels of
# it that touch another of it, a side or a corner.
def joined-ink [screen: record<width: int, height: int, pixels: binary>, color: string]: nothing -> record<count: int, left: int, top: int, right: int, bottom: int> {
    let w = $screen.width
    let h = $screen.height
    let rgb = ($color | decode hex)
    let px = $screen.pixels
    let same = {|x: int, y: int| $x >= 0 and $y >= 0 and $x < $w and $y < $h and ($px | bytes at (($y * $w + $x) * 3)..<(($y * $w + $x) * 3 + 3)) == $rgb }
    let around = [[-1 -1] [0 -1] [1 -1] [-1 0] [1 0] [-1 1] [0 1] [1 1]]
    let joined = ($px | bytes index-of --all $rgb | where {|i| $i mod 3 == 0 } | each {|i| { x: (($i // 3) mod $w), y: (($i // 3) // $w) } } | where {|p| $around | any {|d| do $same ($p.x + $d.0) ($p.y + $d.1) } })
    if ($joined | is-empty) { return { count: 0, left: -1, top: -1, right: -1, bottom: -1 } }
    { count: ($joined | length), left: ($joined | get x | math min), top: ($joined | get y | math min), right: ($joined | get x | math max), bottom: ($joined | get y | math max) }
}
