# main.S

midi: the kernel's synthesizer under test. Sets channel 0 to the
square lead, plays the A at 440 Hz for a second at full velocity,
releases it, and spins on the clock for half a second more, never
waiting in the kernel, so every refill of the stream comes through
the trap vector while the program runs; then exits. The host
records what played and the test measures it. With no sound device
it says so and exits 2.
