# player.S

The player's frame beyond the camera and the body: its health and its rounds;
a round fired, the frame hurt, a magazine taken, a noise heard.

The chance is seeded from jab.sys.random's eight bytes, the clock when the
machine has no entropy device; jab.rng.seed replaces a zero word. A noise
floods NOISE_HOPS sectors deep through the walls' portals and rouses every
unroused shootable android in a flooded sector within 30 m of the eye; in the
factory the bay's shot reaches the corridor through the sill and the garage
through the yard's door, the driveway, and the roller door in six hops.

## .set HEALTH_START

`i32`: the player's health at the start.

## .set MAGAZINE_ROUNDS

`i32`: the rounds a magazine adds.

## .set NOISE_HOPS

The sectors deep a noise floods, rousing within its range.

## .set MET_NOTHING

`i32`: a round met nothing, over the API.

## .set MET_GEOMETRY

`i32`: a round met the geometry.

## .set MET_ANDROID

`i32`: a round met an android.

## k_round_range_d

`f64`: a round's range.

## k_pickup_sq_d

`f64`: a pickup's reach in the plan, squared.

## k_pickup_rise_d

`f64`: a pickup's reach in height.

## k_noise_range_sq_d

`f64`: a noise's range, squared.

## player_fire

An android met takes the spark on it, then the hurt; the geometry takes the
spark at the point, in the ray's sector.

## player_pickups

A magazine taken leaves the actor table.

## noise_heard

After the flood, the androids in the flooded sectors within range are roused.

## rng

`u64`: the generator's state word.

## health

`i32`: the player's health.

## rounds

`i32`: the player's rounds.

## pad_prev

`u32`: the pad's keys the frame before.

## noise_fifo

`MAX_SECTORS u32`: the flood's queue, a sector with its depth above it.

## noise_seen

`MAX_SECTORS u8`: the sectors the flood reached.
