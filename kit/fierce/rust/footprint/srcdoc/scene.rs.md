# scene.rs

The reference's geometry as `05_Renderer.md` and the sources state it: the
camera camera_basis derives, the pixel's ray, and each surface's world
mapping, in doubles, independent of the engine's arithmetic.

## const HX

## const HY

## const HZ

raster.S's k_hx, k_hy, and k_hz: the ray through pixel (x, y) is right
(x - hx) + down (y - hy) + forward hz, so a pixel's centre is x + 0.5.

## const LUMAP_PLANES

## const SURFACE_SPRITES

## const SURFACE_ACTORS

The OWNER index space (render.inc): a plane at twice its sector plus one
for the ceiling, a wall at LUMAP_PLANES on, a map sprite at SURFACE_SPRITES
plus its entity, an actor past them; MAX_SECTORS 1024, MAX_WALLS 8192, and
MAX_ENTITIES 1024 from map.inc.

## const OWNER_NONE

## const MIP_LEVELS

## const SPRITE_PULL

## const SPRITE_TINY

sprite.S's k_pull_d and k_tiny_d.

## fn dot

## fn scaled

## fn summed

## struct Camera

## fn Camera::from_angles

camera_basis's: forward (cos p cos y, cos p sin y, sin p), the level right
(sin y, -cos y, 0), its up, then the roll turning right and up about
forward, a positive roll tilting up toward the right. The engine takes its
sines and cosines in singles from the SDK's approximations; the reference's
are exact, a difference of parts in ten million.

## fn Camera::ray

## struct Mapping

The texel coordinates' world gradients at level 0 and their values at the
world origin, u = u.p + u0, the texture's size folded in as surface_axis
folds it, and for a lit plane or wall its lumel map's origin taken off, as
the engine draws it (`folded`). The intercepts move no unclamped derivative;
the drawn mapping's derivative past the floor carries them
(ClampedReference).

## enum Owned

## const FRAME_SETS

## const FRAME_SINGLES

frames_load's table: the sets stand to struck, eight rotations each at
`android/<set>_<r>`, index set times 8 plus r, then fallen, the three
sparks, and the magazine at 64 to 68.

## fn frame_stem

## fn chain_levels

mip.S's rule: a level while both sides are two texels or more before the
halving, ten at most, so the fence's 256 by 1024 holds 9 and the sky's 1024
by 512 10. A chain the arena cannot finish stops short in the engine; the
mips line's totals say whether one did.

## fn png_size_of

## fn png_size

## struct Textures

## fn Textures::of

The engine loads its images into the material records after the map's,
frame_base being the map's material count, so a material index past the
map's names an image by its distance past them.

## fn Textures::unread

## fn textures

Each material's PNG in the tree, `<name>.png`, and each image's,
`sprite/<stem>.png`, as the loader composes them.

## fn textured

## fn owned

An actor's surface maps by the entity its frame's export carries for it, the
scratch entity sprite_draw drew; without one it is unresolved. A plane or a
wall takes its lumel map's origin from the bake's replication (lumel.rs); a
sprite and an actor name no map, POLY_LUMAP 0, and keep their own.

## fn plane_mapping

plane_draw's: the normal (-a, -b, 1) through (0, 0, c), u = u_offset +
u_scale x and v = v_offset + v_scale y in repeats, so the intercepts are
the offsets in texels.

## fn wall_mapping

wall_surface's: the normal (ay - by, bx - ax, 0) through vertex a, u along
the unit run from a, v down from the anchor; the intercepts u_offset -
u_scale a.e and v_offset + v_scale anchor, in texels.

## fn folded

lumap_bind's fold: a lit polygon with a map has u/z less U0 times 1/z, and
v/z less V0 times it, on all three coefficients, so its drawn coordinate is
the texture's less the origin, a constant the unclamped derivative cancels
and the held one keeps. The engine shifts the 6.26 1/z coefficient's product
down ten for the 48.16 u/z, a truncation of under a unit there, which the
reference leaves out. Without the fold, the clamp pose's floor read the held
down term at 6.21 texels a row, level 2, where both captures drew level 1
on every clamped block: the garage floor's v, 1,075 to 2,406 texels over its
bounds, counted from the world origin rather than from its map's V0 of
1,024, its U0 being 0. A map the bake could not lay is unmapped, the surface
drawn unlit and unfolded; one past an unread texture is unresolved, its fold
unknown.

## fn sprite_mapping

## fn quad_mapping

sprite_draw's: facing the camera, the camera's right kept level and scaled
to half the width, the centre half the height up; fixed, (-sin yaw, cos
yaw, 0); flat, the centre the feet and the quad along its yaw face up; then
the quad scaled about the eye by k_pull, its gradients r over twice its
length squared and d likewise, its intercepts a half at the pulled centre,
1/2 - c.a_u (PLANE_U0). The pull moves no screen derivative, since scaling
about the eye keeps every ray's texel.
