# lumel.rs

The bake's lumel maps as light.S's `lumaps_bake` and `lumap_frame` lay them,
computed again from the map and the textures' sizes, for one fact the
reference needs: where each lit surface's coordinates count from. A lit,
mapped polygon is bound to its map once (`lumap_bind`), which folds the
map's origin into its u/z and v/z on A, B, and C, so the coordinate the
engine draws is the texture's less U0, and v's less V0. An unclamped
derivative never sees that constant; the mapping held at the depth floor
does, since its derivative is u/z's step over the floor and u/z carries the
intercept times 1/z (ClampedReference). The reference folds the same origin
into the surface's mapping (scene.rs's `folded`).

The bake's counts are the engine's load line's, `fps: lumel maps K baked in
T ms: N lumels, M unmapped`, so a reading holds this replication to the
engine's own bake: Render Zero 228 maps and 64,726 lumels, its copies the
same, Render One 79 and 13,194, none unmapped.

## const LUMEL_METRE

## const SQRT2_MANTISSA

## const LUMEL_K_MAX

## const LUMEL_ARENA_BYTES

## const LUMEL_BYTES

## enum Lumel

## struct Lumels

## fn Lumels::of

A surface the bake passes over, a sky or one whose material has no texture,
is absent and reads unmapped, as `poly_mode` leaves it unlit.

## struct Frame

## fn wrap_mask

material_bind's mask, the largest power of two within the side less one;
every texture is a power of two a side, so it is the side less one.

## fn lumel_shift

lumap_frame's rounding by the exponent: k is the exponent of half a metre's
texels along u, one more when the mantissa reaches the square root of two's,
so k is the power of two nearest in the logarithm, held to 0 to 15.

## fn frame

The origin is the least texel's floor less one, cleared to a multiple of the
side by the mask, so a node sits before the surface's first texel and the
counting stays non-negative under wrapping; the columns are the greatest
texel's ceiling less the origin shifted by k, plus two, a node past the far
end for the bilinear read. Rounding is floor and ceiling as `fcvt.l.d`
takes them with rdn and rup.

## fn ordered

## fn height

plane_height's order of operations, x a times one product fused with y b,
then c, since the frame's v range rests on the wall's end heights.

## enum Baked

## fn bound

## fn plane_frame

A plane's texel range over its sector's bounds as the compiler wrote them:
u at the bounds' x ends, v at their y ends, each scale times the end fused
with the offset, then times the texture's size, as the bake's `fmadd.d` and
`fmul.d` take it, so the floor of the least texel lands where the engine's
does.

## fn wall_frame

A wall's u from its start, u_offset, to its end, u_scale times its length
fused with u_offset; its v from the higher of its sector's ceiling at its
two ends to the lower of its floor at them, each from the anchor. The
length is the SDK's register length, x squared fused with y squared, then
the square root. A wall of no length, or a surface with a scale of 0, is
counted unmapped.

## fn lumels

The bake's order, every sector's floor then its ceiling, then every wall,
matters only for the arena: a map past the 8 MiB arena's room is left
unmapped and the bake goes on, so a later, smaller map can still fit. A map
with no light entity bakes nothing, `light_count` being zero. A texture the
crate cannot read leaves its surface unresolved and every map after it
uncertain, since its map's size, unknown, may have taken the arena's room.
