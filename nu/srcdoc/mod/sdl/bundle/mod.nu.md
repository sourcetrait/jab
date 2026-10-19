# sdl/bundle

## main

A probed run's capture made portable, `sdl bundle <probe dir> <bundle
dir>`, on the host that took it as the run's last step, while
the objects its log names are still the files their lines name. The log
in the probe directory, `sdl.log`, is classified as the probe reads it
(sdl classify), a refusal ending the bundle with nothing written; then
into `bundle`, a directory not yet there, go the log as it was written;
for each object whose table the reading read, nm's text as it was
parsed, `tables/<index>.nm`, the file's own SHA-256 taken with its
inode, size, and modification time its line's before the hash and
unchanged after it, a change refusing the bundle as changed while
bundling; `classified.nuon`, every event with its line, stamp, name,
render flag, chain key, kind, and callers, each chain's decision, and
the counts by kind; the probe directory's `api.out`, `identity.nuon`,
`trace.log`, and each file `extra` names, where it has them, copied
whole; and last `bundle.nuon`, the manifest, bundle_schema 2: the
profile; the reader (sdl-reader), `identity reader`'s record, the one
field schema 2 changes; the host, its OS, kernel release,
hostname, and QEMU (sdl-qemu-of); every object of the log's table with
its line's fields, its state, and for a read one its SHA-256 and its
table with that file's SHA-256 and its source; every other file with
its SHA-256 and size; the events counted; and the run, the identity's
capture fields beside the log's process and nonce. The profile is
`--profile`, else the identity's, else generic, and historical for a
log written before the run's lines; a paired bundle needs the log's
nonce, `api.out`, and `identity.nuon`. The manifest. Untyped because it
ends in an error.

## sdl-reader

The reader a bundle records and its check sets beside its own:
`identity reader` over jab's checkout, the root four levels above this
file, its commit and state and the interpreter running it
(ReaderIdentity). It is provenance, read by a person; a bundle made by
other code is checked the same. A schema 1 bundle's reader, the jab commit
and jab.nu's SHA-256, stays as written.

## sdl-qemu-of

The QEMU a log names, object 0 of its table (sdl log): its path, and
while the file is the one its line names, its version and its SHA-256,
`sha256` where it was taken already; null fields otherwise.

## bundle-check

A bundle (sdl bundle) held to its manifest wherever it is read, `sdl
bundle-check <bundle dir>`, stage by stage, the first that fails
refusing it by its stage and name with nothing read from it: 1, the
inventory, bundle.nuon at bundle_schema 1 or 2, every file the manifest
lists there with its SHA-256 and size
and none it does not but bundle.nuon, sdl.log and classified.nuon among
them and a paired bundle's api.out and identity.nuon; 2, the
correspondence, the manifest's objects one for one with the log's table
lines, index, path, inode, size, and modification time alike, a read
object's table listed and no other's; 3, the sequence, the log's events
as sdl-log reads them, which reads no object file, classified.nuon's in
count and line by line in line, stamp, name, render flag, and chain key;
4, the replay, the log classified again from the bundle's tables
(sdl classify --tables), every event's kind and callers classified.nuon's;
5, the run by its profile: paired, the log's process the identity's
qemu_pid, the log's nonce the identity's capture_nonce, and the nonce
the guest echoed, read from the bundle's api.out by `guest`, the
program's reader, equal to both, a 0 or a missing value refused; generic
and historical, nothing bound and nothing paired; and with trace.log,
QEMU's flushes paired in order one for one with the log's flip uploads,
each upload within 5 ms after its flush on the one host clock; 6, the
reader, the host's set beside this one, `same` whether their jab commits
agree, read from schema 1's `jab` or schema 2's first repository and
refusing nothing, the replay's equality being what admits another
revision. The profile, the run, both readers, the trace's
pairing, and classified.nuon's events. Untyped because it ends in an
error.
