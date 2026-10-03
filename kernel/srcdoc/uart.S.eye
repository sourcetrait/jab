macro uart_wait base address > scratch t1 [3:8] :waits until the transmit register is empty
 base :the UART's address
call uart_putc byte u8 [13:19]
call uart_puts string address > clobber a0 [20:33]
 string :NUL-terminated
call uart_put_hex value u64 > clobber a0 [34:61] :writes 0x and sixteen hex digits
call uart_put_dec value u64 > clobber a0 [62:84] :writes in decimal
