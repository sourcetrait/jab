# main.S

framecap: the frame cap and the flips' receipts. A flip before the
display opens, which answers 2. Then sixty-four flips in a row with no
waiting: the first goes through and the rest come too early, which the
kernel refuses without showing them. Then sixty-four frames the proper
way, await then flip, half of them whole and half a rectangle, which take
sixty-four periods of the cap while the hart halts between them. Then a
rectangle reaching past the screen's edge, which the kernel must refuse;
then a list of two rectangles as one flip, a list with one past the edge,
and a list of none; then a flip, a print to the screen, and a flip, the
print's present between them; then what the kernel was built with.

Every flip keeps its receipt: the kind of flip, the status in a0, the
decision's stamp in a1, the eligibility tick in a2, and the present
ordinal in a3 as the kernel answered them, with the program's own
`rdtime` just before the call and just after it, the bracket a stamp must
lie in. The receipts are kept in memory and printed after the flips, so
no print slows the burst.

With the API on the machine, a letter sent over it picks a scenario
instead, each run under one of the kernel's GPU knobs: `l` a list of
three whose second transfer the knob refuses, `b` a list past a batch
whose first batch's transfer it refuses, `t` a whole flip whose transfer
it refuses, `f` one whose flush it refuses, and `s` the GPU's source held
until it fails. After `t`'s and `f`'s refused flip, the pixel at the
origin is flipped at once: the tick it reads is the one the refused flip
left, so the receipt shows whether a refusal moved the frame clock, and a
pixel away from the screen's middle keeps `t`'s capture the old frame's.
`k` takes the frame clock's rule at exact ticks, under no knob: after the
letter, a u64 count of cases and each case's tick, acceptance, and
present's end as u64, read by a bounded wait; each case through
`jab.sys.frame.step`, a DEBUG kernel's call, its receipt the kind, the
status, the tick in the before field, the next tick in a1, and the case's
acceptance and end in a2 and a3. A zero-length API write asks whether the
port is there: it answers 1 with none.

## .set FLIPS

`u64`: the flips in each run, sixty-four.

## .set RECEIPTS

`u64`: the receipts the program keeps, room for the plain run's 135.

## .set RECEIPT_BYTES

`u64`: a receipt's bytes: the kind, the status, the stamp before, a1 to
a3, and the stamp after, seven u64, and one spare.

## .set SELECT_WAIT

`u64`: two seconds of `rdtime`, how long the program waits for a
scenario's letter.

## .set HELD_WAIT

`u64`: three and a half seconds of `rdtime`, past the stuck-source
window's three, how long the held scenario awaits with no flip.

## .set SENTINEL

`u64`: what the held scenario leaves in a1 to a3 before its last flip,
so a kernel that wrote nothing there shows it.

## .set OLD

`u32`: the old frame's colour, 0x00RRGGBB.

## .set NEW

`u32`: the new frame's colour, 0x00RRGGBB.

## .set LIST_LONG

`u64`: the long list's rectangles, thirty-three, past a batch's
thirty-one.

## .set KIND_CLOSED

`u64`: a receipt's kind: the flip before the open.

## .set KIND_BURST

`u64`: a flip of the burst.

## .set KIND_WHOLE

`u64`: an awaited whole flip.

## .set KIND_RECT

`u64`: an awaited rectangle flip.

## .set KIND_BADRECT

`u64`: the rectangle past the edge.

## .set KIND_RECTS

`u64`: the list of two.

## .set KIND_BADRECTS

`u64`: the list holding one past the edge.

## .set KIND_NORECTS

`u64`: the list of none.

## .set KIND_BEFORE_PRINT

`u64`: the flip before the print.

## .set KIND_AFTER_PRINT

`u64`: the flip after the print.

## .set KIND_OLD

`u64`: a scenario's whole flip of the old frame.

## .set KIND_LIST

`u64`: the list scenario's list.

## .set KIND_LONG

`u64`: the long list scenario's list.

## .set KIND_BADXFER

`u64`: the transfer scenario's whole flip.

## .set KIND_BADFLUSH

`u64`: the flush scenario's whole flip.

## .set KIND_HELD

`u64`: the held scenario's flip before the source fails.

## .set KIND_FAILED

`u64`: the held scenario's flip after it failed.

## .set KIND_STEP

`u64`: a receipt of `k`'s, one a step case.

## .set STEP_CASES

`u64`: the most step cases a scenario takes.

## .set STEP_BYTES

`u64`: a step case's bytes, its tick, acceptance, and end as u64.

## .set KIND_AFTER

`u64`: the pixel's flip right after a refused whole flip.

## .set rect

`u64`: the long list's rectangle being laid out, the assembler's count.

## line

`128 u8`: a receipt's line, `receipt ` and seven sixteen-digit hex fields,
the last ending the line, written over in place for each receipt.

## flags

`6 u8`: the kernel flags' line, its digits following.

## flags_digits

`4 u8`: the kernel's flags, a newline, and the terminator.

## two_rects

`8 u32`: two rectangles apart on the screen.

## bad_rects

`8 u32`: two rectangles, the second reaching past the bottom.

## three_rects

`12 u32`: three rectangles in a row across the top, the list scenario's.

## long_rects

`132 u32`: LIST_LONG rectangles of ten pixels, forty apart along a row.

## paced

`7 u8`: the plain run's last line, once every check has run.

## msg_print

`9 u8`: the text the plain run prints to the screen between two flips.

## msg_done

`25 u8`: a scenario's line once its receipts are out.

## msg_no_scenario

`23 u8`: the line for an API with no letter in time.

## msg_no_display

`22 u8`: the line for a machine with no display.

## msg_flip_failed

`37 u8`: the line for a flip after await that failed.

## receipt_count

`u64`: how many receipts are kept.

## receipts

`RECEIPTS * RECEIPT_BYTES u8`: the receipts, RECEIPT_BYTES each.

## selector

`8 u8`: where the scenario's letter lands, and the zero-length write's
buffer.

## step_cases

`8 + STEP_CASES * STEP_BYTES u8`: `k`'s count, a u64, and its cases as they
came over the API.
