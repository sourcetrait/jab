# clamp.rs

ClampedReference's plan, run over a capture of the clamp pose made at the
release floor: the threshold and its witnesses chosen by the reference's own
computation before the live comparison, recorded in the plan.

## const PLAN_DEPTHS

## const PLAN_SHARES

## const PLAN_AIM

## const PLAN_STEP

## const PLAN_WITNESSES

The parameter as ClampedReference states it: its meaning the depth where
the test images clamp; its bounds 4 to 20 m, inside garage_far's floor; its
rule the depth on a half-metre grid putting the share of the surface's
blocks past it nearest a third, within a fifth to a half.

## struct Planned

A clamped block's three levels. Held: the reference on the drawn mapping,
the secant over the held ends and the held down term. Unbranched: the
candidate's estimate without its clamp branch, |UZB - u IZB| z with u the
drawn coordinate and z the held one, row_derivative's arithmetic in
doubles. Free: the mapping with no hold at all.

## fn rated

## fn margin

## fn Planned::margin

A witness's robustness: the least distance in octaves from a level boundary
over its three footprints, so the strongest witness lies farthest from
flipping.

## fn unbranched_down

## fn chosen_depth

## fn quantile

## fn clamp_plan

The witnesses are the clamped blocks outside every band, held, unbranched,
and free, whose unbranched level differs from the held one, ranked by
margin. The derivative witness at the median clamped block holds the
analytic held down term to the drawn mapping's change across one row: the
held mapping is affine there, so the two agree to rounding. On garage_far's
floor, surface 34, from 5631b65's owner and levels captures, the floor's
mapping counted from its lumel map's origin: 59,403 blocks from 2.47 to
29.9 m, median 4.10; 5.5 m puts 30.5 percent past it, IZ_MIN 12,201,612;
18,123 clamped, 7,450 witnesses, the strongest at row 511 and x0 735, 27.79
m, held level 1 at 2.56 texels a row, unbranched level 0, free level 5,
0.306 octaves from a boundary; the derivative 2.5568997033302754 analytic
against 2.5568997033302594 by the row's difference. Every held block's down
term is the one value, the held mapping's down step being constant over the
plane.
