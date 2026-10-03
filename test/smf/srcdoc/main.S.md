# main.S

smf: the Standard MIDI File player under test. Reads /piece.mid off
the first disk, a file the test wrote, plays it, spins on the clock
until the piece has ended so the stream's refills come through the
trap vector, lingers a moment for the last release, and exits, which
plays the stream out; the host records what played and the test
holds it against the file. With no sound device it says so and exits
2; with no file, 1; with a file the player refuses, 3.

## _start

The file comes out of the romfs and into memory, a read at a time from the
offset the one before returned.
