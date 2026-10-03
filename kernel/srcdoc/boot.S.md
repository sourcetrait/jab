# boot.S

Machine-mode entry. QEMU starts every hart here, at the start of RAM, with
-bios none -kernel. Hart 0 opens memory, delegates traps, hands the timer to
supervisor mode, and drops to supervisor mode in kmain; every other hart
parks.

## _start

Physical memory protection is one entry over everything. Traps go to
supervisor mode; what still lands in machine mode stops at mtrap. The
supervisor timer is stimecmp (Sstc), with time readable there. The mret
enters kmain as supervisor.
