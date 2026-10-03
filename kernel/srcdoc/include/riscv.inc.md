# riscv.inc

The RISC-V privileged bits the kernel touches.

## .set SSTATUS_FS_INITIAL

The extension state fields are two bits each. A program may use floating
point and vectors, which RVA23 requires of the machine, so the kernel leaves
both FS and VS Initial rather than Off; Off would make the first such
instruction an illegal instruction.

## .set MENVCFG_CBZE

The cache-block operations are RVA23's, Zicboz's cbo.zero and Zicbom's
cbo.clean, cbo.flush, and cbo.inval, so a program assembled for the profile
may use them, and each is an illegal instruction below machine mode until
menvcfg allows it, and in user mode until senvcfg does as well.

## .set MENVCFG_CBIE_FLUSH

CBIE is two bits: 00 refuses cbo.inval, 01 runs it as a flush, 11 as an
invalidation. A flush writes dirty data back before it drops the block,
where an invalidation drops it unwritten. Under QEMU, which keeps no cache,
each checks the access and does nothing more.

## .set MSTATEEN0_ENVCFG

Smstateen gates supervisor mode's reach of senvcfg, so without this bit
kmain's write of it is an illegal instruction. The RVA23 CPU always carries
Smstateen, so boot.S writes mstateen0 unconditionally.

## .set MCOUNTEREN_ALL

Every bit: mcounteren and scounteren keep only the bits of the counters the
hart implements, so the counters opened are the hart's own, under QEMU
cycle, time, instret, and hpmcounter3 to hpmcounter18. Their configuration,
the events and the inhibits, stays machine mode's, and the kernel sets none.
Under QEMU's TCG with no -icount, cycle and instret both read the host's
tick counter, so they time the host at its own rate and count neither the
guest's cycles nor its instructions, and hpmcounter3 to hpmcounter18 read 0,
since no event is selected. time, at JAB_TIME_HZ, is the clock to measure a
frame's work by.
