# jab.inc

The Jab SDK header: the jab.sys.* macros, each a trap into the kernel, with
the constants and the record layouts the calls speak. jab_keys.inc and
jab_pad.inc are included here; jab_f32.inc, jab_f64.inc, and jab_rng.inc
beside it are included by name.

Every kernel call is a `jab.sys.*` macro so the trap boundary is visible at
each site in the name: a program reads where it leaves its own code and
enters the kernel. The mathematics beside this file, jab_f32.inc,
jab_f64.inc, and jab_rng.inc, is carried code expanded in place, never a call
and never a trap, and jab.inc includes none of it: a program includes what it
names and pays for what it uses.

A call's macro loads its operands into a0 on and the call number into a7,
then traps. The kernel puts every register back from its trap frame but the
results, so the scratch an entry names is what the macro itself loaded. An
address a call is given that lies outside the program's window, a string's
start or any byte of a buffer, ends the run.

## .set JAB_PROGRAM_BASE

`addr`: where the loader places the program, the start of the window it owns.

Where a program lives. The machine has 4 GiB of RAM from 0x80000000; the
kernel keeps the first 2 MiB and the framebuffer the 8 MiB after it, and
everything from there to the end of RAM is the program's: QEMU's loader
device places the .jab file at JAB_PROGRAM_BASE.

## .set JAB_PROGRAM_SIZE

`u64`: the bytes the program owns from JAB_PROGRAM_BASE.

## .set JAB_STACK_TOP

`addr`: sp at the program's start, the end of RAM and of the window.

## .set JAB_DISPLAY_BASE

`addr`: the framebuffer, a pixel the little-endian word 0x00RRGGBB.

The display: a framebuffer between the kernel and the window, four bytes a
pixel, blue, green, red, and one unused, so a pixel stored as a little-endian
word reads 0x00RRGGBB. The program draws into it and jab.sys.display.flip
shows it; RAM starts zero, so it starts black.

## .set JAB_DISPLAY_WIDTH

`u64`: the framebuffer's width in pixels.

## .set JAB_DISPLAY_HEIGHT

`u64`: the framebuffer's height in pixels.

## .set JAB_DISPLAY_PITCH

`u64`: a row's bytes, four a pixel.

## .set JAB_DISPLAY_SIZE

`u64`: the framebuffer's bytes.

## .set JAB_DISPLAY_FPS_TARGET

`u64`: the frame rate a program is built to hold.

## .set JAB_DISPLAY_FPS_CAP

`u64`: the most flips a second.

## .set JAB_TIME_HZ

`u64`: the ticks a second of the time counter rdtime reads.

A program moves things by time, never by frames: it reads the counter each
frame and moves each thing by its speed times the ticks since the frame
before over JAB_TIME_HZ, so the frame cap and a late frame change when a
thing is seen and never where it is.

## .set JAB_AWAIT_DISPLAY

`u64`: the display's next frame tick.

## .set JAB_AWAIT_KEYBOARD

`u64`: a key event waiting.

## .set JAB_AWAIT_API

`u64`: bytes from the host waiting on the API.

## .set JAB_AWAIT_PAD

`u64`: a pad event waiting.

## .set JAB_AWAIT_SOUND

`u64`: room in the sound stream for a period.

## .set JAB_SYS_EXIT

`u64`.

The system call numbers, in a7 when a macro traps; doc/syscalls.nuon is the
table of record.

## .set JAB_SYS_PRINT

`u64`.

## .set JAB_SYS_UART_PRINT

`u64`.

## .set JAB_SYS_DISPLAY_OPEN

`u64`.

## .set JAB_SYS_DISPLAY_READY

`u64`.

## .set JAB_SYS_DISPLAY_FLIP

`u64`.

## .set JAB_SYS_DISPLAY_PRINT

`u64`.

## .set JAB_SYS_AWAIT

`u64`.

## .set JAB_SYS_DISPLAY_FLIP_RECT

`u64`.

## .set JAB_SYS_KEYBOARD_INPUT

`u64`.

## .set JAB_SYS_BLOCK_LIST

`u64`.

## .set JAB_SYS_BLOCK_FIND

`u64`.

## .set JAB_SYS_BLOCK_READ

`u64`.

## .set JAB_SYS_BLOCK_WRITE

`u64`.

## .set JAB_SYS_ROMFS_LIST

`u64`.

## .set JAB_SYS_ROMFS_FIND

`u64`.

## .set JAB_SYS_ROMFS_READ

`u64`.

## .set JAB_SYS_TAR_LIST

`u64`.

## .set JAB_SYS_TAR_FIND

`u64`.

## .set JAB_SYS_GZ_SIZE

`u64`.

## .set JAB_SYS_GZ_READ

`u64`.

## .set JAB_SYS_CHECKSUM

`u64`.

## .set JAB_SYS_HASH

`u64`.

## .set JAB_SYS_API_WRITE

`u64`.

## .set JAB_SYS_API_READ

`u64`.

## .set JAB_SYS_PNG_SIZE

`u64`.

## .set JAB_SYS_SPRITE_PNG

`u64`.

## .set JAB_SYS_SPRITE_DRAW

`u64`.

## .set JAB_SYS_SPRITE_LOAD

`u64`.

## .set JAB_SYS_DISPLAY_FLIP_RECTS

`u64`.

## .set JAB_SYS_KERNEL_FLAGS

`u64`.

## .set JAB_SYS_PAD_READ

`u64`.

## .set JAB_SYS_PAD_INPUT

`u64`.

## .set JAB_SYS_PAD_AXIS

`u64`.

## .set JAB_SYS_DISPLAY_TEXT

`u64`.

## .set JAB_SYS_PAD_NAME

`u64`.

## .set JAB_SYS_RANDOM

`u64`.

## .set JAB_SYS_SOUND_OPEN

`u64`.

## .set JAB_SYS_SOUND_WRITE

`u64`.

## .set JAB_SYS_SOUND_READY

`u64`.

## .set JAB_SYS_MIDI_PROGRAM

`u64`.

## .set JAB_SYS_MIDI_NOTE

`u64`.

## .set JAB_SYS_MIDI_CONTROL

`u64`.

## .set JAB_SYS_MIDI_BEND

`u64`.

## .set JAB_SYS_MIDI_INSTRUMENT

`u64`.

## .set JAB_SYS_MIDI_SILENCE

`u64`.

## .set JAB_SYS_MIDI_PLAY

`u64`.

## .set JAB_SYS_MIDI_STOP

`u64`.

## .set JAB_SYS_MIDI_PLAYING

`u64`.

## .set JAB_SYS_MIDI_SOUNDFONT

`u64`.

## .set JAB_TEXT_WIDTH

`u64`: a text cell's width in pixels at JAB_TEXT_SCALE_ONE.

## .set JAB_TEXT_HEIGHT

`u64`: a text cell's height in pixels at JAB_TEXT_SCALE_ONE.

## .set JAB_TEXT_SCALE_ONE

`u64`: the font's own size, the scale in 256ths as a sprite's.

## .set JAB_TEXT_SCALE_MAX

`u64`: the largest text scale.

## .set JAB_TEXT_PLAIN

`u32`: the console's white, the text colour when left out.

## .set JAB_TEXT_BOLD

`u64`: the style bit striking each glyph twice a pixel apart.

## .set JAB_PAD_NAME_BYTES

`u64`: the most a pad's name takes, its terminator included.

## .set JAB_SOUND_RATE

`u64`: the one format's frames a second.

Sound: one format and only one. The kernel plays a stream on the device's
clock in periods, JAB_SOUND_PERIODS of them in flight, enough that the host's
own buffer behind the device is always full, mixing two sources into it: the
frames a program queues with jab.sys.sound.write, which wait in the ring and
play in order as they reach the front, and the synthesizer's voices
(jab.sys.midi.*). A ring that runs dry is silence. A program's exit plays the
stream out: the ring, the voices, and then enough silence that the host has
played the last of it before the machine ends. A device that returns nothing
for three seconds with periods in flight has stopped: the stream is then
dead, the sound and MIDI calls answer 2 from then on, jab.sys.await drops the
sound's bit, and the UART says `jab: sound stalled`.

## .set JAB_SOUND_CHANNELS

`u64`: signed 16-bit samples a frame, interleaved left then right.

## .set JAB_SOUND_FRAME_BYTES

`u64`: a frame's bytes.

## .set JAB_SOUND_PERIOD

`u64`: a period's frames, 20 ms.

## .set JAB_SOUND_PERIODS

`u64`: the periods in flight.

## .set JAB_SOUND_RING

`u64`: the frames the ring behind jab.sys.sound.write holds.

## .set JAB_MIDI_CHANNELS

`u64`: the channels, 0 to 15.

MIDI: the kernel's synthesizer behind MIDI's own numbers. Each channel has a
program, 0 to 127 in General MIDI's order, and its controllers; of the
controllers the kernel keeps the JAB_MIDI_CC_* and takes the rest without
effect. The voices are chip-tune: an instrument is a spec of
JAB_MIDI_INSTRUMENT_ENTRY bytes, laid out by JAB_MIDI_WAVE and the fields
after it. Every program has a General MIDI default, and
jab.sys.midi.instrument puts a spec of the program's own in its place. A note
past JAB_MIDI_VOICES sounding takes the oldest voice, a releasing one first.

A Standard MIDI File the program holds, format 0 or 1 with up to
JAB_MIDI_TRACKS tracks and a division in ticks a quarter note, plays through
the same voices with jab.sys.midi.play, its events landing within a period of
their time. The file's notes and the calls' are each their own: a note off, a
channel's notes off, and jab.sys.midi.stop reach only the notes of the side
that sent them, while a channel's program and controllers are shared between
the two, by MIDI's own rule, so a file that changes a channel's program
changes it for the calls as well.

A SoundFont 2 file the program holds, loaded with jab.sys.midi.soundfont,
plays the notes after it through sampled voices instead, JAB_MIDI_FONT_VOICES
of them at once: a channel's bank, JAB_MIDI_CC_BANK, and program pick its
preset, channel JAB_MIDI_PERCUSSION's the kit in bank 128, a bank with no
such preset falling back to bank 0 and a missing kit to kit 0; the generators
read are the ranges, the sample and its offsets, the root key, the tunings,
the loop mode, the volume envelope, the pan, the attenuation, and the
exclusive class, the modulators, the filter, and the LFOs not, with the
velocity, the volume, the expression, the pan, and the bend applied as the
specification's defaults.

## .set JAB_MIDI_VOICES

`u64`: the chip-tune notes sounding at once.

## .set JAB_MIDI_FONT_VOICES

`u64`: the SoundFont notes sounding at once.

## .set JAB_MIDI_TRACKS

`u64`: the most tracks a Standard MIDI File may carry.

## .set JAB_MIDI_PERCUSSION

`u64`: the drum kit's channel, its notes naming drums.

## .set JAB_MIDI_BEND_CENTER

`u16`: the bend for none.

## .set JAB_MIDI_CC_BANK

`u8`: the bank select, picking a SoundFont preset's bank.

## .set JAB_MIDI_CC_VOLUME

`u8`: the volume, scaling the channel's notes.

## .set JAB_MIDI_CC_PAN

`u8`: the pan, 64 the middle.

## .set JAB_MIDI_CC_EXPRESSION

`u8`: the expression, scaling the channel's notes.

## .set JAB_MIDI_CC_PEDAL

`u8`: the pedal, down from 64, holding every note released until it lifts.

## .set JAB_MIDI_CC_ALL_SOUND_OFF

`u8`: frees the channel's voices at once.

## .set JAB_MIDI_CC_RESET

`u8`: puts the channel's controllers back to their defaults.

## .set JAB_MIDI_CC_ALL_NOTES_OFF

`u8`: releases the channel's notes.

## .set JAB_MIDI_WAVE

`u8`: an instrument spec's wave, a JAB_WAVE_*.

## .set JAB_MIDI_DUTY

`u8`: the square's duty in 256ths of a cycle.

## .set JAB_MIDI_ATTACK

`u16`: the attack in milliseconds.

## .set JAB_MIDI_DECAY

`u16`: the decay in milliseconds.

## .set JAB_MIDI_RELEASE

`u16`: the release in milliseconds.

## .set JAB_MIDI_SUSTAIN

`u8`: the sustain in 256ths of full.

## .set JAB_MIDI_VIBRATO

`u8`: the vibrato's depth in 256ths of about a semitone.

## .set JAB_MIDI_VIBRATO_RATE

`u8`: the vibrato's rate in hertz.

## .set JAB_MIDI_INSTRUMENT_ENTRY

`u64`: an instrument spec's bytes, the last one spare.

## .set JAB_WAVE_SQUARE

`u8`.

## .set JAB_WAVE_TRIANGLE

`u8`.

## .set JAB_WAVE_SAW

`u8`.

## .set JAB_WAVE_SINE

`u8`.

## .set JAB_WAVE_NOISE

`u8`.

## .set JAB_PAD_ENTRY

`u64`: a pad state record's bytes, on a 4-byte boundary.

The pad: a gamepad the host passed through as a virtio-input device. Each
axis is normalised from the axis's own range: a centred axis reads 0 across
its flat band about the middle of its range and rescales to full scale at
either end; ABS_GAS and ABS_BRAKE, one-sided, read 0 to JAB_PAD_FULL; a hat
reads -JAB_PAD_FULL, 0, or JAB_PAD_FULL; an axis the pad lacks, or one that
has not moved since the program started, reads 0. The pad's own range for an
axis is what jab.sys.pad.axis writes.

## .set JAB_PAD_KEYS

`u32`: the gamepad's keys held, bit n for the code JAB_BTN_GAMEPAD + n.

## .set JAB_PAD_AXES

`64 i16`: every axis at its JAB_ABS_* code, -JAB_PAD_FULL through JAB_PAD_FULL.

## .set JAB_PAD_AXIS_COUNT

`u64`: the axes a state record holds.

## .set JAB_PAD_FULL

`i16`: an axis's full scale either way.

## .set JAB_PAD_AXIS_ENTRY

`u64`: an axis range record's bytes, on a 4-byte boundary.

## .set JAB_PAD_AXIS_MIN

`i32`: the axis's least reading, as virtio reports it.

## .set JAB_PAD_AXIS_MAX

`i32`: the axis's greatest reading.

## .set JAB_PAD_AXIS_FUZZ

`i32`: the axis's noise.

## .set JAB_PAD_AXIS_FLAT

`i32`: the band about the middle that reads as rest.

## .set JAB_PAD_AXIS_RES

`i32`: the axis's resolution.

## .set JAB_KERNEL_DEBUG

`u64`: the kernel was built with DEBUG, its own lines on its debug channel.

A program can .ifdef the same symbols at build, since every symbol reaches it
too; jab.sys.kernel.flags is for the same fact at run time.

## .set JAB_SPRITE_WIDTH

`u32`: one frame's width.

A sprite: frames of pixels in the framebuffer's own format, which the program
owns and jab.sys.sprite.draw blends onto the screen. The record is a header of
four 32-bit fields and then the pixels, frame k one contiguous block. A pixel
is the framebuffer's blue, green, and red, with the unused byte carrying
alpha, 0 clear through 255 solid. A sprite of one frame is a plain image.

## .set JAB_SPRITE_HEIGHT

`u32`: one frame's height.

## .set JAB_SPRITE_FRAMES

`u32`: the frame count.

## .set JAB_SPRITE_FLAGS

`u32`: JAB_SPRITE_SPANNED or 0.

## .set JAB_SPRITE_PIXELS

`u32`: the pixels, 0xAARRGGBB, frame after frame, each frame's rows top to bottom.

jab.sys.sprite.png fills a sprite from a PNG the program holds, a sheet of
frames stacked top to bottom, and jab.sys.sprite.load from a directory of
PNGs on a romfs disk, one frame each; both decode in place and add the span
table, so the buffer holding the record needs JAB_SPRITE_PIXELS plus four
bytes a pixel and four bytes a row of every frame: for N frames of W by H,
JAB_SPRITE_PIXELS + N * H * (W * 4 + 4). A program that knows its asset
writes that down with .set; one that does not asks jab.sys.png.size first.
Declare the record on a 4-byte boundary, as its fields want.

## .set JAB_SPRITE_SPANNED

`u32`: the flag saying the span table follows the pixels.

With JAB_SPRITE_SPANNED in the flags, a table follows the pixels: for every
row of every frame, in order, two 16-bit columns, the first and the last that
carry any alpha, the first past the last in a row with none; the draw then
walks only those columns, which is what makes a thin figure in a wide frame
cheap. jab.sys.sprite.png and jab.sys.sprite.load write the table and set the
flag; a sprite written by hand may leave the flags 0 and is drawn whole.

## .set JAB_RECT_X

`u32`: the rectangle's left column.

## .set JAB_RECT_Y

`u32`: the rectangle's top row.

## .set JAB_RECT_WIDTH

`u32`.

## .set JAB_RECT_HEIGHT

`u32`.

## .set JAB_RECT_SIZE

`u64`: a rectangle record's bytes.

## .set JAB_SPRITE_PLAIN

`u32`: white, the tint that draws a sprite as it is.

The tint multiplies each channel of a sprite's pixel, over 255, before it is
blended, so white draws the sprite as it is and black draws its silhouette. A
sprite meant to be recoloured is drawn white with its shape in alpha.

## .set JAB_SPRITE_SCALE_ONE

`u64`: a frame's own size, the scale in 256ths.

Half of it draws the frame at half its size and twice it at twice, sampling
the nearest source pixel.

## .set JAB_SPRITE_SCALE_MAX

`u64`: the largest sprite scale.

## .set JAB_SPRITE_FLIP_H

`u64`: the pose bit mirroring the frame left to right.

The mirrors apply to the frame before the turn, and the turn is about the
scaled frame's centre.

## .set JAB_SPRITE_FLIP_V

`u64`: the pose bit mirroring the frame top to bottom.

## .set JAB_SPRITE_SOLID

`u64`: the pose bit writing the tint over every pixel the frame covers.

No alpha and no blend: each row's span for a spanned sprite, the whole frame
otherwise. Drawing the frame a program drew last time, at the same place,
scale, and pose, solid in the background's colour is how it clears that frame
at the cost of its shape rather than its box, and a solid draw in any colour
is a silhouette.

## .set JAB_PNG_OK

`u64`.

PNG, as GIMP 3 exports it by default from any image mode: colour types 0
(grey), 2 (RGB), 3 (indexed, with its palette and its transparency), 4 (grey
with alpha) and 6 (RGBA); 8 bits a sample, and 1, 2, or 4 for grey and
indexed, which GIMP writes for a small palette; not interlaced. Every
ancillary chunk is skipped. What GIMP writes only when asked - 16 bits a
sample, Adam7 interlace - is JAB_PNG_UNSUPPORTED. Every chunk's CRC-32 and
the stream's Adler-32 are checked. The codes from JAB_PNG_INPUT on come from
the DEFLATE stream inside the file rather than the PNG around it, in the
order jab.sys.gz.read reports them.

## .set JAB_PNG_NOT_PNG

`u64`: no PNG signature.

## .set JAB_PNG_UNSUPPORTED

`u64`: a form the decoder does not take, 16 bits a sample or Adam7 interlace among them.

## .set JAB_PNG_TRUNCATED

`u64`: the file ends early.

## .set JAB_PNG_CRC

`u64`: a chunk's CRC-32 fails.

## .set JAB_PNG_ZLIB

`u64`: the zlib stream's header or Adler-32 fails.

## .set JAB_PNG_LENGTH

`u64`: the image data inflates to the wrong size.

## .set JAB_PNG_FILTER

`u64`: a row's filter type does not exist.

## .set JAB_PNG_PALETTE

`u64`: an indexed image with no palette or an index past it.

## .set JAB_PNG_FRAMES

`u64`: the height does not divide by the frames, or a frame's size differs from the first's.

## .set JAB_PNG_SIZE

`u64`: the sprite's buffer is short of the rule.

## .set JAB_PNG_NOT_FOUND

`u64`: the directory or its 0.png is not on the disk.

## .set JAB_PNG_INPUT

`u64`: the DEFLATE stream ends in the middle of something.

## .set JAB_PNG_OUTPUT

`u64`: the DEFLATE stream overruns the image.

## .set JAB_PNG_BLOCK

`u64`: a DEFLATE block type that does not exist.

## .set JAB_PNG_STORED

`u64`: a stored block's length disagrees with itself.

## .set JAB_PNG_CODES

`u64`: a code table that is not a Huffman code.

## .set JAB_PNG_SYMBOL

`u64`: a symbol no table can produce.

## .set JAB_PNG_DISTANCE

`u64`: a distance reaching before the output.

## .set JAB_GZ_OK

`u64`.

gzip, which is DEFLATE with a jacket: ten bytes of header, optionally an
extra field, a name and a comment, then the compressed bytes, then a CRC-32
of the contents and their length. That length is why the read is one shot: a
program asks jab.sys.gz.size first, sizes its buffer, and gets everything in a
single call. DEFLATE cannot be entered in the middle, so a cursor would mean
the kernel holding decoder state between calls, which nothing else here does.
The codes from JAB_GZ_INPUT on come from the DEFLATE stream itself rather
than the jacket.

## .set JAB_GZ_NOT_GZIP

`u64`: no gzip header of deflated data, or too short for a trailer.

## .set JAB_GZ_TRUNCATED

`u64`: the header runs past the end, or no compressed bytes follow it.

## .set JAB_GZ_CRC

`u64`: the contents' CRC-32 is not the trailer's.

## .set JAB_GZ_LENGTH

`u64`: the contents' length is not the trailer's.

## .set JAB_GZ_INPUT

`u64`: the DEFLATE stream ends in the middle of something.

## .set JAB_GZ_OUTPUT

`u64`: the buffer cannot hold the contents.

## .set JAB_GZ_BLOCK

`u64`: a DEFLATE block type that does not exist.

## .set JAB_GZ_STORED

`u64`: a stored block's length disagrees with itself.

## .set JAB_GZ_CODES

`u64`: a code table that is not a Huffman code.

## .set JAB_GZ_SYMBOL

`u64`: a symbol no table can produce.

## .set JAB_GZ_DISTANCE

`u64`: a distance reaching before the output.

## .set JAB_TAR_ENTRY

`u64`: a tar record's bytes.

A tar archive, read where the program already holds it: unlike romfs, which
lives on a disk, a tar is bytes in the program's own memory, usually a
.tar.gz read out of romfs and inflated. Everything a tar call names is
therefore an offset into that block of bytes, and an entry's data needs no
reading call at all. A ustar path is a 155-byte prefix, a separator, and a
100-byte name, so 256 characters at most, and the record holds all of them.

## .set JAB_TAR_PAGE

`u64`: the records jab.sys.tar.list writes when the capacity is left out.

## .set JAB_TAR_LIST_SIZE

`u64`: the bytes a page of records takes.

## .set JAB_TAR_BLOCK

`u64`: a header's bytes and every block's, so every offset is a multiple of it.

## .set JAB_TAR_OFFSET

`u64`: the entry's header, an offset into the archive.

## .set JAB_TAR_DATA

`u64`: the entry's data, an offset into the archive, where it already sits.

## .set JAB_TAR_SIZE

`u64`: the data's bytes.

## .set JAB_TAR_TYPE

`u8`: tar's own type byte, a JAB_TAR_* digit character; an old archive's zero reads JAB_TAR_REGULAR.

## .set JAB_TAR_NAME

`264 u8`: the path, NUL-terminated, a ustar prefix joined on with a separator.

## .set JAB_TAR_NAME_BYTES

`u64`: the name field's bytes.

## .set JAB_TAR_REGULAR

`u8`.

## .set JAB_TAR_HARDLINK

`u8`.

## .set JAB_TAR_SYMLINK

`u8`.

## .set JAB_TAR_CHAR

`u8`: a character device.

## .set JAB_TAR_BLOCKDEV

`u8`: a block device.

## .set JAB_TAR_DIRECTORY

`u8`.

## .set JAB_TAR_FIFO

`u8`.

## .set JAB_BLOCK_MAX

`u64`: the most disks, their ids 1 to JAB_BLOCK_MAX.

The disks: QEMU's virtio-blk devices, one id each, in the order their
transports sit on the machine. A record's fields are each the width virtio
gives them. The kind is what the kernel found on the disk, not what anyone
meant to put there; a record of zeroes reads as JAB_BLOCK_KIND_NONE, and so
does a disk that would not come up.

## .set JAB_BLOCK_SECTOR

`u64`: a sector's bytes, virtio's unit for every capacity and request.

## .set JAB_BLOCK_ENTRY

`u64`: a disk record's bytes.

## .set JAB_BLOCK_LIST_SIZE

`u64`: the bytes that hold every disk's record.

## .set JAB_BLOCK_ID

`u8`: the disk's id.

## .set JAB_BLOCK_KIND

`u8`: what the kernel found on the disk, a JAB_BLOCK_KIND_*.

## .set JAB_BLOCK_SECTORS

`u64`: the capacity in sectors.

## .set JAB_BLOCK_SERIAL

`20 u8`: the device ID string, at most 20 characters.

## .set JAB_BLOCK_SERIAL_BYTES

`u64`: the serial field's bytes.

## .set JAB_BLOCK_KIND_NONE

`u8`: nothing found, or a disk that would not come up.

## .set JAB_BLOCK_KIND_RAW

`u8`: a disk with no romfs on it.

## .set JAB_BLOCK_KIND_ROMFS

`u8`: a romfs image.

## .set JAB_ROMFS_ENTRY

`u64`: a romfs record's bytes.

RomFS on a disk: read-only, every structure on a 16-byte boundary, every
value big-endian on the image and little-endian in a record. Everything romfs
names is a header's offset in the image, which is what jab.sys.romfs.find
gives back and what jab.sys.romfs.list and jab.sys.romfs.read take.
JAB_ROMFS_NEXT carries the mode as the image stores it, and clearing the bits
JAB_ROMFS_TYPE and JAB_ROMFS_EXEC mask leaves the offset. A name is at most
127 characters, the most a Linux mount of the same image can read.

## .set JAB_ROMFS_PAGE

`u64`: the records jab.sys.romfs.list writes when the capacity is left out.

## .set JAB_ROMFS_LIST_SIZE

`u64`: the bytes a page of records takes.

## .set JAB_ROMFS_OFFSET

`u32`: the entry's own header, its offset in the image.

## .set JAB_ROMFS_NEXT

`u32`: the next header's offset, the mode in its low four bits.

## .set JAB_ROMFS_SPEC

`u32`: romfs's spec info, a directory's first entry or a hard link's target.

## .set JAB_ROMFS_SIZE

`u32`: the file's bytes.

## .set JAB_ROMFS_NAME

`128 u8`: the name, NUL-terminated.

## .set JAB_ROMFS_NAME_BYTES

`u64`: the name field's bytes, 127 characters and the terminator.

## .set JAB_ROMFS_ROOT

`u64`: the volume's first header, its root directory.

## .set JAB_ROMFS_TYPE

`u32`: the mask of JAB_ROMFS_NEXT's type.

## .set JAB_ROMFS_EXEC

`u32`: JAB_ROMFS_NEXT's executable bit.

## .set JAB_ROMFS_HARDLINK

`u32`.

## .set JAB_ROMFS_DIRECTORY

`u32`.

## .set JAB_ROMFS_REGULAR

`u32`.

## .set JAB_ROMFS_SYMLINK

`u32`.

## .set JAB_ROMFS_BLOCK

`u32`: a block device.

## .set JAB_ROMFS_CHAR

`u32`: a character device.

## .set JAB_ROMFS_SOCKET

`u32`.

## .set JAB_ROMFS_FIFO

`u32`.

## .macro jab.sys.display.flip

A program awaits the tick, or asks jab.sys.display.ready, before it flips.

## .macro jab.sys.display.flip.rect

One flip a frame, so several changed areas go as the one rectangle holding
them. The host copies and paints only the rectangle, which is what keeps a
moving object cheap.

## .macro jab.sys.display.flip.rects

What jab.sys.display.flip.rect is for several changed areas at once. The host
copies only the rectangles listed and paints once, the rectangle holding them
all, so a busy screen costs the host one draw a tick whatever the list.

## .macro jab.sys.display.text

What is under the text stays, so a program clears the strip first when it
wants a clean line, and then flips the rectangle, whole or with the rest. A
scaled cell samples the nearest source pixel, as a sprite does.

## .macro jab.sys.keyboard.input

Call it until a0 is 0 to take everything that arrived.

## .macro jab.sys.await

A program names the inputs it reads and the wait is for those alone: an
input in the mask that the program never reads stays waiting and ends every
wait at once.

## .macro jab.sys.pad.input

Call it until a0 is 0 to take everything that arrived.

## .macro jab.sys.sound.write

What did not fit waits for the stream to play some, which
jab.sys.sound.await watches.

## .macro jab.sys.midi.program

The MIDI calls drive the kernel's synthesizer with MIDI's numbers
(.set JAB_MIDI_CHANNELS above); every argument is a register, which the
kernel masks to its range rather than checks. Each brings the sound device up
on the first call.

## .macro jab.sys.midi.play

The file's notes, controllers, program changes, bends, and tempo changes go
to the synthesizer as the piece runs, stepped a period at a time on the sound
device's clock. A file the player does not take has no MThd header, a format
past 1, a SMPTE division, no track or more than JAB_MIDI_TRACKS, or a chunk
past the end.

## .macro jab.sys.midi.soundfont

The file stays unchanged while it is loaded because its presets, instruments,
and samples are read in place. Not a SoundFont 2 file: no RIFF sfbk form, a
list or a hydra chunk missing or out of order, no sample data. Unsound: a
chunk past the end, a chunk no whole number of its records fills, the buffer
off a 4-byte boundary.

## .macro jab.sys.api.write

The API: bytes both ways between the program and the host over a port of the
machine, there when the run put it there (`--api`) and absent otherwise,
which the calls report; one build runs either way. A byte stream, so any
record shape is the program's own.

A host that stops reading holds the program here once what is between them
is full: with jab.sys.await the one call that can wait.

## .macro jab.sys.api.read

To sleep until bytes arrive, jab.sys.api.await.

## .macro jab.sys.block.list

The disk and file calls take the program's buffer first, the way a RISC-V
load names its destination first, then what they act on, then where in it,
then how much the buffer holds. Each macro loads the argument registers from
the highest down, so a value already sitting in a low argument register can
be passed as a later argument: that is what lets a paging loop hand a1
straight back as the next cursor.

## .macro jab.sys.checksum

A digest is 32 bytes, which is exactly four registers, so it comes back in a0
to a3 and needs no buffer.

## .macro jab.sys.hash

Where jab.sys.checksum answers whether bytes are exactly the bytes expected,
this answers which bytes they are, quickly, for keying and lookups.

## .macro jab.sys.gz.size

The size comes first so a program can size its buffer before it inflates
anything.

## .macro jab.sys.gz.read

Unlike a list's capacity this one is a register, since a program works it
out from jab.sys.gz.size rather than writing it down.

## .macro jab.sys.romfs.read

The next offset makes a loop over a file of any size the same shape as a
listing.

## .macro jab.sys.png.size

How a program sizes a sprite for a PNG it holds.

## .macro jab.sys.sprite.png

The decode is in place, so the buffer holds the filtered rows on the way to
the pixels.

## .macro jab.sys.sprite.load

Each frame decodes straight off the disk into its own block, so the program
holds no buffer for the files.

## .macro jab.sys.sprite.draw

The turn is about the scaled frame's centre with x, y still where the
unturned frame's top left would be. tint, scale, and pose are registers when
given, so a program may vary them at run time. Per pixel, alpha 0 is
skipped, 255 copied, and anything between blended over what is there: each
channel becomes (s * a + d * (255 - a)) / 255, rounded, with s the sprite's
tinted channel and d the screen's; solid, the tint is written over every
pixel the frame covers instead. The program flips, whole or the rectangles.
A record whose width, height, or frame count is past 65535 is no sprite and
ends the run, as a buffer outside the window does.
