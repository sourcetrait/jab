# display.S

The display: QEMU's virtio-gpu in 2D over mmio. One resource, the
framebuffer at JAB_DISPLAY_BASE, is the program's to draw into; the kernel
attaches it as the resource's backing, sets it as scanout 0, and on a flip
transfers the whole of it, or the rectangles the program names, to the host
and flushes them. The screen console draws text into the same framebuffer
with the font in font.S and transfers only the rows it touched. Commands go
through the control queue in batches, a chain of two descriptors each, one
notify and one wait for the whole batch with the hart halted until the
device has answered every one, since each wait costs a halt and a wake of
every hart and a rectangle list is dozens of commands; a single command is
a batch of one. The queue is the wide one of virtio.inc, so a batch holds up
to GPUQ_CHAINS commands. Each response's type says whether the device took
the command. A rectangle list is transferred rectangle by rectangle, only
the changed pixels crossing, and flushed once as the one rectangle holding
them all, so the host's window draws one upload a tick whatever the list: a
flush costs the host's window a fixed price and a wait each, and a window
drawn on a timer draws late by as long as the flushes take.

The console is cells of FONT_WIDTH by FONT_HEIGHT, each glyph a 16-bit row
per pixel row with the glyph in the high FONT_WIDTH bits, white on black. A
newline ends the line; the bottom scrolls.

## sys_display_flip_rects

Every rectangle is checked before any is shown. The count is bounded before
it is scaled, so the byte size the bounds see never wraps.

## display_present_rects

The rectangle holding them all is found from the list first; then the
transfers go in batches of GPU_TRANSFERS_PER_BATCH, and the flush rides the
last batch, so a list up to GPU_TRANSFERS_PER_BATCH is one wait.

## gpu_batch_add

Pending chain p takes descriptors 2p and 2p + 1, and the available ring's
slot at the ring's index plus the pending count; the index itself moves when
the batch runs.

## gpu_wait_batch

The wait wakes on the transport's line. The external enable is cleared after
unless the sound stream is live, whose line must keep reaching the vector
while the program runs (sound.S).

## sys_display_text

A cell is the font's size times the scale, the nearest source pixel taken
as a sprite's is; what is under the text stays, and the program flips to
show it.

## text_glyph

Its t registers live across text_pixel, which touches t1 and a7 only.

## display_open

What the display is comes first, then the resource, its backing, the
scanout, and the first frame.

## display_present_rect

The transfer's offset is the byte offset of the rectangle's top left in the
framebuffer.

## gpu_get_display_info

With DEBUG the first mode is reported on the debug channel.

## gpu_submit

Descriptors 0 and 1 carry it. With DEBUG every command and its answer is
reported on the debug channel.

## console_write

A newline moves to the next line; a line past the last scrolls the screen
up; other control bytes are skipped, and bytes past ASCII draw as a space.
The dirty band takes in each line's pixel rows, and only that band is
shown.
