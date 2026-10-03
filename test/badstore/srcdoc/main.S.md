# main.S

badstore: stores into the kernel's memory. The kernel must report a
program fault (a store page fault, cause 15) and end the run with
status 1; the message after the store must never print.
