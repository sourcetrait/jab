# reference.rs

FootprintEstimate's independent reference: the exact footprint at each
block's start pixel's centre from the map and the pose, on the mapping the
engine draws there, its level by the engine's rule, and every capture's
blocks united, classed, and the judged held to it (ClampedReference,
SpanEndpoint, JudgedPopulation).

## const BAND

2^(1/16): the criteria's threshold-sensitive band about each level
boundary, where either neighbouring level passes for every estimator.

## const BLOCK

## fn depth_floor

An image's IZ_MIN is 1/z in 6.26, so its floor is IZ_MIN over 2^26 of a
metre's inverse: 4096 is 16,384 m, the landed clamp images' 12,201,612 is
5.5 m. The reference takes the integer from the image's provenance, never
a symbol's name or a nominal depth.

## struct Derivatives

`clamped` says the drawn mapping held z at the floor at that pixel.

## fn Derivatives::footprint

## enum Footprint

## fn reach

## fn inverse_depth

## fn over_z

## fn over_z_step

1/z at a pixel is n.dir / (hz n.(q - p)) and u/z is (u.p + u0) 1/z + u.dir
/ hz, both affine over the screen; their steps along an axis are n.axis /
(hz n.(q - p)) and (u.p + u0) times that plus u.axis / hz. The intercept u0,
u's value at the world origin, enters through 1/z's step.

## fn footprint

With n the plane's normal, q its point, p the eye, and dir the pixel's ray,
u = u.p + u0 + (n.(q - p) / n.dir) u.dir, so du/dx = n.(q - p) (u.right
n.dir - u.dir n.right) / (n.dir)^2 and du/dy the same with down; v alike.
The depth is hz n.(q - p) / n.dir. Where 1/z falls under the floor the
engine holds z at 1/floor (raster.S's block ends and the span's start), so
the drawn coordinate is u/z over the floor, and its derivatives are u/z's
steps over the floor, which carry the intercept; hence the mapping keeps
each surface's u0 and v0, a lit surface's counted from its lumel map's
origin as the engine draws it (scene.rs's `folded`). The release floor is
past every view of the pose set; the landed clamp images' 5.5 m brings
garage_far's floor under it. There the drawn mapping's down term exceeds
the free mapping's: at the threshold the two differ by u times 1/z's step
over 1/z, u being the drawn coordinate, 2.56 texels a row held on
garage_far's floor against 1.94 to 2.01 free just short of the threshold,
every held block at level 1.

## fn held_texel

The drawn texel: u/z and v/z over the greater of 1/z and the floor, as
raster.S takes z from a block end's 1/z held at IZ_MIN.

## fn block_secant

The engine steps a block by its secant along the span, the exact
coordinates at its two ends over its pixels, and both estimators share
it; the derivative at the start parts from the secant where the footprint
changes fast along the span. Render One's spawn view showed three blocks
of a wall's narrow sliver at 4.18 to 4.38 texels a pixel by the derivative
and 3.82 to 4.00 by the secant, both estimators reading the secant's
level, one sharper than the derivative's. So beside the declared reference
each block is held to the secant along the span and the exact derivative
down it, which isolates the row term the candidate changes. Where either
end's 1/z falls under the floor both ends take the drawn texel; otherwise
the hit point's coordinates, the unclamped form unchanged, so a reading on
the release floor rounds as the earlier ones did.

## fn level_of

raster.S's halvings: m for a footprint in [2^m, 2^(m + 1)), 0 under two
texels, capped at the chain's last.

## fn band_of

## enum Verdict

## fn judge

## enum Class

JudgedPopulation's classes. Judged: a reference established and the block
present in every capture. Sky, excluded: its pixels drawn by the sky path,
which has no texel mapping. The unresolved, each named: unknown (no OWNER
surface for the span, or an index naming nothing), unread (a texture whose
PNG could not be read), actor (an actor surface whose frame's export
carries no attributes), degenerate (no positive depth at the start pixel),
no_end (a span the table lacks), unpaired (a block one capture shows and
another does not). The stamp's cells are skipped before blocks form, so a
block there is never among them. The checks run in that order, surface,
mapping, footprint, end, pairing, so a block carries one reason.

## fn Class::name

## fn Class::unresolved

## struct Population

The union of every capture's blocks by class, beside the judged blocks in
a band, held at the floor, and on actors.

## fn Population::count

## fn Population::unresolved

## struct Tally

One capture's verdicts on the judged blocks alone, against the declared
reference and the secant's. A block a capture lacks is unpaired and counted
in no capture's verdicts, so every capture's counts cover the same blocks.

## struct Row

Every union block, its class and what classifying it found: the start
pixel's depth and hold, the block's length, the references for a block
judged or unpaired.

## struct Capture

## struct Scene

## struct United

## fn span_surfaces

A span is one command and so one surface, so the OWNER capture's index at
any pixel a LEVELS capture's span shows is the span's surface; a pixel drawn
in one capture and not the other, or a span on two surfaces, means the
captures are not of one frame and is refused. Every capture's spans are
read, the candidate's being the same packet's as today's.

## fn check_table

SpanEndpoint's binding of a table to its capture: every LEVELS pixel's span
index, all 16 bits, inside its span's x0 to x1 on its row, else the capture
and the table are not of one frame, and the reading is refused.

## fn block_length

SpanEndpoint: the lesser of BLOCK and its span's x1 less the block's start,
whatever its pixels show, since a later surface, a mask, or the stamp can
hide a span's tail and no pixel recovers a hidden end; a span the table
lacks leaves its blocks no end. A capture made before the export, with no
table, keeps the legacy rule: a block followed by another of its span full,
the span's last its pixels seen.

## fn compare

The captures' tables must be equal, FOOTPRINT changing no span. Each union
block is classed once, from the first capture holding it, and judged only
where every capture holds it.

## fn classify
