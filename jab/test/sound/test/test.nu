# sound's integration test: the kernel brings the sound device up in
# the one format and a second of a 440 Hz square wave the program
# writes reaches the host, which records it. The recording is 48 kHz
# stereo 16-bit, holds the tone for the whole second, since the exit
# plays the ring out, at the amplitude the program set, and its zero
# crossings count out 440 Hz.
use ../../../sdk/nu/jab.nu
use std/assert

const RATE = 48000
const AMPLITUDE = 16000
const TONE = 440
# A sample past this is the tone and not silence
const HEARD = 1000

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --sound --seconds 15)
    assert equal $run.status 0 $"exit status, with the UART: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    assert ($run.debug | str contains "jab: sound at ") $"the kernel found the sound device: ($run.debug)"
    assert ($run.sound != "") "the host recorded the sound"
    let wave = (jab wave $run.sound)
    assert equal [$wave.rate $wave.channels $wave.bits] [$RATE 2 16] $"the recording is in the one format: ($wave | reject samples)"
    assert ($wave.frames > 40000) $"most of a second was recorded: ($wave.frames) frames"
    # the left channel, then the stretch where the tone is
    let left = (0..<$wave.frames | each {|i| $wave.samples | bytes at ($i * 4)..<($i * 4 + 2) | into int --endian little --signed })
    let heard = ($left | enumerate | where {|s| ($s.item | math abs) > $HEARD } | get index)
    assert (($heard | length) > 0) "the tone is in the recording"
    let first = ($heard | first)
    let last = ($heard | last)
    let seconds = (($last - $first) / $RATE)
    assert ($seconds > 0.95 and $seconds < 1.05) $"the tone lasts the second the program wrote: ($seconds)"
    let tone = ($left | slice $first..$last)
    let peak = ($tone | each {|s| $s | math abs } | math max)
    assert ($peak >= ($AMPLITUDE - 500) and $peak <= $AMPLITUDE) $"at the amplitude the program set: ($peak)"
    let crossings = ($tone | window 2 | where {|w| ($w.0 < 0) != ($w.1 < 0) } | length)
    let frequency = ($crossings / 2.0 / $seconds)
    assert ($frequency > ($TONE - 2) and $frequency < ($TONE + 2)) $"the zero crossings count out ($TONE) Hz: ($frequency)"
    print $"sound: ($seconds | math round -p 2) seconds of ($frequency | math round -p 1) Hz at ($peak) recorded from the device; QEMU used ($run.cpu_seconds) CPU seconds over ($run.wall_seconds | math round -p 2) seconds"
    print "sound: ok"
}
