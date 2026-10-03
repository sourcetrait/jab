# kernel.S

Supervisor-mode entry. Zeroes bss, turns on paging, starts the frame clock,
installs the trap vector, and enters the program at JAB_PROGRAM_BASE in user
mode with its stack at JAB_STACK_TOP and every other register cleared. The
display comes up when the program asks for it. The ports come up before the
program, the API when the run put its port on the machine (serial.S). The
UART carries only the program's output and the fault lines; with DEBUG set
at assembly (`--set debug`) the kernel's own lines go to its debug channel,
a port of the same device.

## kmain

The kernel reads and writes program memory (a message to print, the
framebuffer), so SUM. The machine is RVA23, so the program has floating
point and vectors; their state starts Initial, since Off makes the first
such instruction an illegal instruction. The program may read every
counter the hart has and run the cache-block operations, cbo.inval as a
flush (riscv.inc), which boot.S opened below machine mode.

The ports come up before the program starts: the API when the run put its
port on the machine, and under DEBUG the debug channel, first, so the banner
and everything after it go there. sscratch holds the kernel stack top while
the program runs.

## kernel_flags

Built from the symbols the assembler was given, JAB_KERNEL_* each, so a
program reads at run time what it could also .ifdef at build.
