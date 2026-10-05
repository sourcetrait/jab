# kernel.S

Supervisor-mode entry on hart 0, bss already cleared and the device tree
read in machine mode (boot.S). Builds the page tables and turns on paging,
starts the frame clock, installs the trap vector, releases the secondary
harts (harts.S), and enters the program at JAB_PROGRAM_BASE in user mode
with its stack at JAB_STACK_TOP and every other register cleared. The
display comes up when the program asks for it. The ports come up before the
program, the API when the run put its port on the machine (serial.S). The
UART carries only the program's output and the fault lines; with DEBUG set
at assembly (`--set debug`) the kernel's own lines go to its debug channel,
a port of the same device.

## kmain

tp holds the hart's record from the start, worked out from the hart id
machine mode hands over, never from a program, and sscratch is 0 while the
kernel runs (trap.S). The tables are built here, once, and every hart turns
its own paging on with them (page.S). The kernel reads and writes program
memory (a message to print, the framebuffer), so SUM. The machine is RVA23,
so the program has floating point and vectors; their state starts Initial,
since Off makes the first such instruction an illegal instruction. The
program may read every counter the hart has and run the cache-block
operations, cbo.inval as a flush (riscv.inc), which boot.S opened below
machine mode.

Hart 0 writes its id and its canary (harts.S's hart_self_check) and is
online. The supervisor APLIC domain and hart 0's interrupt file are set up
before any device's interrupt is let through (aia.S's aia_supervisor). The
ports come up before the secondaries are released, whose check-in hart 0
waits for on the drain (harts.S's harts_release), and before the program
starts: the API when the run put its port on the machine, and under DEBUG
the debug channel, first, so the banner and everything after it go there,
the serial device's transport right after the banner (serial.S's
serial_report), every hart's line after the release (harts.S's
harts_report). sscratch holds the hart's record while the program runs.

## msg_banner

`29 u8`: the banner on the debug channel, under DEBUG only.

## .set KERNEL_FLAG_DEBUG

`u32`: the flag JAB_KERNEL_DEBUG when assembled with DEBUG, else 0.

## kernel_flags

`u32`: the mask of what the kernel was built with.

Built from the symbols the assembler was given, JAB_KERNEL_* each, so a
program reads at run time what it could also .ifdef at build.
