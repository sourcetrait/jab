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
call local read_file buffer addr,room u64,disk u8,path addr > bytes a0 u64,clobber a1-a4,a7 [114:166] :the file at path on the disk, from its root, into the buffer a page at a time
 bytes :read, 0 when the file is not there
call local print_counts name addr,presets u64,instruments u64,samples u64 > clobber a0-a1,a7 [168:195] :prints the name then the counts as presets=P instruments=I samples=S on the UART
call local print_code message addr,code u64 > clobber a0-a1,a7 [197:211] :prints the message then the code on the UART
 code :arrives in s1
call local append_str at addr,string addr > end a0 addr,clobber a1 [213:222] :copies the NUL-terminated string to at, without its terminator
 end :past the copy
call local append_dec at addr,value u64 > end a0 addr,clobber a1 [224:243] :writes the value in decimal at at, without a terminator
 end :past the digits
call local spin ticks u64 [245:251] :the ticks go by with the hart busy the whole time
