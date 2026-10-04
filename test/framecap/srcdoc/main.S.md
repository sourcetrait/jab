# main.S

framecap: the frame cap. Sixty-four flips in a row with no waiting:
the first goes through and the rest come too early, which the kernel
refuses without showing them. Then sixty-four frames the proper way,
await then flip, half of them whole and half a rectangle, which take
sixty-four periods of the cap while the hart halts between them.
Then a rectangle reaching past the screen's edge, which the kernel
must refuse; then a list of two rectangles as one flip, a list with
one past the edge, and a list of none; then what the kernel was built
with. Reports on the UART.

## .set FLIPS

`u64`: the flips in each run, sixty-four.

## _start

The lines in order: `refused=NN`, the flips refused of the first run; then
thirty-two whole frames, awaited, and thirty-two rectangles, awaited, which
print nothing unless one fails; then a rectangle past the right edge,
`badrect=NN`; then a list of two rectangles as one flip, a list holding one
past the edge, and a list of none, `rects=NN badrects=NN norects=NN` a line
each; then what the kernel was built with, `flags=NN`; then `paced`. Each
number is two digits.

## refused

`8 u8`: the refused flips' line, its digits following.

## refused_digits

`4 u8`: the refused flips' count, a newline, and the terminator.

## badrect

`8 u8`: the bad rectangle's line, its digits following.

## badrect_digits

`4 u8`: the bad rectangle's code, a newline, and the terminator.

## rects

`6 u8`: the list's line, its digits following.

## rects_digits

`4 u8`: the list's code, a newline, and the terminator.

## badrects

`9 u8`: the bad list's line, its digits following.

## badrects_digits

`4 u8`: the bad list's code, a newline, and the terminator.

## norects

`8 u8`: the empty list's line, its digits following.

## norects_digits

`4 u8`: the empty list's code, a newline, and the terminator.

## flags

`6 u8`: the kernel flags' line, its digits following.

## flags_digits

`4 u8`: the kernel's flags, a newline, and the terminator.

## two_rects

`8 u32`: two rectangles apart on the screen.

## bad_rects

`8 u32`: two rectangles, the second reaching past the bottom.

## paced

`7 u8`: the last line, once every check has run.

## msg_no_display

`22 u8`: the line for a machine with no display.

## msg_flip_failed

`37 u8`: the line for a flip after await that failed.
