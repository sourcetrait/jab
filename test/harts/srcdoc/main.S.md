# main.S

harts: the machine's harts as jab.sys.harts reports them, one line for the
test to judge, `harts <discovered> <online> <failed>`, each mask in
decimal, bit n for hart n.

## _start

The cursor in the line rides s3 through the helpers, which keep nothing
else.

## word_harts

`7 u8`: the line's first word.

## line

`128 u8`: the line being built.

## digits

`32 u8`: put_dec's digits, built backward.
