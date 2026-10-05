# dtb.inc

The flattened device tree's format as dtb.S reads it: the header's fields,
the structure's tokens, the reader's bounds, and its answers. Included by
the kernel's dtb.S and harts.S and by a program that assembles dtb.S in, so
it guards itself against a second inclusion.

## .set DTB_INC

`u32`: set once the file is included, the guard.

## .set DTB_MAGIC

`u32`: the header's first word, 0xd00dfeed, big-endian like every word of
the format.

## .set DTB_VERSION

`u32`: the version the reader reads, 17, whose header carries the
structure's size; an older tree is refused.

## .set DTB_LAST_COMPATIBLE

`u32`: the greatest last compatible version taken, 16: a tree that says it
reads as version 16 reads as 17, and one that needs a later reader is
refused.

## .set DTB_HEADER

`u64`: the header's bytes; no block starts inside them.

## .set DTB_MAX

`u64`: the largest tree taken, 1 MiB (working); QEMU's for this machine is
under 10 KiB.

## .set DTB_DEPTH

`u64`: the deepest nesting taken, the root at 1, 16 (working).

## .set DTB_HDR_MAGIC
## .set DTB_HDR_TOTALSIZE
## .set DTB_HDR_OFF_STRUCT
## .set DTB_HDR_OFF_STRINGS
## .set DTB_HDR_OFF_RSVMAP
## .set DTB_HDR_VERSION
## .set DTB_HDR_LAST_COMPATIBLE
## .set DTB_HDR_SIZE_STRINGS
## .set DTB_HDR_SIZE_STRUCT

`u32`: the header's fields by their offsets: the magic, the tree's total
bytes, the structure's, the strings', and the reservations' offsets, the
version and the last compatible one, then past the boot cpu's field the
strings' and the structure's sizes.

## .set DTB_BEGIN_NODE
## .set DTB_END_NODE
## .set DTB_PROP
## .set DTB_NOP
## .set DTB_END

`u32`: the structure's tokens, each a word: a node's start, its name after
it NUL-terminated and padded to a word; its end; a property, its value's
bytes and its name's offset in the strings after it, then the value padded
to a word; nothing; the structure's end.

## .set DTB_OK
## .set DTB_BAD_MAGIC
## .set DTB_BAD_VERSION
## .set DTB_BAD_SIZE
## .set DTB_BAD_BLOCK
## .set DTB_CUT
## .set DTB_BAD_NAME
## .set DTB_BAD_PROP
## .set DTB_TOO_DEEP
## .set DTB_BAD_TOKEN

`u32`: dtb_check's answers: the tree whole; a bad magic; a version before 17
or a last compatible one past 16; a total size under the header, past the
bytes the caller vouches for, or past DTB_MAX; a block off its alignment,
inside the header, or past the total size, or a tree off an 8-byte boundary;
a token or a property's header past the structure; a node's name running
past it; a property's value past it or its name past the strings; nesting
past DTB_DEPTH; and a token out of place: unknown, a property outside every
node or after a child of its node, an end with no node open or with one
open, a second root, or no root at all.
