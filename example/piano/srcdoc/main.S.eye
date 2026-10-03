set CHANNEL u8 [3] :the MIDI channel the keys play on
set PROGRAM u8 [4] :the General MIDI program, the acoustic grand piano
set VELOCITY u8 [5] :every note's velocity
set KEYS u64 [6] :the keys, one octave
set NOTE_FIRST u8 [7] :the first key's note, middle C
set KEY_WIDTH u64 [8] :a key's width in pixels
set KEY_HEIGHT u64 [9] :a key's height in pixels
set KEY_GAP u64 [10] :the pixels between two keys
set KEY_STRIDE u64 [11] :a key and its gap
set ROW_WIDTH u64 [12] :the row of keys' width
set ROW_X i64 [13] :the row's left, centred on the screen
set ROW_Y i64 [14] :the row's top, centred on the screen
set KEY_COLOR u32 [15] :every key's colour, white
set LABEL_SCALE u64 [16] :three times the console's cell, in 256ths
set LABEL_WIDTH u64 [17] :a label's width, bold adding a pixel
set LABEL_HEIGHT u64 [18] :a label's height
set LABEL_X i64 [19] :a label's left within its key, centred
set LABEL_Y i64 [20] :a label's top within its key, centred
set LABEL_COLOR u32 [21] :a label's colour, black
set LABEL_ENTRY u64 [22] :a label's bytes, a character and its terminator
j _start [26:36] :opens the display and the sound, draws the keys, and plays them until the window closes
j local loop [37:43] :takes every key event waiting and applies it, then waits for more
j local no_display [45:47] :says so on the UART and exits with 1
j local no_sound [49:51] :says so on the UART and exits with 2
call local draw_keys > keys JAB_DISPLAY_BASE u32,clobber a0-a5,a7 [53:97]
 keys :every key a white rectangle with its label in it, not flipped
call local apply_key code u16,value i32 > clobber a0-a3,a7 [99:128] :a press starts the key's note and a release ends it, a repeat or another key ignored
 value :JAB_KEY_PRESSED, JAB_KEY_RELEASED, or JAB_KEY_HELD
rodata local key_codes 12 u8 [131:133] :the keys that play, C4 up a semitone each
rodata local labels 24 u8 [134:136] :each key's label, LABEL_ENTRY bytes, terminated
rodata local msg_no_display 19 u8 [137:138] :the line for a machine with no display
rodata local msg_no_sound 17 u8 [139:140] :the line for a machine with no sound
