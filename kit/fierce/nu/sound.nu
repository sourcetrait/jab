# sound.nu: a sound from a synthesis recipe. `nu sound.nu render
# <recipe.nuon> <out.pcm>` writes RATE hertz mono 16-bit little-endian
# samples from a NUON of layers, each a wave at a frequency sweeping to
# another over the sound under an envelope and a gain, the tree's
# `sound/<name>.pcm` the engine plays; `render` is the synthesis for a
# caller of its own, its samples -1 to 1.

const rate = 48000
const two_pi = 6.283185307179586

# Sound: a recipe. A layer's wave is sine, square, saw, triangle, or
# noise; it begins `start` seconds into the sound, silent before, at
# `frequency` hertz and slides straight to `sweep` hertz at the sound's
# end, the same for none; the envelope rises over `attack` seconds
# from its start, falls over `decay` to the `sustain` level, and fades
# over the sound's last `release` seconds; `gain` scales it, the layers
# summed and clamped.
# record<
#     seconds: float,
#     layers: table<
#         wave: string,
#         start: float,
#         frequency: float,
#         sweep: float,
#         gain: float,
#         attack: float,
#         decay: float,
#         sustain: float,
#         release: float,
#     >,
# >

def main [] {
    print "sound.nu render <recipe.nuon> <out.pcm>"
}

# The recipe rendered to the file; a line with the counts.
def "main render" [recipe: path, out: path] {
    let r = (open $recipe)
    let samples = (render $r)
    to-pcm $samples | save --raw -f $out
    let peak = ($samples | each {|s| $s | math abs } | math max)
    print $"sound: ($recipe) -> ($out): ($samples | length) samples, ($r.seconds) s, ($r.layers | length) layers, peak ($peak)"
}

# The recipe's samples, -1 to 1: each layer's wave along its sweep
# under its envelope times its gain, summed and clamped.
export def render [r: record]: nothing -> list<float> {
    let seconds = ($r.seconds | into float)
    let n = (($seconds * $rate) | math round | into int)
    let silence = (0..<$n | each {|i| 0.0 })
    let mixed = ($r.layers | reduce --fold $silence {|l, acc|
        let layer = (layer-samples $l $n $seconds)
        $acc | zip $layer | each {|p| $p.0 + $p.1 }
    })
    $mixed | each {|s| if $s > 1.0 { 1.0 } else if $s < -1.0 { -1.0 } else { $s } }
}

# The samples as 16-bit little-endian PCM.
export def to-pcm [samples: list<float>]: nothing -> binary {
    $samples | each {|s| (($s * 32767.0) | math round | into int) | into binary --endian little | bytes at 0..<2 } | bytes collect
}

# One layer's samples, silent before its start: the phase is the
# frequency's integral along the sweep from the start, so a chirp holds
# its pitch at every instant.
def layer-samples [l: record, n: int, seconds: float]: nothing -> list<float> {
    let start = ($l.start | into float)
    let span = ($seconds - $start)
    if $span <= 0.0 { error make { msg: $"a layer starting at ($start) s lies past the sound's ($seconds) s" } }
    let f0 = ($l.frequency | into float)
    let f1 = ($l.sweep | into float)
    let slope = (($f1 - $f0) / $span)
    let gain = ($l.gain | into float)
    0..<$n | each {|i|
        let t = ((($i | into float) / $rate) - $start)
        if $t < 0.0 { 0.0 } else {
            let phase = ($f0 * $t + $slope * $t * $t / 2.0)
            let cycle = ($phase - ($phase | math floor))
            let wave = (match $l.wave {
                "sine" => (($two_pi * $phase) | math sin),
                "square" => (if $cycle < 0.5 { 1.0 } else { -1.0 }),
                "saw" => (2.0 * $cycle - 1.0),
                "triangle" => (4.0 * (($cycle - 0.5) | math abs) - 1.0),
                "noise" => (noise-at $i),
                _ => (error make { msg: $"a layer's wave is sine, square, saw, triangle, or noise, not ($l.wave)" }),
            })
            $wave * (envelope-at $l $t $span) * $gain
        }
    }
}

# The envelope's level at t: the attack from 0 to 1, the decay from 1
# to the sustain, the sustain held, and the release fading to 0 at the
# end, over whatever the level was.
def envelope-at [l: record, t: float, seconds: float]: nothing -> float {
    let a = ($l.attack | into float)
    let d = ($l.decay | into float)
    let s = ($l.sustain | into float)
    let rel = ($l.release | into float)
    let held = (if $a > 0.0 and $t < $a {
        $t / $a
    } else if $d > 0.0 and $t < ($a + $d) {
        1.0 - (1.0 - $s) * (($t - $a) / $d)
    } else {
        $s
    })
    if $rel > 0.0 and $t > ($seconds - $rel) { $held * (($seconds - $t) / $rel) } else { $held }
}

# White noise, -1 to 1, the same for the same sample every time: the
# sample index hashed through two rounds of shift, xor, and multiply,
# so neighbouring samples do not correlate; an affine map of the index
# would be a ramp, a buzz at one pitch.
def noise-at [i: int]: nothing -> float {
    mut x = ($i bit-and 0xFFFFFFFF)
    $x = (((($x bit-shr 16) bit-xor $x) * 0x45d9f3b) bit-and 0xFFFFFFFF)
    $x = (((($x bit-shr 16) bit-xor $x) * 0x45d9f3b) bit-and 0xFFFFFFFF)
    $x = (($x bit-shr 16) bit-xor $x)
    (($x | into float) / 2147483648.0) - 1.0
}
