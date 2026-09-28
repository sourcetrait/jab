# soundfont's integration test: the test writes a SoundFont 2 file of
# one sample, eight cycles of a sine at 24 kHz, 60 points a cycle, so
# 400 Hz, looped whole and rooted at the A above middle C, in one
# instrument and one preset, puts it on a romfs disk, and the kernel
# plays that A for a second at full velocity and volume while the host
# records; then the kernel loads FluidR3 GM off the mix disk and plays
# a piano's middle C. The recording holds the sine at 400 Hz, at the
# level a full-scale sample gives after the mixer's scaling, for the
# second and the release, and then the piano, heard; the UART says
# what each font held, the one-sample font's three ones and FluidR3's
# counts as the pinned file has them.
use ../../../sdk/nu/jab.nu
use std/assert

const RATE = 48000
# The sample: 60 points a cycle at 24 kHz is 400 Hz, eight cycles
const SAMPLE_RATE = 24000
const CYCLE = 60
const CYCLES = 8
const AMPLITUDE = 32000
const ROOT = 69
const PITCH = 400.0
# Full velocity at full volume through the mixer's shift right by two
const PEAK = 8000
# A sample past this is the tone and not silence; the piano, quieter and
# decaying, is heard past a lower one
const HEARD = 500
const PIANO_HEARD = 100
# Silence longer than this after the tone parts the piano from it
const GAP_MS = 100
# FluidR3 GM, as the generic disk's manifest pins it
const FLUID = { presets: 189, instruments: 193, samples: 1418 }

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let img = ($out | path join "tone.romfs")
    write-font ($out | path join "tone") $img
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --sound --disk $img --serial "tone" --seconds 90)
    assert equal $run.status 0 $"exit status, with the UART: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    assert ($run.sound != "") "the host recorded the sound"
    let counts = ($run.serial | lines | each {|l|
        $l | parse --regex '^soundfont: (?P<font>\w+) presets=(?P<presets>\d+) instruments=(?P<instruments>\d+) samples=(?P<samples>\d+)$' | get -o 0
    } | compact)
    let tone = ($counts | where font == "tone" | first)
    assert equal [$tone.presets $tone.instruments $tone.samples] ["1" "1" "1"] $"the tone font holds one of each, with the UART: ($run.serial)"
    let fluid = ($counts | where font == "fluid" | first)
    assert equal [($fluid.presets | into int) ($fluid.instruments | into int) ($fluid.samples | into int)] [$FLUID.presets $FLUID.instruments $FLUID.samples] $"FluidR3 holds what the pinned file holds, with the UART: ($run.serial)"

    let wave = (jab wave $run.sound)
    assert equal [$wave.rate $wave.channels $wave.bits] [$RATE 2 16] $"the recording is in the one format: ($wave | reject samples)"
    let left = (0..<$wave.frames | each {|i| $wave.samples | bytes at ($i * 4)..<($i * 4 + 2) | into int --endian little --signed })
    # the tone: the first stretch above HEARD, up to a silence of GAP_MS,
    # the second it was held and its release, at the pitch and the level
    # the file and the calls name
    let heard = ($left | enumerate | where {|s| ($s.item | math abs) > $HEARD } | get index)
    assert (($heard | length) > 0) "the tone is in the recording"
    let gap = ($RATE * $GAP_MS // 1000)
    let tone_end = ($heard | window 2 | where {|w| ($w.1 - $w.0) > $gap } | get -o 0.0 | default ($heard | last))
    let t = { start: $heard.0, end: $tone_end }
    let seconds = (($t.end - $t.start) / $RATE)
    assert ($seconds > 0.95 and $seconds < 1.4) $"the tone lasts the second it was held and its release: ($seconds)"
    let samples = ($left | slice $t.start..$t.end)
    let peak = ($samples | each {|s| $s | math abs } | math max)
    assert ($peak >= ($PEAK - 300) and $peak <= ($PEAK + 300)) $"the tone at a full-scale sample's level: ($peak)"
    let crossings = ($samples | window 2 | where {|w| ($w.0 < 0) != ($w.1 < 0) } | length)
    let frequency = ($crossings / 2.0 / $seconds)
    assert (($frequency - $PITCH | math abs) < ($PITCH * 0.02)) $"the tone at ($PITCH) Hz: ($frequency)"
    # the piano: after the tone's silence, heard above PIANO_HEARD for its
    # hold and its decay
    let after = ($t.end + $gap)
    let piano_heard = ($left | enumerate | slice $after..<$wave.frames | where {|s| ($s.item | math abs) > $PIANO_HEARD } | get index)
    assert (($piano_heard | length) > 0) "the piano is in the recording"
    let p = { start: ($piano_heard | first), end: ($piano_heard | last) }
    let piano_seconds = (($p.end - $p.start) / $RATE)
    assert ($piano_seconds > 0.5 and $piano_seconds < 3.0) $"the piano is heard for its hold and its decay: ($piano_seconds)"
    let piano_peak = ($left | slice $p.start..$p.end | each {|s| $s | math abs } | math max)
    assert ($piano_peak > 500) $"the piano is heard: ($piano_peak)"
    print $"soundfont: the tone ($seconds | math round -p 2) s of ($frequency | math round -p 1) Hz at ($peak); the piano ($piano_seconds | math round -p 2) s at ($piano_peak), starting ($p.start / $RATE | math round -p 2) s in; QEMU used ($run.cpu_seconds) CPU seconds over ($run.wall_seconds | math round -p 2) seconds"
    print "soundfont: ok"
}

# The font, written to tone.sf2 under `stage` and made into the romfs
# image at `img`: the RIFF sfbk form of the specification, an INFO
# list, an sdta list with the sine, and a pdta list with the hydra, one
# preset in bank 0 at program 0, one instrument, one zone playing the
# sample looped with a fast attack and a short release, one sample
# header.
def write-font [stage: path, img: path]: nothing -> nothing {
    if ($stage | path exists) { rm -rf $stage }
    mkdir $stage
    let points = (0..<($CYCLE * $CYCLES) | each {|k| ((($k * 2.0 * 3.141592653589793) / $CYCLE) | math sin) * $AMPLITUDE | math round | into int })
    let samples = (($points | each {|v| le16 $v }) ++ (0..<46 | each {|| le16 0 }) | bytes collect)
    let end = ($points | length)
    let info = ((chunk "ifil" ((le16 2) ++ (le16 1)))
        ++ (chunk "isng" (("EMU8000" | into binary) ++ 0x[00]))
        ++ (chunk "INAM" (("tone" | into binary) ++ 0x[00 00])))
    let sdta = (chunk "smpl" $samples)
    # the instrument zone's generators: the loop continuous, an attack
    # of a millisecond, a release of a fifth of a second, the root the A,
    # then the sample last
    let igen = ((gen 54 1) ++ (gen 34 -12000) ++ (gen 38 -2786) ++ (gen 58 $ROOT) ++ (gen 53 0))
    let igen_count = 5
    let pdta = ((chunk "phdr" ((name "tone") ++ (le16 0) ++ (le16 0) ++ (le16 0) ++ (le32 0) ++ (le32 0) ++ (le32 0)
            ++ (name "EOP") ++ (le16 0) ++ (le16 0) ++ (le16 1) ++ (le32 0) ++ (le32 0) ++ (le32 0)))
        ++ (chunk "pbag" ((le16 0) ++ (le16 0) ++ (le16 1) ++ (le16 0)))
        ++ (chunk "pmod" (0..<10 | each {|| 0x[00] } | bytes collect))
        ++ (chunk "pgen" ((gen 41 0) ++ (gen 0 0)))
        ++ (chunk "inst" ((name "tone") ++ (le16 0) ++ (name "EOI") ++ (le16 1)))
        ++ (chunk "ibag" ((le16 0) ++ (le16 0) ++ (le16 $igen_count) ++ (le16 0)))
        ++ (chunk "imod" (0..<10 | each {|| 0x[00] } | bytes collect))
        ++ (chunk "igen" ($igen ++ (gen 0 0)))
        ++ (chunk "shdr" ((name "sine") ++ (le32 0) ++ (le32 $end) ++ (le32 0) ++ (le32 $end) ++ (le32 $SAMPLE_RATE) ++ (byte $ROOT) ++ (byte 0) ++ (le16 0) ++ (le16 1)
            ++ (name "EOS") ++ (0..<26 | each {|| 0x[00] } | bytes collect))))
    let body = (("sfbk" | into binary) ++ (list "INFO" $info) ++ (list "sdta" $sdta) ++ (list "pdta" $pdta))
    let file = (("RIFF" | into binary) ++ (le32 ($body | bytes length)) ++ $body)
    $file | save --raw -f ($stage | path join "tone.sf2")
    ^genromfs -d $stage -f $img -V tone
}

def byte [value: int]: nothing -> binary { $value | into binary --endian little | bytes at 0..<1 }
def le16 [value: int]: nothing -> binary { $value | into binary --endian little | bytes at 0..<2 }
def le32 [value: int]: nothing -> binary { $value | into binary --endian little | bytes at 0..<4 }
def gen [op: int, amount: int]: nothing -> binary { (le16 $op) ++ (le16 $amount) }
# A name field: the string in its twenty bytes, zero filled
def name [s: string]: nothing -> binary {
    let bytes = ($s | into binary)
    $bytes ++ (0..<(20 - ($bytes | bytes length)) | each {|| 0x[00] } | bytes collect)
}
# A chunk: its tag, its size, its data padded to even
def chunk [tag: string, body: binary]: nothing -> binary {
    let pad = (if (($body | bytes length) mod 2) == 1 { 0x[00] } else { 0x[] })
    ($tag | into binary) ++ (le32 ($body | bytes length)) ++ $body ++ $pad
}
# A list: a LIST chunk whose data opens with its form
def list [form: string, body: binary]: nothing -> binary { chunk "LIST" (($form | into binary) ++ $body) }
