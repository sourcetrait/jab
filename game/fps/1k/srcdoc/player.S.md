# player.S

The player's frame beyond the camera and the body: its health and its rounds;
a round fired, the frame hurt, a magazine taken, a noise heard.

The chance is seeded from jab.sys.random's eight bytes, the clock when the
machine has no entropy device; jab.rng.seed replaces a zero word. A noise
floods NOISE_HOPS sectors deep through the walls' portals and rouses every
unroused shootable android in a flooded sector within 30 m of the eye; in the
factory the bay's shot reaches the corridor through the sill and the garage
through the yard's door, the driveway, and the roller door in six hops.

## player_fire

An android met takes the spark on it, then the hurt; the geometry takes the
spark at the point, in the ray's sector.

## player_pickups

A magazine taken leaves the actor table.

## noise_heard

After the flood, the androids in the flooded sectors within range are roused.
