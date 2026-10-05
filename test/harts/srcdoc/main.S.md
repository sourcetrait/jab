# main.S

harts: the machine's harts as jab.sys.harts reports them, one line for the
test to judge, `harts <discovered> <online> <failed>`, each mask in
decimal, bit n for hart n, read after a hold of two seconds.

## _start

The hold is display ticks awaited, the hart halted between them, so the
test can measure the idle harts' threads over a second of it, and a hart
whose check-in lost its race has long since tried its swap when the masks
are read. The cursor in the line rides s3 through the helpers, which keep
nothing else.

## .set HOLD_TICKS

`u64`: the display ticks the program awaits before it reads the masks, two
seconds at 60.

## word_harts

`7 u8`: the line's first word.

## line

`128 u8`: the line being built.

## digits

`32 u8`: put_dec's digits, built backward.
