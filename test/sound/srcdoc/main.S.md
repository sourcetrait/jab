# main.S

sound: the kernel's sound device under test. Opens the stream and
plays a second of a 440 Hz square wave at AMPLITUDE either side of
silence, one period at a time, waiting whenever the ring is full,
then exits, which plays the ring out; the host records what played
and the test measures it. With no sound device it says so and
exits 2.

## next

One period of the wave is built in period, the square's sign from the
phase's top bit and both channels alike, the phase stepping STEP a frame and
kept to 32 bits. It goes into the stream whole, waiting for room as needed.
