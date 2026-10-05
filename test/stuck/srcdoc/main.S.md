# main.S

stuck: the stuck-source scenarios, one a launch, for the test to judge from
the UART and the debug channel. The test sends one letter over the API a
second in, r, p, a, s, or d, and runs a debug kernel whose knobs hold the
scenario's device line (`jab.hold`) or leave its sends unnotified
(`jab.unsent`), so the device's source stays asserted with no progress until
the kernel masks it, resets the device, and ends every wait on it with the
failure. Each scenario echoes `stuck: scenario <name>`, prints one line of
what its calls answered, and exits 0; the kernel's own line for the masked
source, `jab: interrupt source N stalled`, lands between them.

## .set SELECT_WAIT

`u64`: how long the program waits for the scenario's letter, two seconds of
the time counter.

## .set DRAW_BYTES

`u64`: the bytes each draw asks for, the whole quota the test gives a period.

## .set RNG_HOLD

`u64`: how long past draw 1 the buffer is held before it is checked, seven
seconds, past the test's six-second period and a margin.

## .set PATTERN

`u8`: what the buffer is filled with between the draws.

## .set SPIN

`u64`: the sound scenario's second of user mode after its await.

## .set API_BYTES

`u64`: the bytes each API write sends.

## _start

The selector is read without waiting on it alone: the program awaits the
display's tick or the API, so it gives up at SELECT_WAIT even when no byte
comes.

## rng

Draw 1 takes the period's whole quota, which the test sets with QEMU's rng
properties, and its completion is the one the held line leaves asserted;
draw 2 then waits for a refill that comes only at the next period, so it is
outstanding when the source's window runs out, and answers 1. The buffer is
filled with PATTERN after draw 1, snapshotted after draw 2, and compared
again past draw 1's time plus RNG_HOLD, which is past the device's next
refill: a device left running after the failure would have written its
refill into the buffer then. Without the knob both draws answer 0 and the
buffer holds the second's bytes, unchanged after.

## pad

The pad on the serial device's port, its header taken at open; the test
sends no events. The serial device's line is held, so its source fails and
takes the port pad with it: the await on the pad alone ends with 0, and the
read after it answers 1.

## api

The first write's descriptor is published and the device never told
(`jab.unsent`), so it is outstanding when the console's source fails and
answers 2; the second answers 1, the port down with the device.

## sound

The ring filled with silence and an await on the sound alone: the held
stream's returned periods are taken back and none offered again, so its
source's window fires before the stream's own stall check, and the await
ends with 0 through its teardown. SPIN of user mode after it is where a
timer left enabled would fault.

## disk

The disks as jab.sys.block.list gives them, each id and kind; the test reads
the kernel's per-disk debug lines beside it.

## word_none
## word_scenario
## name_rng
## name_pad
## name_api
## name_sound
## name_disk
## word_random
## word_then
## word_intact
## word_overwritten
## word_flip
## word_pad_read
## word_await
## word_read
## word_api_write
## word_sound_write
## word_took
## word_disks
## word_kind

`u8`: the lines' words and the scenarios' names.

## api_bytes

`8 u8`: what each API write sends.

## disks

`JAB_BLOCK_LIST_SIZE u8`: the disks' records.

## pad_record

`JAB_PAD_ENTRY u8`: the pad's state, as a read writes it.

## buffer

`DRAW_BYTES u8`: where the draws land.

## snapshot

`DRAW_BYTES u8`: the buffer as it stood after draw 2.

## silence

`JAB_SOUND_RING * JAB_SOUND_FRAME_BYTES u8`: the frames the sound scenario
writes, zeros.

## selector

`8 u8`: the scenario's letter.

## line

`128 u8`: the line being built.

## digits

`32 u8`: put_dec's digits, built backward.
