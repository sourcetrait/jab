# harts.S

The machine's harts as the device tree describes them, read once in
machine mode before anything runs, and the call that reports them. QEMU's
reset vector hands every hart the tree in a1, and the tree sits at the top
of RAM, in the program's window under its stack, so the kernel copies what
it needs into bss and never reads the tree again.

## .set HARTS_PROBLEMS

`u64`: the topology problems kept to name, past which they are counted.

## .set HARTS_PROBLEM_BYTES

`u64`: a kept problem, its kind and its id, two u64.

## .set PROBLEM_CELLS
## .set PROBLEM_REG
## .set PROBLEM_PAST_MAX
## .set PROBLEM_NO_BOOT

`u64`: the topology problems: /cpus's #address-cells neither 1 nor 2, so no
cpu's reg can be read; a cpu with no reg its cells can read; a cpu whose id
is at or past JAB_HARTS_MAX, the id kept; the boot hart, 0, not in the tree.

## .set BOOT_ARGS_BYTES

`u64`: the most of /chosen's bootargs kept, its NUL among them.

## harts_topology

The platform check's two classes. A tree dtb_check refuses, or a timebase
other than QEMU_VIRT_TIMEBASE, ends the run with its line on the UART and
status 1, since hart 0 alone repairs neither and the frame clock counts in
that timebase. A usable cpu's timebase is its own timebase-frequency, else
/cpus's, as the device tree specification has a client read it, in one
cell or two, the high cell first; absent, or of another length, it counts
0, and with no usable cpu /cpus's own is held to it, as is a tree with no
/cpus. A topology problem keeps the kernel on its boot hart: it is kept to
name on the debug channel, and every hart the tree lists but the boot hart
is failed, so jab.sys.harts says so.

A cpu is every child of /cpus whose device_type is "cpu" and whose status
is absent or "okay"; a disabled one is passed over, which is no problem.
Its id is its reg in #address-cells cells; its interrupt controller is its
child named interrupt-controller, whose phandle is kept by the id for the
AIA's interrupts-extended, 0 for a cpu with none. Under DEBUG, /chosen's
bootargs, QEMU's -append, are copied for the knobs a debug build reads.

## harts_report

Under DEBUG, after the debug channel is open: the three masks, each kept
problem, and the bootargs when there are any.

## sys_harts

The masks as kept: hart 0 online from the bootstrap on, a secondary listed
and neither online nor failed parked.

## path_cpus

`6 u8`: the node of the harts.

## word_timebase
## word_address_cells
## word_device_type
## word_cpu
## word_status
## word_okay
## word_reg
## word_intc
## word_phandle

`u8`: the properties, the values, and the node name harts_topology reads by.

## msg_tree_refused

`32 u8`: the fault line's head for a tree dtb_check refuses, the code after
it.

## msg_timer

`44 u8`: the fault line's head for a timebase not QEMU_VIRT_TIMEBASE, the
tree's after it in hertz.

## msg_harts
## msg_online
## msg_failed
## msg_cells
## msg_reg
## msg_hart
## msg_past_max
## msg_no_boot
## msg_bootargs

`u8`: harts_report's lines, under DEBUG only.

## path_chosen
## word_bootargs

`u8`: under DEBUG only, where the bootargs are.

## harts_discovered

`u64`: bit n set for hart n the tree lists, n under JAB_HARTS_MAX.

## harts_online

`u64`: bit n set for hart n running the kernel or a program, hart 0 once
the tree is read.

## harts_failed

`u64`: bit n set for hart n that failed, every listed hart but 0 under a
topology problem.

## harts_intc

`JAB_HARTS_MAX u32`: each hart's interrupt controller's phandle by id, 0
where it has none.

## harts_problem_count

`u64`: the topology problems met, kept or not.

## harts_problems

`HARTS_PROBLEMS * HARTS_PROBLEM_BYTES u8`: the problems kept, each its kind
and its id.

## boot_args

`BOOT_ARGS_BYTES u8`: under DEBUG, /chosen's bootargs, NUL-terminated,
empty when the tree has none.
