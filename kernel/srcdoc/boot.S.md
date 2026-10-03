# boot.S

Machine-mode entry. QEMU starts every hart here, at the start of RAM, with
-bios none -kernel. Hart 0 opens memory, delegates traps, hands the timer to
supervisor mode, and drops to supervisor mode in kmain; every other hart
parks.

## _start

Physical memory protection is one entry over everything. Traps go to
supervisor mode; what still lands in machine mode stops at mtrap. The
supervisor timer is stimecmp (Sstc). menvcfg also lets the modes below run
the cache-block operations, cbo.inval as a flush (riscv.inc), and
mstateen0 lets supervisor mode reach senvcfg, where kmain opens the same
operations to the program: the RVA23 CPU carries Smstateen, under which
senvcfg is an illegal instruction in supervisor mode until machine mode
allows it. Every counter the hart has is readable below machine mode. The
mret enters kmain as supervisor.
