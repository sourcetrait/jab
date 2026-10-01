.include "riscv.inc"
.include "qemu_virt.inc"
.include "jab.inc"

# The frame clock and the wait: a tick every 1/JAB_DISPLAY_FPS_CAP of a
# second, kept as the time of the next tick. jab.sys.display.flip moves it,
# jab.sys.display.ready reads it, and jab.sys.await halts the hart until it,
# or until a key arrives, through the supervisor timer (stimecmp) and
# the PLIC, with the interrupts enabled only while waiting and taken by
# wfi rather than by the trap vector. A tick that has passed is
# reported by the next wait as it stands and moved on by the flip, so
# a program that woke on an input and comes back after the tick loses
# nothing; the wait moves a passed tick itself only when it reported
# that tick already and no flip has answered it (frame_reported).
.set TICK, (QEMU_VIRT_TIMEBASE / JAB_DISPLAY_FPS_CAP)
# A wait on the sound stream alone wakes this often to look for a stall
# (sound.S), since a device that stops returning raises no line
.set SOUND_POLL, (QEMU_VIRT_TIMEBASE / 2)

.section .text

# frame_clock_init: the first tick is now.
.global frame_clock_init
frame_clock_init:
    rdtime t0
    la t1, frame_tick
    sd t0, 0(t1)
    ret

# frame_ready: a0 becomes 1 when the next tick has come, else 0.
.global frame_ready
frame_ready:
    rdtime t0
    la t1, frame_tick
    ld t1, 0(t1)
    sltu a0, t0, t1
    xori a0, a0, 1
    ret

# frame_flipped: a flip went through now. The next tick is one period
# after the current one, or one period from now when a whole period has
# already gone by, so a punctual program keeps an exact cadence and a
# slow one is never refused. The tick the program was told of is
# answered by this flip, so the wait no longer owes it a move.
.global frame_flipped
frame_flipped:
    rdtime t0
    la t2, frame_tick
    ld t1, 0(t2)
    li t3, TICK
    add t1, t1, t3
    bltu t0, t1, 1f
    add t1, t0, t3
1:
    sd t1, 0(t2)
    la t2, frame_reported
    sd zero, 0(t2)
    ret

# sys_await (jab.sys.await): a0 is the mask of events to wait for, and
# the wait is for those and nothing else, since a program claims the
# inputs it reads: the display's next tick (JAB_AWAIT_DISPLAY), a key
# event (JAB_AWAIT_KEYBOARD), which brings the keyboard up and is
# dropped from the mask when there is none, bytes from the host over
# the API (JAB_AWAIT_API), dropped when the machine has no API port, a
# pad event (JAB_AWAIT_PAD), which brings the pad up and is dropped
# when there is none, and room in the sound stream (JAB_AWAIT_SOUND),
# which brings the sound device up and is dropped when there is none.
# A source in the mask that a program never drains holds every wait
# at once, which is why nothing is in the mask but what it names. a0
# becomes the events that ended the wait, 0 when nothing in the mask
# can happen, at once for a mask of 0.
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
    li a0, 0
    beqz s0, 9f
    # the display's tick: a tick the program was told of and has not
    # flipped on (frame_reported) moves forward past now, period by
    # period, so a program that only idles wakes once a period; a tick
    # that passed since the last flip stays where it is, so the wait
    # reports it at once, while the program was handling a key or a
    # pad event, and the flip after it lands one period on from the
    # tick rather than a period late; then the timer is armed, and a
    # tick already past ends the wait before it halts
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
    beqz t0, 4f
    li t4, SIE_SEIE
    csrs sie, t4
4:
    # wait: what in the mask has happened, else halt
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
    # a stream that has stopped returning is declared dead and its bit
    # dropped; with nothing else in the mask the wait ends with 0
    call sound_stalled
    beqz a0, 612f
    andi s0, s0, ~JAB_AWAIT_SOUND
    beqz s0, 7f
    j 62f
612:
    # the sound line raises nothing from a stalled device, so with no
    # display tick armed the timer wakes the wait to look
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
    wfi
    call plic_service
    j 4b
7:
    # the display's tick reported: the next wait moves it on unless a
    # flip answers it first
    andi t0, s1, JAB_AWAIT_DISPLAY
    beqz t0, 71f
    la t0, frame_reported
    li t1, 1
    sd t1, 0(t0)
71:
    li t4, SIE_STIE
    csrc sie, t4
    # the external lines stay enabled while the sound stream is live,
    # so its interrupt keeps reaching the vector as the program runs
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
# 1 once a wait has reported the tick, 0 once a flip has answered it
frame_reported:
    .skip 8
