set MSTATUS_MPP_MASK u64 [1] :mstatus's previous-privilege field
set MSTATUS_MPP_S u64 [2] :mstatus's previous privilege as supervisor
set SSTATUS_SPIE u64 [4] :sstatus's previous interrupt enable
set SSTATUS_SPP u64 [5] :sstatus's previous privilege, set when the trap came from supervisor
set SSTATUS_SUM u64 [6] :sstatus's supervisor access to user pages
set SSTATUS_FS_INITIAL u64 [8] :sstatus's floating-point state as Initial
set SSTATUS_VS_INITIAL u64 [9] :sstatus's vector state as Initial
set SIE_STIE u64 [11] :sie's supervisor timer interrupt enable
set SIE_SEIE u64 [12] :sie's supervisor external interrupt enable
set MENVCFG_STCE u64 [14] :stimecmp (Sstc) usable in supervisor mode
set MCOUNTEREN_CY_TM_IR u64 [16] :cycle, time, and instret readable below machine mode
set SCOUNTEREN_TM u64 [17] :time readable in user mode
set PMP_NAPOT_RWX u64 [19] :one PMP entry, NAPOT, read, write, execute
set MEDELEG_ALL u64 [21] :every exception delegated
set MIDELEG_S_ALL u64 [22] :the three supervisor interrupts delegated
set SCAUSE_ECALL_U u64 [24] :scause of an ecall from user mode
set SCAUSE_S_EXTERNAL u64 [25] :scause of a supervisor external interrupt, the interrupt bit and code 9
set SATP_MODE_SV39 u64 [27] :satp's mode field as Sv39
set PTE_V u64 [28] :page table entry valid
set PTE_R u64 [29] :page table entry readable
set PTE_W u64 [30] :page table entry writable
set PTE_X u64 [31] :page table entry executable
set PTE_U u64 [32] :page table entry reachable from user mode
set PTE_A u64 [33] :page table entry accessed
set PTE_D u64 [34] :page table entry dirty
set PTE_TABLE u64 [35] :an entry pointing to the next level's table
set PTE_KERNEL_RW u64 [36] :a kernel data leaf
set PTE_KERNEL_RWX u64 [37] :a kernel leaf that also executes
set PTE_USER_RW u64 [38] :a program data leaf
set PTE_USER_RWX u64 [39] :a program leaf that also executes
