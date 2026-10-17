# start.S

The startup check (ProgramMinimums): before the program starts, the
image's first page, which the SDK writes ahead of its code, held to the
machine the launch provisioned. A program lists the specs it supports and
reserves the harts it needs; its build embeds both in its image, each
listed spec's definition with them, and the launch names the spec it
provisions in the bootargs, jab.spec. The name alone enforces nothing: the
kernel looks it up in the image's own list and holds the guest's harts and
RAM to that entry, and holds the harts online to the image's base demand.
Code paths come from the values, never the name.

The first page, little-endian throughout: at offset 0 one uncompressed
`jal x0` to the code at offset JAB_IMAGE_CODE, every kernel entering at the
base taking it first; at 4 the magic `JABD`, then the version, the flags
(bit 0 declared), and the declaration's offset, length, and CRC-32, zeros
to JAB_IMAGE_HEADER_SIZE; at JAB_DECL_OFFSET the declaration, never
executed: the base demand (u16), the count of specs (u8), a zero byte, then
an entry of JAB_DECL_SPEC_BYTES a spec, its name in lowercase ASCII zero
padded to JAB_SPEC_NAME_BYTES, its cores, its RAM in GiB, its display's
width and height, its frame rate, and its ISA (JAB_ISA_RVA23), each u16,
the rest zero (jab.inc).

## start_check

In this order:

1. No magic at offset 4: an image built before the header, whose first
   page is its own code; it is entered as ever. A legacy image's bytes at 4
   could read as the magic with a header that holds after it, a case ruled
   out only by its odds.
2. The version other than JAB_IMAGE_VERSION, then a flag bit past
   JAB_IMAGE_DECLARED: refused.
3. Flags 0: undeclared, every field 0, a program listing no specs; a
   length, an offset, or a CRC refused by name; else entered through the
   jump.
4. Flags 1: declared. A length of 0, an offset other than JAB_DECL_OFFSET,
   a length short of one spec's, JAB_DECL_LEAST, or past the first page's,
   JAB_DECL_MAX, a CRC that fails over the declaration's bytes (gz.S's
   gz_crc32), a count of 0 or past JAB_DECL_SPECS_MAX, and a length other
   than the list's: each refused by name.
5. The bootargs' jab.spec (harts.S's spec_name), when there is one: looked
   up among the entries by its name, its letters folded to lowercase, a
   name longer than an entry's never listed; not listed, refused naming
   it. Listed, the machine held to the entry: the harts discovered as many
   as its cores, every one online (harts_masks), and the RAM installed
   (ram.S's ram_installed) exactly its RAM; else refused naming the spec,
   what it wants, and what the guest has.
6. The harts online held to the base demand, with a spec named or none, a
   custom machine's: short, refused naming both counts. Under DEBUG the
   jab.nominimum knob of 1 skips this check and nothing else, so a
   program's own handling of a short reservation can be reached; a release
   kernel reads no knob.

The display is not checked here: the guest's resource is the ABI's 1920 by
1080 for every spec a build lets an image list, and the window's size is
the host's to change.

A refusal composes its line in start_text and ends the run through trap.S's
fatal_plain, the kernel's one fatal path: recorded in hart 0's record, the
secondaries, released and idle by now, stopped by the shutdown, and the
line printed under the line lock with status 1. Every such line starts with
one of the three heads, msg_refused, msg_spec, msg_short, which
test/purity's fault list carries.

## start_refused

The line's end written at the cursor, then fatal_plain with start_text.

## line_byte

The one writer of start_text: a byte past START_TEXT_BYTES less one is
dropped, so a name off a long command line ends the line short rather than
past its buffer.

## .set START_TEXT_BYTES

`u64`: a refusal's line with its end, room for a name of the bootargs'
whole BOOT_ARGS_BYTES with the words around it.

## msg_refused

`27 u8`: the head of a malformed declaration's line, `jab: declaration
refused: `, its reason after it.

## why_version
## why_flags
## why_undeclared_length
## why_undeclared_offset
## why_undeclared_crc
## why_no_length
## why_offset
## why_length
## why_crc
## why_crc_header
## why_count
## why_for
## why_specs

`u8`: the reasons and the words between the values of a malformed
declaration's line.

## msg_spec

`11 u8`: the head of a spec's line, `jab: spec `, the name after it.

## why_not_listed
## why_wants
## why_harts
## why_discovered
## why_online
## why_gib
## why_installed

`u8`: the words of a spec's line: not listed, or what it wants and what
the guest has.

## msg_short

`43 u8`: the head of the minimum's line, the harts online and the base
demand after it.

## knob_nominimum

`15 u8`: under DEBUG only, the knob that skips the minimum.

## start_cursor

`addr`: where start_text's next byte goes.

## start_text

`START_TEXT_BYTES u8`: a refusal's line, made before it is recorded.
