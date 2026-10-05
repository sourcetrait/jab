.include "jab_keys.inc"
.include "jab_pad.inc"

.set JAB_PROGRAM_BASE, 0x80a00000
.set JAB_PROGRAM_SIZE, 0xff600000
.set JAB_STACK_TOP, (JAB_PROGRAM_BASE + JAB_PROGRAM_SIZE)

.set JAB_DISPLAY_BASE, 0x80200000
.set JAB_DISPLAY_WIDTH, 1920
.set JAB_DISPLAY_HEIGHT, 1080
.set JAB_DISPLAY_PITCH, (JAB_DISPLAY_WIDTH * 4)
.set JAB_DISPLAY_SIZE, (JAB_DISPLAY_PITCH * JAB_DISPLAY_HEIGHT)
.set JAB_DISPLAY_FPS_TARGET, 60
.set JAB_DISPLAY_FPS_CAP, 60

.set JAB_TIME_HZ, 10000000

.set JAB_AWAIT_DISPLAY, 1
.set JAB_AWAIT_KEYBOARD, 2
.set JAB_AWAIT_API, 4
.set JAB_AWAIT_PAD, 8
.set JAB_AWAIT_SOUND, 16

.set JAB_SYS_EXIT, 1
.set JAB_SYS_PRINT, 2
.set JAB_SYS_UART_PRINT, 3
.set JAB_SYS_DISPLAY_OPEN, 4
.set JAB_SYS_DISPLAY_READY, 5
.set JAB_SYS_DISPLAY_FLIP, 6
.set JAB_SYS_DISPLAY_PRINT, 7
.set JAB_SYS_AWAIT, 8
.set JAB_SYS_DISPLAY_FLIP_RECT, 9
.set JAB_SYS_KEYBOARD_INPUT, 10
.set JAB_SYS_BLOCK_LIST, 11
.set JAB_SYS_BLOCK_FIND, 12
.set JAB_SYS_BLOCK_READ, 13
.set JAB_SYS_BLOCK_WRITE, 14
.set JAB_SYS_ROMFS_LIST, 15
.set JAB_SYS_ROMFS_FIND, 16
.set JAB_SYS_ROMFS_READ, 17
.set JAB_SYS_TAR_LIST, 18
.set JAB_SYS_TAR_FIND, 19
.set JAB_SYS_GZ_SIZE, 20
.set JAB_SYS_GZ_READ, 21
.set JAB_SYS_CHECKSUM, 22
.set JAB_SYS_HASH, 23
.set JAB_SYS_API_WRITE, 24
.set JAB_SYS_API_READ, 25
.set JAB_SYS_PNG_SIZE, 26
.set JAB_SYS_SPRITE_PNG, 27
.set JAB_SYS_SPRITE_DRAW, 28
.set JAB_SYS_SPRITE_LOAD, 29
.set JAB_SYS_DISPLAY_FLIP_RECTS, 30
.set JAB_SYS_KERNEL_FLAGS, 31
.set JAB_SYS_PAD_READ, 32
.set JAB_SYS_PAD_INPUT, 33
.set JAB_SYS_PAD_AXIS, 34
.set JAB_SYS_DISPLAY_TEXT, 35
.set JAB_SYS_PAD_NAME, 36
.set JAB_SYS_RANDOM, 37
.set JAB_SYS_SOUND_OPEN, 38
.set JAB_SYS_SOUND_WRITE, 39
.set JAB_SYS_SOUND_READY, 40
.set JAB_SYS_MIDI_PROGRAM, 41
.set JAB_SYS_MIDI_NOTE, 42
.set JAB_SYS_MIDI_CONTROL, 43
.set JAB_SYS_MIDI_BEND, 44
.set JAB_SYS_MIDI_INSTRUMENT, 45
.set JAB_SYS_MIDI_SILENCE, 46
.set JAB_SYS_MIDI_PLAY, 47
.set JAB_SYS_MIDI_STOP, 48
.set JAB_SYS_MIDI_PLAYING, 49
.set JAB_SYS_MIDI_SOUNDFONT, 50
.set JAB_SYS_HARTS, 51

.set JAB_HARTS_MAX, 8

.set JAB_TEXT_WIDTH, 12
.set JAB_TEXT_HEIGHT, 24
.set JAB_TEXT_SCALE_ONE, 256
.set JAB_TEXT_SCALE_MAX, 65536
.set JAB_TEXT_PLAIN, 0x00ffffff
.set JAB_TEXT_BOLD, 1

.set JAB_PAD_NAME_BYTES, 128

.set JAB_SOUND_RATE, 48000
.set JAB_SOUND_CHANNELS, 2
.set JAB_SOUND_FRAME_BYTES, 4
.set JAB_SOUND_PERIOD, 960
.set JAB_SOUND_PERIODS, 8
.set JAB_SOUND_RING, 8192

.set JAB_MIDI_CHANNELS, 16
.set JAB_MIDI_VOICES, 16
.set JAB_MIDI_FONT_VOICES, 32
.set JAB_MIDI_TRACKS, 32
.set JAB_MIDI_PERCUSSION, 9
.set JAB_MIDI_BEND_CENTER, 8192
.set JAB_MIDI_CC_BANK, 0
.set JAB_MIDI_CC_VOLUME, 7
.set JAB_MIDI_CC_PAN, 10
.set JAB_MIDI_CC_EXPRESSION, 11
.set JAB_MIDI_CC_PEDAL, 64
.set JAB_MIDI_CC_ALL_SOUND_OFF, 120
.set JAB_MIDI_CC_RESET, 121
.set JAB_MIDI_CC_ALL_NOTES_OFF, 123
.set JAB_MIDI_WAVE, 0
.set JAB_MIDI_DUTY, 1
.set JAB_MIDI_ATTACK, 2
.set JAB_MIDI_DECAY, 4
.set JAB_MIDI_RELEASE, 6
.set JAB_MIDI_SUSTAIN, 8
.set JAB_MIDI_VIBRATO, 9
.set JAB_MIDI_VIBRATO_RATE, 10
.set JAB_MIDI_INSTRUMENT_ENTRY, 12
.set JAB_WAVE_SQUARE, 0
.set JAB_WAVE_TRIANGLE, 1
.set JAB_WAVE_SAW, 2
.set JAB_WAVE_SINE, 3
.set JAB_WAVE_NOISE, 4

.set JAB_PAD_ENTRY, 132
.set JAB_PAD_KEYS, 0
.set JAB_PAD_AXES, 4
.set JAB_PAD_AXIS_COUNT, 64
.set JAB_PAD_FULL, 32767
.set JAB_PAD_AXIS_ENTRY, 20
.set JAB_PAD_AXIS_MIN, 0
.set JAB_PAD_AXIS_MAX, 4
.set JAB_PAD_AXIS_FUZZ, 8
.set JAB_PAD_AXIS_FLAT, 12
.set JAB_PAD_AXIS_RES, 16

.set JAB_KERNEL_DEBUG, 1

.set JAB_SPRITE_WIDTH, 0
.set JAB_SPRITE_HEIGHT, 4
.set JAB_SPRITE_FRAMES, 8
.set JAB_SPRITE_FLAGS, 12
.set JAB_SPRITE_PIXELS, 16
.set JAB_SPRITE_SPANNED, 1

.set JAB_RECT_X, 0
.set JAB_RECT_Y, 4
.set JAB_RECT_WIDTH, 8
.set JAB_RECT_HEIGHT, 12
.set JAB_RECT_SIZE, 16

.set JAB_SPRITE_PLAIN, 0x00ffffff
.set JAB_SPRITE_SCALE_ONE, 256
.set JAB_SPRITE_SCALE_MAX, 65536
.set JAB_SPRITE_FLIP_H, 0x10000
.set JAB_SPRITE_FLIP_V, 0x20000
.set JAB_SPRITE_SOLID, 0x40000

.set JAB_PNG_OK, 0
.set JAB_PNG_NOT_PNG, 1
.set JAB_PNG_UNSUPPORTED, 2
.set JAB_PNG_TRUNCATED, 3
.set JAB_PNG_CRC, 4
.set JAB_PNG_ZLIB, 5
.set JAB_PNG_LENGTH, 6
.set JAB_PNG_FILTER, 7
.set JAB_PNG_PALETTE, 8
.set JAB_PNG_FRAMES, 9
.set JAB_PNG_SIZE, 10
.set JAB_PNG_NOT_FOUND, 11
.set JAB_PNG_INPUT, 12
.set JAB_PNG_OUTPUT, 13
.set JAB_PNG_BLOCK, 14
.set JAB_PNG_STORED, 15
.set JAB_PNG_CODES, 16
.set JAB_PNG_SYMBOL, 17
.set JAB_PNG_DISTANCE, 18

.set JAB_GZ_OK, 0
.set JAB_GZ_NOT_GZIP, 1
.set JAB_GZ_TRUNCATED, 2
.set JAB_GZ_CRC, 3
.set JAB_GZ_LENGTH, 4
.set JAB_GZ_INPUT, 5
.set JAB_GZ_OUTPUT, 6
.set JAB_GZ_BLOCK, 7
.set JAB_GZ_STORED, 8
.set JAB_GZ_CODES, 9
.set JAB_GZ_SYMBOL, 10
.set JAB_GZ_DISTANCE, 11

.set JAB_TAR_ENTRY, 296
.set JAB_TAR_PAGE, 16
.set JAB_TAR_LIST_SIZE, (JAB_TAR_PAGE * JAB_TAR_ENTRY)
.set JAB_TAR_BLOCK, 512
.set JAB_TAR_OFFSET, 0
.set JAB_TAR_DATA, 8
.set JAB_TAR_SIZE, 16
.set JAB_TAR_TYPE, 24
.set JAB_TAR_NAME, 32
.set JAB_TAR_NAME_BYTES, 264
.set JAB_TAR_REGULAR, '0'
.set JAB_TAR_HARDLINK, '1'
.set JAB_TAR_SYMLINK, '2'
.set JAB_TAR_CHAR, '3'
.set JAB_TAR_BLOCKDEV, '4'
.set JAB_TAR_DIRECTORY, '5'
.set JAB_TAR_FIFO, '6'

.set JAB_BLOCK_MAX, 8
.set JAB_BLOCK_SECTOR, 512
.set JAB_BLOCK_ENTRY, 40
.set JAB_BLOCK_LIST_SIZE, (JAB_BLOCK_MAX * JAB_BLOCK_ENTRY)
.set JAB_BLOCK_ID, 0
.set JAB_BLOCK_KIND, 1
.set JAB_BLOCK_SECTORS, 8
.set JAB_BLOCK_SERIAL, 16
.set JAB_BLOCK_SERIAL_BYTES, 20
.set JAB_BLOCK_KIND_NONE, 0
.set JAB_BLOCK_KIND_RAW, 1
.set JAB_BLOCK_KIND_ROMFS, 2

.set JAB_ROMFS_ENTRY, 144
.set JAB_ROMFS_PAGE, 16
.set JAB_ROMFS_LIST_SIZE, (JAB_ROMFS_PAGE * JAB_ROMFS_ENTRY)
.set JAB_ROMFS_OFFSET, 0
.set JAB_ROMFS_NEXT, 4
.set JAB_ROMFS_SPEC, 8
.set JAB_ROMFS_SIZE, 12
.set JAB_ROMFS_NAME, 16
.set JAB_ROMFS_NAME_BYTES, 128
.set JAB_ROMFS_ROOT, 0
.set JAB_ROMFS_TYPE, 7
.set JAB_ROMFS_EXEC, 8
.set JAB_ROMFS_HARDLINK, 0
.set JAB_ROMFS_DIRECTORY, 1
.set JAB_ROMFS_REGULAR, 2
.set JAB_ROMFS_SYMLINK, 3
.set JAB_ROMFS_BLOCK, 4
.set JAB_ROMFS_CHAR, 5
.set JAB_ROMFS_SOCKET, 6
.set JAB_ROMFS_FIFO, 7

.macro jab.sys.exit status=0
    li a0, \status
    li a7, JAB_SYS_EXIT
    ecall
.endm

.macro jab.sys.print message
    la a0, \message
    li a7, JAB_SYS_PRINT
    ecall
.endm

.macro jab.sys.uart.print message
    la a0, \message
    li a7, JAB_SYS_UART_PRINT
    ecall
.endm

.macro jab.sys.display.open
    li a7, JAB_SYS_DISPLAY_OPEN
    ecall
.endm

.macro jab.sys.display.ready
    li a7, JAB_SYS_DISPLAY_READY
    ecall
.endm

.macro jab.sys.display.flip
    li a7, JAB_SYS_DISPLAY_FLIP
    ecall
.endm

.macro jab.sys.display.flip.rect
    li a7, JAB_SYS_DISPLAY_FLIP_RECT
    ecall
.endm

.macro jab.sys.display.flip.rects buffer, count
    mv a1, \count
    mv a0, \buffer
    li a7, JAB_SYS_DISPLAY_FLIP_RECTS
    ecall
.endm

.macro jab.sys.kernel.flags
    li a7, JAB_SYS_KERNEL_FLAGS
    ecall
.endm

.macro jab.sys.display.print message
    la a0, \message
    li a7, JAB_SYS_DISPLAY_PRINT
    ecall
.endm

.macro jab.sys.display.text message, x, y, color, style, scale
    .ifb \scale
    li a5, JAB_TEXT_SCALE_ONE
    .else
    mv a5, \scale
    .endif
    .ifb \style
    li a4, 0
    .else
    mv a4, \style
    .endif
    .ifb \color
    li a3, JAB_TEXT_PLAIN
    .else
    mv a3, \color
    .endif
    mv a2, \y
    mv a1, \x
    la a0, \message
    li a7, JAB_SYS_DISPLAY_TEXT
    ecall
.endm

.macro jab.sys.keyboard.input
    li a7, JAB_SYS_KEYBOARD_INPUT
    ecall
.endm

.macro jab.sys.await mask
    li a0, \mask
    li a7, JAB_SYS_AWAIT
    ecall
.endm

.macro jab.sys.display.await
    jab.sys.await JAB_AWAIT_DISPLAY
.endm

.macro jab.sys.keyboard.await
    jab.sys.await JAB_AWAIT_KEYBOARD
.endm

.macro jab.sys.api.await
    jab.sys.await JAB_AWAIT_API
.endm

.macro jab.sys.pad.await
    jab.sys.await JAB_AWAIT_PAD
.endm

.macro jab.sys.pad.read record
    mv a0, \record
    li a7, JAB_SYS_PAD_READ
    ecall
.endm

.macro jab.sys.pad.input
    li a7, JAB_SYS_PAD_INPUT
    ecall
.endm

.macro jab.sys.pad.name buffer
    mv a0, \buffer
    li a7, JAB_SYS_PAD_NAME
    ecall
.endm

.macro jab.sys.random buffer, length
    mv a1, \length
    mv a0, \buffer
    li a7, JAB_SYS_RANDOM
    ecall
.endm

.macro jab.sys.sound.open
    li a7, JAB_SYS_SOUND_OPEN
    ecall
.endm

.macro jab.sys.sound.write buffer, frames
    mv a1, \frames
    mv a0, \buffer
    li a7, JAB_SYS_SOUND_WRITE
    ecall
.endm

.macro jab.sys.sound.ready
    li a7, JAB_SYS_SOUND_READY
    ecall
.endm

.macro jab.sys.sound.await
    li a0, JAB_AWAIT_SOUND
    li a7, JAB_SYS_AWAIT
    ecall
.endm

.macro jab.sys.midi.program channel, program
    mv a1, \program
    mv a0, \channel
    li a7, JAB_SYS_MIDI_PROGRAM
    ecall
.endm

.macro jab.sys.midi.note channel, note, velocity, on
    mv a3, \on
    mv a2, \velocity
    mv a1, \note
    mv a0, \channel
    li a7, JAB_SYS_MIDI_NOTE
    ecall
.endm

.macro jab.sys.midi.note.on channel, note, velocity
    li a3, 1
    mv a2, \velocity
    mv a1, \note
    mv a0, \channel
    li a7, JAB_SYS_MIDI_NOTE
    ecall
.endm

.macro jab.sys.midi.note.off channel, note
    li a3, 0
    li a2, 0
    mv a1, \note
    mv a0, \channel
    li a7, JAB_SYS_MIDI_NOTE
    ecall
.endm

.macro jab.sys.midi.control channel, control, value
    mv a2, \value
    mv a1, \control
    mv a0, \channel
    li a7, JAB_SYS_MIDI_CONTROL
    ecall
.endm

.macro jab.sys.midi.bend channel, value
    mv a1, \value
    mv a0, \channel
    li a7, JAB_SYS_MIDI_BEND
    ecall
.endm

.macro jab.sys.midi.instrument program, spec
    mv a1, \spec
    mv a0, \program
    li a7, JAB_SYS_MIDI_INSTRUMENT
    ecall
.endm

.macro jab.sys.midi.silence
    li a7, JAB_SYS_MIDI_SILENCE
    ecall
.endm

.macro jab.sys.midi.play source, length
    mv a1, \length
    mv a0, \source
    li a7, JAB_SYS_MIDI_PLAY
    ecall
.endm

.macro jab.sys.midi.stop
    li a7, JAB_SYS_MIDI_STOP
    ecall
.endm

.macro jab.sys.midi.playing
    li a7, JAB_SYS_MIDI_PLAYING
    ecall
.endm

.macro jab.sys.midi.soundfont buffer, length
    mv a1, \length
    mv a0, \buffer
    li a7, JAB_SYS_MIDI_SOUNDFONT
    ecall
.endm

.macro jab.sys.harts
    li a7, JAB_SYS_HARTS
    ecall
.endm

.macro jab.sys.pad.axis buffer, code
    li a1, \code
    mv a0, \buffer
    li a7, JAB_SYS_PAD_AXIS
    ecall
.endm

.macro jab.sys.api.write buffer, length
    mv a1, \length
    mv a0, \buffer
    li a7, JAB_SYS_API_WRITE
    ecall
.endm

.macro jab.sys.api.read buffer, capacity
    li a1, \capacity
    mv a0, \buffer
    li a7, JAB_SYS_API_READ
    ecall
.endm

.macro jab.sys.block.list buffer, at=zero, capacity=JAB_BLOCK_MAX
    li a2, \capacity
    mv a1, \at
    mv a0, \buffer
    li a7, JAB_SYS_BLOCK_LIST
    ecall
.endm

.macro jab.sys.block.find serial
    la a0, \serial
    li a7, JAB_SYS_BLOCK_FIND
    ecall
.endm

.macro jab.sys.block.read buffer, id, sector, count
    mv a3, \count
    mv a2, \sector
    mv a1, \id
    mv a0, \buffer
    li a7, JAB_SYS_BLOCK_READ
    ecall
.endm

.macro jab.sys.block.write buffer, id, sector, count
    mv a3, \count
    mv a2, \sector
    mv a1, \id
    mv a0, \buffer
    li a7, JAB_SYS_BLOCK_WRITE
    ecall
.endm

.macro jab.sys.romfs.list buffer, id, directory, offset=zero, capacity=JAB_ROMFS_PAGE
    li a4, \capacity
    mv a3, \offset
    mv a2, \directory
    mv a1, \id
    mv a0, \buffer
    li a7, JAB_SYS_ROMFS_LIST
    ecall
.endm

.macro jab.sys.romfs.find buffer, id, directory, path
    la a3, \path
    mv a2, \directory
    mv a1, \id
    mv a0, \buffer
    li a7, JAB_SYS_ROMFS_FIND
    ecall
.endm

.macro jab.sys.tar.list buffer, archive, length, offset=zero, capacity=JAB_TAR_PAGE
    li a4, \capacity
    mv a3, \offset
    mv a2, \length
    mv a1, \archive
    mv a0, \buffer
    li a7, JAB_SYS_TAR_LIST
    ecall
.endm

.macro jab.sys.tar.find buffer, archive, length, path
    la a3, \path
    mv a2, \length
    mv a1, \archive
    mv a0, \buffer
    li a7, JAB_SYS_TAR_FIND
    ecall
.endm

.macro jab.sys.checksum bytes, size
    mv a1, \size
    mv a0, \bytes
    li a7, JAB_SYS_CHECKSUM
    ecall
.endm

.macro jab.sys.hash bytes, size
    mv a1, \size
    mv a0, \bytes
    li a7, JAB_SYS_HASH
    ecall
.endm

.macro jab.sys.gz.size source, length
    mv a1, \length
    mv a0, \source
    li a7, JAB_SYS_GZ_SIZE
    ecall
.endm

.macro jab.sys.gz.read buffer, source, length, capacity
    mv a3, \capacity
    mv a2, \length
    mv a1, \source
    mv a0, \buffer
    li a7, JAB_SYS_GZ_READ
    ecall
.endm

.macro jab.sys.romfs.read buffer, id, file, offset, length
    mv a4, \length
    mv a3, \offset
    mv a2, \file
    mv a1, \id
    mv a0, \buffer
    li a7, JAB_SYS_ROMFS_READ
    ecall
.endm

.macro jab.sys.png.size source, length
    mv a1, \length
    mv a0, \source
    li a7, JAB_SYS_PNG_SIZE
    ecall
.endm

.macro jab.sys.sprite.png sprite, source, length, capacity, frames=1
    li a4, \frames
    li a3, \capacity
    mv a2, \length
    mv a1, \source
    mv a0, \sprite
    li a7, JAB_SYS_SPRITE_PNG
    ecall
.endm

.macro jab.sys.sprite.load sprite, id, path, capacity
    li a3, \capacity
    la a2, \path
    mv a1, \id
    mv a0, \sprite
    li a7, JAB_SYS_SPRITE_LOAD
    ecall
.endm

.macro jab.sys.sprite.draw sprite, frame, x, y, tint, scale, pose
    .ifb \pose
    li a6, 0
    .else
    mv a6, \pose
    .endif
    .ifb \scale
    li a5, JAB_SPRITE_SCALE_ONE
    .else
    mv a5, \scale
    .endif
    .ifb \tint
    li a4, JAB_SPRITE_PLAIN
    .else
    mv a4, \tint
    .endif
    mv a3, \y
    mv a2, \x
    mv a1, \frame
    mv a0, \sprite
    li a7, JAB_SYS_SPRITE_DRAW
    ecall
.endm
