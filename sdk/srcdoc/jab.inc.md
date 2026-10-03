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

Where a program lives. The machine has 4 GiB of RAM from 0x80000000; the
kernel keeps the first 2 MiB and the framebuffer the 8 MiB after it, and
everything from there to the end of RAM is the program's: QEMU's loader
device places the .jab file at JAB_PROGRAM_BASE.

## .set JAB_DISPLAY_BASE

The display: a framebuffer between the kernel and the window, four bytes a
pixel, blue, green, red, and one unused, so a pixel stored as a little-endian
word reads 0x00RRGGBB. The program draws into it and jab.sys.display.flip
shows it; RAM starts zero, so it starts black.

## .set JAB_TIME_HZ

A program moves things by time, never by frames: it reads the counter each
frame and moves each thing by its speed times the ticks since the frame
before over JAB_TIME_HZ, so the frame cap and a late frame change when a
thing is seen and never where it is.

## .set JAB_SYS_EXIT

The system call numbers, in a7 when a macro traps; doc/syscalls.nuon is the
table of record.

## .set JAB_SOUND_RATE

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

## .set JAB_MIDI_CHANNELS

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

## .set JAB_PAD_ENTRY

The pad: a gamepad the host passed through as a virtio-input device. Each
axis is normalised from the axis's own range: a centred axis reads 0 across
its flat band about the middle of its range and rescales to full scale at
either end; ABS_GAS and ABS_BRAKE, one-sided, read 0 to JAB_PAD_FULL; a hat
reads -JAB_PAD_FULL, 0, or JAB_PAD_FULL; an axis the pad lacks, or one that
has not moved since the program started, reads 0. The pad's own range for an
axis is what jab.sys.pad.axis writes.

## .set JAB_KERNEL_DEBUG

A program can .ifdef the same symbols at build, since every symbol reaches it
too; jab.sys.kernel.flags is for the same fact at run time.

## .set JAB_SPRITE_WIDTH

A sprite: frames of pixels in the framebuffer's own format, which the program
owns and jab.sys.sprite.draw blends onto the screen. The record is a header of
four 32-bit fields and then the pixels, frame k one contiguous block. A pixel
is the framebuffer's blue, green, and red, with the unused byte carrying
alpha, 0 clear through 255 solid. A sprite of one frame is a plain image.

## .set JAB_SPRITE_PIXELS

jab.sys.sprite.png fills a sprite from a PNG the program holds, a sheet of
frames stacked top to bottom, and jab.sys.sprite.load from a directory of
PNGs on a romfs disk, one frame each; both decode in place and add the span
table, so the buffer holding the record needs JAB_SPRITE_PIXELS plus four
bytes a pixel and four bytes a row of every frame: for N frames of W by H,
JAB_SPRITE_PIXELS + N * H * (W * 4 + 4). A program that knows its asset
writes that down with .set; one that does not asks jab.sys.png.size first.
Declare the record on a 4-byte boundary, as its fields want.

## .set JAB_SPRITE_SPANNED

With JAB_SPRITE_SPANNED in the flags, a table follows the pixels: for every
row of every frame, in order, two 16-bit columns, the first and the last that
carry any alpha, the first past the last in a row with none; the draw then
walks only those columns, which is what makes a thin figure in a wide frame
cheap. jab.sys.sprite.png and jab.sys.sprite.load write the table and set the
flag; a sprite written by hand may leave the flags 0 and is drawn whole.

## .set JAB_SPRITE_PLAIN

The tint multiplies each channel of a sprite's pixel, over 255, before it is
blended, so white draws the sprite as it is and black draws its silhouette. A
sprite meant to be recoloured is drawn white with its shape in alpha.

## .set JAB_SPRITE_SCALE_ONE

Half of it draws the frame at half its size and twice it at twice, sampling
the nearest source pixel.

## .set JAB_SPRITE_FLIP_H

The mirrors apply to the frame before the turn, and the turn is about the
scaled frame's centre.

## .set JAB_SPRITE_SOLID

No alpha and no blend: each row's span for a spanned sprite, the whole frame
otherwise. Drawing the frame a program drew last time, at the same place,
scale, and pose, solid in the background's colour is how it clears that frame
at the cost of its shape rather than its box, and a solid draw in any colour
is a silhouette.

## .set JAB_PNG_OK

PNG, as GIMP 3 exports it by default from any image mode: colour types 0
(grey), 2 (RGB), 3 (indexed, with its palette and its transparency), 4 (grey
with alpha) and 6 (RGBA); 8 bits a sample, and 1, 2, or 4 for grey and
indexed, which GIMP writes for a small palette; not interlaced. Every
ancillary chunk is skipped. What GIMP writes only when asked - 16 bits a
sample, Adam7 interlace - is JAB_PNG_UNSUPPORTED. Every chunk's CRC-32 and
the stream's Adler-32 are checked. The codes from JAB_PNG_INPUT on come from
the DEFLATE stream inside the file rather than the PNG around it, in the
order jab.sys.gz.read reports them.

## .set JAB_GZ_OK

gzip, which is DEFLATE with a jacket: ten bytes of header, optionally an
extra field, a name and a comment, then the compressed bytes, then a CRC-32
of the contents and their length. That length is why the read is one shot: a
program asks jab.sys.gz.size first, sizes its buffer, and gets everything in a
single call. DEFLATE cannot be entered in the middle, so a cursor would mean
the kernel holding decoder state between calls, which nothing else here does.
The codes from JAB_GZ_INPUT on come from the DEFLATE stream itself rather
than the jacket.

## .set JAB_TAR_ENTRY

A tar archive, read where the program already holds it: unlike romfs, which
lives on a disk, a tar is bytes in the program's own memory, usually a
.tar.gz read out of romfs and inflated. Everything a tar call names is
therefore an offset into that block of bytes, and an entry's data needs no
reading call at all. A ustar path is a 155-byte prefix, a separator, and a
100-byte name, so 256 characters at most, and the record holds all of them.

## .set JAB_BLOCK_MAX

The disks: QEMU's virtio-blk devices, one id each, in the order their
transports sit on the machine. A record's fields are each the width virtio
gives them. The kind is what the kernel found on the disk, not what anyone
meant to put there; a record of zeroes reads as JAB_BLOCK_KIND_NONE, and so
does a disk that would not come up.

## .set JAB_ROMFS_ENTRY

RomFS on a disk: read-only, every structure on a 16-byte boundary, every
value big-endian on the image and little-endian in a record. Everything romfs
names is a header's offset in the image, which is what jab.sys.romfs.find
gives back and what jab.sys.romfs.list and jab.sys.romfs.read take.
JAB_ROMFS_NEXT carries the mode as the image stores it, and clearing the bits
JAB_ROMFS_TYPE and JAB_ROMFS_EXEC mask leaves the offset. A name is at most
127 characters, the most a Linux mount of the same image can read.

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
