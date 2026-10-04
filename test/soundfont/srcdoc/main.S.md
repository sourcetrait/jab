# main.S

soundfont: the kernel's SoundFont reader and its sampled voices under
test. With a disk of serial `tone` on the machine it loads the
one-sample font there, a sine at 24 kHz rooted at the A above middle
C, plays that A for a second at full velocity and volume, releases
it, and spins for half a second more; then it loads FluidR3 GM off
the mix disk, says what the file holds, plays a piano's middle C for
most of a second, releases it, and exits. The host records what
played and the test measures it. A step it cannot take says so on
the UART and exits with its own code; the tone font alone is
skipped when its disk is not there, so a run outside the test plays
the piano.

## .set CHANNEL

`u8`: the MIDI channel played.

## .set TONE_NOTE

`u8`: the A above middle C, the tone font's root.

## .set TONE_VELOCITY

`u8`: full velocity.

## .set TONE_VOLUME

`u8`: full volume.

## .set TONE_HOLD

`u64`: how long the tone sounds, a second in ticks.

## .set TAIL

`u64`: the spin after each release, half a second in ticks.

## .set PIANO_PROGRAM

`u8`: the General MIDI program, the acoustic grand piano.

## .set PIANO_NOTE

`u8`: middle C.

## .set PIANO_VELOCITY

`u8`: the piano note's velocity.

## .set PIANO_HOLD

`u64`: how long the piano sounds, most of a second in ticks.

## .set TONE_BYTES

`u64`: room for the tone font, 4 KiB.

## .set FONT_BYTES

`u64`: room for FluidR3 GM, 160 MiB.

## .set PAGE_BYTES

`u64`: the most one read takes, 1 MiB.

## .set LINE_BYTES

`u64`: room for a line.

## .set DIGITS_BYTES

`u64`: room for a decimal's digits.

## _start

The tone font is played only when its disk is there.

## fluid

FluidR3 GM comes off the mix disk and the piano's middle C plays through it.
After the release the program spins TAIL before it exits.

## read_file

The path sits in a register, so the find goes by the plain call. The bytes
read so far ride in a4, which the read call's macro loads, so they are kept
on the stack across each read.

## rec

`144 u8`: a file's romfs record.

## digits

`24 u8`: append_dec's digits, built backward.

## line

`128 u8`: the line being built.

## tone

`4096 u8`: the tone font.

## font

`167772160 u8`: the FluidR3 GM font.

## serial_tone

`5 u8`: the tone disk's serial.

## serial_mix

`4 u8`: the mix disk's serial.

## path_tone

`10 u8`: the tone font's path on its disk.

## path_fluid

`29 u8`: the path of FluidR3 GM on the mix disk.

## label_tone

`16 u8`: the tone font's counts line's label.

## label_fluid

`17 u8`: the label of FluidR3 GM's counts line.

## word_presets

`10 u8`: the word before the presets.

## word_instruments

`14 u8`: the word before the instruments.

## word_samples

`10 u8`: the word before the samples.

## msg_no_sound

`21 u8`: the line for a machine with no sound.

## msg_no_tone

`45 u8`: the line for a tone disk without the font.

## msg_tone_refused

`38 u8`: the line for a refused tone font, its code following.

## msg_no_mix

`24 u8`: the line for a machine without the mix disk.

## msg_no_fluid

`43 u8`: the line for a mix disk without FluidR3 GM.

## msg_fluid_refused

`32 u8`: the line for a refused FluidR3 GM, its code following.
