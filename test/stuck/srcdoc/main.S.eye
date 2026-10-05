j _start [12:42] :opens the display, waits SELECT_WAIT for the scenario's letter over the API, and runs its scenario; with none, `stuck: no scenario` and exit 2
j local rng [44:116] :two draws, the second outstanding when the rng's source fails, the buffer checked past the device's next refill: `stuck random <first> then <second>, buffer intact|overwritten, flip <status>`, exit 0
j local pad [118:142] :a pad read, an await on the pad alone, a read again: `stuck pad: read <status>, await <events>, read <status>`, exit 0
j local api [144:163] :two API writes: `stuck api: write <status> then <status>`, exit 0
j local sound [165:195] :the ring filled, an await on the sound alone, then SPIN in user mode: `stuck sound: write <status> took <frames>, await <events>`, exit 0
j local disk [197:232] :the disks listed: `stuck disks <count>: <id> kind <kind>, ...`, exit 0
call local echo > clobber a0-a1,a7,s3 [234:246] :`stuck: scenario <name>` on the UART
 name :in a1, NUL-terminated
call local say > clobber a0,a7 [248:253] :the line, from its start to the cursor in s3, ended and printed on the UART
call local put_char char u8 > text line u8,clobber s3 [255:258]
 text :the character at the cursor in s3, which moves past it
call local put_str string addr > clobber a1,s3 [260:268]
 string :in a1, NUL-terminated, put at the cursor without its terminator
call local put_dec value u64 > clobber a0,s3 [270:290] :the value in decimal at the cursor, built backward in digits first
