# census

The census's lines, a CENSUS build's (census.S), read off a run's serial log:
the directory after the load, the clamped edge's two verdicts, and every frame
read against the directory as census_print writes it. A frame stands valid when
it is whole and accounts: its frame line; each side the directory names, in its
order, once, its side line followed by its contexts 0 to the directory's count
less one in order, each a head and its continuations; the end line last; every
context's list reassembled from its chunks, its surfaces the directory's, each
once, each count at least 1; no block dropped; and each side's counts in the
relations census.S keeps among them.

`census-fixture-holds` is the census fixture's reading of a census build's log,
apart from the launch so it runs on any capture a census build wrote; the
suite's census part calls it on its run's log in a nu of its own, since the
suite's modules loaded around it slowed every closure about tenfold (measured on
test.nu). `census-reader-holds` holds the reader alone on any capture's log.

## DIRECTORY_FIRST

the directory's first format, naming no contexts: its census kept
three, hart 0's and two workers', the count its logs are read against

## directory

The directory the census sized at the load: the lumel maps it holds,
the surface index the walls start at, the surfaces in all, the contexts
a side's lines name each frame, and each tile side's entries and bytes;
null when the log holds no directory

## edge

The clamped edge's case at the load: whether a tile past a map's last
node reads uniform by its nodes and by lumel_sample, 1 for uniform;
skipped when a map fills the lumel arena's tail, null when the log
holds no edge line

## frames

Every census frame of a serial log in order, read against the log's
directory: its counts, the lighting's revision and the context lines'
chunk in force, its sides with each context's list reassembled, and
whether it stands valid, with the reasons it does not

## expected-shape

The records a whole frame holds between its frame and end lines, in
order: each side the directory names, its line, then the contexts the
directory counts

## shape-reasons

What keeps a frame's records from the whole frame's: those missing,
those repeated, those the directory does not name, else the first out of
its order

## surface-reasons

A context's list against the directory: each surface one it holds, once
in the list, its count at least 1

## accounting

A side's counts against the relations census.S keeps among them, for a
frame with nothing dropped and the side's contexts whole: every block
eligible, straddling, or outside; a request an eligible passing block; a
context's distinct tiles among its requests; the demand within its
contexts' distinct tiles; a tile of one surface, its classes its
surface's, a plane's one and a wall's the walls or the openings or both;
a demanded tile sampled; a check, a mismatch, and a uniform verdict once
a demanded tile, a checked tile the sampler kept uniform counted
uniform; the side's surfaces its contexts'; the window this frame the
demand, by the surface's class, each window the planes' and walls' sum,
a longer window holding a shorter's; the listed tiles of each class
covering its window this frame

## pairs-of

A list's surface:count pairs, the text after a head's semicolon or a
continuation's colon, and every item that is no such pair

## census-fixture-holds

The census fixture's reading of its run's log (suite/census's census-holds),
its line returned: the clamped edge's case at the load, a tile past a
map's last node read shaded by its nodes and by lumel_sample, where nodes
clamped to the last column alone read it uniform; every frame valid as
`frames` reads it, whole and accounting; the directory counting hart 0's
context and a slot's each, `slots` of them, and every worker's context
drawn into, hart 0's not; the `shrunk` chunk splitting every list of two
surfaces or more and the build's own bound splitting none; planes and
walls both demanded; the lighting's revisions in order, no tile uniform
by its nodes and not by lumel_sample, the ordinary light's uniform tiles
checked, every demanded tile uniform and checked in a full bright
revision's first frame and uniform through it, none uniform or checked
under the parity; and the log read whole (census-reader-holds).

- the clamped edge: a 3 by 3 map whose last column's nodes are alike
  and whose penultimate column's last node is a level under, a tile at
  level 1 past the last node, which lumel_sample reads through the
  penultimate cell; its nodes from the sampler's clamp and the sampler
  itself both find it shaded
- the contexts: the directory counting hart 0's and a slot's each, and
  every worker's drawn into
- the line's bound: the shrunk chunk splits every list of two surfaces
  or more, each reassembled whole, and the build's own bound none here
- the lighting: the revisions in order, no tile its nodes call uniform
  that lumel_sample does not, the ordinary light's uniform tiles
  checked, every demanded tile uniform and checked in a full bright
  revision's first frame and uniform through it, none under the parity

## census-reader-holds

The census reader on a capture's log (`frames`): the log read whole,
every frame valid but a last one the run's end cut, and the directory
present. The log alone, no launch, so it runs on any capture a census
build wrote, of either directory format.
