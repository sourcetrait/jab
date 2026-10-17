# main.S

harts: the machine's harts as jab.sys.harts reports them, one line for the
test to judge, `harts <discovered> <online> <failed>`, each mask in
decimal, bit n for hart n, read after a hold of two seconds; then the
window probe's line, `window <pages> <wrong>`.

## _start

The hold is display ticks awaited, the hart halted between them, so the
test can measure the idle harts' threads over a second of it, and a hart
whose check-in lost its race has long since tried its swap when the masks
are read. The cursor in the line rides s3 through the helpers, which keep
nothing else. The window probe writes each page's first word of the
window's last GiB, the stack's top MiB left out, with its own address,
then reads every one back, counting the pages and those that did not
hold it; the same window on every machine, 4 GiB or 8.

## .set HOLD_TICKS

`u64`: the display ticks the program awaits before it reads the masks, two
seconds at 60.

## .set PAGE

`u64`: the probe's step, a page.

## .set PROBE_BASE

`u64`: the probe's first page, a GiB below the stack top.

## .set PROBE_END

`u64`: past the probe's last page, a MiB below the stack top, where the
stack lives.

## word_harts

`7 u8`: the line's first word.

## word_window

`8 u8`: the probe's line's first word.

## line

`128 u8`: the line being built.

## digits

`32 u8`: put_dec's digits, built backward.
