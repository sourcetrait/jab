# sdl/symbols

## console_updates

The console's rectangle update in QEMU's two families, the function a
device's flush calls and its whole-surface form: 11.1.2's names, then
10.2.2's, which a modular build exports to its modules.

## device_module

How a virtio-gpu module's file name starts in a modular QEMU's
packages: hw-display-virtio-gpu.so and its -gl and -pci kin.

## sdl-unread

An object's table left unread, with the state that kept it so.

## sdl-stat

A file's inode, size, and modification time in nanoseconds as `ls -l`
gives them now, the three an object's line records; null where no file
is there.

## sdl-table

The symbol table of an object a decision needs, as binutils' nm reads
it: its full table, else on "no symbols" its dynamic one, keeping the
function symbols that carry a size, each name read up to its first `.`
so gcc's parts (.cold, .part.N, .isra.N, .constprop.N, .lto_priv.N)
read as their function, sorted by start with the furthest end reached
so far beside each, which bounds a search back to an enclosing function
(sdl-functions-at). The file is read only while it is the one its line
names, the inode, size, and modification time `ls -l` gives now the
same, and an executable whose path ends ` (deleted)` never is. `state`
says which held: read, no_file, nm_absent, deleted, changed, or
unreadable, with nm's own words in `why`; `source` which table
answered: symtab, dynsym, or none; `console` whether it holds both of
the console's update functions of one family; and `nm`, nm's text as it
was read, which a bundle keeps (sdl bundle).

## sdl-table-from

A symbol table read from nm's POSIX text as sdl-table reads it, `source`
the table the text came from, the text kept whole as `nm`.

## sdl-bundled-table

A needed object's table out of a bundle (sdl bundle) in place of nm on
its path, the replay's source (sdl bundle-check): the state its
manifest entry records where that is not `read`, else its table file,
taken only when the file's raw bytes have the SHA-256 the entry names;
`unbundled` where the manifest holds no entry, no table, or another
table's bytes.

## sdl-functions-at

The functions of a table (sdl-table) whose [start, end) holds an
address, aliases included: a binary search for the last start at or
below it, then back while the furthest end reached so far lies past
it. None where the address falls between functions. `overlap` says
whether the symbols holding it span more than one extent: aliases of one
function share theirs, so they read as one, while two functions' symbols
covering one address are an ambiguity no reading tells apart
(RenderAnchor).

## resolve

The shim's log at `log` (sdl log) with its make_currents' frames
resolved: the object table, each object with its file name and the
state of its symbol table (sdl-table); `virtio_gpu_in`, module or
executable; and every event in order, each frame of a make_current
with its object's file name, its table's state, and the functions that
hold it. A frame is a return address, so it resolves at the address
less one: a call that ends its function returns to the first byte past
it. It lies in every function of its object's table whose [value,
value + size) holds that address, an alias included, and in none where
the address falls between functions; a frame also carries `overlap`
(sdl-functions-at). The tables read are the ones a decision needs, read
before any rule is chosen: the objects of the immediate caller and of
its caller in every make_current, a render's included, so a render's
caller is held to its table like any other (RenderAnchor), and the
executable's where the device's code is there; with --every, every
object a make_current's frame lies in. The device's code lives in a module when
the table lists one whose file name starts hw-display-virtio-gpu, else
in the executable. With --tables, a bundle's directory (sdl bundle),
each table comes out of the bundle in place of nm on its object's path,
as a bundle's check replays it (sdl-bundled-table). A log the shim could
not have written is refused.

## sdl-resolved

sdl-resolve's reading, beside it each object's table whole as read
(sdl-table), by index, and the run's lines (sdl log); `bundle` the
tables' bundle, "" for nm.

## sdl-held

The refusal a frame's object holds before its symbols can answer: nm
absent, the file changed or the executable deleted, a replay's table
not in its bundle, or nm unable to read it; null when its table was
read or it has none to read.

## sdl-device

Whether a frame lies in the device's code: in a virtio-gpu module, or,
with the device in the executable, in an executable function named
virtio_gpu_*.
