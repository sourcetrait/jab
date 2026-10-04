# riscv.inc

The RISC-V privileged bits the kernel touches.

## .set MSTATUS_MPP_MASK

`u64`: mstatus's previous-privilege field.

## .set MSTATUS_MPP_S

`u64`: mstatus's previous privilege as supervisor.

## .set SSTATUS_SPIE

`u64`: sstatus's previous interrupt enable.

## .set SSTATUS_SPP

`u64`: sstatus's previous privilege, set when the trap came from supervisor.

## .set SSTATUS_SUM

`u64`: sstatus's supervisor access to user pages.

## .set SSTATUS_FS_INITIAL

`u64`: sstatus's floating-point state as Initial.

The extension state fields are two bits each. A program may use floating
point and vectors, which RVA23 requires of the machine, so the kernel leaves
both FS and VS Initial rather than Off; Off would make the first such
instruction an illegal instruction.

## .set SSTATUS_VS_INITIAL

`u64`: sstatus's vector state as Initial.

## .set SIE_STIE

`u64`: sie's supervisor timer interrupt enable.

## .set SIE_SEIE

`u64`: sie's supervisor external interrupt enable.

## .set MENVCFG_STCE

`u64`: stimecmp (Sstc) usable in supervisor mode.

## .set MENVCFG_CBZE

`u64`: cbo.zero usable below machine mode.

The cache-block operations are RVA23's, Zicboz's cbo.zero and Zicbom's
cbo.clean, cbo.flush, and cbo.inval, so a program assembled for the profile
may use them, and each is an illegal instruction below machine mode until
menvcfg allows it, and in user mode until senvcfg does as well.

## .set MENVCFG_CBCFE

`u64`: cbo.clean and cbo.flush usable below machine mode.

## .set MENVCFG_CBIE_FLUSH

`u64`: cbo.inval usable below machine mode, run as a flush.

CBIE is two bits: 00 refuses cbo.inval, 01 runs it as a flush, 11 as an
invalidation. A flush writes dirty data back before it drops the block,
where an invalidation drops it unwritten. Under QEMU, which keeps no cache,
each checks the access and does nothing more.

## .set SENVCFG_CBZE

`u64`: cbo.zero usable in user mode.

## .set SENVCFG_CBCFE

`u64`: cbo.clean and cbo.flush usable in user mode.

## .set SENVCFG_CBIE_FLUSH

`u64`: cbo.inval usable in user mode, run as a flush.

## .set MSTATEEN0_ENVCFG

`u64`: senvcfg reachable from supervisor mode (Smstateen).

Smstateen gates supervisor mode's reach of senvcfg, so without this bit
kmain's write of it is an illegal instruction. The RVA23 CPU always carries
Smstateen, so boot.S writes mstateen0 unconditionally.

## .set MCOUNTEREN_ALL

`u32`: every counter the hart has readable below machine mode.

Every bit: mcounteren and scounteren keep only the bits of the counters the
hart implements, so the counters opened are the hart's own, under QEMU
cycle, time, instret, and hpmcounter3 to hpmcounter18. Their configuration,
the events and the inhibits, stays machine mode's, and the kernel sets none.
Under QEMU's TCG with no -icount, cycle and instret both read the host's
tick counter, so they time the host at its own rate and count neither the
guest's cycles nor its instructions, and hpmcounter3 to hpmcounter18 read 0,
since no event is selected. time, at JAB_TIME_HZ, is the clock to measure a
frame's work by.

## .set SCOUNTEREN_ALL

`u32`: every counter the hart has readable in user mode.

## .set PMP_NAPOT_RWX

`u64`: one PMP entry, NAPOT, read, write, execute.

## .set MEDELEG_ALL

`u64`: every exception delegated.

## .set MIDELEG_S_ALL

`u64`: the three supervisor interrupts delegated.

## .set SCAUSE_ECALL_U

`u64`: scause of an ecall from user mode.

## .set SCAUSE_S_EXTERNAL

`u64`: scause of a supervisor external interrupt, the interrupt bit and code 9.

## .set SATP_MODE_SV39

`u64`: satp's mode field as Sv39.

## .set PTE_V

`u64`: page table entry valid.

## .set PTE_R

`u64`: page table entry readable.

## .set PTE_W

`u64`: page table entry writable.

## .set PTE_X

`u64`: page table entry executable.

## .set PTE_U

`u64`: page table entry reachable from user mode.

## .set PTE_A

`u64`: page table entry accessed.

## .set PTE_D

`u64`: page table entry dirty.

## .set PTE_TABLE

`u64`: an entry pointing to the next level's table.

## .set PTE_KERNEL_RW

`u64`: a kernel data leaf.

## .set PTE_KERNEL_RWX

`u64`: a kernel leaf that also executes.

## .set PTE_USER_RW

`u64`: a program data leaf.

## .set PTE_USER_RWX

`u64`: a program leaf that also executes.
