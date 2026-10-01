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

The brightness is taken in double at both ends of a span, on the first row of
a polygon and every LIGHT_ROWS 8 rows after, held in the polygon between, and
stepped a pixel in 16.16 with the three channels packed 21 bits apart in one
word. Per-vertex interpolation would lose a bulb's pool on a room's floor,
whose vertices are all far from it; per row the cost was a microsecond a row
of every polygon, which the stride cuts: two evaluations a row over 57 pieces
of 500 rows was 30 ms, the eight-row stride 7.

## span_light

The hot site of the type libraries: the loop runs about 2232 times a frame on
the factory's spawn view, over the bay's list of 19 lights. The light's
vector d is register-resident, so each light stores it to vec3_scratch for
jab.f64.vec3.sqrlen, the radius test, and jab.f64.vec3.len, and reloads it
for the normal's dot and the spotlight's axis; the loop's own state sits in
a3 to a7 and ft8 to ft11, outside the libraries' scratch set. Measured on
the spawn view paired against the inline form in the same batch: 25.9, 24.4,
and 25.6 ms against 24.7, 24.1, and 30.4, within the run-to-run spread, about
a millisecond on the lit view; the yard view, few lights, unchanged. The
function is page-aligned and the test holds it within a page with no trap.
