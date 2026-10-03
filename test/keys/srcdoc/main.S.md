# main.S

keys: the keyboard. Waits for key events and reports each on the
UART as `key <code> <value>`, three digits and one, until the space
bar is released, then exits 0.

## next

The event's code and value are kept in s0 and s1. The code goes into
code_digits as three digits, the value into value_digit as one, and report
is printed from its start through both.
