# sector.S

A plane is z = a x + b y + c, so a height at a point is two multiplies and two
adds, in double. The even-odd rule counts a wall whose ends straddle the
point's y when the wall's x at that y lies past the point's, the same sense
as the host's reader, so the host's sector for a point is the guest's; the
thousandth's slack between the planes is the host's rule too.

sector_find starts from the sector the point was last in and walks its
portals breadth-first before taking the unreached sectors from the top, so a
body crossing a portal finds its new sector in one hop and a camera placed
anywhere still finds its room.
