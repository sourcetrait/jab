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
set MENVCFG_CBZE u64 [15] :cbo.zero usable below machine mode
set MENVCFG_CBCFE u64 [16] :cbo.clean and cbo.flush usable below machine mode
set MENVCFG_CBIE_FLUSH u64 [17] :cbo.inval usable below machine mode, run as a flush
set SENVCFG_CBZE u64 [18] :cbo.zero usable in user mode
set SENVCFG_CBCFE u64 [19] :cbo.clean and cbo.flush usable in user mode
set SENVCFG_CBIE_FLUSH u64 [20] :cbo.inval usable in user mode, run as a flush
set MSTATEEN0_ENVCFG u64 [21] :senvcfg reachable from supervisor mode (Smstateen)
set MCOUNTEREN_ALL u32 [23] :every counter the hart has readable below machine mode
set SCOUNTEREN_ALL u32 [24] :every counter the hart has readable in user mode
set PMP_NAPOT_RWX u64 [26] :one PMP entry, NAPOT, read, write, execute
set MEDELEG_ALL u64 [28] :every exception delegated
set MIDELEG_S_ALL u64 [29] :the three supervisor interrupts delegated
set SCAUSE_ECALL_U u64 [31] :scause of an ecall from user mode
set SCAUSE_S_EXTERNAL u64 [32] :scause of a supervisor external interrupt, the interrupt bit and code 9
set SATP_MODE_SV39 u64 [34] :satp's mode field as Sv39
set PTE_V u64 [35] :page table entry valid
set PTE_R u64 [36] :page table entry readable
set PTE_W u64 [37] :page table entry writable
set PTE_X u64 [38] :page table entry executable
set PTE_U u64 [39] :page table entry reachable from user mode
set PTE_A u64 [40] :page table entry accessed
set PTE_D u64 [41] :page table entry dirty
set PTE_TABLE u64 [42] :an entry pointing to the next level's table
set PTE_KERNEL_RW u64 [43] :a kernel data leaf
set PTE_KERNEL_RWX u64 [44] :a kernel leaf that also executes
set PTE_USER_RW u64 [45] :a program data leaf
set PTE_USER_RWX u64 [46] :a program leaf that also executes
