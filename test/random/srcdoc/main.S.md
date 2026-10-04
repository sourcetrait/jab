# main.S

random: the kernel's entropy call under test. Asks jab.sys.random for 64
bytes twice, into two buffers, and prints each answer as `bytes
<given>` and then the bytes in decimal on one line, so the test can
see that they came, that the two draws differ, and that they look
like entropy. A machine with no rng device says so and exits 2.

## .set BYTES

`u64`: the bytes asked for in each draw.

## .set LINE_BYTES

`u64`: room for a line.

## .set DIGITS_BYTES

`u64`: room for a decimal's digits.

## line_begin

The line: begun empty, strings and signed decimals appended, ended with a
newline and sent to the UART.

## line_len

`u64`: the line's length so far.

## line

`320 u8`: the line being built.

## digits

`24 u8`: line_int's digits, built backward.

## first

`64 u8`: the first draw.

## second

`64 u8`: the second draw.

## msg_no_rng

`16 u8`: the line for a machine with no rng device.

## msg_bytes

`7 u8`: the count line's first word.

## msg_space

`2 u8`: the space after each byte.
