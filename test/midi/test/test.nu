# midi's integration test: the kernel's synthesizer plays a note over
# the live calls and the host records it: a second of the square lead
# at the A above middle C, 440 Hz by its zero crossings, at the level
# full velocity gives, falling away once the note is released, and
# the stream still running in silence after it. The program spins the
# whole time, so every refill of the stream came through the trap
# vector rather than a wait.
use ../../../sdk/nu/jab.nu
use std/assert

const RATE = 48000
const TONE = 440
# Full velocity on the square lead after the mixer's scaling: 32767 *
# 96 / 128 / 4
const PEAK = 6143
# A sample past this is the note and not silence
const HEARD = 500

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --sound --seconds 15)
    assert equal $run.status 0 $"exit status, with the UART: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    assert ($run.debug | str contains "jab: sound at ") $"the kernel found the sound device: ($run.debug)"
    assert ($run.sound != "") "the host recorded the sound"
    let wave = (jab wave $run.sound)
    assert equal [$wave.rate $wave.channels $wave.bits] [$RATE 2 16] $"the recording is in the one format: ($wave | reject samples)"
    # the left channel, then the stretch where the note is
    let left = (0..<$wave.frames | each {|i| $wave.samples | bytes at ($i * 4)..<($i * 4 + 2) | into int --endian little --signed })
    let heard = ($left | enumerate | where {|s| ($s.item | math abs) > $HEARD } | get index)
    assert (($heard | length) > 0) "the note is in the recording"
    let first = ($heard | first)
    let last = ($heard | last)
    let seconds = (($last - $first) / $RATE)
    assert ($seconds > 0.95 and $seconds < 1.2) $"the note lasts the second it was held and its release: ($seconds)"
    let tone = ($left | slice $first..$last)
    let peak = ($tone | each {|s| $s | math abs } | math max)
    assert ($peak >= ($PEAK - 300) and $peak <= ($PEAK + 300)) $"at full velocity's level: ($peak)"
    let crossings = ($tone | window 2 | where {|w| ($w.0 < 0) != ($w.1 < 0) } | length)
    let frequency = ($crossings / 2.0 / $seconds)
    assert ($frequency > ($TONE - 2) and $frequency < ($TONE + 2)) $"the zero crossings count out ($TONE) Hz: ($frequency)"
    # the release: the last 20 ms heard are well under the peak
    let tail = ($tone | last 960 | each {|s| $s | math abs } | math max)
    assert ($tail < $peak / 2) $"the note falls away once released: ($tail) at its end against ($peak)"
    # the stream ran on in silence while the program spun
    let after = (($wave.frames - $last) / $RATE)
    assert ($after > 0.3) $"the stream kept running after the note: ($after) seconds recorded after it"
    print $"midi: ($seconds | math round -p 2) seconds of ($frequency | math round -p 1) Hz at ($peak), falling to ($tail), then ($after | math round -p 2) seconds of silence; QEMU used ($run.cpu_seconds) CPU seconds over ($run.wall_seconds | math round -p 2) seconds"
    print "midi: ok"
}
