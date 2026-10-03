set DISK u8 [3] :the romfs disk's id
set WIDTH u32 [4] :the logo's width in pixels
set HEIGHT u32 [5] :the logo's height in pixels
set SPRITE_BYTES u64 [6] :the sprite one frame of the logo needs
set PNG_BYTES u64 [7] :room for the PNG, 32 KiB
set X i64 [8] :the logo's left, centred on the screen
set Y i64 [9] :the logo's top, centred on the screen
j _start [13:51] :reads the PNG off the romfs, decodes it, draws it centred, and idles until the window closes
j local no_file [53:55] :says so on the UART and exits with 1
j local bad_png [56:58] :says so on the UART and exits with 1
j local no_display [59:61] :says so on the UART and exits with 1
rodata local path 21 u8 [64:65] :the PNG's path on the romfs
rodata local msg_no_file 35 u8 [66:67] :the line for a romfs without the PNG
rodata local msg_bad_png 32 u8 [68:69] :the line for a PNG that would not decode
rodata local msg_no_display 18 u8 [70:71] :the line for a machine with no display
bss local rec 144 u8 [75:76] :the PNG's romfs record
bss local png 32768 u8 [77:78] :the PNG as read
bss local sprite 1231376 u8 [79:80] :the logo as a sprite of one frame
