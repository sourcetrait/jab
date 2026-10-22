.include "riscv.inc"
.include "qemu_virt.inc"
.include "jab.inc"

.set TICK, (QEMU_VIRT_TIMEBASE / JAB_DISPLAY_FPS_CAP)
.set SOUND_POLL, (QEMU_VIRT_TIMEBASE / 2)
.set FRAME_EPS, 3700
.if (FRAME_EPS < 100) || (FRAME_EPS > 10000) || ((FRAME_EPS % 100) != 0)
.error "FRAME_EPS is a multiple of 100 ticks from 100 to 10000"
.endif

.section .text

.global frame_clock_init
frame_clock_init:
    rdtime t0
    la t1, frame_tick
    sd t0, 0(t1)
    ret

.global frame_ready
frame_ready:
    rdtime t0
    la t1, frame_tick
    ld t1, 0(t1)
    sltu a0, t0, t1
    xori a0, a0, 1
    mv a1, t0                               # the decision's stamp
    mv a2, t1                               # the eligibility tick it read
    ret

.global frame_flipped
frame_flipped:
    addi sp, sp, -16
    sd ra, 8(sp)
    mv a1, a0                               # the acceptance, the flip's own stamp
    la t3, frame_tick
    ld a0, 0(t3)
    call frame_next
    la t3, frame_tick
    sd a0, 0(t3)
    la t3, frame_reported
    sd zero, 0(t3)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.global frame_next
frame_next:
    li t0, TICK
    sub t1, a1, a0                          # the acceptance's lateness past its tick
    li t2, FRAME_EPS
    bgeu t1, t2, 1f
    add a0, a0, t0                          # on time: the grid kept
    ret
1:
    add a0, a1, t0                          # late: a period from the acceptance
    ret

.ifdef DEBUG
.global sys_frame_step
sys_frame_step:
    ld a0, 80(sp)
    ld a1, 88(sp)
    bltu a1, a0, 1f                         # before its tick: refused, the tick as it stood
    call frame_next
    sd zero, 80(sp)
    sd a0, 88(sp)
    j trap_return
1:
    li t0, 1
    sd t0, 80(sp)
    sd a0, 88(sp)
    j trap_return
.endif

.global sys_await
sys_await:
    mv s0, a0
1:
    andi t0, s0, JAB_AWAIT_KEYBOARD
    beqz t0, 2f
    call keyboard_open
    beqz a0, 2f
    andi s0, s0, ~JAB_AWAIT_KEYBOARD
2:
    andi t0, s0, JAB_AWAIT_API
    beqz t0, 20f
    call api_up
    bnez a0, 20f
    andi s0, s0, ~JAB_AWAIT_API
20:
    andi t0, s0, JAB_AWAIT_PAD
    beqz t0, 23f
    call pad_open
    beqz a0, 23f
    andi s0, s0, ~JAB_AWAIT_PAD
23:
    andi t0, s0, JAB_AWAIT_SOUND
    beqz t0, 24f
    call sound_open
    beqz a0, 24f
    andi s0, s0, ~JAB_AWAIT_SOUND
24:
    li s1, 0
    beqz s0, 7f                             # nothing left to await: 0, through the teardown
    andi t0, s0, JAB_AWAIT_DISPLAY
    beqz t0, 3f
    la t2, frame_tick
    ld t1, 0(t2)
    la t4, frame_reported
    ld t5, 0(t4)
    beqz t5, 22f
    sd zero, 0(t4)
    li t3, TICK
    rdtime t0
21:
    bltu t0, t1, 22f
    add t1, t1, t3
    j 21b
22:
    sd t1, 0(t2)
    csrw stimecmp, t1
    li t4, SIE_STIE
    csrs sie, t4
3:
    andi t0, s0, JAB_AWAIT_KEYBOARD | JAB_AWAIT_API | JAB_AWAIT_PAD | JAB_AWAIT_SOUND
    bnez t0, 31f
    la t0, workers_live
    ld t0, 0(t0)
    beqz t0, 4f                             # no device awaited, and no worker whose fault must reach it
31:
    li t4, SIE_SEIE
    csrs sie, t4
4:
    li s1, 0
    andi t0, s0, JAB_AWAIT_DISPLAY
    beqz t0, 5f
    rdtime t0
    la t1, frame_tick
    ld t1, 0(t1)
    bltu t0, t1, 5f
    ori s1, s1, JAB_AWAIT_DISPLAY
5:
    andi t0, s0, JAB_AWAIT_KEYBOARD
    beqz t0, 6f
    call keyboard_pending
    beqz a0, 6f
    ori s1, s1, JAB_AWAIT_KEYBOARD
6:
    andi t0, s0, JAB_AWAIT_API
    beqz t0, 60f
    call api_pending
    beqz a0, 60f
    ori s1, s1, JAB_AWAIT_API
60:
    andi t0, s0, JAB_AWAIT_PAD
    beqz t0, 61f
    call pad_pending
    beqz a0, 61f
    ori s1, s1, JAB_AWAIT_PAD
61:
    andi t0, s0, JAB_AWAIT_SOUND
    beqz t0, 62f
    call sound_pending
    beqz a0, 611f
    ori s1, s1, JAB_AWAIT_SOUND
611:
    call sound_stalled
    beqz a0, 612f
    andi s0, s0, ~JAB_AWAIT_SOUND
    beqz s0, 7f
    j 62f
612:
    andi t0, s0, JAB_AWAIT_DISPLAY
    bnez t0, 62f
    rdtime t0
    li t1, SOUND_POLL
    add t0, t0, t1
    csrw stimecmp, t0
    li t4, SIE_STIE
    csrs sie, t4
62:
    bnez s1, 7f
    la t0, shutdown_owner
    ld t0, 0(t0)
    bnez t0, 7f                             # a shutdown: back to the boundary, which parks
    wfi
    call irq_drain
    mv s1, a0
    call irq_report
    bnez s1, 1b                             # a source stuck: what is awaited opened again
    j 4b
7:
    andi t0, s1, JAB_AWAIT_DISPLAY
    beqz t0, 71f
    la t0, frame_reported
    li t1, 1
    sd t1, 0(t0)
71:
    li t4, SIE_STIE
    csrc sie, t4
    la t4, sound_live
    ld t4, 0(t4)
    bnez t4, 8f
    li t4, SIE_SEIE
    csrc sie, t4
8:
    li t0, -1
    csrw stimecmp, t0
    mv a0, s1
9:
    sd a0, 80(sp)
    j trap_return

.section .bss
.balign 8
frame_tick:
    .skip 8
frame_reported:
    .skip 8
