# reference.rs

FootprintEstimate's independent reference: the exact footprint at each
block's start pixel's centre from the map and the pose, its level by the
engine's rule, and each LEVELS capture's levels held to it.

## const IZ_MIN

## const BAND

2^(1/16): the criteria's threshold-sensitive band about each level
boundary, where either neighbouring level passes for every estimator.

## const BLOCK

## struct Derivatives

## fn Derivatives::footprint

## enum Footprint

## fn footprint

With n the plane's normal, q its point, p the eye, and dir the pixel's ray,
u = u.p + u0 + (n.(q - p) / n.dir) u.dir, so du/dx = n.(q - p) (u.right
n.dir - u.dir n.right) / (n.dir)^2 and du/dy the same with down; v alike.
The depth is hz n.(q - p) / n.dir. Where 1/z falls under IZ_MIN, past
16,384 m, the engine draws z constant and the derivative is that clamped
mapping's, which needs the lumel map's origin the reference does not
compute; such blocks are counted clamped and left unjudged, and no view of
the pose set reaches one.

## fn block_secant

The engine steps a block by its secant along the span, the exact
coordinates at its two ends over its pixels, and both estimators share
it; the derivative at the start parts from the secant where the footprint
changes fast along the span. Render One's spawn view showed three blocks
of a wall's narrow sliver at 4.18 to 4.38 texels a pixel by the derivative
and 3.82 to 4.00 by the secant, both estimators reading the secant's
level, one sharper than the derivative's. So beside the declared reference
each block is held to the secant along the span and the exact derivative
down it, which isolates the row term the candidate changes.

## fn level_of

raster.S's halvings: m for a footprint in [2^m, 2^(m + 1)), 0 under two
texels, capped at the chain's last.

## fn band_of

## enum Verdict

## fn judge

## struct Tally

The declared verdicts, agree, sharper, and coarser against the four exact
derivatives, beside the secant reference's.

## struct Row

## fn block_length

A block followed by another of its span is a full one; the span's last is
its pixels seen, one past its last seen less its start, short of the
engine's where the span's tail is hidden.

## fn span_surfaces

A span is one command and so one surface, so the OWNER capture's index at
any pixel the first LEVELS capture's span shows is the span's surface; a
pixel drawn in one capture and not the other, or a span on two surfaces,
means the captures are not of one frame and is refused. The first capture
is today's estimator's, whose levels the OWNER build shares, so their
masked pixels pass alike.

## fn compare

Each capture's blocks are judged on their own; a block judged once is one
row, every capture's level beside it. The candidate's spans are the same
packet's as today's, preparation not depending on the estimator, so the
first capture's surfaces serve every capture.
