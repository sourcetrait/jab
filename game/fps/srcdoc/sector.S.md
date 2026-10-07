# sector.S

The world's geometry asked about a point: a plane's height, the even-odd
rule, the sector holding a point.

A plane is z = a x + b y + c, so a height at a point is two multiplies and two
adds, in double. The even-odd rule counts a wall whose ends straddle the
point's y when the wall's x at that y lies past the point's, the same sense
as the host's reader, so the host's sector for a point is the guest's; the
thousandth's slack between the planes is the host's rule too.

## k_hold_slack_d

`f64`: a point's slack about its sector's planes.

## sector_holds_plan

The wall's x at y past the point's: (y - ay)(bx - ax) against (x - ax)(by -
ay), the sense by the sign of by - ay.

## sector_find

sector_find starts from the sector the point was last in and walks its
portals breadth-first before taking the unreached sectors from the top, so a
body crossing a portal finds its new sector in one hop and a camera placed
anywhere still finds its room.

A sector before past the count searches every sector from the top. The walk
starts with nothing seen but the start and the fifo empty; every portal of
every wall of the sector in hand has its sector queued, and the next sector
is the fifo's, else one not yet reached.

## sector_fifo

`MAX_SECTORS u32`: sector_find's walk's queue.

## sector_seen

`MAX_SECTORS u8`: sector_find's sectors reached.
