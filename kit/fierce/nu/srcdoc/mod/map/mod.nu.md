# map

The Jab FPS map on the host. `read` parses <name>.jabfps.map into a record,
every section a table with its names resolved, and holds the file to the
format's rules, stopping where it breaks one; `float-at` and `float-bytes` read
and write the singles the file and the program's records carry; `show` prints a
compiled map's counts and its spawn. src/map.inc spells the same layout.

Its children: map/compile, the compiler, which turns a map source into the
record and writes the tree the engine reads; map/plan, the plan views; and
map/trees, every source of the game's content compiled into the asset shard. `nu
bin/nuance/map.nu compile <source> <out> [--content <dir>]` and `nu
bin/nuance/map.nu show <map>` run the compiler and `show` from the command line,
the compiler in a nu of its own.

## magic

JAB and a zero, little-endian

## show

The map's counts and its spawn, as one NUON record.

## tile-path

The romfs path a material's name maps to: a leading slash and .png.

## read

The whole map, held to the format: the directory within the file,
every section once at its record size, every index in range, every
portal exact, every entity in its sector by the loops and the planes.

The directory is held before any section is read, so a fault names the
kind that broke the rule rather than failing later on a garbage record.
The alignment rule exists for the program, not the host: the loader
reads every record in place with word loads, and a section that starts
off a word boundary would trap the guest, so an offset that is not a
multiple of four is refused here as it is there.

Floats are decoded from their bits into the host's double, which holds
a single exactly, so a test's even-odd and plane arithmetic in double
is the arithmetic the loader does when it widens a single.

## records

The record count of a section applied to a closure of each record's
offset.

## surface-at

A surface at an offset.

## check

The format's rules over a record, as the loader holds them.

The same rules the loader holds the file to, in the same order, so a
map that passes here loads and one that fails names the same record.
The even-odd test counts a crossing where the wall's x at the point's y
lies past the point's x, and the loader mirrors that sense, so a point
on a boundary reads the same on both sides of the wire.

## holds-plan

Whether the sector holds the point in the plan, by the even-odd rule
over its loops.

## plane-z

A plane's height at a point.

## sector-holding

The sector holding a point: in the plan by the loops, and, unless
`--plan` alone, with z between the floor and the ceiling there; -1
for none.

## summary

The map's counts and its spawn.

## float-at

A single read at an offset of any bytes, for a reader of the
program's own records, which carry the same singles.

## float-bytes

A single's four bytes, little-endian, of a host float: the double's
bits taken apart and put back with the narrower exponent and
mantissa, rounded to nearest, anything under the single's range
flushed to zero; a value past its range is an error.

A host float to a single's bytes by taking the double's bits apart,
because a float `==` in nushell is approximate and an encoder that went
by `math log` and `**` was wrong twice over; the bits are exact.

## f32

An IEEE 754 single from its bits: the sign, the exponent, and the
mantissa, exact in the host's double.
