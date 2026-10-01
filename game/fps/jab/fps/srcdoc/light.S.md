# light.S

A surface point is lit, in each of red, green, and blue, by the ambient 0.15
plus, for each light of a list within the light's radius, the light's channel
times the cosine at the surface's unit normal into the room, one for a
surface lit at no angle, times the falloff 1 - distance / radius, one at the
light and nothing at the radius; a spotlight scales that by (cos angle - cos
spread) / (1 - cos spread) from one on its axis to nothing at its spread;
each channel clamped to one, so a lit texel is never brighter than its
texture. The falloff is straight because a model with a core and an inverse
square passed the contrast test and left every room dark, a colour capping at
one while a room is metres across; an author predicts the straight rule. A
light reaches a sector by the compiler's list, bounds and radius in the plan
without z.

The light is a property of the world, baked at load: every textured surface
carries a lumel map, the model evaluated once at each node of a half-metre
grid over the surface, which the lit spans read (raster.S). The same point
then reads the same from every eye by construction. The frame's evaluation
before it took the brightness at a span's two ends and stepped between, so a
pool between the ends was never sampled and a floor point read up to 44
levels apart from three yaws at one spot, light that moved as the camera
turned; a held table keyed by the span's ends, a stride of rows, and a
per-polygon cull all went with that scheme.

## lights_cull

The sector's list is the compiler's, by bounds and radius in the plan without
z, so the bay's holds nineteen lights, the garage's four below the slab among
them. Per surface the list is culled once into the polygon's own: a light
stays when its sphere meets the surface's world box, the gap on each axis
clamped at zero and squared, and when it lies ahead of the plane's normal, a
light behind the surface adding nothing at any point; a surface lit at no
angle keeps every light in reach. The bake culls once a map and the frame
once a polygon, where the dynamic lights to come will loop the polygon's
list. The box comes from the polygon's world points for a wall piece or a
sprite, and for a plane from the sector's bounds with the plane's height at
their corners (plane_box), since a plane's loops are appended one at a time.

## point_light and span_light

Single precision throughout. The brightness ends as a 16.16 fraction per
channel, which a single's 24 bits cover with margin; positions within the
factory's 64 metres resolve to microns. Every light field is a single, so
nothing converts. The light's vector is computed into ft0 to ft2 and used
there: the register forms `jab.f32.vec3.reg.sqrlen` and `reg.dot` touch only
their destination, so the vector survives them for the radius test, the
normal's cosine, and the spotlight's axis with no store and no reload; the
memory form on the same vector cost three stores and nine loads a light and
measured about a millisecond a frame when this ran per span.

span_light is the frame's form for a dynamic light, the muzzle flash to come:
the world point down a pixel's ray from its 1/z, then point_light under the
polygon's normal facing the camera over the polygon's list. It falls into
point_light rather than calling it, both being leaves, so the pixel-to-point
part stays page-aligned on its own for the hot-function check while the model
is shared with the bake and the sprites. No frame calls it yet.

## lumaps_bake

A map's grid is the surface's own: a plane's from the bounds' corner along x
and y at the plane's height, a lumel along x rising by a times the spacing
and along y by b, so a sloped plane's nodes lie on it; a wall's from its first
vertex at the higher of its ceiling ends, a lumel along the wall and a lumel
down to below the lower of its floor ends, so every piece and opening of the
wall lies within the map. A node past each end in both axes, so a sample at
the edge still has the lumel beyond it to blend with. The normal is the room's
side: (-a, -b, 1) made unit for a floor and its negative for a ceiling, the
run turned a quarter left for a wall, since the sector lies on its left. Nodes
outside a plane's loops but inside its bounds are evaluated and never read,
the cost of a box over a polygon.

The texel-to-lumel map is per surface, two scales and two offsets, because a
span steps its texel u and v and nothing else: lu = u RU >> 32 - OU with RU
2^32 over texw u_scale L, so the multiply and shift divide u by the texels in
a lumel, and OU the texel origin's lumel coordinate, (u_offset / u_scale +
ox) / L for a plane whose u runs from world x = 0, u_offset / (u_scale L) for
a wall whose u runs from its vertex; v the same, a wall's against its anchor
and its top. A mapping of no scale has no map and the surface draws unlit,
as does one the arena cannot hold, each counted unmapped on the bake's line.

Measured on the factory: 228 maps, 42,485 lumels, baked in 23 ms against
twenty lights, each map's list culled first to the lights its box reaches;
the maps take 340 KB of the 8 MiB arena. The estimate of a tenth of a second
assumed the whole sector list per lumel.

## lumel_pack

A lumel holds each channel in 256ths, the brightness word's 16.16 lane
shifted down eight, so four lumels summed under weights adding to 256 give
back a 16.16 lane, exactly the brightness word the lit loops step. The
weighted sum rides the packed lanes whole, since 256 times 256 is 17 bits
and a lane is 21.
