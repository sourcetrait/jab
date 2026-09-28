# sound.nu

## render

A layer is a pure map over the sample index, no state carried between
samples: the phase is the frequency's integral along the sweep,
f0 t + (f1 - f0) t^2 / 2 s, so a chirp holds its pitch at every instant
and a sample can be computed alone; the envelope is a function of t;
the noise is a hash of the index, so a recipe renders the same bytes
every time and the tree's PCM is reproducible. Layers are summed by a
reduce over zipped lists rather than an inner loop over layers per
sample, since a list operation is where nushell is fast.

## The rate and the format

48 kHz mono 16-bit little-endian, the kernel's one rate and sample
width, so the engine doubles a sample into the stereo ring with no
resampling; a header would say nothing the recipe does not, and the
tree's `sound/<name>.pcm` is the samples alone.
