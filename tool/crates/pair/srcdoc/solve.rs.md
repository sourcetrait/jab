# solve.rs

The model (PairBracket): the guest's rdtime reads QEMU_CLOCK_VIRTUAL and
the shim stamps the host's real clock, so over a run with no pause and no
real-clock step host = a + b guest. A pair's upload lies inside its call
[l, u] on the guest's clock and inside [h_lo, h_hi] on the host's, so a is
at least h_lo - b u and at most h_hi - b l, and b is feasible where the
greatest lower bound is at most the least upper one. The margin, ceiling
less floor, is concave and piecewise linear, so its greatest value over the
range lies at an end or at a break of either envelope; those are the
candidates, and every comparison among them is exact.

## const LIMIT

## const PART_LIMIT

## const QUANTUM

The shim writes whole microseconds (`SystemTime`'s `subsec_micros`), so an
upload logged at h lies in [h, h + 1 us), ticks [10 h, 10 h + 10) with
rational points inside. The closed [10 h, 10 h + 10] is the conservative
reading, admitting the one point no instant logged h holds (Astra's review
13, C4); the old end, 10 h + 9, refused Astra's counterexample, kept as the
regression (`bracket_with` takes the span for it).

## const FREE

The wide range a half to two, solved beside the declared one, so the reading
tells drift past the declared bound (feasible here, not there) from a model
that holds at no drift (a pause, a real-clock step, an upload outside its
call).

## struct Pair

## struct Centered

Centered on the first pair, the host on its h_lo and the guest on its l, so
the limits bound differences rather than a clock's epoch.

## struct Bracket

## struct Best

The first candidate where the margin is greatest; on a flat top, its least
drift.

## struct Region

The feasible set reported as its region in (b, a): the drifts where the
margin is not negative, and the offset's least floor and greatest ceiling
over all of them, never two endpoints taken apart as one mapping.

## struct Sweep

## fn center_pairs

## fn drift_range

## fn bracket

## fn bracket_with

## fn sweep_range

## fn inside

## fn merged

## fn margin_at

## fn best_index

## fn feasible_span

The feasible drifts are one interval, the margin being concave; it is walked
out from the best candidate, a zero between two candidates taken from the
lines holding both envelopes just past the first.

## fn zero_after

## fn region_of

The floor is convex and the ceiling concave, so their extremes over the span
lie at its ends or at a break inside it, all among the points.

## fn places_of

An upload's place t = (H - a) / b over H in its host interval and (b, a)
feasible: earliest with H at h_lo and a at the ceiling, latest with H at h_hi
and a at the floor. In c = 1 / b the earliest is h_lo c plus the greatest of
(l_j - h_hi_j c), convex, and the latest concave, so over the points, sorted
by b, each falls then rises or rises then falls, and a binary search finds
its extreme in O(log n). The place is then held to the call, [l, u], and
written from the call's start.

## fn extreme

## fn binding_of

Every pair whose line equals the envelope at the best b, so ties are named
whole; where the bracket is infeasible these are the pairs that bound it.
