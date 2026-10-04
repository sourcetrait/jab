# main.S

badstore: stores into the kernel's memory. The kernel must report a
program fault (a store page fault, cause 15) and end the run with
status 1; the message after the store must never print.

## before

`25 u8`: the line printed before the store.

## after

`24 u8`: the line that must never print.
