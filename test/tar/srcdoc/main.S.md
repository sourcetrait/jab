# main.S

tar: an archive the program holds itself. Reads /foo.tar out of the
romfs disk into memory, then reports what the kernel makes of it: each
entry as `t <type> <size> <data> <name>`, then a find as
`f <code> <size> <name>`, then one for a name that is not there. The
test is the judge.

## .set DISK

`u8`: the romfs disk's id.

## .set BUFFER

`u64`: room for the archive, 32 KiB.

## _start

The archive comes out of romfs and into the program's own memory, a read at
a time from the offset the one before returned, and its length is printed as
`archive <bytes>`. Then every entry, a page of four at a time, the cursor
the a1 of the page before. Then a name that is there, and one that is not.

## path_tar

`9 u8`: the archive's path on the romfs.

## path_note

`13 u8`: a name the archive holds.

## path_missing

`17 u8`: a name the archive does not hold.

## word_archive

`9 u8`: the length line's first word.

## word_t

`3 u8`: an entry line's first word.

## word_f

`3 u8`: a find line's first word.

## archive_len

`u64`: the archive's bytes in memory.

## rec

`296 u8`: the archive's romfs record, then a find's tar record.

## recs

`4736 u8`: a page of tar records.

## archive

`32768 u8`: the archive as read.

## line

`512 u8`: the line being built.

## lineptr

`addr`: the cursor in line.

## digits

`32 u8`: line_dec's digits, built backward.
