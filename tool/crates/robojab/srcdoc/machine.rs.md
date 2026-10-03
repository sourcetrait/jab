# machine.rs

## const O_NONBLOCK

## struct Tail

### fn new

### fn bytes

### fn lines

## struct Machine

### fn start

The binary is the plan's `qemu_binary`, never the name on this process's
PATH: the SDK chose it and checked its CPU model, and a run on another QEMU
is the mistake its `extern/qemu` lookup exists to prevent. The files a
previous run left, the API's and the debug channel's, are emptied so the
tails start at nothing.

### fn wait_up

A QEMU that ends before its pid file appears is reported with what it wrote
to `robojab.stderr`, the only account of a line QEMU refused.

### fn elapsed

### fn alive

124 is `timeout`'s own code for a run the bound ended.

### fn exit_code

### fn monitor

A blocking open of the monitor's fifo with QEMU gone would wait for a reader
forever; `O_NONBLOCK` makes the open fail instead, and the command reports.

### fn api_send

### fn api_recv

### fn has_api

### fn poll

A fault is any UART line starting `jab: `, kept for good once seen, so a
frame long after it still carries it.

### fn serial

### fn debug

### fn screendump

QEMU writes the PPM over time, so the file is taken once its size holds
across two looks 50 ms apart, ten seconds at most.

### fn quit

Three seconds after the monitor's quit, TERM to the pid in the pid file,
QEMU itself where the child is the `timeout` around it, three seconds more,
then the child killed, reported as -9.

### fn resolve

The routine is the greatest text symbol at or below the epc, read with the
`nm` of the prefix given, the toolchain the program was built with; none
without an ELF or an epc.
