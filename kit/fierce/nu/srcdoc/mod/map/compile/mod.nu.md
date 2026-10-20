# map/compile

The map compiler. `build` turns a map source into the map record, the vertices
shared, the windings fixed, the portals, bounds, and light lists computed;
`write` encodes the record as the file's bytes; `main` writes the tree the
engine reads under <out>/<name>/, with a plan view an SVG a storey (map/plan).
It runs in a nu of its own through `bin/nuance/map.nu compile`, since its
closures run several times slower beside other loaded code.

## main

The source compiled into the tree under <out>/<name>/: the map, the
name file and the title's when the source gives a title, every
material and ambient the map names copied from the content, map.nuon
and tile.nuon, and a plan view an SVG a storey.

## write

The record encoded as the file's bytes.

The names table is the one section of arbitrary length, and it comes
first, so every section after it would sit off a word boundary but for
the padding: each section's bytes are padded with zeros to a multiple
of four and the next offset follows the padded length, while the names
section's count stays the table's own length. The padding is not part
of any section, and `read` never looks at it.

- every section on a word boundary, the names table padded with
  zeros past its count, so the program reads every record in place

## padded

The bytes padded with zeros to a multiple of four.

## joined

A list of byte chunks as one, an empty list as no bytes.

## build

A map source as the map record: the vertices shared to a thousandth,
each loop's winding fixed, the planes from heights and slopes, the
walls with their overrides and anchors, the portals by the edge rule,
the bounds, the entities with their sectors, and each sector's light
list. Stops on what the source gets wrong.

Portals are found by the edge rule over shared vertices rather than by
coordinates: two walls of different sectors on the same two vertices
reversed, with height ranges that overlap at either end, sorted top
down by the ceiling at the wall's middle. Sharing vertices to a
thousandth is what makes the rule exact; a hand-authored loop whose
corner misses another's by more than that gets no portal, which the
plan view shows as a black wall.

An entity other than the spawn takes its sector by the loops alone
when no sector holds it between its planes, since a light sits in a
ceiling and a sprite may sink into a floor; the spawn must be between
the planes, since the body starts there.

- the walls in the author's order, each with its surface
- the winding: the outer loop counter-clockwise, a hole clockwise
- the portals: for every wall, the walls of other sectors running its
  edge the other way whose height ranges overlap at either end,
  sorted from the top down
- the entities, their sectors, and the sectors' light lists
- the sector holding the entity by the loops and the planes; any
  class but the spawn may sit above or below its sector's planes,
  a light in a ceiling or a sprite sunk in a floor, and takes the
  sector by the loops alone

## point

A source point as floats.

## plane-of

A plane from a height at the point and a slope.

## surface-of

A surface from a source's material spec.

## material-index

A name's index in a name list, appended when new.

## vertex-index

A point's vertex index, shared to a thousandth, appended when new.

## signed-area

Twice a polygon's signed area, positive counter-clockwise with y up.

## ranges-overlap

Whether two sectors' height ranges overlap at a point: the higher
floor at or below the lower ceiling.

## lay-out

The tree written: the map, the name file and the title's when the
source gives a title, the materials and ambients the map names and
every sound copied from the content, map.nuon, tile.nuon, and the plan
views; the summary line.

tile.nuon names each material's index, name, and path in the tree, and
its source relative to the content, or nothing where the content has
none. The tree holds no path of the machine that compiled it, so a
checkout anywhere compiles the same bytes, and a disk made from it hashes
the same.

`map/title` is written only when the source gives a title, so a tree
without the file is a map with none, and the loader draws the map's name
on the load screen in its place; `map/name` is always written, since the
loader composes the map's path from it.

- every sound the content holds, since the game's tables name them
  rather than the map, and every sprite image likewise, the
  androids' frames and the gun's among them
