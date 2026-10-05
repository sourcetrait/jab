# main.S

workerfault: a worker's fault ends the run, one scenario a launch. The test
sends one letter over the API a second in, k, t, j, a, or p; each scenario
echoes `workerfault: scenario <name>`, starts the workers it needs, and
leaves hart 0 waiting on something that never comes, so only the
shutdown's wake ends its wait and the kernel's lines alone follow the echo.

## .set SELECT_WAIT

`u64`: how long the program waits for the scenario's letter, two seconds of
the time counter.

## .set STACK_BYTES

`u64`: a worker's stack, 16 KiB; stacks holds two, hart 1's and hart 2's.

## .set KERNEL

`u64`: the kernel's first address, where every worker's store faults.

## .set LATE

`u64`: how long the join's worker spins before its store, a tenth of a
second.

## .set LONG_BYTES

`u64`: the print scenario's line, 32 KiB before its newline.

## two

Both workers wait at the same gate and store at once; the test's debug
kernel holds the first claim (jab.claimhold) so the second store lands
before the first owner's wake could stop that worker.

## printing

The fault lands in the print's first KiB, so hart 0 prints the rest under
the line lock with the shutdown already claimed, its sound_tick draining
every KiB, and stops at the boundary its print returns through.

## forever

The API's port is on the machine, so the await holds until bytes come,
which they never do.

## word_none
## word_scenario
## word_refused
## word_after
## name_store
## name_two
## name_join
## name_address
## name_print

`u8`: the lines' words and the scenarios' names.

## selector

`8 u8`: the scenario's letter.

## go

`8 u8`: the gate the workers wait at, a 32-bit word.

## never

`8 u8`: the join's word, which nobody sets.

## line

`128 u8`: the line being built.

## stacks

`2 * STACK_BYTES u8`: the workers' stacks.

## silence

`JAB_SOUND_RING * JAB_SOUND_FRAME_BYTES u8`: the frames the print scenario
writes, zeros.

## long_line

`LONG_BYTES + 2 u8`: the long line, its newline, and its terminator.
