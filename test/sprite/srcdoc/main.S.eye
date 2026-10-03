set BACKGROUND u32 [3] :the painted background's colour
set TINT u32 [4] :the tinted draw's colour
j _start [8:168] :paints the background, draws the sprites every way with each code on the UART, flips once, and idles
j local no_display [170:172] :says so on the UART and exits with 1
call local report code u64 > clobber a0,a7 [174:192] :prints draw and the code on the UART
 code :jab.sys.sprite.draw's, one digit
rodata local blend 16 u32 [196:200] :one frame of 4 by 3, every kind of alpha, no flags, so it is drawn whole
rodata local sheet 12 u32 [201:206] :two frames of 2 by 2, one after the other
rodata local thin 32 u32 [207:216] :one frame of 6 by 4, mostly clear, its span table of 16-bit columns last
rodata local msg_no_display 20 u8 [217:218] :the line for a machine with no display
bss local line 16 u8 [221:222] :the report line
