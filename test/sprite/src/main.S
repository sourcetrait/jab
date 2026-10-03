.include "jab.inc"

.set BACKGROUND, 0x00203040
.set TINT, 0x00ff8040

.section .text
.global _start
_start:
    jab.sys.display.open
    bnez a0, no_display
    li t0, JAB_DISPLAY_BASE
    li t1, JAB_DISPLAY_BASE + JAB_DISPLAY_SIZE
    li t2, BACKGROUND
    slli t3, t2, 32
    or t2, t2, t3
1:
    sd t2, 0(t0)
    addi t0, t0, 8
    bltu t0, t1, 1b
    la s0, blend
    la s1, sheet
    li t1, 10
    li t2, 10
    jab.sys.sprite.draw s0, zero, t1, t2
    call report
    li t1, -2
    li t2, -1
    jab.sys.sprite.draw s0, zero, t1, t2
    call report
    li t1, JAB_DISPLAY_WIDTH - 2
    li t2, JAB_DISPLAY_HEIGHT - 1
    jab.sys.sprite.draw s0, zero, t1, t2
    call report
    li t1, 100
    li t2, 100
    li t3, TINT
    jab.sys.sprite.draw s0, zero, t1, t2, t3
    call report
    li t1, 200
    li t2, 200
    li t3, JAB_SPRITE_PLAIN
    li t4, 2 * JAB_SPRITE_SCALE_ONE
    jab.sys.sprite.draw s0, zero, t1, t2, t3, t4
    call report
    li t1, 300
    li t2, 300
    li t3, JAB_SPRITE_PLAIN
    li t4, JAB_SPRITE_SCALE_ONE / 2
    jab.sys.sprite.draw s0, zero, t1, t2, t3, t4
    call report
    li t0, 1
    li t1, 400
    li t2, 400
    jab.sys.sprite.draw s1, t0, t1, t2
    call report
    li t1, 700
    li t2, 100
    li t3, JAB_SPRITE_PLAIN
    li t4, JAB_SPRITE_SCALE_ONE
    li t5, JAB_SPRITE_FLIP_H
    jab.sys.sprite.draw s0, zero, t1, t2, t3, t4, t5
    call report
    li t1, 700
    li t2, 200
    li t5, JAB_SPRITE_FLIP_V
    jab.sys.sprite.draw s0, zero, t1, t2, t3, t4, t5
    call report
    li t1, 700
    li t2, 300
    li t4, 2 * JAB_SPRITE_SCALE_ONE
    li t5, JAB_SPRITE_FLIP_H | JAB_SPRITE_FLIP_V
    jab.sys.sprite.draw s0, zero, t1, t2, t3, t4, t5
    call report
    li t1, 800
    li t2, 100
    li t4, 4 * JAB_SPRITE_SCALE_ONE
    li t5, 90
    jab.sys.sprite.draw s0, zero, t1, t2, t3, t4, t5
    call report
    li t1, 800
    li t2, 300
    li t5, 45
    jab.sys.sprite.draw s0, zero, t1, t2, t3, t4, t5
    call report
    li t1, 800
    li t2, 500
    li t4, 3 * JAB_SPRITE_SCALE_ONE
    li t5, JAB_SPRITE_FLIP_H | 30
    jab.sys.sprite.draw s0, zero, t1, t2, t3, t4, t5
    call report
    la s2, thin
    li t1, 900
    li t2, 100
    jab.sys.sprite.draw s2, zero, t1, t2
    call report
    li t1, 900
    li t2, 200
    li t4, JAB_SPRITE_SCALE_ONE
    li t5, JAB_SPRITE_FLIP_H
    jab.sys.sprite.draw s2, zero, t1, t2, t3, t4, t5
    call report
    li t1, 900
    li t2, 300
    li t4, 3 * JAB_SPRITE_SCALE_ONE
    jab.sys.sprite.draw s2, zero, t1, t2, t3, t4
    call report
    li t1, 900
    li t2, 400
    li t4, JAB_SPRITE_SCALE_ONE / 2
    jab.sys.sprite.draw s2, zero, t1, t2, t3, t4
    call report
    li t1, 900
    li t2, 450
    li t4, 3 * JAB_SPRITE_SCALE_ONE
    li t5, JAB_SPRITE_FLIP_H
    jab.sys.sprite.draw s2, zero, t1, t2, t3, t4, t5
    call report
    li t1, 900
    li t2, 550
    li t4, 4 * JAB_SPRITE_SCALE_ONE
    li t5, 45
    jab.sys.sprite.draw s2, zero, t1, t2, t3, t4, t5
    call report
    li t1, 1000
    li t2, 100
    li t3, 0x00ff0000
    li t4, JAB_SPRITE_SCALE_ONE
    li t5, JAB_SPRITE_SOLID
    jab.sys.sprite.draw s2, zero, t1, t2, t3, t4, t5
    call report
    li t1, 1000
    li t2, 200
    li t4, 3 * JAB_SPRITE_SCALE_ONE
    li t5, JAB_SPRITE_SOLID | JAB_SPRITE_FLIP_H
    jab.sys.sprite.draw s2, zero, t1, t2, t3, t4, t5
    call report
    li t1, 1000
    li t2, 300
    li t3, 0x0000ff00
    li t4, JAB_SPRITE_SCALE_ONE
    li t5, JAB_SPRITE_SOLID
    jab.sys.sprite.draw s0, zero, t1, t2, t3, t4, t5
    call report
    li t1, 1000
    li t2, 400
    li t4, 4 * JAB_SPRITE_SCALE_ONE
    li t5, JAB_SPRITE_SOLID | 45
    jab.sys.sprite.draw s2, zero, t1, t2, t3, t4, t5
    call report
    li t0, 2
    li t1, 500
    li t2, 500
    jab.sys.sprite.draw s1, t0, t1, t2
    call report
    li t1, 600
    li t2, 600
    li t3, JAB_SPRITE_PLAIN
    li t4, JAB_SPRITE_SCALE_MAX + 1
    jab.sys.sprite.draw s0, zero, t1, t2, t3, t4
    call report
    li t1, 5000
    li t2, 5000
    jab.sys.sprite.draw s0, zero, t1, t2
    call report
    jab.sys.display.flip
2:
    jab.sys.display.await
    j 2b

no_display:
    jab.sys.uart.print msg_no_display
    jab.sys.exit 1

report:
    la t0, line
    li t1, 'd'
    sb t1, 0(t0)
    li t1, 'r'
    sb t1, 1(t0)
    li t1, 'a'
    sb t1, 2(t0)
    li t1, 'w'
    sb t1, 3(t0)
    li t1, ' '
    sb t1, 4(t0)
    addi t1, a0, '0'
    sb t1, 5(t0)
    li t1, '\n'
    sb t1, 6(t0)
    sb zero, 7(t0)
    jab.sys.uart.print line
    ret

.section .rodata
.balign 4
blend:
    .word 4, 3, 1, 0
    .word 0xffff0000, 0x8000ff00, 0x000000ff, 0xffffffff
    .word 0x40ff8000, 0xc0ffffff, 0xff102030, 0x01ffffff
    .word 0x7f7f7f7f, 0xfe000000, 0x00ffffff, 0x80404040
sheet:
    .word 2, 2, 2, 0
    .word 0xff111111, 0xff222222
    .word 0xff333333, 0xff444444
    .word 0xffaa0000, 0xff00aa00
    .word 0xff0000aa, 0x80ffffff
thin:
    .word 6, 4, 1, JAB_SPRITE_SPANNED
    .word 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    .word 0x00000000, 0x00000000, 0xffff0000, 0xff00ff00, 0x00000000, 0x00000000
    .word 0x00000000, 0xff0000ff, 0x00123456, 0x00000000, 0x80ffffff, 0x00000000
    .word 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0xffffff00
    .2byte 6, 0
    .2byte 2, 3
    .2byte 1, 4
    .2byte 5, 5
msg_no_display:
    .asciz "sprite: no display\n"

.section .bss
line:
    .skip 16
