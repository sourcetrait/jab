# demand

## image_code

The image's first page (jab.inc's JAB_IMAGE_* and JAB_DECL_*), which the
kernel reads before the program starts (start_check): at the window's
base one uncompressed `jal x0` to the code at the second page,
image_jump; the header after it, image_header bytes from the base, the
magic `JABD` as a little-endian word, the version, the flags, bit 0
declared, and the declaration's offset, length, and CRC-32; the
declaration at decl_offset, never executed: the base demand, the count
of the specs listed, at most decl_specs_max, and an entry of
decl_spec_bytes a spec, its name zero padded to decl_name_bytes.

## decl_isas

The ISAs a declaration names, by the spec data's profile: RVA23 is 1.

## reserved_roles

The roles a manifest's sections may name, each a count of harts: those
`[reserved]` may reserve, and those a `[feature.<name>]` may demand.

## of

A program's declared demand, from the manifest in its directory
(program-demand): the specs it supports as asset/spec.nuon names them,
its reservation by role, each feature's demand, and its base demand.
Null for the legacy path, a manifest with no `specs`. Untyped because it
ends in an error.

## program-demand

A manifest's declared demand, validated. `specs` is a nonempty list of
names the workspace's spec data defines, matched without regard to case
and none twice; either section stands only beside it; `[reserved]` names
only the roles a program reserves, and each `[feature.<name>]` has a
snake_case name and demands at least one of the roles a feature may,
every count a whole number of one or more. The base demand, the main
hart and every hart reserved, is held against every listed spec's
harts, its `cores`, a spec that cannot hold it refused by name; a
feature's demand refuses nothing, since a spec it does not fit runs the
program without the feature. The specs come back by their names in the
spec data, the reservation with every role, 0 for one not reserved.
Null for the legacy path, a manifest with no `specs` and neither
section, which builds and launches as before, its runs recorded
undeclared. Untyped because it ends in an error.

## section-counts

A section's counts as given, a record of role and harts, each role one
of `roles` and each count a whole number of one or more; an empty
record for a section left out. Untyped because it ends in an error.

## demand-include

A declared demand as the assembly takes it, generated at every build of
the program ahead of its staleness check: `jab_manifest.inc` in the
build's output directory, which the build carries among its includes
and its inputs, so a program reads its numbers with `.include
"jab_manifest.inc"` and keeps no copy of them: JAB_BASE_HARTS;
JAB_RESERVED_<ROLE> for every role a program may reserve, 0 where it
reserves none; and JAB_FEATURE_<NAME>_<ROLE> for every role each feature
demands. The file is written only when its text differs from what is
there, so its time moves with its text alone. Its path.

## image-declaration

A program's declaration, the bytes its image's first page carries at
decl_offset for the kernel to hold the machine to before the program
starts (start_check), from its declared demand (program-demand) and its
workspace's spec data: the base demand (u16), the count of the specs it
lists (u8), a zero byte, then each spec's entry, decl_spec_bytes long, in
the demand's order: its name in lowercase ASCII, zero padded to
decl_name_bytes, then its cores, its RAM in GiB, its display's width and
height, its frame rate, and its ISA (decl_isas), each u16, the rest zero;
little-endian throughout. A listed spec an image cannot declare is
refused naming the program, the spec, and why: a display other than the
ABI's, display_size, the one every image renders at; an ISA profile
decl_isas gives no number; RAM in no whole number of GiB; a name past
decl_name_bytes or of other than letters and digits; a count past a u16.
More specs than decl_specs_max are refused too. Beside the bytes the
header's flags, offset, length, and CRC-32 (crc32): 1, decl_offset, the
bytes' length, and their CRC for a declared program; every one 0 and no
bytes for one declaring no demand. Untyped because it ends in an error.

## crc32

The CRC-32 gzip and PNG carry, as the kernel's gz.S computes it over an
image's declaration: the reflected polynomial 0xedb88320 through a
table, the register starting all ones and inverted at the end.

## header-source

The image's first page as the assembly takes it: `jab_header.S` in the
build's output directory, generated at every build of a program ahead of
its staleness check and counted among its inputs, its sections placed by
program.ld, `.jab.header` at the window's base and `.jab.decl`
decl_offset bytes on: the jump to `__jab_code`, the code's first byte at
the second page, assembled uncompressed and unrelaxed so it is the four
bytes of image_jump; the magic, the version, and the declaration's
flags, offset, length, and CRC (image-declaration), then zeros to
image_header bytes; then the declaration's bytes, none for a program
declaring no demand. The file is written only when its text differs from
what is there, so its time moves with its text alone. Its path.

- the jump and six words, then zeros to the header's end

## check-image

An image's first page, read as the kernel reads it before the program
starts (start_check) and held to the rules the build writes it by
(header-source): `legacy`, no magic at offset 4, an image built before
the header, its first page its own code; `undeclared`, the header with
flags 0 and the offset, the length, and the CRC 0, a program declaring no
demand; `declared`, flags 1, the declaration at decl_offset, its length
from one spec's to the first page's end and exactly its list's, its CRC
holding. Where the kernel refuses an image, so does this, by the kernel's
own reason (`declaration refused: <reason>`); past the kernel's rules, the
jump at offset 0 is image_jump, the image holds its whole first page and
code after it, and each entry is a name of lowercase letters and digits
zero padded, an ISA decl_isas numbers, and zeros past its fields. The
record: `kind`; `header`, the magic, version, flags, offset, length, and
CRC, null for a legacy image; and `declaration`, the base demand and each
spec with its cores, RAM in GiB, display, frame rate, and ISA, null but
for a declared image. Each refusal names the image. Untyped because it
ends in an error.

## bit-not-of

Every bit of a 32-bit word but those of `mask`.

## image

The demand recorded with an image at its build, `demand.nuon` beside it,
read and held to its rules (demand-record-problems): exactly `image`, the
image's SHA-256, and `demand`, null on the legacy path, else a demand in
program-demand's shape. No record beside the image is absent evidence,
no declaration, and comes back null as the legacy record's demand does;
a record present and unsound, unreadable as NUON, of other fields, of
another image, or of a demand off the shape, is refused naming the
record and its faults, never read as the legacy path, as is a record
beside no image. The demand, or null. Untyped because it can end in an
error.

## demand-record-of

Where an image's demand record lies: beside it, demand.nuon.

## demand-record-problems

What is wrong with a demand record for an image of that hash, a line
each; none when it holds: a record of exactly `image` and `demand`;
`image` the hash; `demand` null, or in program-demand's shape
(demand-shape-problems).

## demand-shape-problems

What is wrong with a recorded demand against program-demand's shape, a
line each; none for null, the legacy path's: `specs` a nonempty list of
names; `reserved` a record of every role reserved_roles names and no
other, each an int of 0 or more; `features` a list of records, each a
snake_case `name` and at least one role of feature_roles, each an int of
1 or more, and no other field; `base` an int, 1 plus the reserved harts.

## record-holds

Whether the record beside an image holds (image-demand) and names the
demand a build resolved; a record missing, unsound, of another image,
or of another demand is false, so the build runs again whole.

## spec-listed

A named spec held to the program's demand: refused naming both when the
demand recorded with its image (image-demand) does not list it; a
custom machine, and a legacy image, null demand, on any machine, pass.
Untyped because it ends in an error.
