# main.S

pad: the kernel's pad driver under test. Prints the pad's name as
the device reports it, its own range for X, GAS, and HAT0X and for
an axis this pad lacks, then reports
every pad event as `pad <type> <code> <value>` and, after each, the
state as `state <keys> <x> <y> <hat0x> <gas>`, the keys as a mask and
the axes normalised, until BTN_SOUTH is released. With no pad on the
machine it says so and exits.

## print_axis

One line, `axis <code> <min> <max> <fuzz> <flat> <res>`, or
`axis <code> none`. The call goes by hand since the code sits in a register.

## line_begin

The line: begun empty, strings and signed decimals appended, ended with a
newline and sent to the UART.
