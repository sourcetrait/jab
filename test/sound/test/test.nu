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
#
# The delayed service refills all eight periods from the ring at once, so
# a period the program had not yet written by then is mixed silent: the
# late run's tone may hold whole periods of exact zeros, a race between the
# program's first writes and QEMU's first return that the kernel's design
# allows. Each such period, on the stream's period boundaries and all
# zeros, is set aside and counted, and the tone's length and pitch are read
# over the rest. The plain run's tone holds no silence at all.
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
# The stream's period in frames, the kernel's JAB_SOUND_PERIOD
const PERIOD = 960

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
    let late_tone = (tone-holds $late --gaps)
    print $"sound: under jab.soundlate=300, ($late_tone.seconds | math round -p 2) seconds of ($late_tone.frequency | math round -p 1) Hz at ($late_tone.peak) after a silent start of ($late_tone.start | math round -p 2) seconds against the plain run's ($tone.start | math round -p 2); submitted ($late_counts.submitted) returned ($late_counts.returned) exhausted ($late_counts.exhausted), ($late_tone.gaps) whole silent periods inside the tone set aside"
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

# The recording holds the second of tone at its pitch and amplitude. With
# `--gaps`, whole periods of exact zeros inside it, each on the stream's
# period boundaries, are set aside and counted before its length and pitch
# are read; without it, nothing inside the tone is silent.
def tone-holds [run: record, --gaps]: nothing -> record<seconds: float, frequency: float, peak: int, start: float, gaps: int> {
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
    # the frames inside the tone heard as silence, by the period they lie in
    let quiet = ($left | slice $first..$last | enumerate | where {|s| ($s.item | math abs) <= $HEARD } | each {|s| $s.index + $first })
    let silent = ($quiet | each {|i| $i // $PERIOD } | uniq)
    if not $gaps {
        assert ($quiet | is-empty) $"nothing inside the tone is silent: frames in periods ($silent)"
    }
    let zeros = (0..<($PERIOD * 4) | each { 0x[00] } | bytes collect)
    for p in $silent {
        let lo = ($p * $PERIOD)
        let hi = ($lo + $PERIOD)
        assert ($lo > $first and $hi <= $last) $"a silent period whole inside the tone: frames ($lo) to ($hi - 1) in ($first) to ($last)"
        assert (($wave.samples | bytes at ($lo * 4)..<($hi * 4)) == $zeros) $"the silent period at frames ($lo) to ($hi - 1) all exact zeros"
    }
    let tone = ($left | slice $first..$last | enumerate | where {|s| (($s.index + $first) // $PERIOD) not-in $silent } | get item)
    let seconds = ((($last - $first) - ($silent | length) * $PERIOD) / $RATE)
    assert ($seconds > 0.95 and $seconds < 1.05) $"the tone lasts the second the program wrote: ($seconds)"
    let peak = ($tone | each {|s| $s | math abs } | math max)
    assert ($peak >= ($AMPLITUDE - 500) and $peak <= $AMPLITUDE) $"at the amplitude the program set: ($peak)"
    let crossings = ($tone | window 2 | where {|w| ($w.0 < 0) != ($w.1 < 0) } | length)
    let frequency = ($crossings / 2.0 / $seconds)
    assert ($frequency > ($TONE - 2) and $frequency < ($TONE + 2)) $"the zero crossings count out ($TONE) Hz: ($frequency)"
    { seconds: ($seconds | into float), frequency: $frequency, peak: $peak, start: ($first / $RATE | into float), gaps: ($silent | length) }
}
