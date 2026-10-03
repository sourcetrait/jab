# riscv.inc

The RISC-V privileged bits the kernel touches.

## .set SSTATUS_FS_INITIAL

The extension state fields are two bits each. A program may use floating
point and vectors, which RVA23 requires of the machine, so the kernel leaves
both FS and VS Initial rather than Off; Off would make the first such
instruction an illegal instruction.
