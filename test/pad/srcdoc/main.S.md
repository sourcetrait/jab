# main.S

pad: the kernel's pad driver under test. Prints the pad's name as
the device reports it, its own range for X, GAS, and HAT0X and for
an axis this pad lacks, then reports
every pad event as `pad <type> <code> <value>` and, after each, the
state as `state <keys> <x> <y> <hat0x> <gas>`, the keys as a mask and
the axes normalised, until BTN_SOUTH is released. With no pad on the
machine it says so and exits.

## .set LINE_BYTES

`u64`: room for a line.

## .set DIGITS_BYTES

`u64`: room for a decimal's digits.

## print_axis

One line, `axis <code> <min> <max> <fuzz> <flat> <res>`, or
`axis <code> none`. The call goes by hand since the code sits in a register.

## line_begin

The line: begun empty, strings and signed decimals appended, ended with a
newline and sent to the UART.

## line_len

`u64`: the line's length so far.

## line

`160 u8`: the line being built.

## digits

`24 u8`: line_int's digits, built backward.

## axis_record

`5 i32`: an axis's range as jab.sys.pad.axis wrote it.

## state_record

`132 u8`: the pad's state as jab.sys.pad.read wrote it.

## name_buffer

`128 u8`: the pad's name.

## quit

`bool`: set once BTN_SOUTH is released.

## msg_ready

`12 u8`: the first line.

## msg_no_pad

`13 u8`: the line for a machine with no pad.

## msg_name

`6 u8`: the name line's first word.

## msg_axis

`6 u8`: an axis line's first word.

## msg_none

`6 u8`: an axis line's end when the pad has no such axis.

## msg_pad

`5 u8`: an event line's first word.

## msg_state

`7 u8`: a state line's first word.

## msg_space

`2 u8`: a space.
