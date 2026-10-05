# hart.inc

A hart's area and its record, which boot.S, kernel.S, trap.S, and harts.S
share. It guards itself against a second inclusion and leans on
qemu_virt.inc for the timebase.

## .set HART_STACK_BYTES

`u64`: a hart's kernel stack, 16 KiB.

## .set HART_RECORD_BYTES

`u64`: a hart's record, above its stack, with room for the worker's fields
to come.

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

## .set HART_CANARY

`u64`: the word each hart writes at its stack's bottom, xored with its id.

## .set HART_CHECKIN_TICKS

`u64`: how long hart 0 waits for the released harts' check-in, 100 ms.
