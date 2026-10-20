# suite

fps's integration test, on our own content alone: Render One and
Render Zero, `render_1` and `render_0`, and copies of them the test
compiles with fixtures of its own. Each map's tree goes on the machine
as a romfs image built here, the manifest's image being Render Zero's:
the UART reports the load with its counts, which must be the tree's
from map.nuon and tile.nuon; then the first frame with its phases and
counts, every pixel of a view reached by a surface but a rounding's
worth, and the same for the frames drawn from the poses the console
places; the API's state records carry the camera in each pose's
sector after its console record; QEMU has nothing to say. First the
load screen: Render One's title drawn there, and with no title in its
tree a map's name in its place. Then a sprite of the test's own
texture on a copy of Render One with its lights dropped, its
transparent half the wall behind as a copy without the sprite draws
it, the alpha policy at load over the test's own textures, and a quad
straddling the door sector's two portal walls drawn whole beside the
doorway, outside the door's rectangle; Render One with its counts,
the camera at the spawn with its eye over the floor there facing the
spawn's way, the window, the grate, the door's line, the door, the
ramp, and the hall's light, which lights the floor under it past the
far wall, the hum heard and the plan views read, then the stair on it
walked to the upper storey; Render Zero, the game's map, from its
spawn and four poses, one under the down flight's sloped ceiling,
with the sky read off the yard's capture and two traces answered, its
flights and driveway walked from placed starts with the ambient
following and their clock read, the three cadences on a schedule of
stalls and trigger reports and on a timed walk (cadence-holds), the
fight: an android roused and firing, struck down by four rounds from
the console and one from the trigger, fallen, its magazine taken on a
walk, the shots heard; the services under the default two workers,
ten seconds of play from a pad table at the reference pad's rate with
the sound recorded, every event the table sent taken by the program
and none dropped by the kernel's ring or the device, no sound service
finding its queue empty, and the recording heard in every 50 ms window
once the ambient plays; the light's view independence, floor points of
the bay read from the spawn at two yaws on a still copy of Render
Zero, as lit and with every lumel full bright, the light alone the
same from both yaws; the alpha policy rendered, a texture of the
test's own on Render One's grate wall read from poses at three
levels, each patch present in its exact colour where the oracle's
scaled means pass, the weighted mean of the shrink among those
colours, and the solid backdrop behind where they do not, the lit
loop's picture from the same build agreeing at every level, the same
poses under the room's own light within TheUser's bound, tiled against
lit; the texel-centre rule, a white
texture on that wall under lumels set as a checkerboard, each texel
beside a node read from its tile at the light of its centre by the
test's own bilinear; one level a block, the still copy's spawn view
with every level built against the tiles held off, identical over the
screen with the far floor's blocks past the tiles' levels, drawn in
packets of a few commands and spans, flushed many times, identical
again, and drawn by the serial backend, one worker, and two in bands of
sixteen rows, identical again with the same counts; the flow's
eye on the line two sectors share reaching the sector behind it, and
a map where a hall's rectangle grows through a later path before the
room beyond it can be reached; a map whose magic is wrong, which exits
6, and Render One's map cut short, which exits 7, each saying so on
the UART. On a CENSUS build the test runs the census's own fixtures
alone (census-holds).

## WORKSPACE

The workspace's root, the checkout this module lies in, from the module's own
file at parse time.

## main

The suite in the order its cases are listed: on a CENSUS build the census's
fixtures alone and on a HANDOFF build the handoff's, each printing `fps: ok`;
on any other the release's checks, then the context, `{kernel, image, out,
set, assets, game, trees, render_1: {source, tree}}`, then every case with
the context and the records of the cases it reads, kept by case name in one
record, and the report last, printing the summary lines and `fps: ok`.
