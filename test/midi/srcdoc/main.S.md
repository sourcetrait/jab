# main.S

midi: the kernel's synthesizer under test. Sets channel 0 to the
square lead, plays the A at 440 Hz for a second at full velocity,
releases it, and spins on the clock for half a second more, never
waiting in the kernel, so every refill of the stream comes through
the trap vector while the program runs; then exits. The host
records what played and the test measures it. With no sound device
it says so and exits 2.

## .set CHANNEL

`u8`: the MIDI channel played.

## .set PROGRAM

`u8`: the General MIDI program, the square lead.

## .set NOTE

`u8`: the A at 440 Hz.

## .set VELOCITY

`u8`: full velocity.

## .set HOLD

`u64`: how long the note sounds, a second in ticks.

## .set TAIL

`u64`: how long the program spins after the release, half a second in ticks.

## msg_no_sound

`16 u8`: the line for a machine with no sound.
