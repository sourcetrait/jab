j _start [5:62] :lists the disks, prints a line for each and the page's answer, tries a write to the first, and exits with 0
call local line_reset > cursor lineptr addr [64:68]
 cursor :the start of line
call local line_char char u8 > text line u8,cursor lineptr addr [70:76]
 text :the character appended at the cursor, not terminated
call local line_nl > text line u8,cursor lineptr addr [78:86]
 text :a newline and the terminator appended where the line ends, the cursor left on the terminator
call local line_str string addr > text line u8,cursor lineptr addr [88:101]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_dec value u64 > text line u8,cursor lineptr addr [103:127]
 text :the value in decimal appended, built backward in digits first
