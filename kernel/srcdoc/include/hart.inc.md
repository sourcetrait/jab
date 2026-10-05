# hart.inc

A hart's area and its record, which boot.S, kernel.S, trap.S, harts.S, and
workers.S share, the worker's states and bounds, and a fault's kinds. It
guards itself against a second inclusion and leans on qemu_virt.inc for the
timebase.

## .set HART_STACK_BYTES

`u64`: a hart's kernel stack, 16 KiB.

## .set HART_RECORD_BYTES

`u64`: a hart's record, above its stack, 144 bytes, so every area stays on
16 bytes.

## .set HART_AREA_BYTES

`u64`: a hart's stack and record together, its stride in hart_areas.

## .set HART_ID

`u64`: the record's hart id, written by the hart.

## .set HART_STATE

`u64`: the record's state, HART_PARKED to HART_FAILED, moved by compare and
swap once the hart is released.

## .set HART_WHY

`u64`: the record's reason for a failure, HART_WHY_*, written by hart 0
alone; 0 on a failed hart is its own self-check.

## .set HART_RESULT

`u64`: the record's self-check result, 0 or 1, written by the hart.

## .set HART_WORK

`u64`: the record's worker state, WORK_IDLE to WORK_HALTED: idle and
starting written by hart 0, running, idle again, and halted by the hart.

## .set HART_ENTRY
## .set HART_ARG
## .set HART_STACK_LOW
## .set HART_STACK_HIGH

`u64`: the record's worker: its entry, its argument, and its stack's lowest
address and top, written by hart 0 before the start.

## .set HART_CONTROL

`u64`: the record's control word, WORK_STOP and WORK_FORCED, set by hart 0's
stop and cleared by the worker's leave.

## .set HART_SLEEPING

`u64`: the record's 1 while the hart sleeps in jab.sys.worker.wait, which a
wake reads.

## .set HART_FAULT

`u64`: the record's fault, a FAULT_* kind, 0 for none, written after its
fields.

## .set HART_CAUSE
## .set HART_EPC
## .set HART_TVAL

`u64`: a trap's fault: scause, sepc, and stval.

## .set HART_LINE
## .set HART_VALUE

`u64`: a line's fault: the line's address and the value printed after it.

## .set HART_PARKED
## .set HART_RELEASED
## .set HART_ONLINE
## .set HART_FAILED

`u64`: a hart's states: parked, never released; released, its wake sent;
online, checked in; failed, for the run.

## .set HART_WHY_TOPOLOGY
## .set HART_WHY_NO_FILE
## .set HART_WHY_NO_CHECKIN

`u64`: hart 0's reasons: refused by the tree's problem; no supervisor file
to wake it through, none in the tree or its release store faulting; no
check-in by the bound.

## .set HART_WHY_NO_START

`u64`: hart 0's reason for a hart that did not take a worker's start within
WORK_START_TICKS.

## .set WORK_IDLE
## .set WORK_STARTING
## .set WORK_RUNNING
## .set WORK_HALTED

`u64`: a hart's worker states: idle, no worker; starting, the start sent
and not yet taken; running; halted, stopped for a shutdown.

## .set WORK_STOP
## .set WORK_FORCED

`u64`: the control word's bits: a stop asked, which a wait answers with 1;
and the stop forced, which takes the worker out at its next boundary.

## .set FAULT_PROGRAM
## .set FAULT_KERNEL
## .set FAULT_LINE
## .set FAULT_LINE_DEC
## .set FAULT_LINE_HEX

`u64`: a fault's kinds: a trap in the program, a trap in the kernel, and a
line alone, with a value in decimal, or with a value in hex.

## .set LEAVEHOLD_HELD
## .set LEAVEHOLD_EXPIRED

`u32`: the jab.leavehold witness word's states (DEBUG): held at the exit's
gap; and the hold's bound passed with nothing having looked, an expired
window that proves neither order.

## .set LEAVEHOLD_SAW_WORKING
## .set LEAVEHOLD_SAW_IDLE

`u32`: what an observer read of the held hart's HART_WORK, written over the
held state: working, or idle.

## .set LEAVEHOLD_BY_START
## .set LEAVEHOLD_BY_STOP

`u32`: who looked, added to what it saw: the start's busy check, or the
stop's scan or stop_pending; so 0x10 and 0x11 are a start's, 0x30 and 0x31
a stop's.

## .set HART_CANARY

`u64`: the word each hart writes at its stack's bottom, xored with its id.

## .set HART_CHECKIN_TICKS

`u64`: how long hart 0 waits for the released harts' check-in, 100 ms.

## .set WORK_START_TICKS

`u64`: how long hart 0 waits for a hart to take a worker's start, 100 ms,
the check-in's bound: a hart's vCPU thread is a host thread a busy host can
keep off a core for milliseconds, and a hart that misses it is failed for
the run.

## .set WORK_STOP_TICKS

`u64`: how long a stop waits for its workers to leave on their own, 50 ms,
before it interrupts them.

## .set WORK_FORCE_TICKS

`u64`: how long a stop then waits for the interrupted ones, a second, before
it ends the run.

## .set SHUTDOWN_TICKS

`u64`: how long the shutdown's owner waits for every other hart to halt, a
second; a hart past it is named after the fault lines.

## .set LEAVEHOLD_TICKS

`u64`: how long jab.leavehold holds an exit for an observer, 200 ms, before
the word reads expired and the exit goes on.
