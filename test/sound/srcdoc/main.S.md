# main.S

sound: the kernel's sound device under test. Opens the stream and
plays a second of a 440 Hz square wave at AMPLITUDE either side of
silence, one period at a time, waiting whenever the ring is full,
then exits, which plays the ring out; the host records what played
and the test measures it. With no sound device it says so and
exits 2.

## .set PERIODS_TO_PLAY

`u64`: the periods played, a second.

## .set AMPLITUDE

`i16`: the wave's height either side of silence.

## .set STEP

`u32`: 440 Hz as a phase step in 1/2^32 cycles a frame at 48 kHz.

## next

One period of the wave is built in period, the square's sign from the
phase's top bit and both channels alike, the phase stepping STEP a frame and
kept to 32 bits. It goes into the stream whole, waiting for room as needed.

## period

`1920 i16`: one period of frames, left then right.

## msg_no_sound

`17 u8`: the line for a machine with no sound, or a refused write.
