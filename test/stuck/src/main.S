.include "jab.inc"

.set SELECT_WAIT, (2 * JAB_TIME_HZ)
.set DRAW_BYTES, 64
.set RNG_HOLD, (7 * JAB_TIME_HZ)
.set PATTERN, 0xa5
.set SPIN, JAB_TIME_HZ
.set API_BYTES, 8

.section .text
.global _start
_start:
    jab.sys.display.open
    rdtime s7
    li t0, SELECT_WAIT
    add s7, s7, t0                          # the selector's deadline
1:
    la s4, selector
    jab.sys.api.read s4, 1
    bnez a0, 2f                             # it came
    rdtime t0
    bgeu t0, s7, 9f
    jab.sys.await JAB_AWAIT_DISPLAY | JAB_AWAIT_API
    j 1b
2:
    lbu t0, 0(s4)
    li t1, 'r'
    beq t0, t1, rng
    li t1, 'p'
    beq t0, t1, pad
    li t1, 'a'
    beq t0, t1, api
    li t1, 's'
    beq t0, t1, sound
    li t1, 'd'
    beq t0, t1, disk
9:
    la s3, line
    la a1, word_none
    call put_str
    call say
    jab.sys.exit 2

rng:
    la a1, name_rng
    call echo
    rdtime s7                               # the first draw's time
    la s4, buffer
    li s5, DRAW_BYTES
    jab.sys.random s4, s5
    mv s0, a0
    la t0, buffer
    li t1, DRAW_BYTES
    li t2, PATTERN
1:
    sb t2, 0(t0)                            # what the device never writes
    addi t0, t0, 1
    addi t1, t1, -1
    bnez t1, 1b
    jab.sys.random s4, s5
    mv s1, a0
    la t0, buffer
    la t1, snapshot
    li t2, DRAW_BYTES
2:
    lbu t3, 0(t0)
    sb t3, 0(t1)
    addi t0, t0, 1
    addi t1, t1, 1
    addi t2, t2, -1
    bnez t2, 2b
    li t0, RNG_HOLD
    add s7, s7, t0                          # past the device's next refill
3:
    rdtime t0
    bgeu t0, s7, 4f
    jab.sys.display.await
    j 3b
4:
    li s8, 0                                # whether the buffer moved since the snapshot
    la t0, buffer
    la t1, snapshot
    li t2, DRAW_BYTES
5:
    lbu t3, 0(t0)
    lbu t4, 0(t1)
    beq t3, t4, 6f
    li s8, 1
6:
    addi t0, t0, 1
    addi t1, t1, 1
    addi t2, t2, -1
    bnez t2, 5b
    jab.sys.display.await
    jab.sys.display.flip
    mv s2, a0
    la s3, line
    la a1, word_random
    call put_str
    mv a0, s0
    call put_dec
    la a1, word_then
    call put_str
    mv a0, s1
    call put_dec
    la a1, word_intact
    beqz s8, 7f
    la a1, word_overwritten
7:
    call put_str
    la a1, word_flip
    call put_str
    mv a0, s2
    call put_dec
    call say
    jab.sys.exit 0

pad:
    la a1, name_pad
    call echo
    la s4, pad_record
    jab.sys.pad.read s4
    mv s0, a0
    jab.sys.await JAB_AWAIT_PAD
    mv s1, a0
    jab.sys.pad.read s4
    mv s2, a0
    la s3, line
    la a1, word_pad_read
    call put_str
    mv a0, s0
    call put_dec
    la a1, word_await
    call put_str
    mv a0, s1
    call put_dec
    la a1, word_read
    call put_str
    mv a0, s2
    call put_dec
    call say
    jab.sys.exit 0

api:
    la a1, name_api
    call echo
    la s4, api_bytes
    li s5, API_BYTES
    jab.sys.api.write s4, s5
    mv s0, a0
    jab.sys.api.write s4, s5
    mv s1, a0
    la s3, line
    la a1, word_api_write
    call put_str
    mv a0, s0
    call put_dec
    la a1, word_then
    call put_str
    mv a0, s1
    call put_dec
    call say
    jab.sys.exit 0

sound:
    la a1, name_sound
    call echo
    la s4, silence
    li s5, JAB_SOUND_RING
    jab.sys.sound.write s4, s5
    mv s0, a0
    mv s6, a1                               # the frames the ring took
    jab.sys.sound.await
    mv s1, a0
    rdtime s7
    li t0, SPIN
    add s7, s7, t0
1:
    rdtime t0
    bltu t0, s7, 1b                         # in user mode, where a timer left enabled would fault
    la s3, line
    la a1, word_sound_write
    call put_str
    mv a0, s0
    call put_dec
    la a1, word_took
    call put_str
    mv a0, s6
    call put_dec
    la a1, word_await
    call put_str
    mv a0, s1
    call put_dec
    call say
    jab.sys.exit 0

disk:
    la a1, name_disk
    call echo
    la s4, disks
    jab.sys.block.list s4
    mv s5, a0                               # the records
    la s3, line
    la a1, word_disks
    call put_str
    mv a0, s5
    call put_dec
    li a0, ':'
    call put_char
    li s6, 0                                # the record
1:
    bgeu s6, s5, 3f
    beqz s6, 2f
    li a0, ','
    call put_char
2:
    li a0, ' '
    call put_char
    li t0, JAB_BLOCK_ENTRY
    mul t0, t0, s6
    add s7, s4, t0
    lbu a0, JAB_BLOCK_ID(s7)
    call put_dec
    la a1, word_kind
    call put_str
    lbu a0, JAB_BLOCK_KIND(s7)
    call put_dec
    addi s6, s6, 1
    j 1b
3:
    call say
    jab.sys.exit 0

echo:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a1, 0(sp)
    la s3, line
    la a1, word_scenario
    call put_str
    ld a1, 0(sp)
    call put_str
    call say
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

say:
    li t0, '\n'
    sb t0, 0(s3)
    sb zero, 1(s3)
    jab.sys.uart.print line
    ret

put_char:
    sb a0, 0(s3)
    addi s3, s3, 1
    ret

put_str:
    lbu t0, 0(a1)
    beqz t0, 1f
    sb t0, 0(s3)
    addi s3, s3, 1
    addi a1, a1, 1
    j put_str
1:
    ret

put_dec:
    la t1, digits
    addi t1, t1, 31
    sb zero, 0(t1)
    li t2, 10
1:
    remu t3, a0, t2
    divu a0, a0, t2
    addi t3, t3, '0'
    addi t1, t1, -1
    sb t3, 0(t1)
    bnez a0, 1b
2:
    lbu t3, 0(t1)
    beqz t3, 3f
    sb t3, 0(s3)
    addi s3, s3, 1
    addi t1, t1, 1
    j 2b
3:
    ret

.section .rodata
word_none:
    .asciz "stuck: no scenario"
word_scenario:
    .asciz "stuck: scenario "
name_rng:
    .asciz "rng"
name_pad:
    .asciz "pad"
name_api:
    .asciz "api"
name_sound:
    .asciz "sound"
name_disk:
    .asciz "disk"
word_random:
    .asciz "stuck random "
word_then:
    .asciz " then "
word_intact:
    .asciz ", buffer intact"
word_overwritten:
    .asciz ", buffer overwritten"
word_flip:
    .asciz ", flip "
word_pad_read:
    .asciz "stuck pad: read "
word_await:
    .asciz ", await "
word_read:
    .asciz ", read "
word_api_write:
    .asciz "stuck api: write "
word_sound_write:
    .asciz "stuck sound: write "
word_took:
    .asciz " took "
word_disks:
    .asciz "stuck disks "
word_kind:
    .asciz " kind "
api_bytes:
    .ascii "unheard\n"

.section .bss
.balign 8
disks:
    .skip JAB_BLOCK_LIST_SIZE
pad_record:
    .skip JAB_PAD_ENTRY
.balign 8
buffer:
    .skip DRAW_BYTES
snapshot:
    .skip DRAW_BYTES
silence:
    .skip (JAB_SOUND_RING * JAB_SOUND_FRAME_BYTES)
selector:
    .skip 8
line:
    .skip 128
digits:
    .skip 32
