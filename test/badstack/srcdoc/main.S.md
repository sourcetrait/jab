# main.S

badstack: the kernel never touches the program's stack. sp is put
inside the kernel's own memory, then at zero, then past the end of
RAM, and a call is made from each place: every call prints, since the
kernel keeps its own stack whatever the program's sp says, and the
exit's status comes back from the last of them.

## msg_kernel

`32 u8`: the line printed with sp inside the kernel.

## msg_zero

`22 u8`: the line printed with sp at zero.

## msg_past

`34 u8`: the line printed with sp past the end of RAM.
