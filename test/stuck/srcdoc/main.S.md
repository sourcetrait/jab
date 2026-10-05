# main.S

stuck: a device whose interrupt source stays asserted with no progress, for
the test to judge from the UART: one line, `stuck random <first> then
<second>, flip <status>`, the two draws' statuses and a flip's after them.
Run under a debug kernel's `jab.hold` knob naming the rng's virtio device
id, the rng's line is held from the first draw on, so its source is masked
within the waits (aia.S), the second draw answers 1, and the flip still
answers 0; with no knob both draws answer 0.

## _start

The waits are the display's: each one drains the interrupts, which is where
a held source's window runs out, and its line prints at the wait's safe
point, before the program's own.

## .set WAIT_TICKS

`u64`: the display ticks waited between the draws, four and a half seconds
at 60, past the three a stuck source is given.

## .set DRAW_BYTES

`u64`: the bytes each draw asks for.

## word_stuck
## word_then
## word_flip

`u8`: the line's words.

## buffer

`DRAW_BYTES u8`: where the draws land.

## line

`128 u8`: the line being built.

## digits

`32 u8`: put_dec's digits, built backward.
