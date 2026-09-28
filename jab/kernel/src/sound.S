.include "riscv.inc"
.include "qemu_virt.inc"
.include "virtio.inc"
.include "jab.inc"

# The sound device: QEMU's virtio-sound over the mmio transport, id
# 25, its playback stream driven in Jab's one format, 48 kHz stereo
# signed 16-bit interleaved (jab.inc), TheUser's ruling. The control
# queue carries the stream's set-up, SET_PARAMS, PREPARE, and START,
# each a request the device answers with a status; the tx queue
# carries the samples in periods of JAB_SOUND_PERIOD frames, each a
# chain of two descriptors, the stream id and the samples the device
# reads and a status it writes back, returned once the host's backend
# has consumed it on its own timer. The stream runs on that clock:
# JAB_SOUND_PERIODS periods are in flight, and each one returned
# raises the device's line, which the kernel takes wherever it is,
# in a wait or in the program through the trap vector (trap.S), and
# fills and offers again from the mix of two sources: the frames a
# program has queued with jab.sound.write, a ring of JAB_SOUND_RING
# of them played in order as they reach the front, and the
# synthesizer's voices (synth.S). A dry ring and no voice is silence,
# never a fault. Once the stream is live the external interrupt stays
# enabled in sie for good, so the waits leave it set (timer.S,
# virtio.S). Every period the device returns is looked at: its status
# is counted, and the time of the last return is what tells a stalled
# backend, one that has returned nothing for SOUND_STALL_TICKS while
# periods were in flight, from a slow one; a stalled stream is declared
# dead, with a line on the UART, rather than holding a wait forever. A
# long call looks at the stream from inside its loops through
# sound_tick, so the lead is never spent by the kernel's own work.
.set SOUND_STREAM, 0
.set PERIOD_BYTES, (JAB_SOUND_PERIOD * JAB_SOUND_FRAME_BYTES)
.set PERIOD_STRIDE, (VIRTIO_SND_PCM_XFER_SIZE + PERIOD_BYTES)
.set RING_MASK, (JAB_SOUND_RING - 1)
.set ACCUM_BYTES, (JAB_SOUND_PERIOD * JAB_SOUND_CHANNELS * 4)
# A backend that has returned nothing for this long, with periods in
# flight, has stopped
.set SOUND_STALL_TICKS, (QEMU_VIRT_TIMEBASE * 3)
# How often a wait on the stream alone wakes to look for a stall
.set SOUND_POLL_TICKS, (QEMU_VIRT_TIMEBASE / 2)
# The exit keeps the stream running for this many periods of silence
# past the last with content, so the host's own buffer behind the
# device, 92 ms on ALSA, has played what it held before QEMU ends
.set SOUND_DRAIN_PERIODS, 16
# The exit waits this long at most for the ring and the voices to end
.set SOUND_FLUSH_TICKS, (QEMU_VIRT_TIMEBASE * 3)

.section .text

# sys_sound_open (jab.sound.open): a0 becomes 0, 1 with no sound
# device on the machine, 2 when the device refuses the kernel or the
# format.
.global sys_sound_open
sys_sound_open:
    call sound_open
    sd a0, 80(sp)
    j trap_return

# sys_sound_write (jab.sound.write): a0 is a buffer of frames inside
# the program's window, a1 how many. a0 becomes 0 with a1 how many
# were taken, as many as the ring has room for, or sound_open's code.
# The count is capped to the room before it is multiplied, so a count
# that would wrap the byte size is never the one the bounds see.
.global sys_sound_write
sys_sound_write:
    call sound_open
    bnez a0, 9f
    call sound_room
    ld a1, 88(sp)
    bleu a1, a0, 1f
    mv a1, a0                   # no more than the room
1:
    mv s2, a1                   # frames taken
    ld a0, 80(sp)
    li t0, JAB_SOUND_FRAME_BYTES
    mul a1, a1, t0
    call buffer_bounds
    mv a1, s2
    ld s0, 80(sp)               # the next frame to take
    la t0, sound_head
    ld s1, 0(t0)                # where it goes
2:
    beqz a1, 3f
    li t2, RING_MASK
    and t0, s1, t2
    slli t0, t0, 2
    la t1, sound_ring
    add t0, t0, t1
    lhu t1, 0(s0)
    sh t1, 0(t0)
    lhu t1, 2(s0)
    sh t1, 2(t0)
    addi s0, s0, JAB_SOUND_FRAME_BYTES
    addi s1, s1, 1
    addi a1, a1, -1
    j 2b
3:
    la t0, sound_head
    sd s1, 0(t0)
    sd zero, 80(sp)
    sd s2, 88(sp)
    j trap_return
9:
    sd a0, 80(sp)
    sd zero, 88(sp)
    j trap_return

# sys_sound_ready (jab.sound.ready): a0 becomes 0 with a1 how many
# frames a write would take now, or sound_open's code.
.global sys_sound_ready
sys_sound_ready:
    call sound_open
    bnez a0, 9f
    call sound_room
    sd zero, 80(sp)
    sd a0, 88(sp)
    j trap_return
9:
    sd a0, 80(sp)
    sd zero, 88(sp)
    j trap_return

# sound_room: a0 becomes how many frames the ring has room for.
sound_room:
    la t0, sound_head
    ld t0, 0(t0)
    la t1, sound_tail
    ld t1, 0(t1)
    sub t0, t0, t1
    li a0, JAB_SOUND_RING
    sub a0, a0, t0
    ret

# sound_open: find the sound device and bring it up: the control and
# tx queues, its line let through, the stream's parameters set to the
# one format with JAB_SOUND_PERIODS periods, prepared and started,
# the period chains' descriptors laid out once, the synthesizer
# reset, and every period mixed and offered, so the stream runs from
# here on. Returns 0, or 1 with no sound device, 2 when the device
# refuses the kernel or a request; asked again it answers as before
# at once. Keeps the s registers.
.global sound_open
sound_open:
    la t0, sound_state
    ld t0, 0(t0)
    beqz t0, 1f
    addi a0, t0, -1
    ret
1:
    addi sp, sp, -32
    sd ra, 24(sp)
    li a0, VIRTIO_ID_SOUND
    call virtio_find
    beqz a0, 5f
    la t0, sound_base
    sd a0, 0(t0)
.ifdef DEBUG
    la a0, msg_sound_at
    call debug_puts
    la t0, sound_base
    ld a0, 0(t0)
    call debug_put_hex
    li a0, '\n'
    call debug_putc
    la t0, sound_base
    ld a0, 0(t0)
.pushsection .rodata
msg_sound_at:
    .asciz "jab: sound at "
.popsection
.endif
    call virtio_init
    bnez a0, 6f
    la t0, sound_base
    ld a0, 0(t0)
    li a1, VIRTIO_SND_VQ_CONTROL
    la a2, sound_control_queue
    call virtio_queue_setup
    bnez a0, 6f
    call sound_queue_setup
    bnez a0, 6f
    la t0, sound_base
    ld a0, 0(t0)
    call virtio_driver_ok
    la t0, sound_base
    ld a0, 0(t0)
    call virtio_irq_enable
    # the stream's parameters: the one format, the period, the lead
    la t0, sound_request
    li t1, VIRTIO_SND_R_PCM_SET_PARAMS
    sw t1, VIRTIO_SND_HDR_CODE(t0)
    li t1, SOUND_STREAM
    sw t1, VIRTIO_SND_PCM_HDR_STREAM(t0)
    li t1, PERIOD_BYTES * JAB_SOUND_PERIODS
    sw t1, VIRTIO_SND_SET_PARAMS_BUFFER_BYTES(t0)
    li t1, PERIOD_BYTES
    sw t1, VIRTIO_SND_SET_PARAMS_PERIOD_BYTES(t0)
    sw zero, VIRTIO_SND_SET_PARAMS_FEATURES(t0)
    li t1, JAB_SOUND_CHANNELS
    sb t1, VIRTIO_SND_SET_PARAMS_CHANNELS(t0)
    li t1, VIRTIO_SND_PCM_FMT_S16
    sb t1, VIRTIO_SND_SET_PARAMS_FORMAT(t0)
    li t1, VIRTIO_SND_PCM_RATE_48000
    sb t1, VIRTIO_SND_SET_PARAMS_RATE(t0)
    sb zero, (VIRTIO_SND_SET_PARAMS_RATE + 1)(t0)
    li a0, VIRTIO_SND_SET_PARAMS_SIZE
    call sound_control
    bnez a0, 6f
    li a0, VIRTIO_SND_R_PCM_PREPARE
    call sound_control_simple
    bnez a0, 6f
    li a0, VIRTIO_SND_R_PCM_START
    call sound_control_simple
    bnez a0, 6f
    # the period chains: descriptor 2i the stream id and the samples,
    # 2i+1 the status, laid out once
    la t0, sound_queue
    la t1, sound_periods
    la t2, sound_status
    li t3, 0
2:
    li t4, SOUND_STREAM
    sw t4, 0(t1)
    slli t4, t3, 5              # descriptor 2i, 16 bytes each
    add t4, t4, t0
    sd t1, (SNDQ_DESC + VIRTQ_DESC_ADDR)(t4)
    li t5, PERIOD_STRIDE
    sw t5, (SNDQ_DESC + VIRTQ_DESC_LEN)(t4)
    li t5, VIRTQ_DESC_F_NEXT
    sh t5, (SNDQ_DESC + VIRTQ_DESC_FLAGS)(t4)
    slli t5, t3, 1
    addi t5, t5, 1
    sh t5, (SNDQ_DESC + VIRTQ_DESC_NEXT)(t4)
    sd t2, (SNDQ_DESC + VIRTQ_DESC_SIZE + VIRTQ_DESC_ADDR)(t4)
    li t5, VIRTIO_SND_PCM_STATUS_SIZE
    sw t5, (SNDQ_DESC + VIRTQ_DESC_SIZE + VIRTQ_DESC_LEN)(t4)
    li t5, VIRTQ_DESC_F_WRITE
    sh t5, (SNDQ_DESC + VIRTQ_DESC_SIZE + VIRTQ_DESC_FLAGS)(t4)
    sh zero, (SNDQ_DESC + VIRTQ_DESC_SIZE + VIRTQ_DESC_NEXT)(t4)
    li t5, PERIOD_STRIDE
    add t1, t1, t5
    addi t2, t2, VIRTIO_SND_PCM_STATUS_SIZE
    addi t3, t3, 1
    li t5, JAB_SOUND_PERIODS
    bltu t3, t5, 2b
    call synth_init
    la t0, sound_submitted
    sd zero, 0(t0)
    la t0, sound_returned
    sd zero, 0(t0)
    la t0, sound_failed
    sd zero, 0(t0)
    rdtime t0
    la t1, sound_last_return
    sd t0, 0(t1)
    la t0, sound_state
    li t1, 1
    sd t1, 0(t0)
    # live: the line stays enabled from here on, and the stream is
    # primed with every period
    la t0, sound_live
    sd t1, 0(t0)
    li t0, SIE_SEIE
    csrs sie, t0
    call sound_service
    li a0, 0
    j 8f
5:
.ifdef DEBUG
    la a0, msg_no_sound
    call debug_puts
.pushsection .rodata
msg_no_sound:
    .asciz "jab: no sound\n"
.popsection
.endif
    la t0, sound_state
    li t1, 2
    sd t1, 0(t0)
    li a0, 1
    j 8f
6:
.ifdef DEBUG
    la a0, msg_sound_refused
    call debug_puts
.pushsection .rodata
msg_sound_refused:
    .asciz "jab: sound refused\n"
.popsection
.endif
    la t0, sound_state
    li t1, 3
    sd t1, 0(t0)
    li a0, 2
8:
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

# sound_queue_setup: give the tx queue the wide record's rings,
# SNDQ_SIZE entries. Returns 0, or 1 when the device offers fewer.
sound_queue_setup:
    la t2, sound_base
    ld a0, 0(t2)
    la a2, sound_queue
    li t0, VIRTIO_SND_VQ_TX
    sw t0, VIRTIO_MMIO_QUEUE_SEL(a0)
    lwu t0, VIRTIO_MMIO_QUEUE_NUM_MAX(a0)
    li t1, SNDQ_SIZE
    bltu t0, t1, 1f
    sw t1, VIRTIO_MMIO_QUEUE_NUM(a0)
    addi t0, a2, SNDQ_DESC
    srli t1, t0, 32
    sw t0, VIRTIO_MMIO_QUEUE_DESC_LOW(a0)
    sw t1, VIRTIO_MMIO_QUEUE_DESC_HIGH(a0)
    addi t0, a2, SNDQ_AVAIL
    srli t1, t0, 32
    sw t0, VIRTIO_MMIO_QUEUE_DRIVER_LOW(a0)
    sw t1, VIRTIO_MMIO_QUEUE_DRIVER_HIGH(a0)
    addi t0, a2, SNDQ_USED
    srli t1, t0, 32
    sw t0, VIRTIO_MMIO_QUEUE_DEVICE_LOW(a0)
    sw t1, VIRTIO_MMIO_QUEUE_DEVICE_HIGH(a0)
    li t0, 1
    sw t0, VIRTIO_MMIO_QUEUE_READY(a0)
    li a0, 0
    ret
1:
    li a0, 1
    ret

# sound_control_simple: a0 is a request code that takes only the
# stream; run it. a0 becomes 0 when the device said OK, else 1.
sound_control_simple:
    la t0, sound_request
    sw a0, VIRTIO_SND_HDR_CODE(t0)
    li t1, SOUND_STREAM
    sw t1, VIRTIO_SND_PCM_HDR_STREAM(t0)
    li a0, VIRTIO_SND_PCM_HDR_SIZE
    j sound_control

# sound_control: run the request of a0 bytes in sound_request through
# the control queue, the hart halted until the device answers. a0
# becomes 0 when the device said OK, else 1.
sound_control:
    addi sp, sp, -16
    sd ra, 8(sp)
    mv a3, a0
    la t0, sound_base
    ld a0, 0(t0)
    li a1, VIRTIO_SND_VQ_CONTROL
    la a2, sound_control_queue
    la a4, sound_request
    la a5, sound_response
    li a6, 4
    call virtio_request
    la t0, sound_response
    lwu t0, 0(t0)
    li t1, VIRTIO_SND_S_OK
    beq t0, t1, 1f
    li a0, 1
    j 2f
1:
    li a0, 0
2:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

# sound_service: the stream kept running: every period the device
# has returned is mixed afresh and offered again, the file player
# stepped a period first (smf.S). Called wherever the device's line
# is taken (virtio.S), in a wait or from the trap vector, so it keeps
# every register but the t registers and a0; nothing happens until
# the stream is live.
.global sound_service
sound_service:
    la t0, sound_live
    ld t0, 0(t0)
    beqz t0, 9f
    addi sp, sp, -96
    sd ra, 88(sp)
    sd s0, 80(sp)
    sd a1, 72(sp)
    sd a2, 64(sp)
    sd a3, 56(sp)
    sd a4, 48(sp)
    sd a5, 40(sp)
    sd a6, 32(sp)
    sd a7, 24(sp)
    call sound_drain
    li s0, 0
1:
    la t0, sound_busy
    add t0, t0, s0
    lbu t0, 0(t0)
    bnez t0, 2f
    call smf_step
    li t0, PERIOD_STRIDE
    mul a0, s0, t0
    la t0, sound_periods
    add a0, a0, t0
    addi a0, a0, VIRTIO_SND_PCM_XFER_SIZE
    call sound_mix
    mv a0, s0
    call sound_submit
2:
    addi s0, s0, 1
    li t0, JAB_SOUND_PERIODS
    bltu s0, t0, 1b
    ld ra, 88(sp)
    ld s0, 80(sp)
    ld a1, 72(sp)
    ld a2, 64(sp)
    ld a3, 56(sp)
    ld a4, 48(sp)
    ld a5, 40(sp)
    ld a6, 32(sp)
    ld a7, 24(sp)
    addi sp, sp, 96
9:
    ret

# sound_mix: fill a period's samples at a0: the ring's frames, as
# many as it holds up to the period, scaled by four into the
# accumulator and silence after them; the synthesizer's voices added
# at full scale; the sum, back down by four, clipped to the sample
# range. So a program's frames pass through unchanged and four voices
# at full scale reach it. Keeps the s registers.
sound_mix:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    mv s0, a0
    la t0, sound_tail
    ld t1, 0(t0)
    la t2, sound_head
    ld t2, 0(t2)
    sub t3, t2, t1              # frames the ring holds
    li t4, JAB_SOUND_PERIOD
    bleu t3, t4, 1f
    mv t3, t4
1:
    sub t4, t4, t3              # frames of silence after them
    add t2, t1, t3
    sd t2, 0(t0)                # the tail moves now
    la t5, sound_accum
2:
    beqz t3, 3f
    li t2, RING_MASK
    and t6, t1, t2
    slli t6, t6, 2
    la t0, sound_ring
    add t6, t6, t0
    lh t0, 0(t6)
    slli t0, t0, 2
    sw t0, 0(t5)
    lh t0, 2(t6)
    slli t0, t0, 2
    sw t0, 4(t5)
    addi t5, t5, 8
    addi t1, t1, 1
    addi t3, t3, -1
    j 2b
3:
    beqz t4, 4f
    sw zero, 0(t5)
    sw zero, 4(t5)
    addi t5, t5, 8
    addi t4, t4, -1
    j 3b
4:
    la a0, sound_accum
    li a1, JAB_SOUND_PERIOD
    call synth_render
    la t0, sound_accum
    li t1, JAB_SOUND_PERIOD * JAB_SOUND_CHANNELS
    li t2, 32767
    li t3, -32768
5:
    lw t4, 0(t0)
    srai t4, t4, 2
    ble t4, t2, 6f
    mv t4, t2
6:
    bge t4, t3, 7f
    mv t4, t3
7:
    sh t4, 0(s0)
    addi t0, t0, 4
    addi s0, s0, 2
    addi t1, t1, -1
    bnez t1, 5b
    ld ra, 24(sp)
    ld s0, 16(sp)
    addi sp, sp, 32
    ret

# sound_submit: offer period a0, full, to the device: its chain's
# head in the next slot of the available ring, and a notify; counted.
sound_submit:
    la t0, sound_busy
    add t0, t0, a0
    li t1, 1
    sb t1, 0(t0)
    la t0, sound_submitted
    ld t1, 0(t0)
    addi t1, t1, 1
    sd t1, 0(t0)
    la t0, sound_queue
    lhu t1, (SNDQ_AVAIL + VIRTQ_AVAIL_IDX)(t0)
    andi t2, t1, SNDQ_SIZE - 1
    slli t2, t2, 1
    add t2, t2, t0
    slli t3, a0, 1
    sh t3, (SNDQ_AVAIL + VIRTQ_AVAIL_RING)(t2)
    fence w, w
    addi t1, t1, 1
    sh t1, (SNDQ_AVAIL + VIRTQ_AVAIL_IDX)(t0)
    fence rw, rw
    la t0, sound_base
    ld t0, 0(t0)
    li t1, VIRTIO_SND_VQ_TX
    sw t1, VIRTIO_MMIO_QUEUE_NOTIFY(t0)
    ret

# sound_drain: every period the device has returned is free again,
# each one's status record read: a status other than OK is counted as
# failed, every return is counted and stamps the time of the last.
# Clobbers t registers only.
sound_drain:
    la t0, sound_queue
    ld t1, SNDQ_LAST_USED(t0)
1:
    fence rw, rw
    lhu t2, (SNDQ_USED + VIRTQ_USED_IDX)(t0)
    beq t2, t1, 2f
    andi t2, t1, SNDQ_SIZE - 1
    slli t2, t2, 3
    add t2, t2, t0
    lwu t3, (SNDQ_USED + VIRTQ_USED_RING + VIRTQ_USED_ELEM_ID)(t2)
    srli t3, t3, 1              # the chain's head is 2i
    la t4, sound_busy
    add t4, t4, t3
    sb zero, 0(t4)
    # its status, written by the device after the samples
    li t4, VIRTIO_SND_PCM_STATUS_SIZE
    mul t4, t4, t3
    la t5, sound_status
    add t4, t4, t5
    lwu t4, VIRTIO_SND_PCM_STATUS_STATUS(t4)
    li t5, VIRTIO_SND_S_OK
    beq t4, t5, 11f
    la t4, sound_failed
    ld t5, 0(t4)
    addi t5, t5, 1
    sd t5, 0(t4)
11:
    la t4, sound_returned
    ld t5, 0(t4)
    addi t5, t5, 1
    sd t5, 0(t4)
    rdtime t4
    la t5, sound_last_return
    sd t4, 0(t5)
    addi t1, t1, 1
    li t2, 0xffff
    and t1, t1, t2
    sd t1, SNDQ_LAST_USED(t0)
    j 1b
2:
    ret

# sound_stalled: a0 becomes 1 when the live stream has stopped: a
# period in flight and no return for SOUND_STALL_TICKS. The stream is
# then dead: the refills stop, the calls answer 2 from here on, the
# wait drops its bit, and "jab: sound stalled" goes to the UART, in
# every build, since a program that hears nothing deserves the reason.
# Else 0. Clobbers t registers and a0.
.global sound_stalled
sound_stalled:
    la t0, sound_live
    ld t0, 0(t0)
    beqz t0, 8f
    la t0, sound_busy
    li t1, JAB_SOUND_PERIODS
    li t2, 0
1:
    add t3, t0, t2
    lbu t3, 0(t3)
    bnez t3, 2f
    addi t2, t2, 1
    bltu t2, t1, 1b
    j 8f                        # nothing in flight: nothing to wait on
2:
    rdtime t0
    la t1, sound_last_return
    ld t1, 0(t1)
    sub t0, t0, t1
    li t1, SOUND_STALL_TICKS
    bltu t0, t1, 8f
    la t0, sound_live
    sd zero, 0(t0)
    la t0, sound_state
    li t1, 3
    sd t1, 0(t0)
    addi sp, sp, -16
    sd ra, 8(sp)
    la a0, msg_sound_stalled
    call uart_puts
    ld ra, 8(sp)
    addi sp, sp, 16
    li a0, 1
    ret
8:
    li a0, 0
    ret

# sound_tick: a checkpoint for a long loop inside a call, which runs
# with interrupts off: when the stream is live and the device has
# returned a period since the kernel last looked, the PLIC is serviced
# here, which refills the stream, so a call that outlasts the lead
# cannot starve it. Keeps every register; cheap when nothing came.
.global sound_tick
sound_tick:
    addi sp, sp, -16
    sd t0, 0(sp)
    sd t1, 8(sp)
    la t0, sound_live
    ld t0, 0(t0)
    beqz t0, 9f
    la t0, sound_queue
    fence rw, rw
    lhu t1, (SNDQ_USED + VIRTQ_USED_IDX)(t0)
    ld t0, SNDQ_LAST_USED(t0)
    beq t0, t1, 9f
    addi sp, sp, -80
    sd ra, 72(sp)
    sd a0, 64(sp)
    sd t2, 56(sp)
    sd t3, 48(sp)
    sd t4, 40(sp)
    sd t5, 32(sp)
    sd t6, 24(sp)
    call plic_service
    ld ra, 72(sp)
    ld a0, 64(sp)
    ld t2, 56(sp)
    ld t3, 48(sp)
    ld t4, 40(sp)
    ld t5, 32(sp)
    ld t6, 24(sp)
    addi sp, sp, 80
9:
    ld t0, 0(sp)
    ld t1, 8(sp)
    addi sp, sp, 16
    ret

# sound_wait: halt until the device's line or the poll timer, then
# service the PLIC; the timer is armed so a dead device cannot hold
# the halt, and cleared after. Clobbers t registers and a0.
sound_wait:
    addi sp, sp, -16
    sd ra, 8(sp)
    rdtime t0
    li t1, SOUND_POLL_TICKS
    add t0, t0, t1
    csrw stimecmp, t0
    li t0, SIE_STIE
    csrs sie, t0
    wfi
    li t0, SIE_STIE
    csrc sie, t0
    li t0, -1
    csrw stimecmp, t0
    call plic_service
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

# sound_flush: the stream played out, for a program's exit. Every voice
# goes to its release first, so a note the program left held ends;
# then three waits, each ended early by a stall: until the ring is
# empty and no voice sounds, the refills going on, for at most
# SOUND_FLUSH_TICKS; then SOUND_DRAIN_PERIODS more returns past the
# periods then in flight, every refill silence by then, so the host's
# own buffer has played the last content before QEMU ends; then, the
# refills stopped, until every period has come back. Nothing happens
# with no live stream. With DEBUG the counts go to the debug channel.
# Clobbers t registers and a0.
.global sound_flush
sound_flush:
    la t0, sound_live
    ld t0, 0(t0)
    beqz t0, 9f
    addi sp, sp, -32
    sd ra, 24(sp)
    li a0, 0
    li a1, -1
    call synth_all_off
    rdtime t0
    li t1, SOUND_FLUSH_TICKS
    add t0, t0, t1
    sd t0, 8(sp)                # when to stop waiting for the voices
1:
    call sound_stalled
    bnez a0, 5f
    rdtime t0
    ld t1, 8(sp)
    bgeu t0, t1, 2f
    la t0, sound_head
    ld t0, 0(t0)
    la t1, sound_tail
    ld t1, 0(t1)
    bne t0, t1, 11f
    call synth_sounding
    beqz a0, 2f
11:
    call sound_wait
    j 1b
2:
    la t0, sound_returned
    ld t0, 0(t0)
    addi t0, t0, JAB_SOUND_PERIODS + SOUND_DRAIN_PERIODS
    sd t0, 0(sp)                # the return count to reach
3:
    call sound_stalled
    bnez a0, 5f
    la t0, sound_returned
    ld t0, 0(t0)
    ld t1, 0(sp)
    bgeu t0, t1, 4f
    call sound_wait
    j 3b
4:
    la t0, sound_live
    sd zero, 0(t0)
41:
    call sound_drain
    la t0, sound_busy
    li t1, JAB_SOUND_PERIODS
    li t2, 0
42:
    add t3, t0, t2
    lbu t3, 0(t3)
    bnez t3, 43f
    addi t2, t2, 1
    bltu t2, t1, 42b
    j 5f
43:
    # a stall here is the device keeping a period; the exit goes on
    rdtime t0
    la t1, sound_last_return
    ld t1, 0(t1)
    sub t0, t0, t1
    li t1, SOUND_STALL_TICKS
    bgeu t0, t1, 44f
    call sound_wait
    j 41b
44:
    la a0, msg_sound_stalled
    call uart_puts
5:
.ifdef DEBUG
    la a0, msg_sound_counts
    call debug_puts
    la t0, sound_submitted
    ld a0, 0(t0)
    call debug_put_dec
    la a0, msg_sound_returned
    call debug_puts
    la t0, sound_returned
    ld a0, 0(t0)
    call debug_put_dec
    la a0, msg_sound_failed
    call debug_puts
    la t0, sound_failed
    ld a0, 0(t0)
    call debug_put_dec
    li a0, '\n'
    call debug_putc
.pushsection .rodata
msg_sound_counts:
    .asciz "jab: sound submitted "
msg_sound_returned:
    .asciz " returned "
msg_sound_failed:
    .asciz " failed "
.popsection
.endif
    ld ra, 24(sp)
    addi sp, sp, 32
9:
    ret

# sound_pending: a0 becomes 1 when the ring has room for a period,
# so a write can take more, else 0. Keeps the s registers.
.global sound_pending
sound_pending:
    la t0, sound_head
    ld t0, 0(t0)
    la t1, sound_tail
    ld t1, 0(t1)
    sub t0, t0, t1
    li t1, JAB_SOUND_RING - JAB_SOUND_PERIOD
    sltu a0, t1, t0
    xori a0, a0, 1
    ret

.section .bss
.balign 16
sound_control_queue:
    .skip VQ_BYTES
.balign 16
sound_queue:
    .skip SNDQ_BYTES
.balign 8
sound_periods:
    .skip JAB_SOUND_PERIODS * PERIOD_STRIDE
sound_status:
    .skip JAB_SOUND_PERIODS * VIRTIO_SND_PCM_STATUS_SIZE
sound_request:
    .skip VIRTIO_SND_SET_PARAMS_SIZE
sound_response:
    .skip 8
.global sound_base
sound_base:
    .skip 8
sound_state:
    .skip 8
.global sound_live
sound_live:
    .skip 8
sound_head:
    .skip 8
sound_tail:
    .skip 8
.balign 4
sound_ring:
    .skip JAB_SOUND_RING * JAB_SOUND_FRAME_BYTES
sound_accum:
    .skip ACCUM_BYTES
sound_busy:
    .skip JAB_SOUND_PERIODS
.balign 8
sound_submitted:
    .skip 8
sound_returned:
    .skip 8
sound_failed:
    .skip 8
sound_last_return:
    .skip 8

.section .rodata
msg_sound_stalled:
    .asciz "jab: sound stalled\n"
