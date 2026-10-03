# trace.S

The 3D trace: a ray from a point in a sector along a unit direction for a
distance, walked sector to sector, then against the capsules.

## trace_ray

In the sector in hand, up to 64 sectors deep: the nearest wall of its loops
the ray crosses in the plan, t = cross(a - o, e) / cross(d, e) along the ray
and u = cross(a - o, d) / cross(d, e) along the wall, u within 0 to 1 with a
nanometre's slack, t past the distance walked so far by a millionth so the
wall entered through is not crossed back; the floor and the ceiling met
before it, the ray's height over a plane being linear along the ray, f0 + f1
t, the crossing counting only falling through the floor or rising through
the ceiling; at the wall's crossing the ray's height is held against each
portal's sector's floor and ceiling there, top down, the first that holds it
entered. An opening passes the ray whatever its wall's solid or masked flags,
those being the body's.

The nearest wall crossing is taken past what is walked; then the planes met
before the crossing, the ray's height against the plane's along it, down
through the floor or up through the ceiling; at the wall's crossing its
point, then the first portal whose sector holds the ray's height there, which
is entered. What ends the walk is a piece, a plane, or nothing within the
distance; then the capsules within what is met.

## trace_capsule

The capsules are vertical cylinders of the body's radius from the feet to the
body's height, the caps ignored: the quadratic in t with the offset from the
axis, the nearer root, past 0 since an origin inside misses, short of what is
met, the ray's height there within the feet and the head. The square root
there is the discriminant's, not a length, so it stays an instruction.
