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

## _start

The lines in order: `refused=NN`, the flips refused of the first run; then
thirty-two whole frames, awaited, and thirty-two rectangles, awaited, which
print nothing unless one fails; then a rectangle past the right edge,
`badrect=NN`; then a list of two rectangles as one flip, a list holding one
past the edge, and a list of none, `rects=NN badrects=NN norects=NN` a line
each; then what the kernel was built with, `flags=NN`; then `paced`. Each
number is two digits.
