# light.S

A surface point is lit, in each of red, green, and blue, by the ambient 0.15
plus, for each light of its sector's list within the light's radius, the
light's channel times the cosine at the surface's unit normal facing the
camera, one for a surface lit at no angle, times the falloff 1 - distance /
radius, one at the light and nothing at the radius; a spotlight scales that by
(cos angle - cos spread) / (1 - cos spread) from one on its axis to nothing at
its spread; each channel clamped to one, so a lit texel is never brighter than
its texture. The falloff is straight because a model with a core and an
inverse square passed the contrast test and left every room dark, a colour
capping at one while a room is metres across; an author predicts the straight
rule. A light reaches a sector by the compiler's list, bounds and radius in
the plan without z.

The brightness is taken at both ends of a span, on the first row of a polygon
and every LIGHT_ROWS 8 rows after, held in the polygon between, and stepped a
pixel in 16.16 with the three channels packed 21 bits apart in one word.
Per-vertex interpolation would lose a bulb's pool on a room's floor, whose
vertices are all far from it; per row the cost was a microsecond a row of
every polygon, which the stride cuts: two evaluations a row over 57 pieces of
500 rows was 30 ms, the eight-row stride 7.

## span_light

Single precision throughout. The brightness ends as a 16.16 fraction per
channel, which a single's 24 bits cover with margin; positions within the
factory's 64 metres resolve to microns; the one double input, 1/z as a 6.26
integer, converts into a single exactly enough. Every light field is a single,
so nothing converts, where the double form converted about nine fields a light
in reach and fifteen camera fields an evaluation, each a helper under TCG.

The light's vector is computed into ft0 to ft2 and used there: the register
forms `jab.f32.vec3.reg.sqrlen` and `reg.dot` touch only their destination,
so the vector survives them for the radius test, the normal's cosine, and the
spotlight's axis with no store and no reload. The memory form on the same
vector cost three stores and nine loads a light and recomputed the square
inside the length; measured in one batch on the factory's spawn view, 19
lights on the bay's list, the memory form read 25.9, 24.4, and 25.6 ms
against the inline double's 24.7, 24.1, and 30.4, about a millisecond. The
single register form in its own batch read 25.3, 23.1, and 23.7 against the
inline double's 24.7, 23.4, and 23.6, with the planes phase 10.2, 10.2, and
9.8 against 10.7, 9.8, and 10.3: the memory form's millisecond recovered,
and the conversions' saving under the frame's run-to-run noise, since the
lit pixel loop in span_fill, not this evaluation, carries most of the
light's cost; a per-frame counter of span_light's ticks on the frame line
would resolve it, which the LitFrame task owns. The function is
page-aligned and the test holds it within a page with no trap.
