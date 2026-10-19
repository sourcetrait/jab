# suite/load

## WORKSPACE

The workspace's root, the checkout this module lies in, from the module's own
file at parse time.

## TITLE_AT

The load screen: the map's title in bold off-white at four times the
console's cell, centred (main.S's TITLE_*), read while the program
loads behind it, which here runs from before 0.1 s of a launch to
about 0.65 s

## HOT_FUNCTIONS

the functions whose loops run a pixel or a sample, the span loop with
the helpers it calls, and the packet's render and a band's with the
span they call, each within one page of code (render.inc's CODE_PAGE)
and trapping only where the mixer's two calls a frame are

## HOT_FAMILIES

the families, each together on one page: poly_fill's loop runs once a
span and calls span_bound twice a span, and packet_render's loop and
band_render's call span_fill once a span, so a member on another page
costs every span a lookup, which each member within a page of its own
does not catch

## DEBUG_TEXT

The program's lines: what only a debug build says, its reports, and
what every build says, the exits and a load that fails, so a release
build carries no debug text and prints nothing but an exit

## hot-functions

Each hot function within one page of code and trapping no more than
its table says, and the span loop's family together on one page,
through the SDK's `capture hot` over the ELF beside the image: QEMU's
translator ends a block at a page boundary and chains blocks within a
page only, so a loop straddling one runs seven times slower, a call
across one costs a lookup, and a trap in a per-pixel loop would cost
more. `capture hot` gives an end exclusive, so a page is an end less one's.

## release-strings

A release build carries none of the program's debug text, every
`fps: ` string in it an exit's, and the debug build carries all of it,
so the scan is proved where it must find things before it is trusted
where it must find nothing; the release image is built here through
the tool, since the test's build is a debug one.

## title-holds

A tree's load screen, captured at TITLE_AT while the map loads behind
it: the text in the title's ink, bold at four times the console's cell
and centred, its ink within the text's cells, wider than all of them
but one, and on the title's rows, so a shorter text drawn in its place
fails by its width and nothing drawn by its count; the ink's box.

## title

the load screen: Render One's title drawn there while the map loads
behind it, and with no title in its tree a map's name in its place,
the growth map's (grow-source)

## first-frames

the first frames drawn: a debug build poisons the producer's scratch
once a frame's packet is published (raster.S), so a render reading
it through a pointer faults here, on hart 0 or on a worker

## broken

a map whose magic is wrong

- Render One's map cut short inside its sections
