# map.rs

The map's binary as `14_MapFormat.md` lays it, read for the sections the
reference needs: the names and materials, the vertices, the sectors' planes
and surfaces, the walls, and the entities. The loops, portals, ambients, and
sector lights go unread. Every number is a little-endian word or single,
widened to a double as the engine widens its singles.

## const MAP_MAGIC

## const SURFACE_SKY

## const CLASS_SPRITE

## const ENTITY_CAMERA

## const ENTITY_FLAT

## struct Surface

## struct Plane

## struct Sector

## struct Wall

## struct Entity

## struct Map

## fn read_map

## fn word

## fn single

## fn surface

## fn plane

## fn parse_map

The directory is held to the format's record sizes, each section inside the
file and each kind once, so a map the loader refuses is refused here too
before any record is read.
