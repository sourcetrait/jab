# workers's integration test, on a machine of four harts and three
# workers:
# - Hot, first, since it reads the ELF alone: mandel_row within one page of
#   code and free of ecalls. A loop across a page boundary runs many times
#   slower, which would fail the animation's timing before this said why.
# - Proof: the fixed frame, centred on (-0.5, 0) at 3/1920 a pixel with a
#   cap of 64, drawn by one, two, then three workers; each image hashed
#   before its bars and text, the three hashes equal; each frame's rows
#   by worker the deal's, summing to the frame with every row owned, so
#   each row has one owner; and three rows sent over the API equal to the
#   same rows computed here in the program's fixed point.
# - Bench: three workers over four seconds of the fixed frame (scaling.nu,
#   which `just bench example/workers/scaling` runs on a release build for
#   one, two, and three): the last frame's hash the proof's, each worker's
#   rows a third of every frame's, every row its band's worker's, the
#   bands forward in time and overlapping, and the worker harts busy at
#   once, their threads' CPU over a held second past the second.
# - Animation: on its own with no API, the zoom by the clock: one worker
#   first, its hart's thread busy and the idle workers' at rest over a
#   held second; at nine seconds, more than one worker by then, the bars
#   at the left in the deal's pattern and nowhere else, the caption's
#   text inside its black box, the palette on the rest.
use ../../../sdk/nu/jab.nu
use ./scaling.nu
use std/assert

# the program's fixed point: Q.28 in 64 bits, a product shifted right 28
# and twice x y right 27, each flooring as srai does; escape past 4
const ONE = 268435456
const HALF = 134217728
const ESCAPE = 1073741824
const CAP = 64
const WIDTH = 1920
const HEIGHT = 1080
const STEP = 419430
const CENTRE_X = -134217728
const CENTRE_Y = 0
const PALETTE = [0x421e0f 0x19071a 0x09012f 0x040449 0x000764 0x0c2c8a 0x1852b1 0x397dd1 0x86b5e5 0xd3ecf8 0xf1e9bf 0xf8c95f 0xffaa00 0xcc8000 0x995700 0x6a3403]
const SAMPLES = [100 540 900]
# each worker's rows of a frame when 135 bands of eight go round in turn
const DEAL = [[1080 0 0] [544 536 0] [360 360 360]]
const BARS = {"ff4040": 1, "40ff40": 2, "4080ff": 3}
const BAR_WIDTH = 12
const BAND_ROWS = 8
const BOX = {left: 12, top: 0, right: 511, bottom: 63}
# the CPU seconds an idle worker's vCPU thread may take over a held
# second, as test/jobs holds them, and the least a working one takes
const IDLE_CPU = 0.05
const BUSY_CPU = 0.5
const PALETTE_SEEN = 8

# A row of the fixed frame as the program computes it, each pixel's
# colour as an integer, 0x00RRGGBB.
def row-colors [row: int]: nothing -> list<int> {
    let left = ($CENTRE_X - ($WIDTH // 2) * $STEP)
    let cy = ($CENTRE_Y + ($HEIGHT // 2) * $STEP - $row * $STEP)
    0..<$WIDTH | each {|col|
        let cx = ($left + $col * $STEP)
        mut x = 0
        mut y = 0
        mut n = 0
        mut color = 0
        loop {
            let x2 = (($x * $x) // $ONE)
            let y2 = (($y * $y) // $ONE)
            if ($x2 + $y2) > $ESCAPE {
                $color = ($PALETTE | get ($n bit-and 15))
                break
            }
            let xy = (($x * $y) // $HALF)
            $x = ($x2 - $y2 + $cx)
            $y = ($xy + $cy)
            $n += 1
            if $n >= $CAP { break }
        }
        $color
    }
}

# Each hart's vCPU thread's CPU over a launch's held second.
def hart-cpu [threads: list<record<name: string, cpu: float>>]: nothing -> list<record<hart: int, cpu: float>> {
    $threads | where {|t| $t.name =~ '^CPU \d+/TCG$' } | each {|t| { hart: ($t.name | parse "CPU {n}/TCG" | get 0.n | into int), cpu: $t.cpu } } | sort-by hart
}

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let elf = ($image | path dirname | path join "workers.elf")
    let hot = (jab hot $elf ["mandel_row"] | first)
    assert $hot.paged $"Hot: mandel_row within one page of code: ($hot)"
    assert equal $hot.ecalls 0 $"Hot: no kernel call in mandel_row: ($hot)"

    let send = [[at, bytes]; [1sec, ("p" | into binary)]]
    let run = (jab launch --kernel $kernel --image $image --out ($out | path join "proof") --set $set --send $send --harts 4 --seconds 60)
    let got = ($run.serial | lines)
    assert equal $run.status 0 $"Proof: the exit status: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "Proof: QEMU has no complaint about the guest"
    assert equal ($got | length) 4 $"Proof: three frames' lines and the rows sent: ($run.serial)"
    let proofs = ($got | first 3 | each {|l| $l | parse "workers: proof {w} hash {hash} rows {r0} {r1} {r2} owned {owned}" | get -o 0 })
    for i in 0..2 {
        let p = ($proofs | get $i)
        assert ($p != null) $"Proof: frame ($i + 1)'s line: ($got | get $i)"
        assert equal ($p.w | into int) ($i + 1) $"Proof: frame ($i + 1)'s workers: ($got | get $i)"
        let rows = [($p.r0 | into int) ($p.r1 | into int) ($p.r2 | into int)]
        assert equal $rows ($DEAL | get $i) $"Proof: ($i + 1) workers' rows, the bands dealt in turn: ($got | get $i)"
        assert equal ($p.owned | into int) $HEIGHT $"Proof: every row of ($i + 1) workers' frame owned: ($got | get $i)"
    }
    let hashes = ($proofs | get hash | uniq)
    assert equal ($hashes | length) 1 $"Proof: one image whatever the workers: ($proofs | get hash)"
    let hash = ($hashes | first)
    assert equal ($got | get 3) $"workers: proof sent ($SAMPLES | length) rows" "Proof: the rows sent"
    assert equal ($run.api | bytes length) (($SAMPLES | length) * $WIDTH * 4) $"Proof: ($SAMPLES | length) rows of ($WIDTH) pixels over the API"
    for s in ($SAMPLES | enumerate) {
        let at = ($s.index * $WIDTH * 4)
        let theirs = ($run.api | bytes at $at..<($at + $WIDTH * 4) | chunks 4 | each {|p| $p | into int --endian little })
        let ours = (row-colors $s.item)
        let off = ($ours | zip $theirs | enumerate | where {|e| $e.item.0 != $e.item.1 } | get -o 0)
        let message = (if $off == null { "" } else { $"Proof: row ($s.item) as computed here: pixel ($off.index) is ($off.item.1) where the fixed point gives ($off.item.0)" })
        assert ($off == null) $message
    }

    let doc = (scaling measure $kernel $image ($out | path join "bench") $set --workers 3)
    let frames = $doc.frames
    assert equal $doc.workers 3 $"Bench: three workers: ($doc.workers)"
    assert ($frames >= 1) $"Bench: a frame at least in the stretch: ($frames)"
    assert equal $doc.hash $hash $"Bench: the last frame's hash the proof's: ($doc.hash)"
    let third = ($frames * $HEIGHT // 3)
    assert equal $doc.rows [$third $third $third] $"Bench: each worker's rows a third of ($frames) frames': ($doc.rows)"
    let strays = ($doc.owners | enumerate | where {|e| $e.item != ((($e.index // $BAND_ROWS) mod 3) + 1) } | get index)
    assert ($strays | is-empty) $"Bench: every row its band's worker's, band b on hart b mod 3 plus 1: rows ($strays | first 8)"
    let backward = ($doc.bands | where {|b| $b.start <= 0 or $b.end < $b.start } | get band)
    assert ($backward | is-empty) $"Bench: every band's interval forward in time: bands ($backward | first 8)"
    assert $doc.cpu_at_once $"Bench: the worker harts busy at once, their CPU over the held second past ($doc.at_once) s: ($doc.harts)"
    assert $doc.bands_at_once $"Bench: the last frame's bands overlapping, their time past ($doc.at_once) times the frame's span: ($doc.overlap)"

    let run = (jab launch --kernel $kernel --image $image --out ($out | path join "animation") --set $set --harts 4 --seconds 30 --capture 9sec --threads 1500ms)
    assert equal $run.serial "" "Animation: the UART stays silent"
    assert equal (open --raw $run.qemu_log) "" "Animation: QEMU has no complaint about the guest"
    let cpu = (hart-cpu $run.threads)
    assert equal ($cpu | length) 4 $"Animation: the harts' threads read over the held second: ($run.threads)"
    let working = ($cpu | where hart == 1 | get 0.cpu)
    assert ($working > $BUSY_CPU) $"Animation: one worker first, hart 1 at work over the held second: ($cpu)"
    for h in [2 3] {
        let idle = ($cpu | where hart == $h | get 0.cpu)
        assert ($idle <= $IDLE_CPU) $"Animation: hart ($h)'s worker, asleep in its await while one works, took ($idle) s of CPU over the held second, past ($IDLE_CPU)"
    }
    assert ($run.screen != "") "Animation: a screen was taken"
    let screen = (jab screen $run.screen)
    assert equal [$screen.width $screen.height] [$WIDTH $HEIGHT] "Animation: a 1080p frame"
    let lines = ($screen.pixels | chunks ($WIDTH * 3))
    let bar = ($lines | each {|r|
        let first = ($r | bytes at 0..<3 | encode hex | str lowercase)
        let last = ($r | bytes at (($BAR_WIDTH - 1) * 3)..<($BAR_WIDTH * 3) | encode hex | str lowercase)
        { first: $first, last: $last, hart: ($BARS | get -o $first) }
    })
    let unbarred = ($bar | enumerate | where {|e| $e.item.hart == null or $e.item.first != $e.item.last } | get index)
    assert ($unbarred | is-empty) $"Animation: every row's bar ($BAR_WIDTH) pixels of a worker's colour: rows ($unbarred | first 8)"
    let harts = ($bar | get hart)
    let w = ($harts | uniq | length)
    assert ($w >= 2) $"Animation: more than one worker by nine seconds: ($harts | uniq)"
    let misdealt = ($harts | enumerate | where {|e| $e.item != ((($e.index // $BAND_ROWS) mod $w) + 1) } | get index)
    assert ($misdealt | is-empty) $"Animation: the bars in the deal's pattern for ($w) workers: rows ($misdealt | first 8)"
    for c in ($BARS | columns) {
        let ink = (jab ink $screen $c)
        assert ($ink.count == 0 or $ink.right < $BAR_WIDTH) $"Animation: ($c) in the bars alone: ($ink)"
    }
    let text = (jab ink $screen "ffffff")
    assert ($text.count > 0) "Animation: the caption's text drawn"
    assert ($text.left > $BOX.left and $text.top > $BOX.top and $text.right < $BOX.right and $text.bottom < $BOX.bottom) $"Animation: the caption's text inside its box: ($text)"
    assert equal (jab pixel $screen ($BOX.left + 1) ($BOX.top + 1)) "000000" "Animation: the caption's box black at its top left"
    assert equal (jab pixel $screen $BOX.right $BOX.bottom) "000000" "Animation: the caption's box black at its bottom right"
    let seen = ($PALETTE | each {|c| jab ink $screen ($c | format number | get lowerhex | str replace "0x" "" | fill --alignment right --character "0" --width 6) | get count } | where {|n| $n > 0 } | length)
    assert ($seen >= $PALETTE_SEEN) $"Animation: the palette on the set's outside, ($PALETTE_SEEN) colours at least of 16: ($seen)"

    print $"workers: proof hash ($hash); bench ($frames) frames in ($doc.ms) ms with three, workers' CPU ($doc.worker_cpu | math round --precision 2) s over the held second, bands at once ($doc.overlap.concurrency | math round --precision 2); animation ($w) workers at nine seconds, hart 1 ($working | math round --precision 2) s"
    print "workers: ok"
}
