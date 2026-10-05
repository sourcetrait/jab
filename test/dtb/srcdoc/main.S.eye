j _start [8:222] :checks every tree on the disk of serial dtb, then reads QEMU's through every lookup and dtb_listed over the supervisor IMSIC's compatible, a line each, and exits with 0, or 1 when the disk, a file, the good tree, or a lookup is missing
call local print_reg path addr > clobber a0-a5,s4 [224:263] :`reg <path> <reg>` for the node at the path, or `reg <path> none`
call local load path addr > bytes a0 i64,tree tree u8,clobber a1-a4,a7 [265:304] :the file at the path off the disk in s0 into tree, a page at a time
 bytes :read, at most FILE_BYTES; -1 when the file is not there
call local line_reset > cursor lineptr addr [306:310]
 cursor :the start of line
call local line_char char u8 > text line u8,cursor lineptr addr [312:318]
call local line_str string addr > text line u8,cursor lineptr addr [320:333]
 string :NUL-terminated, appended without its terminator
call local line_dec value u64 > text line u8,cursor lineptr addr [335:359]
 text :the value in decimal appended, built backward in digits first
call local line_print > clobber a0,a7 [361:372] :the line with a newline on the UART, then the line reset
