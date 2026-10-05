.set MSTATUS_MPP_MASK, (3 << 11)
.set MSTATUS_MPP_S, (1 << 11)

.set SSTATUS_SPIE, (1 << 5)
.set SSTATUS_SPP, (1 << 8)
.set SSTATUS_SUM, (1 << 18)

.set SSTATUS_FS_INITIAL, (1 << 13)
.set SSTATUS_VS_INITIAL, (1 << 9)

.set SIE_STIE, (1 << 5)
.set SIE_SEIE, (1 << 9)

.set MENVCFG_STCE, (1 << 63)
.set MENVCFG_CBZE, (1 << 7)
.set MENVCFG_CBCFE, (1 << 6)
.set MENVCFG_CBIE_FLUSH, (1 << 4)
.set SENVCFG_CBZE, (1 << 7)
.set SENVCFG_CBCFE, (1 << 6)
.set SENVCFG_CBIE_FLUSH, (1 << 4)
.set MSTATEEN0_ENVCFG, (1 << 62)
.set MSTATEEN0_SVSLCT, (1 << 60)
.set MSTATEEN0_AIA, (1 << 59)
.set MSTATEEN0_IMSIC, (1 << 58)

.set CSR_SISELECT, 0x150
.set CSR_SIREG, 0x151
.set CSR_STOPEI, 0x15c

.set MCOUNTEREN_ALL, 0xffffffff
.set SCOUNTEREN_ALL, 0xffffffff

.set PMP_NAPOT_RWX, 0x1f

.set MEDELEG_ALL, 0xffff
.set MIDELEG_S_ALL, 0x222

.set SCAUSE_ECALL_U, 8
.set SCAUSE_S_EXTERNAL, ((1 << 63) | 9)

.set SATP_MODE_SV39, (8 << 60)
.set PTE_V, 0x01
.set PTE_R, 0x02
.set PTE_W, 0x04
.set PTE_X, 0x08
.set PTE_U, 0x10
.set PTE_A, 0x40
.set PTE_D, 0x80
.set PTE_TABLE, PTE_V
.set PTE_KERNEL_RW, (PTE_V | PTE_R | PTE_W | PTE_A | PTE_D)
.set PTE_KERNEL_RWX, (PTE_V | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D)
.set PTE_USER_RW, (PTE_V | PTE_R | PTE_W | PTE_U | PTE_A | PTE_D)
.set PTE_USER_RWX, (PTE_V | PTE_R | PTE_W | PTE_X | PTE_U | PTE_A | PTE_D)
