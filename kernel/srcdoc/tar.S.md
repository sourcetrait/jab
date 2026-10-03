# tar.S

Tar, read where the program already holds it. Unlike romfs, which lives on a
disk, a tar archive is bytes in the program's own memory - usually a .tar.gz
read out of romfs and inflated - so every offset here is into that block and
nothing is read from a device. An entry's data needs no call of its own: it
sits 512 bytes after its header, and the record says where.

The format is ustar: a 512-byte header of a 100-byte name, the mode, owner
and group, the size as octal text, the time, a checksum, a type byte, a link
name, the magic `ustar`, and a 155-byte prefix that goes before the name
with a separator when it is used. Data follows padded to 512, and two zeroed
blocks end the archive. A header whose name is empty, or whose checksum does
not answer for it, is the end.

## sys_tar_list

A page that filled the buffer still has to say whether anything follows, so
the next header is looked at without being written.

## tar_entry

An empty name or a checksum that does not answer for the header both mean
the archive ends here, as every tar reader takes them. The whole header has
to be inside the archive; the data follows the header; the next header is
that far on again, the data padded to a block, and it has to be inside the
archive too, or this was the last entry. An old archive leaves the type
byte zero, which is read as a regular file. The name goes over a cleared
field: a ustar prefix goes before it with a separator, which is how a path
longer than a hundred characters is written.

## tar_name_equal

tar writes a directory's name with a trailing separator, which is why the
record's one is ignored.
