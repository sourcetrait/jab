.include "riscv.inc"
.include "qemu_virt.inc"
.include "jab.inc"
.include "hart.inc"

.set SYSCALL_LAST, JAB_SYS_WORKER_STOP
.set UART_PRINT_TICK, 1024

.section .text
.balign 4
.global trap_vector
trap_vector:
    csrrw sp, sscratch, sp
    beqz sp, kernel_trap
    addi sp, sp, -256
    sd x1, 8(sp)
    sd x3, 24(sp)
    sd x4, 32(sp)
    sd x5, 40(sp)
    sd x6, 48(sp)
    sd x7, 56(sp)
    sd x8, 64(sp)
    sd x9, 72(sp)
    sd x10, 80(sp)
    sd x11, 88(sp)
    sd x12, 96(sp)
    sd x13, 104(sp)
    sd x14, 112(sp)
    sd x15, 120(sp)
    sd x16, 128(sp)
    sd x17, 136(sp)
    sd x18, 144(sp)
    sd x19, 152(sp)
    sd x20, 160(sp)
    sd x21, 168(sp)
    sd x22, 176(sp)
    sd x23, 184(sp)
    sd x24, 192(sp)
    sd x25, 200(sp)
    sd x26, 208(sp)
    sd x27, 216(sp)
    sd x28, 224(sp)
    sd x29, 232(sp)
    sd x30, 240(sp)
    sd x31, 248(sp)
    csrr t0, sscratch
    sd t0, 16(sp)
    csrw sscratch, zero
    addi tp, sp, 256                        # the hart's record, above its frame
    csrr t0, sstatus
    andi t0, t0, SSTATUS_SPP
    bnez t0, kernel_fault
    csrr t0, scause
    li t1, SCAUSE_S_EXTERNAL
    beq t0, t1, interrupt
    li t1, SCAUSE_ECALL_U
    bne t0, t1, program_fault
    ld a7, 136(sp)
    ld a0, 80(sp)
    ld t0, HART_ID(tp)
    bnez t0, worker_call
    beqz a7, bad_syscall
    li t0, SYSCALL_LAST
    bgtu a7, t0, bad_syscall
call_table:
    la t0, syscall_table
    slli t1, a7, 3
    add t0, t0, t1
    ld t0, 0(t0)
    jr t0

worker_call:
    li t0, JAB_SYS_HARTS                    # a worker's calls: the masks and the worker calls it may make
    beq a7, t0, call_table
    li t0, JAB_SYS_WORKER_WAIT
    beq a7, t0, call_table
    li t0, JAB_SYS_WORKER_WAKE
    beq a7, t0, call_table
    li t0, JAB_SYS_WORKER_EXIT
    beq a7, t0, call_table
.global sys_denied
sys_denied:
    li t0, JAB_DENIED                       # every other call hart 0's: nothing entered
    sd t0, 80(sp)
    j trap_return

interrupt:
    call irq_drain
    ld t0, HART_ID(tp)
    bnez t0, interrupt_return               # the stalled lines are hart 0's to print
    call irq_report
    j interrupt_return

bad_syscall:
    la a0, msg_bad_syscall
    ld a1, 136(sp)
    j fatal_dec

.global message_bounds
message_bounds:
    li t0, JAB_PROGRAM_BASE
    bltu a0, t0, bad_address
    li a1, JAB_STACK_TOP
    bgeu a0, a1, bad_address
    ret

.global sys_uart_print
sys_uart_print:
    call message_bounds
    mv s0, a0
    mv s1, a1
    call uart_lock                          # the call's bytes together
    li s2, UART_PRINT_TICK
1:
    bgeu s0, s1, 2f
    lbu a0, 0(s0)
    beqz a0, 2f
    call uart_putc
    addi s0, s0, 1
    addi s2, s2, -1
    bnez s2, 1b
    li s2, UART_PRINT_TICK
    call sound_tick
    j 1b
2:
    call uart_unlock
    sd zero, 80(sp)
    j trap_return

.global buffer_bounds
buffer_bounds:
    li t0, JAB_PROGRAM_BASE
    bltu a0, t0, bad_address
    li t1, JAB_STACK_TOP
    bgeu a0, t1, bad_address
    add t2, a0, a1
    bltu t2, a0, bad_address    # a count that wraps is nobody's buffer
    bgtu t2, t1, bad_address
    ret

.global copy_bytes
copy_bytes:
    beqz a2, 2f
1:
    lbu t0, 0(a1)
    sb t0, 0(a0)
    addi a0, a0, 1
    addi a1, a1, 1
    addi a2, a2, -1
    bnez a2, 1b
2:
    ret

.global zero_bytes
zero_bytes:
    beqz a1, 2f
1:
    sb zero, 0(a0)
    addi a0, a0, 1
    addi a1, a1, -1
    bnez a1, 1b
2:
    ret

.global bad_address
bad_address:
    la a0, msg_bad_address
    j fatal_plain

sys_exit:
    mv s0, a0
    call shutdown_enter                     # every worker stopped where it is, or this hart parked behind a fault
    call sound_flush
.ifdef DEBUG
    la a0, msg_exit
    call debug_puts
    mv a0, s0
    call debug_put_dec
    li a0, '\n'
    call debug_putc
.pushsection .rodata
msg_exit:
    .asciz "jab: exit "
.popsection
.endif
    mv a0, s0
    j fatal_exit

program_fault:
    csrr t0, scause
    sd t0, HART_CAUSE(tp)
    csrr t0, sepc
    sd t0, HART_EPC(tp)
    csrr t0, stval
    sd t0, HART_TVAL(tp)
    li t0, FAULT_PROGRAM
    j fault_recorded

kernel_trap:
    csrrw sp, sscratch, sp
    addi sp, sp, -16
    sd t0, 0(sp)
    sd t1, 8(sp)
    csrr t0, sepc
    la t1, hart_wake_store
    ld t1, 0(t1)
    bne t0, t1, 1f
    csrr t0, scause
    li t1, SCAUSE_STORE_ACCESS
    bne t0, t1, 1f
    csrr t0, stval
    la t1, hart_wake_target
    ld t1, 0(t1)
    bne t0, t1, 1f
    la t0, hart_wake_faulted                # the release's store, no file at its address
    li t1, 1
    sd t1, 0(t0)
    csrr t0, sepc
    addi t0, t0, 4
    csrw sepc, t0
    ld t0, 0(sp)
    ld t1, 8(sp)
    addi sp, sp, 16
    sret
1:
    ld t0, 0(sp)
    ld t1, 8(sp)
    addi sp, sp, 16
kernel_fault:
    mv sp, tp                               # its stack from the top, whatever the fault left of it
    ld t0, HART_FAULT(tp)
    bnez t0, 1f                             # a fault inside a fault's own report: nothing left to trust
    csrr t0, scause
    sd t0, HART_CAUSE(tp)
    csrr t0, sepc
    sd t0, HART_EPC(tp)
    csrr t0, stval
    sd t0, HART_TVAL(tp)
    li t0, FAULT_KERNEL
    j fault_recorded
1:
    li a0, 1
    j qemu_exit

.ifdef DEBUG
timer_left_enabled:
    la a0, msg_timer_left
    j fatal_plain
.pushsection .rodata
msg_timer_left:
    .asciz "jab: timer left enabled"
.popsection
.endif

.global fatal_plain
fatal_plain:                                # a0 the fault's line
    li t0, FAULT_LINE
    j 1f
.global fatal_dec
fatal_dec:                                  # a0 the fault's line, a1 a value in decimal after it
    li t0, FAULT_LINE_DEC
    j 1f
.global fatal_hex
fatal_hex:                                  # a0 the fault's line, a1 a value in hex after it
    li t0, FAULT_LINE_HEX
1:
    sd a0, HART_LINE(tp)
    sd a1, HART_VALUE(tp)
fault_recorded:                             # t0 the kind, its fields in the hart's record
    fence w, w                              # the fields before the kind that vouches for them
    sd t0, HART_FAULT(tp)
    call shutdown_enter                     # parks this hart behind another's shutdown
    li a0, 1
.global fatal_exit
fatal_exit:                                 # a0 the status: every recorded fault's line, this hart's first, then the end
    mv s0, a0
    call uart_lock_fatal
    mv a0, tp
    call fault_line
    ld s1, HART_ID(tp)
    li s2, 0                                # the hart
1:
    li t0, JAB_HARTS_MAX
    bgeu s2, t0, 3f
    beq s2, s1, 2f
    mv a0, s2
    call hart_record
    call fault_line
    beqz a0, 2f
    li s0, 1                                # another hart's fault: the run failed
2:
    addi s2, s2, 1
    j 1b
3:
    la t0, shutdown_unanswered
    ld s1, 0(t0)
4:
    beqz s1, 5f
    ctz s2, s1
    li t0, 1
    sll t0, t0, s2
    xor s1, s1, t0
    la a0, msg_unanswered
    call uart_puts
    mv a0, s2
    call uart_put_dec
    li a0, '\n'
    call uart_putc
    j 4b
5:
    mv a0, s0
    j qemu_exit

fault_line:                                 # a0 a hart's record: its fault's line, a0 1 when it had one
    ld t0, HART_FAULT(a0)
    bnez t0, 1f
    li a0, 0
    ret
1:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s0, 0(sp)
    mv s0, a0
    fence r, r                              # the kind before the fields it vouches for
    li t1, FAULT_PROGRAM
    beq t0, t1, 3f
    li t1, FAULT_KERNEL
    beq t0, t1, 5f
    ld a0, HART_LINE(s0)
    call uart_puts
    ld t0, HART_FAULT(s0)
    li t1, FAULT_LINE_DEC
    bne t0, t1, 2f
    ld a0, HART_VALUE(s0)
    call uart_put_dec
    j 8f
2:
    li t1, FAULT_LINE_HEX
    bne t0, t1, 8f
    ld a0, HART_VALUE(s0)
    call uart_put_hex
    j 8f
3:
    ld t0, HART_ID(s0)
    bnez t0, 4f
    la a0, msg_program_fault                # hart 0's: the program's own
    call uart_puts
    j 7f
4:
    la a0, msg_worker_fault
    call uart_puts
    ld a0, HART_ID(s0)
    call uart_put_dec
    la a0, msg_argument
    call uart_puts
    ld a0, HART_ARG(s0)
    call uart_put_hex
    j 6f
5:
    la a0, msg_kernel_fault
    call uart_puts
    ld a0, HART_ID(s0)
    call uart_put_dec
6:
    la a0, msg_cause
    call uart_puts
7:
    ld a0, HART_CAUSE(s0)
    call uart_put_hex
    la a0, msg_epc
    call uart_puts
    ld a0, HART_EPC(s0)
    call uart_put_hex
    la a0, msg_tval
    call uart_puts
    ld a0, HART_TVAL(s0)
    call uart_put_hex
8:
    li a0, '\n'
    call uart_putc
    li a0, 1
    ld ra, 8(sp)
    ld s0, 0(sp)
    addi sp, sp, 16
    ret

.global trap_return
trap_return:
    csrr t0, sepc
    addi t0, t0, 4
    csrw sepc, t0
interrupt_return:
.ifdef DEBUG
    csrr t0, sie
    andi t0, t0, SIE_STIE
    bnez t0, timer_left_enabled             # user mode would take it as a fault
.endif
    la t0, shutdown_owner                   # the boundary, where a hart stops when it must
    ld t0, 0(t0)
    beqz t0, 3f
    j shutdown_park                         # another hart's: an owner never comes back this way
3:
    ld t0, HART_ID(tp)
    beqz t0, 1f
    ld t0, HART_CONTROL(tp)
    andi t0, t0, WORK_FORCED
    beqz t0, 2f
    j worker_leave                          # stopped where it is, out of the program for good
1:
    la t0, workers_live
    ld t0, 0(t0)
    beqz t0, 2f
    li t0, SIE_SEIE
    csrs sie, t0                            # hart 0 open to its workers' faults and wakes while they run
2:
    ld t0, 16(sp)
    csrw sscratch, t0
    ld x1, 8(sp)
    ld x3, 24(sp)
    ld x4, 32(sp)
    ld x5, 40(sp)
    ld x6, 48(sp)
    ld x7, 56(sp)
    ld x8, 64(sp)
    ld x9, 72(sp)
    ld x10, 80(sp)
    ld x11, 88(sp)
    ld x12, 96(sp)
    ld x13, 104(sp)
    ld x14, 112(sp)
    ld x15, 120(sp)
    ld x16, 128(sp)
    ld x17, 136(sp)
    ld x18, 144(sp)
    ld x19, 152(sp)
    ld x20, 160(sp)
    ld x21, 168(sp)
    ld x22, 176(sp)
    ld x23, 184(sp)
    ld x24, 192(sp)
    ld x25, 200(sp)
    ld x26, 208(sp)
    ld x27, 216(sp)
    ld x28, 224(sp)
    ld x29, 232(sp)
    ld x30, 240(sp)
    ld x31, 248(sp)
    addi sp, sp, 256
    csrrw sp, sscratch, sp
    sret

.global qemu_exit
qemu_exit:
    li t0, QEMU_VIRT_TEST
    beqz a0, 1f
    slli a0, a0, 16
    li t1, QEMU_TEST_FAIL
    or a0, a0, t1
    sw a0, 0(t0)
    j halt
1:
    li a0, QEMU_TEST_PASS
    sw a0, 0(t0)
.global halt
halt:
    wfi
    j halt

.section .rodata
.balign 8
syscall_table:
    .quad bad_syscall
    .quad sys_exit
    .quad sys_print
    .quad sys_uart_print
    .quad sys_display_open
    .quad sys_display_ready
    .quad sys_display_flip
    .quad sys_display_print
    .quad sys_await
    .quad sys_display_flip_rect
    .quad sys_keyboard_input
    .quad sys_block_list
    .quad sys_block_find
    .quad sys_block_read
    .quad sys_block_write
    .quad sys_romfs_list
    .quad sys_romfs_find
    .quad sys_romfs_read
    .quad sys_tar_list
    .quad sys_tar_find
    .quad sys_gz_size
    .quad sys_gz_read
    .quad sys_checksum
    .quad sys_hash
    .quad sys_api_write
    .quad sys_api_read
    .quad sys_png_size
    .quad sys_sprite_png
    .quad sys_sprite_draw
    .quad sys_sprite_load
    .quad sys_display_flip_rects
    .quad sys_kernel_flags
    .quad sys_pad_read
    .quad sys_pad_input
    .quad sys_pad_axis
    .quad sys_display_text
    .quad sys_pad_name
    .quad sys_random
    .quad sys_sound_open
    .quad sys_sound_write
    .quad sys_sound_ready
    .quad sys_midi_program
    .quad sys_midi_note
    .quad sys_midi_control
    .quad sys_midi_bend
    .quad sys_midi_instrument
    .quad sys_midi_silence
    .quad sys_midi_play
    .quad sys_midi_stop
    .quad sys_midi_playing
    .quad sys_midi_soundfont
    .quad sys_harts
    .quad sys_worker_start
    .quad sys_worker_wait
    .quad sys_worker_wake
    .quad sys_worker_exit
    .quad sys_worker_stop
msg_bad_syscall:
    .asciz "jab: unknown system call "
msg_bad_address:
    .asciz "jab: address outside the program"
msg_program_fault:
    .asciz "jab: program fault: cause="
msg_worker_fault:
    .asciz "jab: worker fault: hart="
msg_kernel_fault:
    .asciz "jab: kernel fault: hart="
msg_argument:
    .asciz " argument="
msg_cause:
    .asciz " cause="
msg_epc:
    .asciz " epc="
msg_tval:
    .asciz " tval="
msg_unanswered:
    .asciz "jab: shutdown unanswered: hart "
