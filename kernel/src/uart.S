.include "qemu_virt.inc"

.macro uart_wait base
uart_wait_\@:
    lbu t1, 5(\base)
    andi t1, t1, 0x20
    beqz t1, uart_wait_\@
.endm

.section .text

.global uart_putc
uart_putc:
    li t0, QEMU_VIRT_UART0
    uart_wait t0
    sb a0, 0(t0)
    ret

.global uart_puts
uart_puts:
    mv t2, a0
    li t0, QEMU_VIRT_UART0
1:
    lbu a0, 0(t2)
    beqz a0, 2f
    uart_wait t0
    sb a0, 0(t0)
    addi t2, t2, 1
    j 1b
2:
    ret

.global uart_put_hex
uart_put_hex:
    mv t3, a0
    li t0, QEMU_VIRT_UART0
    li a0, '0'
    uart_wait t0
    sb a0, 0(t0)
    li a0, 'x'
    uart_wait t0
    sb a0, 0(t0)
    li t2, 60
    li t5, 10
1:
    srl t4, t3, t2
    andi t4, t4, 0xf
    blt t4, t5, 2f
    addi t4, t4, 'a' - 10
    j 3f
2:
    addi t4, t4, '0'
3:
    mv a0, t4
    uart_wait t0
    sb a0, 0(t0)
    addi t2, t2, -4
    bgez t2, 1b
    ret

.global uart_put_dec
uart_put_dec:
    addi sp, sp, -32
    addi t2, sp, 31
    sb zero, 0(t2)
    li t3, 10
1:
    remu t4, a0, t3
    divu a0, a0, t3
    addi t4, t4, '0'
    addi t2, t2, -1
    sb t4, 0(t2)
    bnez a0, 1b
    li t0, QEMU_VIRT_UART0
2:
    lbu a0, 0(t2)
    beqz a0, 3f
    uart_wait t0
    sb a0, 0(t0)
    addi t2, t2, 1
    j 2b
3:
    addi sp, sp, 32
    ret
