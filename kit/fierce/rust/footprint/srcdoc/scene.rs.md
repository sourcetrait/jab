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

The texel coordinates' world gradients at level 0, the texture's size
folded in as surface_axis folds it. The offsets, the lumel map's origin
among them, move no derivative and are left out.

## enum Owned

## fn chain_levels

mip.S's rule: a level while both sides are two texels or more before the
halving, ten at most, so the fence's 256 by 1024 holds 9 and the sky's 1024
by 512 10. A chain the arena cannot finish stops short in the engine; the
mips line's totals say whether one did.

## fn png_size_of

## fn png_size

## fn texture_sizes

Each material's PNG in the tree, `<name>.png`, as the loader composes it.

## fn textured

## fn owned

## fn plane_mapping

plane_draw's: the normal (-a, -b, 1) through (0, 0, c), u = u_offset +
u_scale x and v = v_offset + v_scale y in repeats.

## fn wall_mapping

wall_surface's: the normal (ay - by, bx - ax, 0) through vertex a, u along
the unit run from a, v down from the anchor.

## fn sprite_mapping

sprite_draw's: facing the camera, the camera's right kept level and scaled
to half the width, the centre half the height up; fixed, (-sin yaw, cos
yaw, 0); flat, the centre the feet and the quad along its yaw face up; then
the quad scaled about the eye by k_pull, its gradients r over twice its
length squared and d likewise. The pull moves no screen derivative, since
scaling about the eye keeps every ray's texel.
