# main.S

random: the kernel's entropy call under test. Asks jab.sys.random for 64
bytes twice, into two buffers, and prints each answer as `bytes
<given>` and then the bytes in decimal on one line, so the test can
see that they came, that the two draws differ, and that they look
like entropy. A machine with no rng device says so and exits 2.

## line_begin

The line: begun empty, strings and signed decimals appended, ended with a
newline and sent to the UART.
