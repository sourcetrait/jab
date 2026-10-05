# boot.S

Machine-mode entry. QEMU starts every hart here, at the start of RAM, with
-bios none -kernel, a0 its hart id and a1 the device tree. Every hart sets
up machine mode; hart 0 then clears bss, reads the tree, and drops to
supervisor mode in kmain, and every other hart parks until kmain releases
it (harts.S). Nothing in supervisor mode returns to machine mode.

## _start

Every hart's machine setup comes first, so a hart released later finds its
own done. Physical memory protection is one entry over everything. Traps go
to supervisor mode; what still lands in machine mode stops at mtrap. mie
holds the supervisor external interrupt alone, which a parked hart's wfi
wakes on. The supervisor timer is stimecmp (Sstc). menvcfg also lets the
modes below run the cache-block operations, cbo.inval as a flush
(riscv.inc), and mstateen0 lets supervisor mode reach senvcfg, where kmain
opens the same operations to the program: the RVA23 CPU carries Smstateen,
under which senvcfg is an illegal instruction in supervisor mode until
machine mode allows it, and the same register lets supervisor mode reach the
interrupt file's CSRs, siselect, sireg, and stopei (riscv.inc). Every
counter the hart has is readable below machine mode.

Hart 0's stack is the top of its area in hart_areas, under its record
(harts.S). The bss is cleared before anything writes it, since the tree's
reading keeps what it finds there; nothing has been pushed on the stack
yet, which lies in bss. The tree is read with paging off at the address
QEMU handed over, the harts first (harts.S's harts_topology), then the
interrupt platform (aia.S's aia_topology), and the root APLIC domain is set
up from it (aia_root); then the mret enters kmain as supervisor with the
hart id in a0.

## hart_park

A secondary waits here, in machine mode on no stack, until hart 0 releases
it. It opens its own supervisor interrupt file for the wake's identity
(aia.S's aia_file_open), which machine mode reaches through siselect and
sireg, then sleeps: wfi wakes on the pending supervisor external interrupt
whatever the privilege. A wake is claimed through stopei, read and cleared
in one instruction, and the release slot is read after a fence, so the slot
hart 0 wrote before its wake is seen; a wake with an empty slot was
spurious, and the hart sleeps again. The slots live in .data, which nothing
clears, so a stale zero never reads as a release and no secondary write
races the bss clear. Released, the slot holds the hart's record, the top of
its stack: its paging goes on with hart 0's tables (page.S's
page_activate), and the mret enters hart_main as supervisor with its hart
id in a0. A hart at or past JAB_HARTS_MAX has no slot and parks for good,
its mie cleared.

## mtrap

A trap machine mode keeps, which the bootstrap's reads or a parked hart can
take, prints its cause, epc, and tval on the UART under the line lock
(uart.S) and ends the run with status 1, rather than spinning silently or
leaving the other harts running.

## msg_machine_trap

`26 u8`: the machine trap's line's head.

## msg_mepc
## msg_mtval

`u8`: the machine trap's line's fields.
