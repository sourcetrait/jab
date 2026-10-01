# piano's integration test, through QEMU's monitor: A pressed and held
# for four tenths of a second plays middle C on the piano, and the host
# records it: a tone at 261.6 Hz by its zero crossings, at the level
# the piano's velocity gives, dying away as the piano does and gone
# soon after the key lifts; the twelve white keys stand in their row
# on the screen with their labels cut out of them in black.
use ../../../sdk/nu/jab.nu
use std/assert

const RATE = 48000
const MIDDLE_C = 261.63
# The piano at the example's velocity after the mixer's scaling:
# 32767 * 75 / 128 / 4
const PEAK = 4799
# A sample past this is the note and not silence
const HEARD = 500
# The keys' white and their row, as src/main.S sets them
const KEY_COLOR = "ffffff"
const KEYS = 12
const KEY_WIDTH = 140
const KEY_HEIGHT = 560
const ROW_X = 76
const ROW_Y = 260
const ROW_WIDTH = 1768
# A label is at most this many of a key's pixels, a bold cell of 37 by 72
const LABEL_PIXELS = 2664

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --sound --keys [[at, key, hold]; [1sec, "a", 400]] --capture 2500ms)
    print $"piano: status ($run.status) after ($run.wall_seconds | math round -p 2) seconds, ($run.debug | lines | length) kernel debug lines"
    assert equal $run.serial "" $"the UART stays silent: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    assert equal $run.stderr "" $"QEMU said nothing on its stderr: ($run.stderr)"
    assert ($run.debug | str contains "jab: sound at ") $"the kernel found the sound device: ($run.debug)"
    assert ($run.sound != "") "the host recorded the sound"
    assert ($run.screen != "") "a screen was taken"

    # the note: middle C on the piano, held four tenths of a second
    let wave = (jab wave $run.sound)
    assert equal [$wave.rate $wave.channels $wave.bits] [$RATE 2 16] $"the recording is in the one format: ($wave | reject samples)"
    let left = (0..<$wave.frames | each {|i| $wave.samples | bytes at ($i * 4)..<($i * 4 + 2) | into int --endian little --signed })
    let heard = ($left | enumerate | where {|s| ($s.item | math abs) > $HEARD } | get index)
    assert (($heard | length) > 0) "the note is in the recording"
    let first = ($heard | first)
    let last = ($heard | last)
    let seconds = (($last - $first) / $RATE)
    assert ($seconds > 0.4 and $seconds < 0.8) $"the note lasts the key's hold and its release: ($seconds)"
    let tone = ($left | slice $first..$last)
    let peak = ($tone | each {|s| $s | math abs } | math max)
    assert ($peak >= ($PEAK - 300) and $peak <= ($PEAK + 300)) $"at the piano's level for the velocity: ($peak)"
    let crossings = ($tone | window 2 | where {|w| ($w.0 < 0) != ($w.1 < 0) } | length)
    let frequency = ($crossings / 2.0 / $seconds)
    assert ($frequency > ($MIDDLE_C - 3) and $frequency < ($MIDDLE_C + 3)) $"the zero crossings count out middle C: ($frequency)"
    let tail = ($tone | last 2400 | each {|s| $s | math abs } | math max)
    assert ($tail < $peak * 0.7) $"the piano dies away: ($tail) at its end against ($peak)"

    # the keys: twelve white rectangles in their row, each less its label
    let screen = (jab screen $run.screen)
    let white = (jab ink $screen $KEY_COLOR)
    let whole = ($KEYS * $KEY_WIDTH * $KEY_HEIGHT)
    assert ($white.count <= $whole and $white.count >= ($whole - $KEYS * $LABEL_PIXELS)) $"the keys are white but for their labels: ($white.count) of ($whole)"
    assert ($white.count < $whole) $"the labels are cut out of the keys: ($white.count) of ($whole)"
    assert equal [$white.left $white.top $white.right $white.bottom] [$ROW_X $ROW_Y ($ROW_X + $ROW_WIDTH - 1) ($ROW_Y + $KEY_HEIGHT - 1)] $"the row sits where the program put it: ($white)"
    print $"piano: ($seconds | math round -p 2) seconds of ($frequency | math round -p 1) Hz at ($peak), falling to ($tail); ($white.count) white pixels of ($whole); QEMU used ($run.cpu_seconds) CPU seconds over ($run.wall_seconds | math round -p 2) seconds"
    print "piano: ok"
}
