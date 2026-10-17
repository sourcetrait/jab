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

## .set DISPLAY_RESOURCE

`u32`: the one resource's id.

## .set GPU_CMD_BYTES

`u64`: bytes a command buffer holds.

## .set GPU_RESP_BYTES

`u64`: bytes a batch response buffer holds.

## .set GPU_TRANSFERS_PER_BATCH

`u64`: the transfers a batch holds, the last batch carrying the flush beside them.

## .set FONT_WIDTH

`u64`: a console cell's width in pixels.

## .set FONT_HEIGHT

`u64`: its height.

## .set FONT_ROW_BYTES

`u64`: bytes in a glyph's row.

## .set FONT_GLYPH_BYTES

`u64`: bytes in a glyph.

## .set FONT_FIRST

`u8`: the first character the font draws.

## .set FONT_LAST

`u8`: the last.

## .set CONSOLE_COLUMNS

`u64`: the cells across the screen.

## .set CONSOLE_ROWS

`u64`: the lines down it.

## .set CONSOLE_LINE_BYTES

`u64`: framebuffer bytes in a line of cells.

## .set CONSOLE_FG

`u32`: the console's text, white.

## .set CONSOLE_BG

`u32`: its ground, black.

## sys_display_flip

Beside its status each flip answers its receipt in a1 to a3: the `rdtime`
frame_ready read as it decided and the tick it held it against, stored the
moment it decides, and present_ordinal as the call returns. A path that ends
before the check, the display not open or failed already, writes zeros of
its own to a1 and a2, so 0 reads as no decision observed, which `rdtime`
never is once the kernel runs.

## sys_display_flip_rect

The rectangle is read again from the frame for the present, so the
receipt's stamp and tick wait in s0 and s1 and go to a1 and a2 with the
status.

## sys_display_flip_rects

Every rectangle is checked before any is shown. The count is bounded before
it is scaled, so the byte size the bounds see never wraps. The count waits
in s1 before the stamp and the tick take its slot.

## display_present_rects

The rectangle holding them all is found from the list first; then the
transfers go in batches of GPU_TRANSFERS_PER_BATCH, and the flush rides the
last batch, so a list up to GPU_TRANSFERS_PER_BATCH is one wait.

present_ordinal moves on the flush's own answer, chain s2 of the last batch,
whatever that batch's transfers answered: the device applies a flush after a
refused transfer of the same batch, so the screen took the present though
the batch's merged answer says a command failed. A stuck source's batch reads
no answer and moves nothing. Under DEBUG the knobs' faults ride the frame at
16 and the transfers sent at 8, a transfer numbered from 1 across the call's
batches.

## gpu_batch_run

2 for its stuck source, whose responses are never read, so a caller tells
it apart from a command the device refused.

## gpu_batch_add

Pending chain p takes descriptors 2p and 2p + 1, and the available ring's
slot at the ring's index plus the pending count; the index itself moves when
the batch runs.

## gpu_wait_batch

The wait wakes on the transport's line. The source's failure is read first
on every pass, and again after the final drain on the completion path, as
virtio.S's virtio_wait_used reads it: the reset in gpu_fault can complete
the batch, and a completion read after the failure must not count. The
external enable is cleared after unless the sound stream is live, whose
line must keep reaching the vector while the program runs (sound.S). Its
callers read the responses with no fence of their own: the drain after
the index moved carries the acquire (aia.S's irq_drain).

## sys_display_text

A cell is the font's size times the scale, the nearest source pixel taken
as a sprite's is; what is under the text stays, and the program flips to
show it.

## text_glyph

Its t registers live across text_pixel, which touches t1 and a7 only.

## display_open

What the display is comes first, then the resource, its backing, the
scanout, and the first frame. Under DEBUG the GPU knobs are read
(present_knobs) before the first frame, the open's present being a present
call of its own.

## msg_gpu_at

`13 u8`: the debug line naming the GPU's transport, under DEBUG only.

## display_present_rect

The transfer's offset is the byte offset of the rectangle's top left in the
framebuffer. Its flush answered OK moves present_ordinal on: the whole flip,
the rectangle flip, the open's first frame, and a print's band alike. Under
DEBUG present_faults numbers the call, and its knobs' faults ride the
frame's slot 0, the transfer's number in the low half, 1 the one this
present sends, and the flush in bit 32; each refused one is sent with a
width past the resource, which QEMU refuses at its bounds check.

## present_knobs

Under DEBUG: the GPU knobs from the bootargs, read once a display_open
before its first frame. `jab.badxfer=<n>` names the present call whose
transfer is refused and `jab.badxferat=<k>` which of its transfers, 1 when
absent; `jab.badflush=<n>` the present call whose flush is refused. A present
call is any display_present_rect or display_present_rects, the open's and a
print's among them.

## knob_badxfer

`13 u8`: the knob naming the present call whose transfer is refused, under
DEBUG only.

## knob_badxferat

`15 u8`: the knob naming which of its transfers.

## knob_badflush

`14 u8`: the knob naming the present call whose flush is refused.

## present_faults

Under DEBUG: the present call counted from boot, and the faults the knobs
name for it.

## gpu_get_display_info

With DEBUG the first mode is reported on the debug channel.

## msg_display

`14 u8`: the debug line on the display's first mode, under DEBUG only.

## msg_enabled

`10 u8`: that line's enabled field.

## gpu_submit

Descriptors 0 and 1 carry it. With DEBUG every command and its answer is
reported on the debug channel.

## msg_gpu_cmd

`14 u8`: the debug line on a command, under DEBUG only.

## msg_gpu_resp

`7 u8`: that line's response field.

## console_write

A newline moves to the next line; a line past the last scrolls the screen
up; other control bytes are skipped, and bytes past ASCII draw as a space.
The dirty band takes in each line's pixel rows, and only that band is
shown.

## gpu_queue

The GPU's control queue record.

## gpu_cmd

`64 u8`: the single command's buffer.

## gpu_resp

`408 u8`: the single command's response.

## gpu_batch_cmds

`2048 u8`: a batch's command buffers, GPU_CMD_BYTES each.

## gpu_batch_resps

`768 u8`: a batch's response buffers, GPU_RESP_BYTES each.

## gpu_base

`addr`: the GPU's transport.

## display_state

`u64`: 1 once open, 3 once its source stuck (aia.S), every call then
answering that the device refuses and jab.sys.print going to the UART.

## console_col

`u64`: the cursor's column.

## console_row

`u64`: the cursor's line.

## present_ordinal

`u64`: the presents the device has answered OK since boot, each a flush's
own answer, in every build.

## present_calls

`u64`: the present calls made since boot, under DEBUG only.

## badxfer_call

`u64`: the present call jab.badxfer names, all ones when absent.

## badxfer_at

`u64`: the transfer of that call jab.badxferat names, 1 when absent.

## badflush_call

`u64`: the present call jab.badflush names, all ones when absent.
