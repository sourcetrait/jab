# main.S

FootprintEstimate's fixtures, the game's third program: the candidate's
arithmetic, each case's answer on the UART. It includes the game's
`render.inc` for `row_derivative`, and `map.inc` and the SDK's
`jab_jobs.inc` beside it for the constants that file's `.set` lines
name. Its test holds each case's answer to the game's footprint crate,
whose `derivative` is the same arithmetic in i128.

## .set CASES

`u64`: the cases in `cases`.

## .set CASE_SIZE

`u64`: a case's bytes, its coordinate, IZB, UZB, and z, a dword each.

## .set LINE_BYTES

`u64`: the line buffer's bytes, a case's line well under it.

## _start

The cases on the UART, then exit 0, the status the test holds.

## cases_run

Each case's line, `footprint: derivative <case> <coord> <izb> <uzb> <z>
<answer>`, its inputs printed so the test feeds them to the exact
arithmetic, the answer the value or `saturated`, the macro's saturate
label. Every number is signed decimal, since the cases reach the most
negative value and the narrowing's largest.

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

## word_derivative

`23 u8`.

## word_saturated

`10 u8`.

## line

`LINE_BYTES u8`: the line in hand, terminated.

## lineptr

`addr`: the line's next byte.
