# boot.S

Machine-mode entry. QEMU starts every hart here, at the start of RAM, with
-bios none -kernel, a0 its hart id and a1 the device tree. Hart 0 opens
memory, delegates traps, hands the timer to supervisor mode, clears bss,
reads the tree, and drops to supervisor mode in kmain; every other hart
parks. Nothing in supervisor mode returns to machine mode.

## _start

Physical memory protection is one entry over everything. Traps go to
supervisor mode; what still lands in machine mode stops at mtrap. The
supervisor timer is stimecmp (Sstc). menvcfg also lets the modes below run
the cache-block operations, cbo.inval as a flush (riscv.inc), and
mstateen0 lets supervisor mode reach senvcfg, where kmain opens the same
operations to the program: the RVA23 CPU carries Smstateen, under which
senvcfg is an illegal instruction in supervisor mode until machine mode
allows it. Every counter the hart has is readable below machine mode.

The bss is cleared here, before anything writes it, since the tree's
reading keeps what it finds there; nothing has been pushed on the stack
yet, which lies in bss. The tree is read with paging off at the address
QEMU handed over (harts.S's harts_topology), then the mret enters kmain as
supervisor with the hart id in a0.

## mtrap

A trap machine mode keeps, which the bootstrap's reads can take, prints its
cause, epc, and tval on the UART and halts, rather than spinning silently.

## msg_machine_trap

`26 u8`: the machine trap's line's head.

## msg_mepc
## msg_mtval

`u8`: the machine trap's line's fields.
