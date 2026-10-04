j _start [26:36] :opens the display and the sound, draws the keys, and plays them until the window closes
j local loop [37:43] :takes every key event waiting and applies it, then waits for more
j local no_display [45:47] :says so on the UART and exits with 1
j local no_sound [49:51] :says so on the UART and exits with 2
call local draw_keys > keys JAB_DISPLAY_BASE u32,clobber a0-a5,a7 [53:97]
 keys :every key a white rectangle with its label in it, not flipped
call local apply_key code u16,value i32 > clobber a0-a3,a7 [99:128] :a press starts the key's note and a release ends it, a repeat or another key ignored
 value :JAB_KEY_PRESSED, JAB_KEY_RELEASED, or JAB_KEY_HELD
