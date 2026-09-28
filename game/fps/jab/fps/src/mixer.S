# mixer.S: the game's sounds into the kernel's stream. The sounds the
# content holds load at start by name, mono 16-bit at the kernel's rate
# as the tree carries them, a missing one named on the UART and silent.
# MIX_CHANNELS channels each play one sound with a gain a side; a frame
# asks the stream for its room, keeps MIX_AHEAD frames queued beyond
# what plays, and mixes that many frames of every channel into a stereo
# buffer, clipped, and writes them; the kernel's periods in flight then
# land a sound about a fifth of a second after its start. A sound
# starts at the player, centred and full, or from a world point: full
# within MIX_NEAR metres and falling straight to nothing at MIX_FAR,
# panned by the point's share along the camera's level right.

.set MIX_CHANNELS, 8
.set MIX_AHEAD, (JAB_SOUND_PERIOD * 3)
.set MIX_MAX, 4096
.set CHANNEL_DATA, 0
.set CHANNEL_FRAMES, 8
.set CHANNEL_POSITION, 16
.set CHANNEL_LEFT, 24
.set CHANNEL_RIGHT, 28
.set CHANNEL_SIZE, 32
.set SOUND_BYTES, (8 * 1024 * 1024)

.section .rodata
.balign 8
sound_stems:
    .dword word_sound_g1_shot, word_sound_g1_reload, word_sound_g1_empty
    .dword word_sound_g1_bolt, word_sound_footstep1, word_sound_footstep2
    .dword word_sound_servo, word_sound_alert, word_sound_spark
    .dword word_sound_struck, word_sound_destroy, word_sound_pickup
    .dword word_sound_door_open, word_sound_door_close, word_sound_gate
    .dword word_sound_respawn
k_mix_near_d:
    .double 2.0
k_mix_range_d:
    .double 38.0
k_mix_pan_d:
    .double 0.6
# A sound's full gain, three eighths in 256ths, so three sounds
# together stay under full scale
k_gain_full_d:
    .double 96.0
k_mix_level_eps_d:
    .double 0.001
word_sound_g1_shot:
    .asciz "g1_shot"
word_sound_g1_reload:
    .asciz "g1_reload"
word_sound_g1_empty:
    .asciz "g1_empty"
word_sound_g1_bolt:
    .asciz "g1_bolt"
word_sound_footstep1:
    .asciz "footstep1"
word_sound_footstep2:
    .asciz "footstep2"
word_sound_servo:
    .asciz "servo"
word_sound_alert:
    .asciz "alert"
word_sound_spark:
    .asciz "spark"
word_sound_struck:
    .asciz "struck"
word_sound_destroy:
    .asciz "destroy"
word_sound_pickup:
    .asciz "pickup"
word_sound_door_open:
    .asciz "door_open"
word_sound_door_close:
    .asciz "door_close"
word_sound_gate:
    .asciz "gate"
word_sound_respawn:
    .asciz "respawn"
word_sound_dir:
    .asciz "/sound/"
word_pcm_ext:
    .asciz ".pcm"
msg_sound:
    .asciz "fps: sound "
msg_sounds:
    .asciz "fps: sounds "

.section .text

# sounds_load: every sound of the engine's stems read off the disk at
# /sound/<stem>.pcm into the sound arena, its samples and their count
# into sound_at and sound_frames; one not there, or one that does not
# fit, is named on the UART and left as none; `fps: sounds N loaded, M
# missing` on the UART.
sounds_load:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    la t0, sound_cursor
    la t1, sound_arena
    sd t1, 0(t0)
    li s2, 0                        # the sound
    li s4, 0                        # loaded
    li s5, 0                        # missing
1:
    li t0, SOUND_COUNT
    bgeu s2, t0, 9f
    la a0, tile_path
    la a1, word_sound_dir
    call append_str
    la t1, sound_stems
    slli t0, s2, 3
    add t1, t1, t0
    ld a1, 0(t1)
    call append_str
    la a1, word_pcm_ext
    call append_str
    sb zero, 0(a0)
    la t0, sound_cursor
    ld a0, 0(t0)                    # the buffer
    la t1, sound_arena
    li t2, SOUND_BYTES
    add t1, t1, t2
    sub s3, t1, a0                  # its room
    mv a1, s3
    mv a2, s0
    la a3, tile_path
    call read_file
    beqz a0, 4f
    bgeu a0, s3, 5f
    # kept, the cursor moved on to a word boundary
    la t0, sound_cursor
    ld t1, 0(t0)
    la t2, sound_at
    slli t3, s2, 3
    add t2, t2, t3
    sd t1, 0(t2)
    la t2, sound_frames
    add t2, t2, t3
    srli t4, a0, 1
    sd t4, 0(t2)
    add t1, t1, a0
    addi t1, t1, 3
    andi t1, t1, -4
    sd t1, 0(t0)
    addi s4, s4, 1
    j 8f
4:
    la a1, word_missing_file
    j 6f
5:
    la a1, word_not_fit_arena
6:
    mv s3, a1
    la a0, line
    la a1, msg_sound
    call append_str
    mv a1, s2
    call append_dec
    la a1, word_space
    call append_str
    la a1, tile_path
    call append_str
    mv a1, s3
    call append_str
    call line_end
    addi s5, s5, 1
8:
    addi s2, s2, 1
    j 1b
9:
    la a0, line
    la a1, msg_sounds
    call append_str
    mv a1, s4
    call append_dec
    la a1, word_loaded_comma
    call append_str
    mv a1, s5
    call append_dec
    la a1, word_missing
    call append_str
    call line_end
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    addi sp, sp, 48
    ret

# sound_start: the sound a0 started, at the player when a1 is 1, else
# from the world point fa0, fa1, fa2, doubles: its gains a side from
# the point's distance to the eye and its share along the camera's
# level right; a free channel, else the one nearest its end. A sound
# the tree lacks starts nothing.
sound_start:
    addi sp, sp, -80
    sd ra, 72(sp)
    sd s2, 64(sp)
    sd s3, 56(sp)
    fsd fs0, 48(sp)
    fsd fs1, 40(sp)
    fsd fs2, 32(sp)
    fsd fs3, 24(sp)
    li t0, SOUND_COUNT
    bgeu a0, t0, 9f
    la t0, sound_at
    slli t1, a0, 3
    add t0, t0, t1
    ld s2, 0(t0)                    # the samples
    beqz s2, 9f
    la t0, sound_frames
    add t0, t0, t1
    ld s3, 0(t0)                    # how many
    la t0, k_gain_full_d
    fld fs0, 0(t0)                  # the left gain
    fmv.d fs1, fs0                  # and the right
    bnez a1, 3f
    # from the world: the volume by the distance to the eye
    la t0, camera
    flw ft0, CAM_X(t0)
    fcvt.d.s ft0, ft0
    fsub.d ft0, fa0, ft0            # from the eye to the point
    flw ft1, CAM_Y(t0)
    fcvt.d.s ft1, ft1
    fsub.d ft1, fa1, ft1
    flw ft2, CAM_Z(t0)
    fcvt.d.s ft2, ft2
    fsub.d ft2, fa2, ft2
    fmul.d ft3, ft0, ft0
    fmadd.d ft3, ft1, ft1, ft3
    fmadd.d ft3, ft2, ft2, ft3
    fsqrt.d ft3, ft3                # the distance
    la t0, k_mix_near_d
    fld ft4, 0(t0)
    fle.d t1, ft3, ft4
    bnez t1, 2f
    fsub.d ft4, ft3, ft4
    la t0, k_mix_range_d
    fld ft5, 0(t0)
    fdiv.d ft4, ft4, ft5            # past near, over the range
    la t0, k_one_d
    fld ft5, 0(t0)
    fsub.d ft4, ft5, ft4            # the volume, 1 down to 0
    fcvt.d.w ft5, zero
    fmax.d ft4, ft4, ft5
    fmul.d fs0, fs0, ft4
    fmv.d fs1, fs0
2:
    # the pan: the point's share to the right, along the level right
    # (sin yaw, -cos yaw), over the level distance
    fmul.d ft4, ft0, ft0
    fmadd.d ft4, ft1, ft1, ft4
    fsqrt.d ft4, ft4
    la t0, k_mix_level_eps_d
    fld ft5, 0(t0)
    flt.d t1, ft4, ft5
    bnez t1, 3f                     # under the eye: centred
    fsd ft0, 0(sp)
    fsd ft1, 8(sp)
    fsd ft4, 16(sp)
    la t0, camera
    flw fa0, CAM_YAW(t0)
    call sine
    fcvt.d.s fs2, fa0               # sin yaw
    la t0, camera
    flw fa0, CAM_YAW(t0)
    call cosine
    fcvt.d.s fs3, fa0               # cos yaw
    fld ft0, 0(sp)
    fld ft1, 8(sp)
    fld ft4, 16(sp)
    fmul.d ft5, ft0, fs2
    fnmsub.d ft5, ft1, fs3, ft5     # dx sin - dy cos
    fdiv.d ft5, ft5, ft4
    la t0, k_mix_pan_d
    fld ft6, 0(t0)
    fmul.d ft5, ft5, ft6            # the pan, -0.6 to 0.6
    la t0, k_one_d
    fld ft6, 0(t0)
    fsub.d ft7, ft6, ft5            # 1 - pan for the left
    fadd.d ft8, ft6, ft5            # 1 + pan for the right
    fmin.d ft7, ft7, ft6
    fmin.d ft8, ft8, ft6
    fmul.d fs0, fs0, ft7
    fmul.d fs1, fs1, ft8
3:
    fcvt.w.d a4, fs0, rne           # the left gain, 0 to the full
    fcvt.w.d a5, fs1, rne
    # a free channel, else the one with the least left to play
    la t0, channels
    li t1, MIX_CHANNELS
    mv t2, t0                       # the pick
    li t3, -1                       # the least remaining, -1 for none yet
4:
    beqz t1, 6f
    ld t4, CHANNEL_FRAMES(t0)
    ld t5, CHANNEL_POSITION(t0)
    sub t4, t4, t5                  # remaining
    blez t4, 5f
    bltz t3, 45f
    bge t4, t3, 46f
45:
    mv t3, t4
    mv t2, t0
46:
    addi t0, t0, CHANNEL_SIZE
    addi t1, t1, -1
    j 4b
5:
    mv t2, t0                       # free
6:
    sd s2, CHANNEL_DATA(t2)
    sd s3, CHANNEL_FRAMES(t2)
    sd zero, CHANNEL_POSITION(t2)
    sw a4, CHANNEL_LEFT(t2)
    sw a5, CHANNEL_RIGHT(t2)
9:
    ld ra, 72(sp)
    ld s2, 64(sp)
    ld s3, 56(sp)
    fld fs0, 48(sp)
    fld fs1, 40(sp)
    fld fs2, 32(sp)
    fld fs3, 24(sp)
    addi sp, sp, 80
    ret

# mixer_update: the stream kept MIX_AHEAD frames ahead: what the ring
# lacks of that mixed from every channel and written.
.balign CODE_PAGE
mixer_update:
    addi sp, sp, -16
    sd ra, 8(sp)
    jab.sound.ready
    bnez a0, 9f
    li t0, JAB_SOUND_RING
    sub t0, t0, a1                  # queued
    li t1, MIX_AHEAD
    sub t1, t1, t0                  # wanted
    blez t1, 9f
    li t0, MIX_MAX
    ble t1, t0, 1f
    mv t1, t0
1:
    mv a2, t1                       # the frames
    # the buffer cleared, then each channel added
    la t0, mixbuf
    slli t1, a2, 3
    add t1, t1, t0
2:
    sd zero, 0(t0)
    addi t0, t0, 8
    bltu t0, t1, 2b
    la t2, channels
    li t3, MIX_CHANNELS
3:
    beqz t3, 6f
    ld t4, CHANNEL_FRAMES(t2)
    ld t5, CHANNEL_POSITION(t2)
    sub t4, t4, t5                  # remaining
    blez t4, 5f
    bge a2, t4, 31f
    mv t4, a2                       # this frame's share
31:
    ld t0, CHANNEL_DATA(t2)
    slli t6, t5, 1
    add t0, t0, t6                  # the next sample
    lw a3, CHANNEL_LEFT(t2)
    lw a4, CHANNEL_RIGHT(t2)
    la t1, mixbuf
    add t5, t5, t4
    sd t5, CHANNEL_POSITION(t2)     # advanced
4:
    lh a5, 0(t0)
    lw a6, 0(t1)
    mul a7, a5, a3
    srai a7, a7, 8
    add a6, a6, a7
    sw a6, 0(t1)
    lw a6, 4(t1)
    mul a7, a5, a4
    srai a7, a7, 8
    add a6, a6, a7
    sw a6, 4(t1)
    addi t0, t0, 2
    addi t1, t1, 8
    addi t4, t4, -1
    bnez t4, 4b
5:
    addi t2, t2, CHANNEL_SIZE
    addi t3, t3, -1
    j 3b
6:
    # clipped into 16-bit pairs, in place from the front
    la t0, mixbuf
    mv t1, t0
    mv t2, a2
    li t5, 32767
    li t6, -32768
7:
    lw t3, 0(t0)
    lw t4, 4(t0)
    bge t5, t3, 71f
    mv t3, t5
71:
    bge t3, t6, 72f
    mv t3, t6
72:
    bge t5, t4, 73f
    mv t4, t5
73:
    bge t4, t6, 74f
    mv t4, t6
74:
    sh t3, 0(t1)
    sh t4, 2(t1)
    addi t0, t0, 8
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, 7b
    la t0, mixbuf
    mv t1, a2
    jab.sound.write t0, t1
9:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.section .bss
.balign 8
sound_cursor:
    .skip 8
# Each sound's samples in the arena and their count, 0 for none
sound_at:
    .skip (SOUND_COUNT * 8)
sound_frames:
    .skip (SOUND_COUNT * 8)
channels:
    .skip (MIX_CHANNELS * CHANNEL_SIZE)
mixbuf:
    .skip (MIX_MAX * 8)
.balign 8
sound_arena:
    .skip SOUND_BYTES
