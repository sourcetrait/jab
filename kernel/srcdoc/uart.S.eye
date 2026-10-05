macro uart_wait base addr > scratch t1 [5:10] :waits until the transmit register is empty
 base :the UART's address
call uart_putc char u8 [15:21]
call uart_puts string addr > clobber a0 [22:35]
 string :NUL-terminated
call uart_put_hex value u64 > clobber a0 [36:63] :writes 0x and sixteen hex digits
call uart_put_dec value u64 > clobber a0 [64:88] :writes in decimal
call uart_lock [89:100] :takes the line lock, waiting while another hart holds it; held for one line and never across a wait
call uart_unlock [101:106] :gives the line lock back
call uart_lock_fatal [107:119] :takes the line lock for a fault's line, waiting at most UART_FATAL_WAIT, after which the line goes out regardless
