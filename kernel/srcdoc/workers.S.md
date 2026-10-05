# workers.S

The workers: the program's work on the harts past hart 0. A secondary
waits in its kernel idle until hart 0 starts a worker on it, runs the
program in user mode from the entry and on the stack it was given, and goes
back to the idle when the worker ends or is stopped. Each hart's record
(hart.inc) carries its worker: HART_WORK its state, idle, starting,
running, or halted; the entry, the argument, and the stack; HART_CONTROL the
stop asked of it; HART_SLEEPING while it waits; and its fault. The wait and
the wake are any hart's, so hart 0 joins its workers with the same calls.
Every wake is a message of the wake's identity to the hart's interrupt file
after `fence w, o` (hart_wake), so whatever the waker stored before it is
there when the woken hart looks.

The shutdown is here too. The first hart to fault, or hart 0 in
jab.sys.exit, claims shutdown_owner; every other hart stops at its next
safe point, the trap boundary or an outermost wait, and marks itself halted
(shutdown_park); the owner waits for each online hart to halt, then prints
every recorded fault (trap.S's fatal_exit). A hart that has not halted
within SHUTDOWN_TICKS is named after the faults, and the run ends anyway.

## hart_idle

The check comes before the wfi and nothing claims between them, so a
start's wake sent after the check stays pending in the hart's file and ends
the wfi at once. The drain claims the wake and fences, so the state is read
after it.

## worker_enter

The swap from starting to running races hart 0's swap from starting back to
idle at the start's bound, and one wins. A hart that loses has been taken
back: it waits for hart 0 to fail it and parks for the run, touching
nothing. The winner wakes hart 0, which waits for it, then leaves the
registers as a start promises: every f register, fcsr, and every v register
0, vcsr 0, and vtype's vill set with vl 0, as a reset leaves them, through a
vsetvl of a type no hart supports; sstatus's FS and VS back to Initial; every
integer register 0 but a0, the argument, a1, the hart's id, and sp, the
stack's top. ra is 0, so a return from the entry faults at address 0 and the
fault's line names the worker. Under DEBUG the knob `jab.noack=<hart>` holds
that hart here, before its swap, until hart 0 has taken the start back.

## knob_noack

`11 u8`: the noack knob's name, under DEBUG only.

## worker_leave

A worker's exit and a forced stop end here, on the worker's hart, the trap's
frame let go. The kernel stack's canary is checked first, since a stack that
ran past its bottom has written into the hart below's record. The old
worker's bookkeeping is finished before the hart is published as startable:
its bit leaves workers_live first, then the state goes idle with release
ordering after everything the worker did, so a stop that reads it idle may
reuse the worker's stack and buffers, and hart 0 is woken, in case it waits
on the exit. The order is the point: a start decides busy by HART_WORK alone
and sets its own bit after, so with the state published first a start
landing between the two steps had its new bit cleared by the old exit, and
hart 0's external enable, gated on workers_live, held a worker's wake or a
fault's shutdown until it next waited. Under DEBUG, leavehold_gap sits
between the two publications.

## sys_worker_wake

The waker's half of the protocol sys_worker_wait describes: the caller
stored its word before the call, then `fence rw, rw`, then each target's
SLEEPING read. A hart in the mask that does not sleep in a wait is not
woken, hart 0 in jab.sys.await among them.

## sys_worker_wait

The sleeper's half: SLEEPING stored, then `fence rw, rw`, then the word read
after every drain. A waker stores the word, then `fence rw, rw`, then reads
SLEEPING. So either the sleeper sees the new word or the waker sees SLEEPING
and sends its wake, which stays pending until the wfi, since nothing claims
between the check and it. The order of the checks, the shutdown, the stop,
then the word, lets a worker ask whether a stop is pending without sleeping,
by a value its word does not hold. On hart 0 the drain serves the devices,
as sys_await's does, so the sound stream plays on through a join.

## sys_worker_start

Every refusal is decided before anything is written, in the order of its
code: the hart, its worker, the entry, the stack, then the overlaps, the
main stack's reservation under the window's top and each running worker's
stack. The busy check that finds the hart idle is followed by `fence r,
rw`, pairing with worker_leave's release, so the record's fields, the
starting state, and the live bit follow the old worker's finished exit; the
branch on the read already orders those stores, and the acquire is kept
explicit. Under DEBUG the busy check's read is leavehold_work's. The
fields go into the hart's record before its state turns to starting, with
`fence w, w` between, and the wake follows the state. The
acknowledgement's wait is bounded by WORK_START_TICKS, 100 ms, the
check-in's bound, since a vCPU thread is a host thread a busy host can keep
off a core for milliseconds, and a hart that misses the bound is lost for
the run. Past it, hart 0 swaps the state back from starting to idle; if that
wins, the hart is failed by CheckInRace's swap with its reason, and the call
answers JAB_START_NO_ACK.

## stop_pending

The harts of a mask whose state is not idle, its state kept in a and t
registers so that, under DEBUG, each read can be leavehold_work's. The
fence after it orders the states' reads before any read of what a stopped
worker wrote.

## sys_worker_stop

The targets are every online secondary in the mask, read from the records
through harts_masks, and the call returns only once every one of them reads
idle through stop_pending, whose fence acquires each final publication, so
a hart mid-exit is waited for. workers_live is no barrier here: an exit
clears its bit before it publishes idle, so a stop filtering on it could
return before a hart's last stores were visible. A target found working is
asked first: the stop's bit set and the hart woken, so a wait answers 1 at
once and a running worker takes the wake as an interrupt and goes on; a
target found idle is asked nothing. Past WORK_STOP_TICKS, 50 ms, each one
still in has the forced bit set and is woken again, and leaves the program
at its next trap boundary. Past WORK_FORCE_TICKS, a second more, a worker
still in may still be writing memory the program would reuse, so the run
ends with `jab: worker stop refused: hart N`. A stop bit left in the control
word of a hart whose exit had already begun is harmless: the next start
zeroes HART_CONTROL before the starting state. The answer's first mask is
the mask's online secondaries, each free of a worker once the call returns,
so it does not depend on whether a worker had already ended by itself.
Under DEBUG each target's read is leavehold_work's.

## shutdown_enter

The claim is a compare-and-swap of shutdown_owner from 0 to the hart's id
plus one, lr and sc as hart_swap's (harts.S). A hart that finds another's
claim parks where it is: its fault is already in its record, and the owner
prints it. The owner wakes every other online hart, so a worker in user mode
traps and a hart in a wait looks again, then waits for each to halt, by
pause rather than wfi, since the run is ending. Under DEBUG the knob
`jab.claimhold=<ms>` holds a won claim that many milliseconds before the
wakes, so a second worker's fault lands before the first owner's wake can
stop it.

## knob_claimhold

`15 u8`: the claimhold knob's name, under DEBUG only.

## shutdown_park

No lock is held at a safe point, so a parked hart holds nothing the owner
needs. Its interrupts are off, sie 0 with no machine bit in mie, so nothing
wakes it again.

## leavehold_gap

The witness of worker_leave's gap, for test/workers' Restart and StopExit:
busy answers and elapsed times prove no interleaving, since a worker can be
descheduled before its exit and hart 0 between a call and its timestamp, so
the gap is held and what looked at the hart inside it is written down. The
knob is read with knob_value as jab.noack's is, and is one-shot: the
named hart's first exit consumes it. The worker's argument is the witness
word's address, checked on 4 bytes inside the program's window before any
write, else the knob is inert for that exit. The address goes to
leavehold_word, then `fence w, w`, then the enable to leavehold_hart, so an
observer never sees the enable with a stale address; then `fence rw, w` and
LEAVEHOLD_HELD into the word, the release of the hold's publication. The
hart then spins with pause reading the word: past LEAVEHOLD_HELD an
observation released it; still held at LEAVEHOLD_TICKS, 200 ms by rdtime, it
swaps the word to LEAVEHOLD_EXPIRED, and finding it already past held takes
the observation instead. Either way `fence r, rw` acquires what the
observer wrote, and leavehold_hart is cleared before the release fence that
precedes the idle. Every transition out of held is a compare and swap in
the specification's constrained LR/SC loop (`isa/v20260120/unpriv/
a-st-ext.md` 12.1.3): lr.w, bne out when the word no longer reads held,
sc.w, bnez back to the lr.w, so only one succeeds and a terminal value is
never overwritten, and a failed SC is a retry, never a lost race. No line
goes to the UART or the debug channel; the witness travels in the word.

## knob_leavehold

`15 u8`: the leavehold knob's name, under DEBUG only.

## leavehold_work

The hook at the three places hart 0 decides by a hart's state: the start's
busy check, the stop's scan, and stop_pending. For the held hart, with
leavehold_hart naming it, `fence r, r`, then the word through leavehold_word
reading held, `fence r, rw` acquires the hold's publication; then the read
of HART_WORK the caller decides by; then the observer's code, its base
LEAVEHOLD_BY_START or LEAVEHOLD_BY_STOP plus LEAVEHOLD_SAW_WORKING or
LEAVEHOLD_SAW_IDLE, swapped into the word by lr.w and sc.w.rl, which
releases the hold. The read sits between the acquiring load and the swap,
never inside the LR/SC pair, whose constrained loop admits no loads; the
swap's success shows the word read held across the read, so the
observation was made inside the hold. Any other hart, or a word not held,
is the plain read. The hook records and releases and changes no decision.

## msg_stop_refused

`32 u8`: the stop's refusal line's prefix.

## msg_overrun

`33 u8`: the kernel stack overrun line's prefix.

## workers_live

`u64`: a bit a hart running a worker, set by its start and cleared by its
leave before the hart reads idle; hart 0 keeps its external interrupts
enabled in user mode and in jab.sys.await while it is not 0. Interrupt
bookkeeping alone, never the stop's barrier.

## shutdown_owner

`u64`: 0, or the shutdown's owner's hart id plus one.

## shutdown_unanswered

`u64`: a bit a hart that did not halt within the shutdown's bound, written
by the owner and printed by fatal_exit.

## leavehold_hart

`u64`: under DEBUG, 0, or the hart jab.leavehold holds at its exit's gap,
its id plus one.

## leavehold_word

`u64`: under DEBUG, the held exit's witness word's address, captured once
and published before leavehold_hart.

## leavehold_spent

`u64`: under DEBUG, 1 once the knob's hart has taken its one exit.
