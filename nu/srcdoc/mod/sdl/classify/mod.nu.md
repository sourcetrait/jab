# sdl/classify

## render_anchor

The front-end function whose own make_current opens a drawn frame,
sdl2_gl_render_surface (QEMU 11.1.2's `ui/sdl2-gl.c:51-62`: MakeCurrent
55, GetWindowSize 57, SwapWindow 61), static, called by sdl2_gl_refresh
(121) and sdl2_gl_redraw (136). A make_current whose immediate caller
resolves to it, its own function and not an inlined copy, is a render
whatever its size call's gap (RenderAnchor).

## render_inliners

The front-end functions a render's make_current or the scanout path's can
lie inlined in: sdl2_gl_refresh, which renders and polls events, whose
resize and expose reach sdl2_redraw (`ui/sdl2.c:611, 614, 170`); and
sdl2_gl_redraw, which in scanout mode returns through
sdl2_gl_scanout_flush (`ui/sdl2-gl.c:126-138, 247-253`), the render's
own event shape. A make_current whose immediate caller is either cannot
tell which path it is on, however many MakeCurrent calls the function
holds, so it is refused as ambiguous; an inlined render is a front end
the probe does not support.

## size_window_us

2 ms, the window the timing rule read every render by: the weaker
reading by timing's bound where a render's caller cannot resolve, and
the bound past which a render's gap is named in the report. A host
stall between a render's two calls makes the gap any length: the
qualification bench's probed_2 run 3 held one at 3.049 ms, line 3934,
which the timing rule sent to the anchor rule and the whole log was
refused.

## sdl-decide

How a make_current's chain reached the window by its frames past the
shim's own (sdl resolve), decided once a chain. Its immediate caller
first: its object's table held (sdl-held), its return address in two
functions' symbols refused as ambiguous (`overlap`, aliases of one
function being one); resolved to the render's anchor a `render`; to an
inliner refused (`inlined`); unresolved in a table that was read and
holds dynamic symbols alone, a front end whose render cannot resolve
since its anchor is static, `timed`, left to each make_current's size
call (sdl-judge); anything else must resolve to the SDL front end, the
anchor rule: sdl2_gl_switch makes a `switch`, the window taking a new
surface; sdl2_gl_update an upload, read by its second frame, the
function that called it. The console's update there makes it a flip's
`upload` when a later frame lies in the device's code, and leaves it
unresolved however many frames follow otherwise; any other resolved
function outside the device's code makes it the `console`'s own, a new
surface's redraw or the registration's first update; an unresolved frame
of the executable makes it the console's own only beside a device
module, with the executable's table read and holding both of the
console's update functions of one family, since a module reaches the
console through those alone. Every frame the decision reads is refused
when two functions' symbols cover it. Anything else is `refused`:
`class` says which refusal (sdl report), `fault` what failed, and `at`
the frame at fault.

## sdl-judge

A make_current read from its chain's decision and its own size call: a
render by its anchor carries the evidence `anchor`; a `timed` chain's
make_current is a render by timing, evidence `timing`, the weaker
evidence a table of dynamic symbols alone gives, when the window's size
call follows it within size_window_us, refused as `late_size` when the
call comes later, and refused at the anchor when none follows; every
other decision stands as decided, with no evidence.

## sdl-frame-name

A frame as the record's callers name it: its function where it
resolves, aliases joined by `/`, else its object's file name and
address, `?` for no object.

## sdl-frame-text

A frame at fault, for a refusal: its object's file name and address,
`?` for no object, with its functions where it resolves.

## sdl-table-text

What an object's symbol table holds, for a refusal, the executable
named as such.

## sdl-fault-text

A fault's words for a refusal, naming the object it lies in.

## sdl-faults

A refusal's faults (sdl-refusal) from the make_currents one class
refused: one a fault and the object it lies in, how many make_currents
hold it, and the frames at fault.

## stamp-us

A log stamp, the shim's `<seconds>.<six digits>`, as whole
microseconds, so a gap is exact.

## render-gaps

Every render's gap from its make_current to the window's size call,
reported, never validity (RenderAnchor): the renders, those read by
timing, those with no size call after them, and over the rest the gap's
median and largest, its 99th from a hundred gaps, by nearest rank, in
milliseconds, and every gap past size_window_us with its line.

## main

The shim's log at `log` (sdl resolve) with each make_current read by
where it came from (sdl-decide, sdl-judge): a `render`, a drawn frame,
by its anchor, or by timing through a front end's dynamic symbols alone;
a `switch`, the window taking a new surface; a flip's `upload`, one per
rectangle the device flushed; or one of the `console`'s own, which is no
flip of the program's. Each event gains its `kind`, a make_current's one
of those four and any other event's its name, its `callers` as the
record names them (sdl-frame-name), the immediate caller first, its
`size_us`, a make_current's gap to a size call right after it, and a
render's `evidence`; the reading carries the renders' gaps
(render-gaps). It comes only when every make_current is decided;
otherwise the first refusal in order: the log's lines, a stop notice,
and its structure (sdl log), nm absent, an object that is no longer the
file its line names or a deleted executable, an object nm cannot read,
a make_current failing the anchor, ambiguous, inlined, late by timing,
or unmodelled, and an upload whose second frame does not resolve, each
naming its fault, how many make_currents or lines hold it, and up to
four of them. With --tables, a bundle's directory, the tables come out
of the bundle (sdl resolve).

## sdl-chain-key

A make_current's chain as the reading keys it: its frames past the
shim's own, each an object's index or `?` with its address in hex; an
event with no frames keys the empty chain.

## sdl-classified

sdl-classify's reading with each event's chain key kept, each chain's
decision by key, every object's table whole (sdl-resolved), and the
run's lines; `bundle` the tables' bundle, "" for nm.
