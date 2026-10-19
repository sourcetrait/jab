# tiles

The tile pool's readers and oracles, lean: tiles and its children import nothing
but one another, since code loaded into a nu slows its closures and its module
calls in proportion, so the suite runs them through `bin/nuance/tiles.nu` in a
nu of their own and keeps its heavy modules out of the per-texel loops.

`read` takes the tile dumps a capture holds, each closed by the console's answer
to its D frame and held whole, every record in its place, and every problem that
breaks them; `dumps <api> <out>` saves them (`nu bin/nuance/tiles.nu dumps <api>
<out>`). `keys <api> <out>` saves every dump's tiles by their headers, frame,
generation, state, and next row among them, each with the SHA-256 of its texels
in place of the texels, which are never decoded, and the dumps' problems as
`read` finds them (`nu bin/nuance/tiles.nu keys <api> <out>`).

Its children: tiles/builder, the builder's oracle; tiles/handoff, the handoff's
statistics; tiles/steps, the lit loop's continuity.

## DUMP_TEXELS

render.inc's DUMP_TEXELS and DUMP_RECORDS at 64: a tile's 4,096
texels twelve a record, the last record's eight past them zero

## SCHEMA

render.inc's REPORT_SCHEMA_VERSION and REPORT_SCHEMA, its offset

## close-tile

A tile's records closed: the problems its count and its padding raise,
and the tile with its texels in rows when it is whole, or with `--hash`
the SHA-256 of its texels' bytes, never decoded. The padding is the last
record's texels past the tile's last.

## read

The tile dumps an API capture holds, each closed by the console's answer
to its D frame, and every problem that breaks them. A record's kind and
a console answer's command are the u32 words the program writes,
little-endian. A dump is its tiles, each a header (kind 16) and then
exactly DUMP_RECORDS texel records (kind 17), each record its tile's
slot, its first texel twelve on from the record before's, and the
schema, the texels past the tile's last zero, and every record 64
bytes; after a tile's records, another header or the closing answer
(kind 11, command 68), and nothing else. A header or the answer before
a tile's records are whole leaves the tile short; any other record
between a dump's first header and its answer is foreign, counting toward
no tile, and outside a dump every record but a texel record is the
game's own. Each tile read whole: its slot, key,
surface, level, column, and row, its map's k, W, and H as the program
holds them, the frame the dump was written in, its slot's generation,
its state (2 READY, 1 BUILDING when the D asked for it), and the next
row its construction builds (64 once whole), and its texels in rows,
each a texel's word as the program holds it, blue in its low byte, then
green, red, and alpha, or with `--hash` the SHA-256 of their bytes in
place of the rows, the texels never decoded. Each problem:
its reason (header schema, slot, schema, first texel, missing, repeated,
order, count, padding, foreign, orphan, truncated, or unfinished), the
record's index in the capture, the dump's, and what was found; a tile
with a problem is left out, and the problems stand whether or not any
tile comes back.

## dumps

A capture's dumps and their problems, saved to out as NUON: the tiles
read whole a dump, and every problem (dumps).

## keys

A capture's dumps keyed, saved to out as NUON: every dump's tiles, each
its header and its texels' SHA-256, and every problem (dumps --hash).

## builder-texel

A texel of the builder fixture's texture, [red, green, blue, alpha]:
every channel varied over both axes, opaque.

## capture

A capture's bytes and where its pixels start, past the header's three
lines.
