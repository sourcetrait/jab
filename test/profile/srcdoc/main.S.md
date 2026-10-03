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

## line_begin

The line: begun empty, strings and signed decimals appended, ended with a
newline and sent to the UART.
