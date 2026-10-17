# main.S

FootprintEstimate's fixtures, the game's third program: the candidate's
arithmetic and the LEVELS capture's transport, each proved before it is
trusted. It includes the game's `render.inc` for `row_derivative`, and
`map.inc` and the SDK's `jab_jobs.inc` beside it for the constants that
file's `.set` lines name. Its test holds each case's answer to the game's
footprint crate, whose `derivative` is the same arithmetic in i128, and
reads the capture back through the crate's `blocks`.

## .set CASES

`u64`: the cases in `cases`.

## .set CASE_SIZE

`u64`: a case's bytes, its coordinate, IZB, UZB, and z, a dword each.

## .set RUNS

`u64`: the runs in `runs`.

## .set RUN_SIZE

`u64`: a run's bytes, its row, start, pixels, level, and span, a word each.

## .set LINE_BYTES

`u64`: the line buffer's bytes, a case's line well under it.

## .set SENTINEL_PIXEL

`u32`: the magenta every DEBUG frame is painted first, LEVELS' sentinel,
level 15.

## _start

The cases first, on the UART while the display is down; then the display
opened, the pattern laid, and one flip, an early answer flipped again at
the next tick, so the capture shows the pattern whole; then the program
waits on the display's tick for the capture's quit.

## cases_run

Each case's line, `footprint: derivative <case> <coord> <izb> <uzb> <z>
<answer>`, its inputs printed so the test feeds them to the exact
arithmetic, the answer the value or `saturated`, the macro's saturate
label. Every number is signed decimal, since the cases reach the most
negative value and the narrowing's largest.

## pattern_draw

The whole framebuffer the sentinel first, then each run's pixels its
code with its offset counting from 0, laid in the table's order so a later
run covers an earlier one's pixels: span 41's four over the start of span
40's block.

## line_signed

The magnitude by unsigned division, so the most negative value, which
`neg` leaves itself, reads as 2^63 behind its minus.

## cases

`CASES 4 i64`: each case's coordinate in 16.16, IZB in 6.26, UZB in 48.16,
and z in 16.16, in the test's order of purposes: an ordinary floor's;
both products past 64 bits with each shift fitting, (3 2^40)(5 2^30) and
(49 2^44)(2^20); the first product past 64 bits once shifted; the
second's; the subtraction overflowing; the most negative value; a
negative derivative; the clamp's, IZB zero; a negative product floored,
-3 by 2^25 shifted to -2; a span's own numbers; the largest the narrowing
keeps, (2^47 - 1) 2^32 shifted to 2^63 - 2^16; and one past it, 2^63.

## runs

`RUNS 5 u32`: each run's row, first pixel, pixels, level, and span: span
300's three blocks, two of one level beside each other and a third of
another, a span past index 255; span 7's full block and a short last one;
span 40's block, its first four pixels covered by span 41's; span 9's run
inside the stamp's cells, which the reader skips, and span 10's half under
them; span 65535 at level 9 on the last row's last pixels, the largest
index and level a code carries.

## word_derivative

`23 u8`.

## word_saturated

`10 u8`.

## line

`LINE_BYTES u8`: the line in hand, terminated.

## lineptr

`addr`: the line's next byte.
