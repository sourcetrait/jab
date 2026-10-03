# fillrate's integration test: every mode reports a line, each rendered
# frames, the flip mode showed some, the screen taken after the last
# mode holds the texture's colours, so the stores reached the
# framebuffer, and the rates are worked out from the clock and printed;
# the numbers themselves are the measurement, not an expectation. The
# polygon, fixed, integer, and lit modes are the renderer's span
# priced: their rates against perspective's say what a float depth
# test, an integer one, a span with no float at all, and the brightness
# multiply cost a pixel.
use ../../../../../../sdk/nu/jab.nu
use std/assert

# Three seconds a mode, eight modes and a ninth with --set vector,
# then the last frame stays up; the capture lands after the last line
const MODE_SECONDS = 3
const SETTLE = 1.5sec

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let hz = (open --raw ($env.FILE_PWD | path join ".." ".." ".." ".." ".." ".." "sdk" "src" "jab.inc") | decode | parse --regex '\.set JAB_TIME_HZ, (?P<hz>\d+)' | get 0.hz | into int)
    let vector = (($set | split row "," | each {|s| $s | str trim | str uppercase }) | any {|s| $s == "VECTOR" })
    let wanted = (["fill" "texture" "perspective" "polygon" "fixed" "integer" "lit"] ++ (if $vector { ["vector"] } else { [] }) ++ ["textureflip"])
    let capture = ((($wanted | length) * $MODE_SECONDS * 1sec) + $SETTLE)
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --seconds 40 --capture $capture)
    assert equal $run.status 0 $"exit status, with the UART: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    let modes = ($run.serial | lines | each {|l|
        $l | parse --regex '^(?P<mode>\w+) frames=(?P<frames>\d+) shown=(?P<shown>\d+) ticks=(?P<ticks>\d+) pixels=(?P<pixels>\d+)$' | get -o 0
    } | compact | each {|m|
        let seconds = (($m.ticks | into int) / $hz)
        let frames = ($m.frames | into int)
        {
            mode: $m.mode,
            frames: $frames,
            shown: ($m.shown | into int),
            seconds: ($seconds | math round -p 2),
            fps: (($frames / $seconds) | math round -p 1),
            mpixels_s: ((($frames * ($m.pixels | into int)) / $seconds / 1_000_000) | math round -p 1),
        }
    })
    for w in $wanted { assert ($w in ($modes | get mode)) $"the ($w) mode reported, with the UART: ($run.serial)" }
    for m in $modes { assert ($m.frames > 0) $"($m.mode) rendered frames" }
    let flip = ($modes | where mode == "textureflip" | first)
    assert ($flip.shown > 0) "flips went through in the flip mode"
    # the screen: the texture's two base colours, each exact at the
    # texel column where the gradient adds nothing, in half the rows
    assert ($run.screen != "") "a screen was taken"
    let screen = (jab screen $run.screen)
    assert equal [$screen.width $screen.height] [1920 1080] "a 1080p frame"
    let orange = (jab ink $screen "ff8040")
    let blue = (jab ink $screen "0040ff")
    assert ($orange.count > 1000) $"the texture's orange reached the screen: ($orange.count) pixels"
    assert ($blue.count > 1000) $"the texture's blue reached the screen: ($blue.count) pixels"
    print ($modes | table)
    print $"fillrate: QEMU used ($run.cpu_seconds) CPU seconds over ($run.wall_seconds | math round -p 2) seconds; ($orange.count) orange and ($blue.count) blue pixels on the screen"
    print "fillrate: ok"
}
