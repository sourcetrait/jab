set CHANNEL u8 [3] :the MIDI channel played
set TONE_NOTE u8 [4] :the A above middle C, the tone font's root
set TONE_VELOCITY u8 [5] :full velocity
set TONE_VOLUME u8 [6] :full volume
set TONE_HOLD u64 [7] :how long the tone sounds, a second in ticks
set TAIL u64 [8] :the spin after each release, half a second in ticks
set PIANO_PROGRAM u8 [9] :the General MIDI program, the acoustic grand piano
set PIANO_NOTE u8 [10] :middle C
set PIANO_VELOCITY u8 [11] :the piano note's velocity
set PIANO_HOLD u64 [12] :how long the piano sounds, most of a second in ticks
set TONE_BYTES u64 [13] :room for the tone font, 4 KiB
set FONT_BYTES u64 [14] :room for FluidR3 GM, 160 MiB
set PAGE_BYTES u64 [15] :the most one read takes, 1 MiB
set LINE_BYTES u64 [16] :room for a line
set DIGITS_BYTES u64 [17] :room for a decimal's digits
j _start [21:53] :opens the sound and, with the tone disk there, loads the tone font and plays its A, then goes on to fluid
j local fluid [54:84] :loads FluidR3 GM off the mix disk, plays the piano's middle C through it, and exits with 0
j local no_sound [86:88] :says so on the UART and exits with 2
j local no_tone [90:92] :says so on the UART and exits with 3
j local tone_refused code u64 [94:98] :says so on the UART with the code and exits with 4
 code :jab.sys.midi.soundfont's
j local no_mix [100:102] :says so on the UART and exits with 5
j local no_fluid [104:106] :says so on the UART and exits with 6
j local fluid_refused code u64 [108:112] :says so on the UART with the code and exits with 7
 code :jab.sys.midi.soundfont's
call local read_file buffer address,room u64,disk u8,path address > bytes a0 u64,clobber a1-a4,a7 [114:166] :the file at path on the disk, from its root, into the buffer a page at a time
 bytes :read, 0 when the file is not there
call local print_counts label address,presets u64,instruments u64,samples u64 > clobber a0-a1,a7 [168:195] :prints the label then the counts as presets=P instruments=I samples=S on the UART
call local print_code message address,code u64 > clobber a0-a1,a7 [197:211] :prints the message then the code on the UART
 code :arrives in s1
call local append_str at address,string address > end a0 address,clobber a1 [213:222] :copies the NUL-terminated string to at, without its terminator
 end :past the copy
call local append_dec at address,value u64 > end a0 address,clobber a1 [224:243] :writes the value in decimal at at, without a terminator
 end :past the digits
call local spin ticks u64 [245:251] :the ticks go by with the hart busy the whole time
bss local rec 144 u8 [255:256] :a file's romfs record
bss local digits 24 u8 [257:258] :append_dec's digits, built backward
bss local line 128 u8 [259:261] :the line being built
bss local tone 4096 u8 [262:264] :the tone font
bss local font 167772160 u8 [265:266] :the FluidR3 GM font
rodata local serial_tone 5 u8 [269:270] :the tone disk's serial
rodata local serial_mix 4 u8 [271:272] :the mix disk's serial
rodata local path_tone 10 u8 [273:274] :the tone font's path on its disk
rodata local path_fluid 29 u8 [275:276] :the path of FluidR3 GM on the mix disk
rodata local label_tone 16 u8 [277:278] :the tone font's counts line's label
rodata local label_fluid 17 u8 [279:280] :the label of FluidR3 GM's counts line
rodata local word_presets 10 u8 [281:282] :the word before the presets
rodata local word_instruments 14 u8 [283:284] :the word before the instruments
rodata local word_samples 10 u8 [285:286] :the word before the samples
rodata local msg_no_sound 21 u8 [287:288] :the line for a machine with no sound
rodata local msg_no_tone 45 u8 [289:290] :the line for a tone disk without the font
rodata local msg_tone_refused 38 u8 [291:292] :the line for a refused tone font, its code following
rodata local msg_no_mix 24 u8 [293:294] :the line for a machine without the mix disk
rodata local msg_no_fluid 43 u8 [295:296] :the line for a mix disk without FluidR3 GM
rodata local msg_fluid_refused 32 u8 [297:298] :the line for a refused FluidR3 GM, its code following
