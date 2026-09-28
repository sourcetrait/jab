# map.nu

## read

The directory is held before any section is read, so a fault names the
kind that broke the rule rather than failing later on a garbage record.
The alignment rule exists for the program, not the host: the loader
reads every record in place with word loads, and a section that starts
off a word boundary would trap the guest, so an offset that is not a
multiple of four is refused here as it is there.

Floats are decoded from their bits into the host's double, which holds
a single exactly, so a test's even-odd and plane arithmetic in double
is the arithmetic the loader does when it widens a single.

## check

The same rules the loader holds the file to, in the same order, so a
map that passes here loads and one that fails names the same record.
The even-odd test counts a crossing where the wall's x at the point's y
lies past the point's x, and the loader mirrors that sense, so a point
on a boundary reads the same on both sides of the wire.

## write

The names table is the one section of arbitrary length, and it comes
first, so every section after it would sit off a word boundary but for
the padding: each section's bytes are padded with zeros to a multiple
of four and the next offset follows the padded length, while the names
section's count stays the table's own length. The padding is not part
of any section, and `read` never looks at it.

## build

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

## float-bytes

A host float to a single's bytes by taking the double's bits apart,
because a float `==` in nushell is approximate and an encoder that went
by `math log` and `**` was wrong twice over; the bits are exact.
