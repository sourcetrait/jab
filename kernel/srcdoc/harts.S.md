# harts.S

The machine's harts: read once from the device tree in machine mode before
anything runs, then, from kmain, each secondary released out of its park
(boot.S's hart_park) into its own supervisor setup on its own stack, its
check-in waited for, and every outcome kept in its record, which the call
reports. QEMU's reset vector hands every hart the tree in a1, and the tree
sits at the top of RAM, in the program's window under its stack, so the
kernel copies what it needs into bss and never reads the tree again.

A hart's area in hart_areas is its 16 KiB kernel stack with its record on
top (hart.inc): sscratch holds the record while the hart's program runs,
tp while its kernel does. Its state there moves from parked to released,
then by compare and swap to online, by the hart, or to failed, by hart 0 at
the check-in's bound or by the hart when its self-check fails; one of the
two wins, and failed is final for the run. The hart writes its own id,
result, and canary; hart 0 writes its reason for a failure, so each field
has one writer.

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

## .set STRAY_FILE

`u64`: under DEBUG, the address jab.stray's store faults at: a megabyte
into the supervisor files' 2 MiB, mapped, past any file of up to 256 harts,
so nothing decodes it.

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
is refused (harts_refused), never released, so jab.sys.harts says failed.

A cpu is every child of /cpus whose device_type is "cpu" and whose status
is absent or "okay"; a disabled one is passed over, which is no problem.
Its id is its reg in #address-cells cells; its interrupt controller is its
child named interrupt-controller, whose phandle is kept by the id for the
AIA's interrupts-extended, 0 for a cpu with none. Under DEBUG, /chosen's
bootargs, QEMU's -append, are copied for the knobs a debug build reads.

## hart_self_check

The canary, HART_CANARY xored with the hart's id so one hart's never reads
as another's, sits in its stack's lowest word, where a stack grown past its
16 KiB lands first.

## hart_swap

lr with acquire and release, sc with release: the hart's own writes before
the swap are out before another hart sees the state change.

## harts_masks

Plain reads of each discovered hart's state, which its swap published; a
discovered hart is always in one of the masks or released, never left
between.

## harts_release

Hart 0, after serial_open, each discovered hart in turn. One the tree's
problem refused, or one with no supervisor file in the tree, is failed and
never released. Every other is released: its state RELEASED, then `fence
w, w`, so a hart that finds its slot, woken by the release or by nothing,
finds its state RELEASED too, then its slot in hart_release, its record's
address, then `fence w, o`, so both are out before the device sees the
wake, then the wake's identity written into its supervisor file. A tree can name a hart the machine lacks, whose file
address nothing decodes: the store then raises a store access fault, which
kernel_trap steps over for that store at that address alone, and the hart
is failed with no file, unless it checked in meanwhile.

The check-in is waited for on the drain with the timer armed at the bound,
HART_CHECKIN_TICKS after the last release, a secondary's wake ending the
wait early; a hart still released at the bound is failed by the swap, its
reason written once the swap is won. The timer and the external interrupt
are put back off after. Under DEBUG, a jab.stray knob of 1 then stores at
STRAY_FILE, the release store's cause at another instruction and address,
which kernel_trap must not step over.

## hart_main

A secondary's supervisor setup is hart 0's own in kmain: stvec, SUM,
floating point and vectors Initial, sie clear, stimecmp at its maximum,
every counter readable, the cache-block operations, sscratch 0, and tp its
record, worked out from the id machine mode hands over. Its interrupt file
stays open from the park. Its self-check, then its swap: from released to
online, or to failed when the self-check broke, hart 0 woken either way
(workers.S's hart_wake, after `fence w, o`, so the hart's record is out
before hart 0 reads it). An online hart goes to its kernel idle,
workers.S's hart_idle, until a start. A hart whose swap lost, hart 0
having failed it first, parks for the run with sie and sstatus.SIE clear in
a wfi loop, touching nothing, and since mie then holds no bit, nothing
wakes it.

Under DEBUG a jab.late knob naming the hart holds it before its swap until
its state reads failed, so the losing swap runs every time.

## harts_report

Under DEBUG, after the release: the three masks, each kept problem, the
bootargs when there are any, then every discovered hart's line, online or
failed with its reason. An online hart's id, result, and canary are read
back from its record and its stack by hart 0, after its state and a `fence
r, r`, so what its swap published is what is read, and hart 0 says so
when any reads wrong. A failed hart with no reason of hart 0's failed its own self-check.

## knob_value

A knob is a token of /chosen's bootargs, its name, an '=', and digits,
read by a debug kernel alone; a token that only begins with the name, or a
value with more than digits, is none.

## sys_harts

The discovered mask as the tree gave it, and the online and failed read
from the records at the call, so a hart's state as it stands.

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

## hart_wake_store

`addr`: the release's wake store's own address, which kernel_trap matches
sepc against; a data word rather than a label, so the store stays inside
harts_release.

## knob_stray
## knob_late

`u8`: under DEBUG only, the knobs harts_release and hart_main read.

## msg_harts
## msg_online
## msg_failed
## msg_cells
## msg_reg
## msg_hart
## msg_past_max
## msg_no_boot
## msg_bootargs
## msg_hart_online
## msg_hart_overwritten
## msg_hart_topology
## msg_hart_no_file
## msg_hart_no_checkin
## msg_hart_self_check
## msg_hart_unsettled

`u8`: harts_report's lines, under DEBUG only.

## path_chosen
## word_bootargs

`u8`: under DEBUG only, where the bootargs are.

## hart_release

`JAB_HARTS_MAX addr`: each hart's release slot, by id, 0 until hart 0
writes the hart's record there. In .data, which the bss clear leaves alone.

## harts_discovered

`u64`: bit n set for hart n the tree lists, n under JAB_HARTS_MAX.

## harts_refused

`u64`: bit n set for hart n the tree lists that a topology problem keeps
parked, every listed hart but 0.

## harts_intc

`JAB_HARTS_MAX u32`: each hart's interrupt controller's phandle by id, 0
where it has none.

## harts_problem_count

`u64`: the topology problems met, kept or not.

## harts_problems

`HARTS_PROBLEMS * HARTS_PROBLEM_BYTES u8`: the problems kept, each its kind
and its id.

## hart_wake_target

`addr`: the file address the release's wake store is writing, which
kernel_trap matches stval against.

## hart_wake_faulted

`u64`: 1 once kernel_trap has stepped over the release's wake store.

## boot_args

`BOOT_ARGS_BYTES u8`: under DEBUG, /chosen's bootargs, NUL-terminated,
empty when the tree has none.

## hart_areas

`JAB_HARTS_MAX * HART_AREA_BYTES u8`: each hart's kernel stack with its
record on top, by id.
