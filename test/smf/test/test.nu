# smf's integration test: the test writes a Standard MIDI File, format
# 1 with a tempo track and a note track, five notes of the square lead
# at known ticks with a tempo change between the last two, using
# running status and a velocity-0 note off, puts it on a romfs disk,
# and the kernel plays it while the host records. The recording holds
# five tones, at the pitches written, starting the intervals apart the
# tempos make of the ticks, each lasting its ticks and the lead's
# release, at the level full velocity gives. The piece ends at its
# last event, so the program lingers a moment before it exits and the
# last release reaches the recording.
use ../../../sdk/nu/jab.nu
use std/assert

const RATE = 48000
# The file: ticks a quarter note, and the two tempos in microseconds a
# quarter note, 120 then 240 beats a minute
const DIVISION = 480
const TEMPO = 500000
const TEMPO_FAST = 250000
# The notes: the A at 440, the E above, the E below, the A, the A above
const NOTES = [69 76 64 69 81]
const PITCHES = [440.0 659.26 329.63 440.0 880.0]
# How long a note holds: half a quarter at the first tempo, and a
# fifth of one once it doubles, so the release still ends before the
# next note starts and the tones stay apart in the recording
const HOLD_TICKS = 240
const HOLD_FAST_TICKS = 96
const PROGRAM = 80
const VELOCITY = 127
# Full velocity on the square lead at the volume the file sets, 127,
# after the mixer's scaling: 32767 * 123 / 128 / 4, the gain being
# 127 * 127 * 127 >> 14 = 125 times the left pan's 126 >> 7
const PEAK = 7871
# A sample past this is a note and not silence
const HEARD = 500

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let img = ($out | path join "piece.romfs")
    write-piece ($out | path join "piece") $img
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --sound --disk $img --serial "piece" --seconds 20)
    assert equal $run.status 0 $"exit status, with the UART: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    assert ($run.sound != "") "the host recorded the sound"
    let wave = (jab wave $run.sound)
    assert equal [$wave.rate $wave.channels $wave.bits] [$RATE 2 16] $"the recording is in the one format: ($wave | reject samples)"
    let left = (0..<$wave.frames | each {|i| $wave.samples | bytes at ($i * 4)..<($i * 4 + 2) | into int --endian little --signed })

    # the tones: stretches above HEARD, split where the silence between
    # notes lasts more than 40 ms
    let heard = ($left | enumerate | where {|s| ($s.item | math abs) > $HEARD } | get index)
    assert (($heard | length) > 0) "the piece is in the recording"
    let gap = ($RATE * 40 // 1000)
    let starts = ([$heard.0] ++ ($heard | window 2 | where {|w| ($w.1 - $w.0) > $gap } | each {|w| $w.1 }))
    let ends = (($heard | window 2 | where {|w| ($w.1 - $w.0) > $gap } | each {|w| $w.0 }) ++ [($heard | last)])
    let tones = ($starts | zip $ends | each {|t| { start: $t.0, end: $t.1 } })
    assert equal ($tones | length) 5 $"five notes: ($tones | each {|t| $"($t.start / $RATE | math round -p 2)..($t.end / $RATE | math round -p 2)" })"

    # each at its pitch and level, lasting its ticks and the release
    let quarter = ($TEMPO / 1000000.0)
    let quarter_fast = ($TEMPO_FAST / 1000000.0)
    let hold = ($quarter * $HOLD_TICKS / $DIVISION)
    let hold_fast = ($quarter_fast * $HOLD_FAST_TICKS / $DIVISION)
    let holds = [$hold $hold $hold $hold_fast $hold_fast]
    for i in 0..<5 {
        let t = ($tones | get $i)
        let tone = ($left | slice $t.start..$t.end)
        let seconds = (($t.end - $t.start) / $RATE)
        let hold = ($holds | get $i)
        assert ($seconds > $hold and $seconds < ($hold + 0.1)) $"note ($i) lasts its ticks and the release: ($seconds) against ($hold)"
        let peak = ($tone | each {|s| $s | math abs } | math max)
        assert ($peak >= ($PEAK - 300) and $peak <= ($PEAK + 300)) $"note ($i) at full velocity's level: ($peak)"
        let crossings = ($tone | window 2 | where {|w| ($w.0 < 0) != ($w.1 < 0) } | length)
        let frequency = ($crossings / 2.0 / $seconds)
        let pitch = ($PITCHES | get $i)
        assert (($frequency - $pitch | math abs) < ($pitch * 0.02)) $"note ($i) at ($pitch) Hz: ($frequency)"
    }

    # the starts the tempos make of the ticks: a quarter note apart
    # throughout, half a second at the first tempo and a quarter once it
    # doubles; within a period and a half either way, since an event
    # lands at a period's mix
    let intervals = ($tones | window 2 | each {|w| ($w.1.start - $w.0.start) / $RATE })
    let expected = [$quarter $quarter $quarter ($quarter_fast)]
    let slack = 0.03
    for i in 0..<4 {
        let got = ($intervals | get $i)
        let want = ($expected | get $i)
        assert (($got - $want | math abs) < $slack) $"interval ($i) is ($want) s: ($got)"
    }
    print $"smf: five notes at ($tones | each {|t| $t.start / $RATE | math round -p 3}) s, intervals ($intervals | each {|s| $s | math round -p 3}); QEMU used ($run.cpu_seconds) CPU seconds over ($run.wall_seconds | math round -p 2) seconds"
    print "smf: ok"
}

# The piece, written to piece.mid under `stage` and made into the romfs
# image at `img`: a tempo track and a note track on channel 0.
def write-piece [stage: path, img: path]: nothing -> nothing {
    if ($stage | path exists) { rm -rf $stage }
    mkdir $stage
    let half = ($DIVISION // 2)
    # the tempo track: the tempo, a tempo change at the fourth note's
    # tick, the end
    let tempo_track = ((delta 0) ++ (meta 0x51 (be24 $TEMPO))
        ++ (delta (3 * $DIVISION)) ++ (meta 0x51 (be24 $TEMPO_FAST))
        ++ (delta 0) ++ (meta 0x2f 0x[]))
    # the note track: the program, the volume, then each note on and,
    # its hold later, off by velocity 0 under running status; a quarter
    # note between starts throughout, which the doubled tempo makes a
    # quarter of a second for the last
    let head = ((delta 0) ++ 0x[c0] ++ (byte $PROGRAM)
        ++ (delta 0) ++ 0x[b0 07 7f])
    let holds = [$HOLD_TICKS $HOLD_TICKS $HOLD_TICKS $HOLD_FAST_TICKS $HOLD_FAST_TICKS]
    let gaps = [0 ($DIVISION - $HOLD_TICKS) ($DIVISION - $HOLD_TICKS) ($DIVISION - $HOLD_TICKS) ($DIVISION - $HOLD_FAST_TICKS)]
    mut notes = 0x[]
    for i in 0..<5 {
        let note = ($NOTES | get $i)
        let on = (if $i == 0 { 0x[90] ++ (byte $note) ++ (byte $VELOCITY) } else { (byte $note) ++ (byte $VELOCITY) })
        $notes = ($notes ++ (delta ($gaps | get $i)) ++ $on ++ (delta ($holds | get $i)) ++ (byte $note) ++ 0x[00])
    }
    let note_track = ($head ++ $notes ++ (delta 0) ++ (meta 0x2f 0x[]))
    let file = (0x[4d 54 68 64] ++ (be32 6) ++ (be16 1) ++ (be16 2) ++ (be16 $DIVISION)
        ++ (chunk "MTrk" $tempo_track) ++ (chunk "MTrk" $note_track))
    $file | save --raw -f ($stage | path join "piece.mid")
    ^genromfs -d $stage -f $img -V piece
}

def byte [value: int]: nothing -> binary { $value | into binary --endian little | bytes at 0..<1 }
def be16 [value: int]: nothing -> binary { $value | into binary --endian big | bytes at 6..<8 }
def be24 [value: int]: nothing -> binary { $value | into binary --endian big | bytes at 5..<8 }
def be32 [value: int]: nothing -> binary { $value | into binary --endian big | bytes at 4..<8 }
def chunk [tag: string, body: binary]: nothing -> binary { ($tag | into binary) ++ (be32 ($body | bytes length)) ++ $body }
def meta [kind: int, body: binary]: nothing -> binary { 0x[ff] ++ (byte $kind) ++ (delta ($body | bytes length)) ++ $body }

# A variable-length quantity: seven bits a byte, the high bit set on
# every byte but the last.
def delta [value: int]: nothing -> binary {
    mut bytes = [($value mod 128)]
    mut rest = ($value // 128)
    while $rest > 0 {
        $bytes = ([(($rest mod 128) + 128)] ++ $bytes)
        $rest = ($rest // 128)
    }
    $bytes | each {|b| byte $b } | bytes collect
}
