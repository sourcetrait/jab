# romfs.S

RomFS on a disk, read through the block layer (block.S). The format is
Linux's romfs: a volume header of the magic, the accessible size, a checksum
and the volume's name, then a chain of file headers, each the next header's
offset with the mode in its low four bits, the spec info, the size, a
checksum, and the name; everything sits on a 16-byte boundary and every
longword is big-endian. Nothing is abstracted away: a handle is a header's
offset in the image, exactly as romfs itself points, and the mode nibble
reaches a program where the image keeps it.

Headers and the partial ends of a read go through one bounce buffer, which
remembers the sectors it holds, so a listing walking a chain inside it costs
one read rather than one per entry; the whole sectors of a file's data go
straight from the device into the program's own buffer. What the image
cannot support ends the run with a line on the UART, under the line lock
(uart.S) - a bad checksum, a
handle that is not a header, a header whose kind is wrong for the call -
since every handle the kernel hands out is none of those and a program that
invents one has a bug.

## .set ROMFS_MAGIC_LOW

`u32`: "-rom" as the little-endian word a load sees.

## .set ROMFS_MAGIC_HIGH

`u32`: "1fs-" likewise.

## .set ROMFS_HEADER

`u64`: bytes in a header before its name.

## .set ROMFS_BOUNCE_SECTORS

`u64`: the sectors the bounce holds.

## .set ROMFS_BOUNCE_BYTES

`u64`.

## .set ROMFS_NAME_LIMIT

`u64`: past this a name is not long but corrupt.

The bounce could not hold a longer name beside its own header.

## .set ROMFS_LINK_LIMIT

`u64`: the hard links followed before a chain is taken as endless.

## sys_romfs_list

Each record is checked as it is written, so a capacity larger than the
buffer costs the run only where it would write outside it.

## sys_romfs_find

A hard link is followed, so . and .. lead where romfs points them and the
record carries the header they point at.

## romfs_lookup

What png.S uses to find a sprite's directory and each frame in it. Each
component is found by skipping separators, then measuring it; once found, a
hard link stands for what it points at, and a component with another after
it must be a directory.

## sys_romfs_read

The whole sectors go from the device into the buffer and the partial ends
through the kernel's bounce. On a sector boundary with whole sectors to go,
the device writes the program's buffer itself; the queue is found first,
since block_base leaves a1 alone, where block_queue would clobber any t
register holding the transport. An image that ends inside what the header
promised ends the run.

## romfs_magic

block.S asks this to name a disk's kind.

## romfs_disk

Both failures are ones a program can see for itself with
jab.sys.block.list.

## romfs_volume

The checksum covers the first sector, or a volume smaller than one; the root
header follows the volume's name.

## romfs_chain

Following a hard link first is what makes the . and .. of any directory lead
where they point.

## romfs_entry

The record holds the handle it was asked about, then the header as the image
keeps it. A name longer than a record holds is reported cut, which is what a
Linux mount of the same image reports, while the length used here is the
real one, so the data still begins where it truly does. The name goes over
a cleared field so a short one ends where it should and a long one is cut
where the record ends.

## romfs_window

The bounce remembers what it holds, so a chain walked inside it is read
once.

## romfs_bounce

`2048 u8`: the bounce, sectors as the disk holds them.

## romfs_scratch

The JAB_ROMFS_* record a header is read into.

## romfs_roots

`8 u64`: each disk's root header offset, 0 until read.

## romfs_sizes

`8 u64`: each disk's accessible size.

## romfs_bounce_disk

`u64`: the disk the bounce holds, its index plus 1, 0 for none.

## romfs_bounce_sector

`u64`: the first sector it holds.

## romfs_bounce_count

`u64`: the sectors it holds.

## msg_romfs_disk_id

`21 u8`.

## msg_romfs_not_romfs

`30 u8`.

## msg_romfs_header

`27 u8`.

## msg_romfs_kind

`27 u8`.

## msg_romfs_disk_error

`23 u8`.
