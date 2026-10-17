.include "riscv.inc"
.include "qemu_virt.inc"
.include "jab.inc"
.include "hart.inc"

.set START_TEXT_BYTES, 320

.section .text

.global start_check
start_check:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s0, 48(sp)
    sd s1, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    sd s6, 0(sp)
    la t0, start_cursor
    la t1, start_text
    sd t1, 0(t0)                            # a refusal's line, empty
    li s0, JAB_PROGRAM_BASE
    lwu t0, JAB_IMAGE_MAGIC_AT(s0)
    li t1, JAB_IMAGE_MAGIC
    bne t0, t1, 90f                         # no magic: an image from before the header, entered as ever
    lwu s1, JAB_IMAGE_VERSION_AT(s0)
    li t0, JAB_IMAGE_VERSION
    beq s1, t0, 1f
    la a0, why_version
    call refused_text
    mv a0, s1
    call line_dec
    j start_refused
1:
    lwu s1, JAB_IMAGE_FLAGS_AT(s0)
    li t0, JAB_IMAGE_DECLARED
    not t0, t0
    and t0, s1, t0                          # a bit past the declared one
    beqz t0, 2f
    la a0, why_flags
    call refused_text
    mv a0, s1
    call line_hex
    j start_refused
2:
    lwu s2, JAB_IMAGE_OFFSET_AT(s0)
    lwu s3, JAB_IMAGE_LENGTH_AT(s0)
    lwu s4, JAB_IMAGE_CRC_AT(s0)
    bnez s1, 10f
    la a0, why_undeclared_length            # undeclared: the offset, the length, and the CRC 0
    bnez s3, 3f
    la a0, why_undeclared_offset
    bnez s2, 3f
    la a0, why_undeclared_crc
    bnez s4, 3f
    j 90f                                   # no list: the legacy path, through the jump
3:
    call refused_text
    j start_refused
10:
    la a0, why_no_length
    beqz s3, 3b
    li t0, JAB_DECL_OFFSET
    beq s2, t0, 11f
    la a0, why_offset
    call refused_text
    mv a0, s2
    call line_dec
    j start_refused
11:
    li t0, JAB_DECL_LEAST
    bltu s3, t0, 12f
    li t0, JAB_DECL_MAX
    bleu s3, t0, 13f
12:
    la a0, why_length
    call refused_text
    mv a0, s3
    call line_dec
    j start_refused
13:
    add s2, s0, s2                          # the declaration
    mv a0, s2
    mv a1, s3
    call gz_crc32
    beq a0, s4, 14f
    mv s5, a0
    la a0, why_crc
    call refused_text
    mv a0, s5
    call line_hex
    la a0, why_crc_header
    call line_text
    mv a0, s4
    call line_hex
    j start_refused
14:
    lbu s5, JAB_DECL_COUNT(s2)              # the specs listed
    beqz s5, 15f
    li t0, JAB_DECL_SPECS_MAX
    bleu s5, t0, 16f
15:
    la a0, why_count
    call refused_text
    mv a0, s5
    call line_dec
    j start_refused
16:
    li t0, JAB_DECL_SPEC_BYTES
    mul t0, s5, t0
    addi t0, t0, JAB_DECL_SPECS
    beq t0, s3, 20f                         # the length exactly the list's
    la a0, why_length
    call refused_text
    mv a0, s3
    call line_dec
    la a0, why_for
    call line_text
    mv a0, s5
    call line_dec
    la a0, why_specs
    call line_text
    j start_refused
20:
    call spec_name
    beqz a0, 50f                            # no name: a custom machine, the minimum alone
    mv s3, a0                               # the name, in the bootargs
    mv s4, a1                               # its length
    li t0, JAB_SPEC_NAME_BYTES
    bgtu s4, t0, 30f                        # longer than any entry's: not listed
    addi s1, s2, JAB_DECL_SPECS             # the entry
    mv s6, s5                               # the entries left
21:
    beqz s6, 30f
    li t2, 0                                # the byte
22:
    li t0, JAB_SPEC_NAME_BYTES
    bgeu t2, t0, 40f                        # every byte alike: this entry
    add t3, s1, t2
    lbu t3, JAB_SPEC_NAME(t3)
    li t4, 0                                # past the name, the entry's padding
    bgeu t2, s4, 23f
    add t4, s3, t2
    lbu t4, 0(t4)
    addi t5, t4, -'A'
    li t6, 26
    bgeu t5, t6, 23f
    addi t4, t4, ('a' - 'A')                # the name in any case, the entries lowercase
23:
    bne t3, t4, 24f
    addi t2, t2, 1
    j 22b
24:
    addi s1, s1, JAB_DECL_SPEC_BYTES
    addi s6, s6, -1
    j 21b
30:
    la a0, msg_spec                         # the name no entry of the image's carries
    call line_text
    mv a0, s3
    mv a1, s4
    call line_bytes
    la a0, why_not_listed
    call line_text
    j start_refused
40:
    call harts_masks
    mv s6, a0                               # online
    la t0, harts_discovered
    ld t0, 0(t0)
    cpop t1, t0
    lhu t2, JAB_SPEC_CORES(s1)
    bne t1, t2, 41f
    beq s6, t0, 42f                         # its cores discovered, every one online
41:
    la a0, msg_spec
    call line_text
    mv a0, s3
    mv a1, s4
    call line_bytes
    la a0, why_wants
    call line_text
    lhu a0, JAB_SPEC_CORES(s1)
    call line_dec
    la a0, why_harts
    call line_text
    la t0, harts_discovered
    ld t0, 0(t0)
    cpop a0, t0
    call line_dec
    la a0, why_discovered
    call line_text
    cpop a0, s6
    call line_dec
    la a0, why_online
    call line_text
    j start_refused
42:
    lhu t1, JAB_SPEC_RAM_GIB(s1)
    slli t1, t1, 30
    la t0, ram_installed
    ld t0, 0(t0)
    beq t0, t1, 50f                         # its RAM installed, no more and no less
    la a0, msg_spec
    call line_text
    mv a0, s3
    mv a1, s4
    call line_bytes
    la a0, why_wants
    call line_text
    lhu a0, JAB_SPEC_RAM_GIB(s1)
    call line_dec
    la a0, why_gib
    call line_text
    la t0, ram_installed
    ld a0, 0(t0)
    call line_hex
    la a0, why_installed
    call line_text
    j start_refused
50:
.ifdef DEBUG
    la a0, knob_nominimum
    call knob_value
    li t0, 1
    beq a0, t0, 90f                         # the knob skips the minimum and nothing else
.pushsection .rodata
knob_nominimum:
    .asciz "jab.nominimum="
.popsection
.endif
    call harts_masks
    cpop s6, a0                             # the harts online
    lhu s1, JAB_DECL_BASE(s2)               # the program's base demand
    bgeu s6, s1, 90f
    la a0, msg_short
    call line_text
    mv a0, s6
    call line_dec
    la a0, why_for
    call line_text
    mv a0, s1
    call line_dec
    j start_refused
90:
    ld ra, 56(sp)
    ld s0, 48(sp)
    ld s1, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    ld s6, 0(sp)
    addi sp, sp, 64
    ret

start_refused:                              # the line made: recorded, and the shutdown ends the run
    la t0, start_cursor
    ld t1, 0(t0)
    sb zero, 0(t1)
    la a0, start_text
    j fatal_plain

refused_text:                               # a0 the reason, after the declaration's refusal
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a0, 0(sp)
    la a0, msg_refused
    call line_text
    ld a0, 0(sp)
    call line_text
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

line_text:                                  # a0 a string, appended to the line
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s0, 0(sp)
    mv s0, a0
1:
    lbu a0, 0(s0)
    beqz a0, 2f
    call line_byte
    addi s0, s0, 1
    j 1b
2:
    ld ra, 8(sp)
    ld s0, 0(sp)
    addi sp, sp, 16
    ret

line_bytes:                                 # a0 the bytes, a1 how many
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    mv s0, a0
    add s1, a0, a1
1:
    bgeu s0, s1, 2f
    lbu a0, 0(s0)
    call line_byte
    addi s0, s0, 1
    j 1b
2:
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    addi sp, sp, 32
    ret

line_dec:                                   # a0 a value, in decimal
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    addi s0, sp, 31                         # the digits, last first, under the saved registers
    sb zero, 0(s0)
    li t3, 10
1:
    remu t4, a0, t3
    divu a0, a0, t3
    addi t4, t4, '0'
    addi s0, s0, -1
    sb t4, 0(s0)
    bnez a0, 1b
    mv a0, s0
    call line_text
    ld ra, 40(sp)
    ld s0, 32(sp)
    addi sp, sp, 48
    ret

line_hex:                                   # a0 a value, as 0x and sixteen digits
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    mv s0, a0
    li a0, '0'
    call line_byte
    li a0, 'x'
    call line_byte
    li s1, 60
1:
    srl a0, s0, s1
    andi a0, a0, 0xf
    li t0, 10
    bltu a0, t0, 2f
    addi a0, a0, ('a' - 10)
    j 3f
2:
    addi a0, a0, '0'
3:
    call line_byte
    addi s1, s1, -4
    bgez s1, 1b
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    addi sp, sp, 32
    ret

line_byte:                                  # a0 a byte, appended while the line has room for it and its end
    la t0, start_cursor
    ld t1, 0(t0)
    la t2, start_text
    addi t2, t2, (START_TEXT_BYTES - 1)
    bgeu t1, t2, 1f
    sb a0, 0(t1)
    addi t1, t1, 1
    sd t1, 0(t0)
1:
    ret

.section .rodata
msg_refused:
    .asciz "jab: declaration refused: "
why_version:
    .asciz "version "
why_flags:
    .asciz "flags "
why_undeclared_length:
    .asciz "flags 0 with a length"
why_undeclared_offset:
    .asciz "flags 0 with an offset"
why_undeclared_crc:
    .asciz "flags 0 with a CRC"
why_no_length:
    .asciz "flags 1 with length 0"
why_offset:
    .asciz "offset "
why_length:
    .asciz "length "
why_crc:
    .asciz "CRC "
why_crc_header:
    .asciz " computed, the header's "
why_count:
    .asciz "spec count "
why_for:
    .asciz " for "
why_specs:
    .asciz " specs"
msg_spec:
    .asciz "jab: spec "
why_not_listed:
    .asciz " not listed"
why_wants:
    .asciz " wants "
why_harts:
    .asciz " harts: "
why_discovered:
    .asciz " discovered, "
why_online:
    .asciz " online"
why_gib:
    .asciz " GiB of RAM: "
why_installed:
    .asciz " bytes installed"
msg_short:
    .asciz "jab: harts short of the program's demand: "

.section .bss
.balign 8
start_cursor:
    .skip 8
start_text:
    .skip START_TEXT_BYTES
