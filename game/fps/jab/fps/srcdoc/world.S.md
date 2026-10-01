# world.S

The walk is breadth-first through the compiler's portals from the camera's
sector, or from every sector when the camera is in none; a sector reached is
drawn once and whole, and the depth buffer resolves every overlap, so there
are no screen boxes and no redraws.

A wall is drawn as pieces between the sectors across it, which the file's
portals give sorted from the top down: for k over the portals plus one, the
piece's top is the sector's ceiling for k 0 and portal k-1's sector's floor
after, its bottom portal k's sector's ceiling or the sector's floor at the
end, each height taken at both ends of the wall. Above each piece but the
first lies the opening into portal k-1's sector: when that sector is not yet
reached, or the wall is masked, the opening's polygon is the neighbour's
ceiling and floor clamped to the sector's, cut as a piece; a camera within the
near distance of the wall reaches the neighbour outright, since the opening
would clip away; else the opening is sampled and the neighbour queued where
any sample shows, and a masked wall's surface is filled over the opening in
masked mode. A piece is cut where its planes cross along the wall: the quad
when the top is above the bottom at both ends, the triangle at the end where
it is.

A wall's u runs along it from its first vertex and its v down from the
author's anchor height, the same for every piece of the wall and over its
openings. The wall's unit direction is a vec2 norm by hand over
jab.f64.vec2.len through vec3_scratch, the library carrying no vec2 norm.

The depth clear is 8 MB, about two milliseconds; its loop and the uncovered
count's are aligned to 32 bytes inside their functions. On a DEBUG build the
frame is painted magenta first, so a capture shows what no surface reached.
