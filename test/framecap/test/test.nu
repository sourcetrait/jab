# framecap's integration test: a burst of flips is refused past the
# first, sixty-four awaited frames, whole and rectangular, take at
# least sixty-four periods of the cap, read from the SDK, a rectangle
# past the edge is refused with 4, a list of rectangles flips as one
# and a list with a bad one or none is refused, the kernel reports the
# symbols it was built with, and the hart halts while it waits, so
# QEMU's CPU time stays well under the run's length.
use ../../../sdk/nu/jab.nu
use std/assert

# Sixty-four awaited frames, half of them whole and half a rectangle
const FRAMES = 64

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let cap = (open --raw ($env.FILE_PWD | path join ".." ".." ".." "sdk" "jab.inc") | decode | parse --regex '\.set JAB_DISPLAY_FPS_CAP, (?P<cap>\d+)' | get 0.cap | into int)
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set)
    assert equal $run.status 0 $"exit status, with the UART: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    let report = ($run.serial | parse "refused={refused}\nbadrect={badrect}\nrects={rects}\nbadrects={badrects}\nnorects={norects}\nflags={flags}\npaced\n" | get -o 0 | default { refused: "", badrect: "", rects: "", badrects: "", norects: "", flags: "" })
    let refused = ($report.refused | into int)
    assert ($refused >= 60) $"the burst is refused past the first flip: ($refused) of 63"
    assert equal ($report.badrect | into int) 4 "a rectangle past the edge is refused with 4"
    assert equal ($report.rects | into int) 0 "a list of two rectangles goes through as one flip"
    assert equal ($report.badrects | into int) 4 "a list with a rectangle past the edge is refused with 4"
    assert equal ($report.norects | into int) 4 "a list of no rectangles is refused with 4"
    let flags = ($report.flags | into int)
    assert equal $flags 1 $"the kernel reports DEBUG and nothing else, as every test build sets it: flags ($flags)"
    let least = ($FRAMES / $cap)
    assert ($run.wall_seconds >= $least) $"sixty-four frames at ($cap) a second take at least ($least | math round -p 2) seconds: ($run.wall_seconds)"
    assert ($run.wall_seconds < ($least + 4.0)) $"and not much more: ($run.wall_seconds)"
    print $"framecap: ($refused) refused; QEMU used ($run.cpu_seconds) CPU seconds over ($run.wall_seconds | math round -p 2) seconds"
    assert ($run.cpu_seconds < ($run.wall_seconds * 0.5)) "the hart halts while it waits"
    print "framecap: ok"
}
