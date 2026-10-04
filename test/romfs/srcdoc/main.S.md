# main.S

romfs: the filesystem. Reports what the kernel makes of a fixture
image the test built, and lets the test be the judge of all of it:
every path it was told to look for, as `f <code> <type> <size>
<name>`; the whole of a binary file, read in pages that never line up
with a sector and written out as hex, 64 bytes to a line as `x <hex>`,
then `png bytes <n>`; an empty file, as `empty <bytes> <next>`; and
the entries of a directory holding a name longer than a record can
carry, as `over <type> <name>`.

## .set DISK

`u8`: the romfs disk's id.

## .set PAGE

`u64`: the bytes a read asks for, never lining up with a sector.

## .set COLUMNS

`u64`: the bytes a hex line carries.

## _start

The binary file is read in pages that never line up with a sector, every
byte of it written out for the test to hold against the original. The empty
file reads as no bytes, and no offset to go on from. The directory holding a
name longer than a record carries is listed from the offset its find gave.

## find_one

The SDK's macro takes a label, which is what a program writing one out does;
walking a table of them reaches the same call the macro does, an ecall with
the arguments in place.

## line_nl

The line is terminated where it ends, so a short line never shows the tail
of a longer one before it.

## paths

`14 addr`: the paths looked for, ended by 0.

## path_readme

`11 u8`: a text file.

## path_empty

`7 u8`: an empty file.

## path_png

`36 u8`: a binary file.

## path_font

`19 u8`: a large text file.

## path_symlink

`21 u8`: a symbolic link.

## path_hardlink

`20 u8`: a hard link.

## path_fifo

`16 u8`: a fifo.

## path_block

`17 u8`: a block device.

## path_char

`16 u8`: a character device.

## path_socket

`18 u8`: a socket.

## path_folder

`23 u8`: a directory.

## path_max

`162 u8`: a path whose last name is 127 characters, the most a record carries and a linux mount reads.

## path_over

`195 u8`: a path whose last name is 165 characters, past both.

## path_over_dir

`29 u8`: the directory holding path_over's name.

## word_f

`3 u8`: a find line's first word.

## word_x

`3 u8`: a hex line's first word.

## word_png

`11 u8`: the binary file's count line's first words.

## word_empty

`7 u8`: the empty file's line's first word.

## word_over

`6 u8`: an overflowing directory entry's line's first word.

## rec

`144 u8`: the romfs record a find wrote.

## recs

`2304 u8`: a page of romfs records.

## buf

`4096 u8`: a page of the binary file, or the empty file's read.

## line

`512 u8`: the line being built.

## lineptr

`addr`: the cursor in line.

## digits

`32 u8`: line_dec's digits, built backward.
