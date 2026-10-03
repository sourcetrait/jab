# main.S

tar: an archive the program holds itself. Reads /foo.tar out of the
romfs disk into memory, then reports what the kernel makes of it: each
entry as `t <type> <size> <data> <name>`, then a find as
`f <code> <size> <name>`, then one for a name that is not there. The
test is the judge.

## _start

The archive comes out of romfs and into the program's own memory, a read at
a time from the offset the one before returned, and its length is printed as
`archive <bytes>`. Then every entry, a page of four at a time, the cursor
the a1 of the page before. Then a name that is there, and one that is not.
