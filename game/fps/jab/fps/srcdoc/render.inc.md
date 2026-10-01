# render.inc

CODE_PAGE: QEMU's translator ends a block at a page boundary and chains
blocks within a page only, so a loop straddling one leaves and re-enters the
translator every iteration, seven times the loop; the sky fill measured 8 ms
in a page and 54 across one. A function whose loops run a pixel or a sample
is aligned to a page and kept under one, which the test holds from the ELF's
symbols; a loop of that kind inside a larger function is aligned to a power
of two past its length. The toolchain emits compressed instructions, so the
layout moves by bytes with any edit and the guard is structural.

camera_d and plane_d exist because the type libraries' vector macros read
doubles from memory: the camera's doubles are written once a frame with the
basis, the plane's once a polygon in surface_setup, each at twice the float
record's offsets.

The stats record grew its span, pixel, and light-tick fields for the light's
instrument, then the rejected-pixel count; a field is added by extending the
record, zeroed in world_draw, and printed by frame_report, with the test's
frame template extended to match, since the template names every field.

The brightness word packs three 16.16 channels CHANNEL_BITS apart, which
integer addition steps exactly while every channel stays in range; the lit
pixel loops unpack each channel to 8.8 by two shifts. The packed step
multiplied by an integer stays exact the same way, which is how a held span's
start moves along it; a packed word halved by an arithmetic shift does not,
since each channel's odd bit lands in the lane below.

The polygon's held light evaluations are a small table rather than one row
and two brightnesses because a row that a hole cuts in two is two spans with
their own ends, and one slot would have each span evict the other every row
(raster.S).
