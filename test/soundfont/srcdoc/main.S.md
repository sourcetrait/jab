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

## _start

The tone font is played only when its disk is there.

## fluid

FluidR3 GM comes off the mix disk and the piano's middle C plays through it.
After the release the program spins TAIL before it exits.

## read_file

The path sits in a register, so the find goes by the plain call. The bytes
read so far ride in a4, which the read call's macro loads, so they are kept
on the stack across each read.
