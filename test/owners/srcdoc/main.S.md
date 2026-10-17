# main.S

owners: the drain's path condition held at run time on a debug kernel. A
worker on hart 1 sleeps in jab.sys.worker.wait and hart 0 wakes it, then
changes its word and wakes it until it is done, so a secondary's idle
entry, its wait's drains, and the wake's claims all run under the kernel's
DEBUG checks (aia.S's irq_drain, workers.S's hart_idle), and the test
reads the run for neither line. The test's static check reads the kernels
themselves, not this program.

## .set STACK_BYTES

`u64`: the worker's stack, 16 KiB.

## .set WAIT_TICKS

`u64`: how long each step waits, two seconds of the time counter.

## .set HART_BIT

`u64`: hart 1's bit in a wake's mask and in its answer.

## word_done
## word_refused
## word_never_slept
## word_never_done

`u8`: the lines.

## word

`8 u8`: the word the worker waits on, a 32-bit word, 0 until hart 0 sets
it.

## done

`8 u8`: the worker's mark, set once its wait has returned.

## stack

`STACK_BYTES u8`: the worker's stack.
