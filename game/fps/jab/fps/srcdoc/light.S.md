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
carries a lumel map, the model evaluated once at each node of a grid over
the surface in its own texels, which the lit spans read (raster.S). The same
point then reads the same from every eye by construction. The frame's
evaluation before it took the brightness at a span's two ends and stepped
between, so a pool between the ends was never sampled and a floor point read
up to 44 levels apart from three yaws at one spot, light that moved as the
camera turned; a held table keyed by the span's ends and a stride of rows
went with that scheme.

## lights_cull

The sector's list is the compiler's, by bounds and radius in the plan without
z, so the bay's holds nineteen lights, the garage's four below the slab among
them. The bake culls it once a map into the polygon's own list: a light stays
when its sphere meets the surface's world box, the gap on each axis clamped
at zero and squared, and when it lies ahead of the plane's normal, a light
behind the surface adding nothing at any point; a surface lit at no angle
keeps every light in reach. The box comes from the polygon's world points
for a sprite, and for a plane from the sector's bounds with the plane's
height at their corners (plane_box). Per frame only a sprite culls, for its
one evaluation; a plane or a wall piece reads its baked map and nothing
reads a per-polygon list, so the cull and the box ran there for no reader
and were dropped. The dynamic lights to come, the muzzle flash first, loop a
polygon's list through span_light and bring the cull back for the frames
they live.

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

A map's grid is in the surface's own texels, so the span's read is a shift
and the bake and the read agree by construction: a lumel is 2^k texels on
both axes, k the power of two nearest half a metre along u, round(log2(0.5
texw |u_scale|)) clamped to 0 through 15, taken from the double's exponent
with the mantissa against root two's; 64 texels on the content's 128 texels
a metre, 128 on carpet and tread, and one k for both axes, so a surface
with unequal scales has a lumel unequal in metres, which is harmless. The
frame (lumap_frame) is the surface's texel range, a plane's u over x at its
bounds' ends and v over y, a wall's u over its length and v over z from its
higher ceiling end to its lower floor end, each the lesser and the greater:
the origin U0 is a multiple of the texture's size at or below the least
texel less one, V0 the same, so a texel counted from the origin is never
negative and wraps by the mask unchanged; the columns are the greatest
less the origin shifted by k plus two, a node past each end for the
bilinear read. The texel-to-world affine (bake_grid) is the world point at
texel (0, 0) and the world step a texel along each axis: a plane's origin
(-u_offset / u_scale, -v_offset / v_scale) at the plane's height there,
along x by 1 over texw u_scale rising by a, along y by 1 over texh v_scale
rising by b; a wall's origin the first vertex moved -u_offset / u_scale
along the run at z anchor + v_offset / v_scale, along the run by 1 over
texw u_scale, and down by 1 over texh v_scale. A node's point is the origin
plus its texel coordinate along each step (lumap_fill). The normal is the
room's side: (-a, -b, 1) made unit for a floor and its negative for a
ceiling, the run turned a quarter left for a wall, since the sector lies on
its left. Nodes outside a plane's loops but inside its bounds are evaluated
and never read, the cost of a box over a polygon, and so are the margin's.

The grid before this was in metres from the bounds' corner with a
texel-to-lumel map of two scales and two offsets per surface, which the
read applied by a multiply, a shift, an offset, and a clamp on each axis
every sample; in texels the map is the fold of the origin into the span's
coefficients once a polygon (raster.S's lumap_bind), and the read is the
shifts.

A mapping of no scale or a wall of no length has no map and the surface
draws unlit, as does one the arena cannot hold, each counted unmapped on
the bake's line. Measured on the factory: 228 maps, 64,726 lumels, baked in
29 ms against twenty lights, each map's list culled first to the lights its
box reaches, the maps a half megabyte of the 8 MiB arena; the metre grid
baked 42,485 lumels, the texel grid's margins and its lumel a power of two
of texels, 0.625 m on the parking's 0.4 repeats a metre, being the
difference.

## lumel_pack

A lumel holds each channel in 256ths, the brightness word's 16.16 lane
shifted down eight, so four lumels summed under weights adding to 256 give
back a 16.16 lane, exactly the brightness word the lit loops step. The
weighted sum rides the packed lanes whole, since 256 times 256 is 17 bits
and a lane is 21.
