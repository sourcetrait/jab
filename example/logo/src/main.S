.include "jab.inc"

.set DISK, 1
.set WIDTH, 480
.set HEIGHT, 640
.set SPRITE_BYTES, (JAB_SPRITE_PIXELS + HEIGHT * (WIDTH * 4 + 4))
.set PNG_BYTES, 32768
.set X, ((JAB_DISPLAY_WIDTH - WIDTH) / 2)
.set Y, ((JAB_DISPLAY_HEIGHT - HEIGHT) / 2)

.section .text
.global _start
_start:
    la t0, rec
    li t1, DISK
    li t2, JAB_ROMFS_ROOT
    jab.sys.romfs.find t0, t1, t2, path
    bnez a0, no_file
    la t0, rec
    lwu s0, JAB_ROMFS_OFFSET(t0)
    li s1, 0                    # where in the file
    li s2, 0                    # how much is here
1:
    la t0, png
    add t0, t0, s2
    li t1, DISK
    mv t2, s0
    mv t3, s1
    li t4, PNG_BYTES
    sub t4, t4, s2
    jab.sys.romfs.read t0, t1, t2, t3, t4
    beqz a0, 2f
    add s2, s2, a0
    mv s1, a1
    bnez s1, 1b
2:
    la t0, sprite
    la t1, png
    mv t2, s2
    jab.sys.sprite.png t0, t1, t2, SPRITE_BYTES
    bnez a0, bad_png
    jab.sys.display.open
    bnez a0, no_display
    la t0, sprite
    li t1, X
    li t2, Y
    jab.sys.sprite.draw t0, zero, t1, t2
    jab.sys.display.flip
3:
    jab.sys.display.await
    j 3b

no_file:
    jab.sys.uart.print msg_no_file
    jab.sys.exit 1
bad_png:
    jab.sys.uart.print msg_bad_png
    jab.sys.exit 1
no_display:
    jab.sys.uart.print msg_no_display
    jab.sys.exit 1

.section .rodata
path:
    .asciz "/lowkick.480x640.png"
msg_no_file:
    .asciz "logo: the png is not on the romfs\n"
msg_bad_png:
    .asciz "logo: the png would not decode\n"
msg_no_display:
    .asciz "logo: no display\n"

.section .bss
.balign 8
rec:
    .skip JAB_ROMFS_ENTRY
png:
    .skip PNG_BYTES
sprite:
    .skip SPRITE_BYTES
