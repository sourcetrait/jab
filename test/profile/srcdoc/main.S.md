# main.S

profile: the RVA23 user profile's instructions that need the kernel's
leave, run from a program. cbo.zero on an address 8 bytes into the first of
two filled blocks clears that whole 64-byte block and leaves the second as
it was; cbo.clean, cbo.flush, and cbo.inval on the second keep its bytes,
cbo.inval running as a flush; time, cycle, and instret are read on either
side of a spin and rise; hpmcounter3 and hpmcounter18, the first and the
last of the sixteen performance counters QEMU implements by default, read.
A line for each step goes to the UART for the test to hold. On a kernel
that leaves any of them disabled the instruction is illegal and the program
faults.

## .set BLOCK_BYTES

`u64`: a cache block, 64 bytes under RVA23.

## .set FILL

`u8`: the byte both blocks are filled with first.

## .set SPIN

`u64`: the spin between the counters' two readings.

## .set LINE_BYTES

`u64`: room for a line.

## .set DIGITS_BYTES

`u64`: room for a decimal's digits.

## line_begin

The line: begun empty, strings and signed decimals appended, ended with a
newline and sent to the UART.

## blocks

`128 u8`: two cache blocks, aligned to one.

## line_len

`u64`: the line's length so far.

## line

`160 u8`: the line being built.

## digits

`24 u8`: line_int's digits, built backward.

## msg_zero

`6 u8`: the zero line's first word.

## msg_untouched

`12 u8`: before the count of the next block's bytes still filled.

## msg_kept

`6 u8`: the line of the bytes kept through clean, flush, and inval.

## msg_rising

`8 u8`: the line of whether each counter rose, 1 or 0.

## msg_space

`2 u8`: between two numbers.

## msg_hpm3

`6 u8`: the performance counters' line.

## msg_hpm18

`8 u8`: before hpmcounter18's reading.
