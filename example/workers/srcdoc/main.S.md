# main.S

workers: the Mandelbrot set computed by the worker harts at 1080p, hart 0
the coordinator. A frame is 135 bands of eight rows, dealt in turn to the
frame's workers through jab_jobs.inc's mailboxes: worker k takes band k,
then every W-th band after it, W the frame's workers. Every online
secondary up to MAX_WORKERS runs a worker, frame_worker, on a mailbox and a
stack of its own; worker k is the k-th online secondary, so on four harts
the workers are harts 1, 2, and 3. Each worker records the rows it
computed, and each row's owner is drawn as a bar at the left edge in its
hart's colour, with the frame's time as text above the set.

A letter over the API in the first two seconds picks what runs. p is the
proof: the fixed frame for one worker, then two, then three, each hashed
before its bars and text, so the three hashes agree when the work is
right whatever the workers, and three of the last frame's rows sent for the
host to compute again. 1 to 3 is the bench: the fixed frame over and over
for four seconds by that many workers. Anything else, or no API port on the
machine, is the animation, which runs on its own: the workers by the clock,
five seconds each of one, two, and three, and the zoom by the clock into
the seahorse valley, over and over in a 32-second cycle.

The arithmetic is fixed point, Q.28 in 64-bit registers: a value v stands
for v / 2^28. A product of two values is shifted right 28 with `srai`, which
floors; twice x y is the product shifted right 27. A point escapes once
x squared plus y squared passes 4, coloured by its iteration count mod 16;
one still in after CAP iterations is in the set and black. Before each
escape check z's parts are under 6.25 in magnitude, 4 from the last square
plus the widest view's c, so every product stays under 2^62.

## .set FIX

`u64`: the fixed point's fraction bits.

## .set ESCAPE

`i64`: 4 in Q.28, the bound on x squared plus y squared.

## .set CAP

`u64`: the iterations at most; a point still in after them is in the set.

## .set BAND_ROWS
## .set BANDS

`u64`: a band's rows and a frame's bands.

## .set BAR_WIDTH

`u64`: the bars' width in pixels at the left edge.

## .set MAX_WORKERS

`u64`: the workers at most, one a secondary of the four-hart machine.

## .set STACK_BYTES

`u64`: a worker's stack, 16 KiB.

## .set SELECT_WAIT

`u64`: how long the program waits for a letter with the API's port on the
machine, two seconds of the time counter.

## .set PHASE_TICKS

`u64`: how long the animation keeps each count of workers, five seconds.

## .set SLOTS
## .set SLOT_TICKS
## .set ZOOM_NUM

`u64`: the zoom's steps, a quarter second each, a cycle of 32 seconds, each
step ZOOM_NUM/256 of the one before: from 419430 to 550, a view three units
wide to one 0.0039 wide.

## .set ZOOM_CX
## .set ZOOM_CY

`i64`: the zoom's centre in Q.28, about (-0.7436439, 0.1318259), in the
seahorse valley.

## .set PROOF_CX
## .set PROOF_CY

`i64`: the fixed frame's centre, (-0.5, 0), the proof's and the bench's.

## .set STEP0

`i64`: a pixel's width at the widest view, 3/1920 in Q.28, the set whole
across the screen.

## .set BENCH_TICKS

`u64`: the bench's stretch, four seconds.

## .set SAMPLES

`u64`: the rows the proof sends, sample_rows'.

## .set PARAM_LEFT
## .set PARAM_TOP
## .set PARAM_STEP

`i64`: the frame's parameters in params: c at the top left pixel and a
pixel's width.

## .set PARAM_WORKERS

`u64`: the frame's workers, in params.

## .set ARG_INDEX

`u64`: a job's own word in its JAB_JOB_ARGS: its worker's index among the
frame's workers.

## .set OWN_ROWS
## .set OWN_TOTAL

`u64`: the worker's own words in its JAB_JOB_OWN: its rows of the last frame
and of every frame.

## .set BOX_WIDTH
## .set BOX_HEIGHT

`u64`: the caption's black box, right of the bars at the top.

## .set TEXT_X
## .set TEXT_Y
## .set TEXT_SCALE

`u64`: the caption's place inside the box, and its scale, twice the font's
size.

## .set TEXT_COLOR

`u32`: the caption's colour, white.

## .set TICKS_PER_MS

`u64`: the time counter's ticks a millisecond.

## _start

A write of no bytes tells whether the API's port is on the machine, 0 with
it and 1 without, so `just run` with no `--api` animates at once.

## proof

Each frame is rendered into the framebuffer and copied whole into image,
inside the program's window, since a kernel call reads the window alone:
the hash and the rows sent are the copy's. The owners are cleared first, so
a row no worker wrote reads 0xff and is not counted; a worker past the
frame's count shows 0 rows. The counts summing to the frame with every row
owned means each row has one owner, so duplicated work cannot pass.

## bench

The frames are counted to the first one ending past BENCH_TICKS, and the
stretch's own time is printed. The hash is the last frame's, the rows each
worker's over every frame.

## render

The parameters are written before the publishes, whose fence orders them
before each generation; a worker reads them after its await.

## mandel_row

On a page of its own (`.balign 4096`), so QEMU's translator chains its loop
within one page, which `jab hot` checks; it makes no kernel call. c's x
advances a step a pixel from the row's first.

## frame_worker

A worker's loop: await a job, read its index and the frame's workers, then
its bands, a row at a time through mandel_row, each row's owner its hart
id, each band's start and end on the time counter. Its rows go into its own
words, then the completion and a wake of hart 0, which is joining.

## palette

`16 u32`: the escape colours, 0x00RRGGBB, by the iteration count mod 16, a
gradient from dark brown through blues and white to orange.

## bar_colors

`8 u32`: a bar's colour by its row's owner: red, green, and blue for harts 1
to 3, white for a row with none (0xff's low three bits).

## sample_rows

`SAMPLES u64`: the rows the proof sends, the middle one on the real axis.

## word_no_display
## word_no_workers
## word_refused
## word_too_few
## word_proof
## word_hash
## word_rows
## word_owned
## word_space
## word_sent
## word_sent_tail
## word_bench
## word_frames
## word_ms_field
## word_worker
## word_workers
## word_ms

`u8`: the lines' and the caption's words.

## mailboxes

`MAX_WORKERS * JAB_JOB_BYTES u8`: a mailbox a worker, on a 64-byte boundary.

## params

`64 u8`: the frame's parameters, PARAM_LEFT to PARAM_WORKERS, a line of
their own, written by hart 0 before a frame's publishes.

## worker_hart

`MAX_WORKERS u64`: each worker's hart.

## workers_n

`u64`: the workers.

## selector

`8 u8`: the letter.

## zoom_steps

`SLOTS i64`: the zoom's steps.

## band_times

`BANDS * 2 u64`: each band's start and end on the time counter, the last
frame's.

## owners

`JAB_DISPLAY_HEIGHT u8`: each row's owner, the hart that computed it in the
last frame, 0xff for none.

## line

`160 u8`: the line being built.

## caption

`64 u8`: the caption being built.

## digits

`32 u8`: put_dec's digits, built backward.

## stacks

`MAX_WORKERS * STACK_BYTES u8`: the workers' stacks.

## image

`JAB_DISPLAY_SIZE u8`: a frame copied into the window for the hash and the
API.
