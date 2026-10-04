j _start [8:168] :paints the background, draws the sprites every way with each code on the UART, flips once, and idles
j local no_display [170:172] :says so on the UART and exits with 1
call local report code u64 > clobber a0,a7 [174:192] :prints draw and the code on the UART
 code :jab.sys.sprite.draw's, one digit
