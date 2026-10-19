# sound

A sound from a synthesis recipe. `render <recipe.nuon> <out.pcm>` writes `rate`
hertz mono 16-bit little-endian samples from a NUON of layers, each a wave at a
frequency sweeping to another over the sound under an envelope and a gain, the
tree's `sound/<name>.pcm` the engine plays; `samples` is the synthesis for a
caller of its own, its samples -1 to 1. game's `render` renders every recipe of
the content through it.

## The recipe

Sound: a recipe. A layer's wave is sine, square, saw, triangle, or
noise; it begins `start` seconds into the sound, silent before, at
`frequency` hertz and slides straight to `sweep` hertz at the sound's
end, the same for none; the envelope rises over `attack` seconds
from its start, falls over `decay` to the `sustain` level, and fades
over the sound's last `release` seconds; `gain` scales it, the layers
summed and clamped.

```nu
record<
    seconds: float,
    layers: table<
        wave: string,
        start: float,
        frequency: float,
        sweep: float,
        gain: float,
        attack: float,
        decay: float,
        sustain: float,
        release: float,
    >,
>
```

## The rate and the format

48 kHz mono 16-bit little-endian, the kernel's one rate and sample
width, so the engine doubles a sample into the stereo ring with no
resampling; a header would say nothing the recipe does not, and the
tree's `sound/<name>.pcm` is the samples alone.

## render

The recipe rendered to the file; a line with the counts.

## samples

The recipe's samples, -1 to 1: each layer's wave along its sweep
under its envelope times its gain, summed and clamped.

A layer is a pure map over the sample index, no state carried between
samples: the phase is the frequency's integral along the sweep,
f0 t + (f1 - f0) t^2 / 2 s, so a chirp holds its pitch at every instant
and a sample can be computed alone; the envelope is a function of t;
the noise is a hash of the index, so a recipe renders the same bytes
every time and the tree's PCM is reproducible. Layers are summed by a
reduce over zipped lists rather than an inner loop over layers per
sample, since a list operation is where nushell is fast.

## to-pcm

The samples as 16-bit little-endian PCM.

## layer-samples

One layer's samples, silent before its start: the phase is the
frequency's integral along the sweep from the start, so a chirp holds
its pitch at every instant.

## envelope-at

The envelope's level at t: the attack from 0 to 1, the decay from 1
to the sustain, the sustain held, and the release fading to 0 at the
end, over whatever the level was.

## noise-at

White noise, -1 to 1, the same for the same sample every time: the
sample index hashed through two rounds of shift, xor, and multiply,
so neighbouring samples do not correlate; an affine map of the index
would be a ramp, a buzz at one pitch.
