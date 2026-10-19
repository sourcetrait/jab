# sound's integration test: the kernel brings the sound device up in
# the one format and a second of a 440 Hz square wave the program
# writes reaches the host, which records it. The recording is 48 kHz
# stereo 16-bit, holds the tone for the whole second, since the exit
# plays the ring out, at the amplitude the program set, and its zero
# crossings count out 440 Hz.
#
# The debug kernel's exit line counts the services that found the queue
# empty after their drain, every period back from the device. The plain
# run counts none; a second run under jab.soundlate=300 holds the first
# service past the priming 300 ms before its drain, past the eight
# periods' 160 ms of lead, and that service alone counts, the stream going
# on and the whole tone recorded after the longer silent start.
use ../../../nu/mod/capture
use ../../../nu/mod/launch
use std/assert

const RATE = 48000
const AMPLITUDE = 16000
const TONE = 440
# A sample past this is the tone and not silence
const HEARD = 1000
# The priming's eight periods and the tone's fifty, which every run's
# counts pass
const PERIODS = 58

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let plain = (launch --kernel $kernel --image $image --out ($out | path join "plain") --set $set --sound --seconds 15)
    let tone = (tone-holds $plain)
    let counts = (counts-of $plain.debug)
    assert equal $counts.exhausted 0 $"sound: no service of the plain run found its queue empty: ($counts)"
    counts-hold $counts "plain"
    print $"sound: ($tone.seconds | math round -p 2) seconds of ($tone.frequency | math round -p 1) Hz at ($tone.peak) recorded from the device; QEMU used ($plain.cpu_seconds) CPU seconds over ($plain.wall_seconds | math round -p 2) seconds; submitted ($counts.submitted) returned ($counts.returned) exhausted ($counts.exhausted)"

    let late = (launch --kernel $kernel --image $image --out ($out | path join "late") --set $set --sound --seconds 15 --bootargs "jab.soundlate=300")
    assert equal $late.status 0 $"the late run's exit status, with the UART: ($late.serial)"
    assert (not ($late.serial | str contains "jab: sound stalled")) $"sound: the late run's stream went on past its empty queue: ($late.serial)"
    let late_counts = (counts-of $late.debug)
    assert equal $late_counts.exhausted 1 $"sound: the late service alone found its queue empty: ($late_counts)"
    counts-hold $late_counts "late"
    let late_tone = (tone-holds $late)
    print $"sound: under jab.soundlate=300, ($late_tone.seconds | math round -p 2) seconds of ($late_tone.frequency | math round -p 1) Hz at ($late_tone.peak) after a silent start of ($late_tone.start | math round -p 2) seconds against the plain run's ($tone.start | math round -p 2); submitted ($late_counts.submitted) returned ($late_counts.returned) exhausted ($late_counts.exhausted)"
    print "sound: ok"
}

# The exit's counts from the debug channel, its one line
def counts-of [debug: string]: nothing -> record<submitted: int, returned: int, failed: int, exhausted: int> {
    let rows = ($debug | lines | parse --regex '^jab: sound submitted (?P<submitted>\d+) returned (?P<returned>\d+) failed (?P<failed>\d+) exhausted (?P<exhausted>\d+)$')
    assert equal ($rows | length) 1 $"one exit line of the sound's counts: ($debug)"
    $rows | first | into int submitted returned failed exhausted
}

# Every period back by the exit, none failed, past the priming and the tone
def counts-hold [counts: record, run: string] {
    assert equal $counts.submitted $counts.returned $"sound: the ($run) run's periods all returned by the exit: ($counts)"
    assert ($counts.submitted > $PERIODS) $"sound: the ($run) run submitted past the priming and the tone: ($counts)"
    assert equal $counts.failed 0 $"sound: none of the ($run) run's periods failed: ($counts)"
}

# The recording holds the second of tone at its pitch and amplitude
def tone-holds [run: record]: nothing -> record<seconds: float, frequency: float, peak: int, start: float> {
    assert equal $run.status 0 $"exit status, with the UART: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    assert ($run.debug | str contains "jab: sound at ") $"the kernel found the sound device: ($run.debug)"
    assert ($run.sound != "") "the host recorded the sound"
    let wave = (capture wave $run.sound)
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
    { seconds: ($seconds | into float), frequency: $frequency, peak: $peak, start: ($first / $RATE | into float) }
}
