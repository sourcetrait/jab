.include "riscv.inc"
.include "qemu_virt.inc"
.include "jab.inc"
.include "hart.inc"

.section .text

.global sys_harts_reserve
sys_harts_reserve:                          # a0 the count: every online secondary the reservation's, the count its floor
    ld s0, 80(sp)
    li s2, JAB_RESERVE_ALREADY
    la t0, owners_reserved
    ld t0, 0(t0)
    bnez t0, 8f
    li a0, JAB_OWNER_NONE
    call owned_mask                         # every online secondary, none owned before a reservation
    mv s1, a0
    li s2, JAB_RESERVE_SHORT
    cpop t0, s1
    bltu t0, s0, 8f                         # fewer than the count: nothing reserved
    mv a0, s1
    call working
    li s2, JAB_RESERVE_BUSY
    bnez a0, 8f                             # a worker running
    mv a0, s1
    li a1, JAB_OWNER_RESERVED
    call set_owner
    la t0, owners_floor
    sd s0, 0(t0)
    la t0, owners_reserved
    li t1, 1
    sd t1, 0(t0)
.ifdef DEBUG
    la a0, knob_claimids
    call knob_value
    bltz a0, 1f                             # no knob: every id the run's
    li t0, CLAIM_IDS
    bleu a0, t0, 2f
    mv a0, t0                               # past the range: every id left
2:
    sub t0, t0, a0
    la t1, owners_next
    sd t0, 0(t1)                            # jab.claimids=<n>: n ids left, the limit proved without 2^63 claims
1:
    la a0, msg_reserved
    call debug_puts
    mv a0, s0
    call debug_put_dec
    la a0, msg_grant
    call debug_puts
    mv a0, s1
    call debug_put_hex
    li a0, '\n'
    call debug_putc
.endif
    sd s1, 88(sp)
    li s2, JAB_RESERVE_OK
    j 9f
8:
    sd zero, 88(sp)
9:
    sd s2, 80(sp)
    j trap_return

.global sys_harts_claim
sys_harts_claim:                            # a0 a mask: its harts from the reservation's grant to a new claim, a1 its id
    ld s0, 80(sp)
    li s3, JAB_CLAIM_UNRESERVED
    la t0, owners_reserved
    ld t0, 0(t0)
    beqz t0, 8f
    li a0, JAB_OWNER_RESERVED
    call owned_mask
    mv s1, a0                               # the reservation's grant
    li s3, JAB_CLAIM_HARTS
    beqz s0, 8f                             # an empty mask
    not t0, s1
    and t0, t0, s0
    bnez t0, 8f                             # a hart outside the grant: hart 0, offline, failed, or claimed
    mv a0, s0
    call working
    li s3, JAB_CLAIM_BUSY
    bnez a0, 8f                             # a worker on a hart of it
    not t0, s0
    and t0, t0, s1
    cpop t0, t0                             # the grant it would leave
    la t1, owners_floor
    ld t1, 0(t1)
    li s3, JAB_CLAIM_FLOOR
    bltu t0, t1, 8f
    la t0, owners_next
    ld s2, 0(t0)
    li t1, CLAIM_IDS
    li s3, JAB_CLAIM_SPENT
    bgeu s2, t1, 8f                         # the run's ids spent: nothing moved, the counter as it stands
    addi t1, s2, 1
    sd t1, 0(t0)
    addi s2, s2, OWNER_FIRST_CLAIM          # the claim's id, 2 up to 2^63 - 1, fresh for the run
    mv a0, s0
    mv a1, s2
    call set_owner
.ifdef DEBUG
    la a0, msg_claimed
    call debug_puts
    mv a0, s2
    call debug_put_dec
    li a0, ' '
    call debug_putc
    mv a0, s0
    call debug_put_hex
    li a0, '\n'
    call debug_putc
.endif
    sd s2, 88(sp)
    li s3, JAB_CLAIM_OK
    j 9f
8:
    sd zero, 88(sp)
9:
    sd s3, 80(sp)
    j trap_return

.global sys_harts_release
sys_harts_release:                          # a0 a claim's id: its harts back to the reservation, a1 them
    ld s0, 80(sp)
    li s2, JAB_RELEASE_UNKNOWN
    li t0, OWNER_FIRST_CLAIM
    bltu s0, t0, 8f                         # none and the reservation are no claim's
    mv a0, s0
    call owned_mask
    mv s1, a0
    beqz s1, 8f                             # no hart holds it
    mv a0, s1
    call working
    li s2, JAB_RELEASE_BUSY
    bnez a0, 8f
    mv a0, s1
    li a1, JAB_OWNER_RESERVED
    call set_owner
.ifdef DEBUG
    la a0, msg_released
    call debug_puts
    mv a0, s0
    call debug_put_dec
    li a0, ' '
    call debug_putc
    mv a0, s1
    call debug_put_hex
    li a0, '\n'
    call debug_putc
.endif
    sd s1, 88(sp)
    li s2, JAB_RELEASE_OK
    j 9f
8:
    sd zero, 88(sp)
9:
    sd s2, 80(sp)
    j trap_return

.global sys_harts_owned
sys_harts_owned:                            # a0 an owner: a0 the online secondaries holding it
    ld a0, 80(sp)
    call owned_mask
    sd a0, 80(sp)
    j trap_return

owned_mask:                                 # a0 an owner: a0 the online secondaries holding it, read at the call
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a0, 0(sp)
    call harts_masks
    andi t4, a0, -2                         # the online secondaries
    ld t5, 0(sp)                            # the owner
    li a0, 0
    li t1, 1                                # the hart
    la t2, hart_areas
    li t3, (HART_AREA_BYTES + HART_STACK_BYTES)
    add t2, t2, t3                          # its record
1:
    li t3, JAB_HARTS_MAX
    bgeu t1, t3, 3f
    srl t3, t4, t1
    andi t3, t3, 1
    beqz t3, 2f
    ld t3, HART_OWNER(t2)
    bne t3, t5, 2f
    li t3, 1
    sll t3, t3, t1
    or a0, a0, t3
2:
    addi t1, t1, 1
    li t3, HART_AREA_BYTES
    add t2, t2, t3
    j 1b
3:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

working:                                    # a0 a mask of harts: a0 those running a worker, read with acquire
    li t0, 0                                # those working
    li t1, 0                                # the hart
    la t2, hart_areas
    li t3, HART_STACK_BYTES
    add t2, t2, t3                          # its record
1:
    li t3, JAB_HARTS_MAX
    bgeu t1, t3, 3f
    srl t3, a0, t1
    andi t3, t3, 1
    beqz t3, 2f
    ld t3, HART_WORK(t2)
    beqz t3, 2f
    li t3, 1
    sll t3, t3, t1
    or t0, t0, t3
2:
    addi t1, t1, 1
    li t3, HART_AREA_BYTES
    add t2, t2, t3
    j 1b
3:
    fence r, rw                             # a worker's exit, released before its idle, before what follows
    mv a0, t0
    ret

set_owner:                                  # a0 a mask of harts, a1 an owner: every hart of the mask its owner
    li t1, 0                                # the hart
    la t2, hart_areas
    li t3, HART_STACK_BYTES
    add t2, t2, t3                          # its record
1:
    li t3, JAB_HARTS_MAX
    bgeu t1, t3, 3f
    srl t3, a0, t1
    andi t3, t3, 1
    beqz t3, 2f
    sd a1, HART_OWNER(t2)
2:
    addi t1, t1, 1
    li t3, HART_AREA_BYTES
    add t2, t2, t3
    j 1b
3:
    ret

.ifdef DEBUG
.pushsection .rodata
msg_reserved:
    .asciz "jab: harts reserved "
msg_grant:
    .asciz " grant "
msg_claimed:
    .asciz "jab: harts claimed "
msg_released:
    .asciz "jab: harts released "
knob_claimids:
    .asciz "jab.claimids="
.popsection
.endif

.section .bss
.balign 8
.global owners_reserved
owners_reserved:
    .skip 8
owners_floor:
    .skip 8
owners_next:
    .skip 8
