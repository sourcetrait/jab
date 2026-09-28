# techno's integration test: the program plays technojab.mid off its
# romfs with nothing pressed, and the host records it: the piece's
# opening kicks, one a beat at 128 beats a minute, are heard in the
# second after the stream's lead; the title stands in the middle of
# the screen in off-white; the UART stays silent and QEMU has nothing
# to say. The piece is minutes long, so the run is ended by the
# capture; test/smf holds the player's end-of-piece exit.
use ../../../sdk/nu/jab.nu
use std/assert

const RATE = 48000
# A sample past this is the piece and not silence
const HEARD = 500
# The title's off-white and its box, as src/main.S sets them
const TITLE_COLOR = "ebe6dc"
const TITLE_WIDTH = 433
const TITLE_HEIGHT = 96
const TITLE_X = 743
const TITLE_Y = 492

def main [--kernel: path, --image: path, --out: path, --set: string = "", --assets: path = ""] {
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --sound --disk $assets --serial "techno" --capture 3200ms)
    print $"techno: status ($run.status) after ($run.wall_seconds | math round -p 2) seconds, ($run.debug | lines | length) kernel debug lines"
    assert equal $run.serial "" $"the UART stays silent: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    assert equal $run.stderr "" $"QEMU said nothing on its stderr: ($run.stderr)"
    assert ($run.debug | str contains "jab: sound at ") $"the kernel found the sound device: ($run.debug)"
    assert (not ($run.debug | str contains "stalled")) $"the stream never stalled: ($run.debug)"
    assert ($run.sound != "") "the host recorded the sound"
    assert ($run.screen != "") "a screen was taken"

    # the piece: the second from a fifth of a second in, past the
    # stream's lead, carries its opening kicks
    let wave = (jab wave $run.sound)
    assert equal [$wave.rate $wave.channels $wave.bits] [$RATE 2 16] $"the recording is in the one format: ($wave | reject samples)"
    let left = (0..<$wave.frames | each {|i| $wave.samples | bytes at ($i * 4)..<($i * 4 + 2) | into int --endian little --signed })
    let piece = ($left | slice ($RATE // 5)..<($RATE * 6 // 5) | enumerate | where {|s| ($s.item | math abs) > $HEARD } | get index)
    assert (($piece | length) > 2000) $"the piece plays on its own: ($piece | length) samples heard in its first second"

    # the title
    let screen = (jab screen $run.screen)
    let title = (jab ink $screen $TITLE_COLOR)
    assert ($title.count > 500) $"the title is on the screen: ($title.count) off-white pixels"
    assert ($title.left >= $TITLE_X and $title.right < $TITLE_X + $TITLE_WIDTH) $"inside its box across: ($title)"
    assert ($title.top >= $TITLE_Y and $title.bottom < $TITLE_Y + $TITLE_HEIGHT) $"inside its box down: ($title)"
    print $"techno: the piece heard for ($piece | length) samples of its first second; the title ($title.count) pixels; QEMU used ($run.cpu_seconds) CPU seconds over ($run.wall_seconds | math round -p 2) seconds"
    print "techno: ok"
}
