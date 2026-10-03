# main.S

romfs: the filesystem. Reports what the kernel makes of a fixture
image the test built, and lets the test be the judge of all of it:
every path it was told to look for, as `f <code> <type> <size>
<name>`; the whole of a binary file, read in pages that never line up
with a sector and written out as hex, 64 bytes to a line as `x <hex>`,
then `png bytes <n>`; an empty file, as `empty <bytes> <next>`; and
the entries of a directory holding a name longer than a record can
carry, as `over <type> <name>`.

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
