# sdl/log

## sdl_line

Every line the sdl shim writes (shim/crates/sdl), its time first, in
seconds to the microsecond: an object-table line, its index, the file's
inode, size, and modification time in nanoseconds or `- - -` where there
is no file, then its path, the rest of the line, empty allowed; a run's
line, `process` or `nonce` with whatever follows, held to its own form
apart so a malformed one is refused by name (sdl-run-lines); a
make_current with its frames, each an object's index or `?` with an
address in lowercase hex; a window-size call, a swap, or a poll; or a
notice the shim writes as it stops the run.

## sdl_notices

The shim's notices, each written as it aborts QEMU when it cannot reach
SDL: libSDL2 missing, or a function missing from it.

## main

The shim's log as written (shim/crates/sdl): the object table, each
object by index with its path and the inode, size, and modification
time in nanoseconds its file had as its line was written, null where it
had no file, as the vDSO has none; and the events in order, each
make_current with its frames past the leading ones in the shim's own
library, object 1, which it counts, a frame by its object's index (null
for none) and its address as written and as a number, and its timing
mark, `render`: a window-size call the next event, within 2 ms, which a
bundle's sequence check compares and the classification never reads, a
render being read by its anchor (sdl classify); every event with its
stamp as the log wrote it. A last line the run's end cut short is left
out. The run's lines are events too, and
their values come back apart: `process`, QEMU's pid, and `nonce`, the
capture nonce as its sixteen hex digits, each null where the log has
none, as a log written before them has neither. Every complete line is
held to the lines the shim writes (sdl_line) before any is read, and a
log the shim could not have written is refused, in order: a line outside
them, counted in lines with up to four shown by number; a notice the
shim wrote as it stopped the run, by name; a run's line given twice,
malformed, or out of its place (sdl-run-lines); then no object table,
an index given twice, a frame naming an index with no line ahead of it,
or a make_current whose frames do not start in the shim's library.

## sdl-run-lines

A shim log's run lines (sdl log), from its events in order, each its
line number and its text past the stamp: the process as the first event,
`process` and QEMU's pid in ASCII digits, and the capture nonce as the
second, `nonce` and sixteen lowercase hex digits, not all zero, a run's
line at most once each. The pid and the nonce, null where the log has
none; or the first fault, a process line before a nonce line: one given
twice, one malformed, a nonce with no process line ahead of it, then one
out of its place, with how many lines hold it and up to four.
