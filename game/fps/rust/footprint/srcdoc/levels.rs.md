# levels.rs

A LEVELS pixel is (level << 20) | (offset << 16) | span (render.inc's
levels_pixel): red's high nibble the block's level, red's low nibble the
pixel's offset in its block, green and blue the span's index in the frame's
packet.

## const SENTINEL

## const LEVEL_MAX

## struct Code

## fn code_of

## struct Block

`end` is one past the block's last pixel seen, so a span's last block,
short or with a hidden tail, has its length as the engine stepped it only
where nothing hides its tail.

## fn blocks

A block is keyed by its span and its start, the pixel's x less its offset,
so a block whose first pixels a later span covers is still found whole
from the pixels left. The refusals are the transport's failures: a level
past 9 that is not the sentinel, a block whose start would lie before its
row, a span on two rows, and a block of two levels, each naming the pixel.
