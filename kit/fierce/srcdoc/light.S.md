# light.S

The map's lights, without shadows: the brightness at a world point of a
surface, the ambient plus each light of a list by cosine and falloff; a lumel
map baked over every textured surface at load in the surface's own texels,
which the lit spans read, and a sprite's one brightness taken at its centre a
frame.

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

## k_lumel_d

`f64`: half a metre, a lumel's aim along u.

## k_sqrt2_mantissa

`u64`: root two's mantissa, past which k rounds up.

## k_light_ambient

`f32`: the ambient in each channel.

## k_light_none

`f32`: a point light's spread cosine, under -1.

## k_light_minus_one

`f32`.

## k_depth_scale

`f32`: 2^26, one in 6.26.

## msg_lumels

`17 u8`.

## word_baked_in

`11 u8`.

## word_lumels

`10 u8`.

## word_unmapped

`10 u8`.

## lights_gather

The axis comes from the yaw and pitch, with the cosine of the spread; a
spread of none makes a point light. Each sector's list is the file's light
entities as light indices.

## lights_cull

The sector's list is the compiler's, by bounds and radius in the plan without
z, so the bay's holds nineteen lights, the garage's four below the slab among
them. The bake culls it once a map into the polygon's own list: a light stays
when its sphere meets the surface's world box, the gap on each axis clamped
at zero and squared, and when it lies ahead of the plane's normal, n . (light
- q) > 0, a light behind the surface adding nothing at any point; a surface
lit at no angle keeps every light in reach. The box comes from the polygon's
world points for a sprite, and for a plane from the sector's bounds with the
plane's height at their corners (plane_box). Per frame only a sprite culls,
for its one evaluation; a plane or a wall piece reads its baked map and
nothing reads a per-polygon list, so the cull and the box ran there for no
reader and were dropped. The dynamic lights to come, the muzzle flash first,
loop a polygon's list through span_light and bring the cull back for the
frames they live.

## span_light

span_light is the frame's form for a dynamic light, the muzzle flash to come:
the world point down a pixel's ray from its 1/z, the camera plus (right sx +
up sy + forward hz) z/hz, then point_light under the polygon's normal facing
the camera over the polygon's list. It falls into point_light rather than
calling it, both being leaves, so the pixel-to-point part stays page-aligned
on its own for the hot-function check while the model is shared with the bake
and the sprites. No frame calls it yet.

## point_light

Single precision throughout. The brightness ends as a 16.16 fraction per
channel, which a single's 24 bits cover with margin; positions within
Render Zero's 64 metres resolve to microns. Every light field is a single, so
nothing converts. The light's vector is computed into ft0 to ft2 and used
there: the register forms `jab.f32.vec3.reg.sqrlen` and `reg.dot` touch only
their destination, so the vector survives them for the radius test, the
normal's cosine, and the spotlight's axis with no store and no reload; the
memory form on the same vector cost three stores and nine loads a light and
measured about a millisecond a frame when this ran per span.

The falloff is one at the light, straight to nothing at the radius; the
spotlight takes the cosine from the light's axis to the point, from the
spread's edge scaled to one on the axis; each channel is clamped to one, in
16.16, and packed.

## lumel_pack

A lumel holds each channel in 256ths, the brightness word's 16.16 lane
shifted down eight, so four lumels summed under weights adding to 256 give
back a 16.16 lane, exactly the brightness word the lit loops step. The
weighted sum rides the packed lanes whole, since 256 times 256 is 17 bits
and a lane is 21.

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
the bake's line. Measured on Render Zero: 228 maps, 64,726 lumels, baked in
29 ms against twenty lights, each map's list culled first to the lights its
box reaches, the maps a half megabyte of the 8 MiB arena; the metre grid
baked 42,485 lumels, the texel grid's margins and its lumel a power of two
of texels, 0.625 m on the parking's 0.4 repeats a metre, being the
difference.

Every map starts as none. For a plane the mapping is held as doubles, fs0
u_scale, fs1 v_scale, fs2 u_offset, fs3 v_offset, fs4 the texture's width,
fs5 its height, fs6 a, fs7 b, fs8 c; the lights are culled to the plane by
its box, a point on it at the bounds' corner, and the normal; the frame's
origin is the world point where u and v are 0, its steps u along x with the
plane's rise a and v along y with b; the surface's texels are u at the
bounds' x ends and v at the y ends, the lesser and the greater of each. For
a wall the extent is from the higher ceiling end down to the lower floor
end; the run is made unit with its length; the lights are culled to the wall
by its box, its first vertex at the top, and the normal; the mapping is held
as doubles, fs9 u_scale, fs10 v_scale, fs11 u_offset, fs2 v_offset, fs3 the
anchor height; the frame's origin lies along the wall from its first vertex
at the height v reaches 0, its steps a texel along the wall and down it; the
wall's texels are u from its first vertex to its length and v from the top to
the bottom against the anchor. The line carries the maps baked, the time,
the lumels, and the textured surfaces left without a map.

## lumap_frame

k comes from the double's exponent, rounded up where the mantissa is at or
past root two's; the origin is the least texel less one, floored to the
texture's size.

## lumap_fill

A node's texel coordinate is the origin plus the column and the row of
lumels, its point taken along the frame's axes.

## light_count

`u32`: the lights in the table.

## lights

`MAX_LIGHTS*12 f32`: the light table, LIGHT_* fields.

## sector_lights

`MAX_SECTORS*SECTOR_LIGHTS_SIZE u8`: each sector's list, a count byte then that many light indices.

## entity_light

`MAX_ENTITIES i32`: each entity's light index, -1 for an entity that is no light.

## lumel_cursor

`addr`: the arena's next free lumel.

## lumap_count

`u64`: the maps baked.

## lumel_count

`u64`: the lumels in them.

## lumap_missing

`u64`: the textured surfaces left without a map.

## bake_grid

`GRID_SIZE u8`: the frame the map in hand is baked over, GRID_* fields.

## lumaps

`LUMAP_COUNT*6 u64`: every surface's map, LUMAP_* fields.

## lumel_arena

`LUMEL_ARENA_BYTES u8`: every map's lumels.
