macro jab.sys.exit status=0 imm > scratch a0,a7 [242:246] :ends the program with the status, the sound stream played out first; never returns
macro jab.sys.print message label > status a0 u64,framebuffer JAB_DISPLAY_BASE,scratch a7 [248:252] :writes the string to the screen console once the display is open, else to the UART
 message :NUL-terminated, inside the program's window
 status :0
 framebuffer :the console's text, once the display is open
macro jab.sys.uart.print message label > status a0 u64,scratch a7 [254:258] :writes the string to the UART
 message :NUL-terminated, inside the program's window
 status :0
macro jab.sys.display.open > status a0 u64,scratch a7 [260:263] :brings the display up and shows the framebuffer
 status :0, also when open already; 1 with no virtio-gpu; 2 when the device refuses the kernel; 3 when a command fails
macro jab.sys.display.ready > ready a0 bool,scratch a7 [265:268]
 ready :1 when a flip would go through now, 0 while the cap holds it back
macro jab.sys.display.flip > status a0 u64,scratch a7 [270:273] :shows the framebuffer; never waits
 status :0 when the frame went to the host; 1 when it came before the cap allows, nothing shown; 2 when the display is not open; 3 when the device refused it
macro jab.sys.display.flip.rect > status a0 u64,scratch a7 [275:278] :shows only the rectangle the program has in a0 to a3, x, y, width, height in pixels
 status :jab.sys.display.flip's codes, and 4 when the rectangle is empty or reaches outside the screen
macro jab.sys.display.flip.rects buffer addr,count u64 > status a0 u64,scratch a1,a7 [280:285] :shows that many rectangles of the framebuffer as one flip
 buffer :the rectangles, JAB_RECT_SIZE bytes each
 status :jab.sys.display.flip's codes, and 4 when the count is 0 or more than the window could hold, or any rectangle is empty or reaches outside the screen, nothing shown then
macro jab.sys.kernel.flags > flags a0 u64,scratch a7 [287:290]
 flags :the mask of what the kernel was built with, JAB_KERNEL_* bits
macro jab.sys.display.print message label > status a0 u64,framebuffer JAB_DISPLAY_BASE,scratch a7 [292:296] :writes the string to the screen console, opening the display first; a newline ends the line, and the console scrolls at the bottom
 message :NUL-terminated, inside the program's window
 status :0, or jab.sys.display.open's code
macro jab.sys.display.text message label,x i64,y i64,color u32,style u64,scale u64 > width a0 u64,height a1 u64,framebuffer JAB_DISPLAY_BASE,scratch a2-a5,a7 [298:319] :draws the string into the framebuffer with the console's font, the glyphs' own pixels only; nothing is presented
 message :NUL-terminated, inside the program's window
 x :the top left's column, negative or past the screen allowed, what falls off clipped; y likewise
 color :0x00RRGGBB, JAB_TEXT_PLAIN when left out
 style :JAB_TEXT_BOLD or 0, 0 when left out
 scale :256ths of a JAB_TEXT_WIDTH by JAB_TEXT_HEIGHT cell, JAB_TEXT_SCALE_ONE when left out, held at JAB_TEXT_SCALE_MAX
 width :the pixels drawn across
 height :a cell's height at the scale
macro jab.sys.keyboard.input > key a0 u16,value a1 i32,scratch a7 [321:324] :takes the next key event; the keyboard comes up on the first call, and a machine with none never has an event
 key :a JAB_KEY_*, or 0 when no event is waiting
 value :JAB_KEY_PRESSED, JAB_KEY_RELEASED, or JAB_KEY_HELD
macro jab.sys.await mask imm > events a0 u64,scratch a7 [326:330] :halts until an event in the mask, bringing each input named up; how a program idles between frames
 mask :JAB_AWAIT_* bits, the inputs the program reads and the display's tick; a source the machine lacks drops out
 events :the bits that fired; 0 when nothing in the mask can happen, at once for a mask of 0
macro jab.sys.display.await > events a0 u64,scratch a7 [332:334] :jab.sys.await for the display's frame tick
macro jab.sys.keyboard.await > events a0 u64,scratch a7 [336:338] :jab.sys.await for a key event
macro jab.sys.api.await > events a0 u64,scratch a7 [340:342] :jab.sys.await for bytes from the host over the API
macro jab.sys.pad.await > events a0 u64,scratch a7 [344:346] :jab.sys.await for a pad event
macro jab.sys.pad.read record addr > status a0 u64,state 0(record),scratch a7 [348:352] :the pad's state now; the pad comes up on the first pad call
 record :JAB_PAD_ENTRY bytes on a 4-byte boundary
 status :0 with the record written, or 1 when the machine carries no pad
 state :the keys held and every axis normalised
macro jab.sys.pad.input > type a0 u16,code a1 u16,value a2 i32,scratch a7 [354:357] :takes the next pad event, in evdev's own terms; a machine with no pad never has one
 type :JAB_EV_KEY or JAB_EV_ABS, or 0 when no event is waiting
 code :a JAB_BTN_* or JAB_ABS_*
 value :for a key JAB_KEY_PRESSED, JAB_KEY_RELEASED, or JAB_KEY_HELD; for an axis the raw reading the pad sent
macro jab.sys.pad.name buffer addr > status a0 u64,length a1 u64,name 0(buffer),scratch a7 [359:363]
 buffer :JAB_PAD_NAME_BYTES
 status :0 with the name written, or 1 when the machine carries no pad
 name :NUL-terminated, as the device reports it
macro jab.sys.random buffer addr,length u64 > status a0 u64,given a1 u64,bytes 0(buffer),scratch a7 [365:370] :fills the buffer from the machine's entropy device
 status :0 with the bytes written, or 1 when the machine carries no rng device
 given :how many bytes the device gave, the whole length from QEMU; 0 with no device
macro jab.sys.sound.open > status a0 u64,scratch a7 [372:375] :brings the sound device up with its stream started in the one format; every other sound call opens it the same way on its first call
 status :0; 1 when the machine carries no sound device; 2 when the device refuses the kernel or the format, or once the stream has stalled
macro jab.sys.sound.write buffer addr,frames u64 > status a0 u64,taken a1 u64,scratch a7 [377:382] :queues frames of the one format into the stream's ring, as many as it has room for
 status :0, or jab.sys.sound.open's code
 taken :how many frames the ring took; 0 on a refusal
macro jab.sys.sound.ready > status a0 u64,room a1 u64,scratch a7 [384:387]
 status :0, or jab.sys.sound.open's code
 room :how many frames jab.sys.sound.write would take now
macro jab.sys.sound.await > events a0 u64,scratch a7 [389:393] :halts until the ring has room for a period
 events :JAB_AWAIT_SOUND, or 0 with no sound device or a stalled stream
macro jab.sys.midi.program channel u8,program u8 > status a0 u64,scratch a1,a7 [395:400] :the channel's instrument becomes that General MIDI program for the notes after
 status :0, or jab.sys.sound.open's code
macro jab.sys.midi.note channel u8,note u8,velocity u8,on bool > status a0 u64,scratch a1-a3,a7 [402:409] :with on set and a velocity the note starts on the channel's instrument, taking a voice; with either 0 every voice sounding that note on the channel goes to its release, or waits for the pedal while it is down
 note :0 to 127, 69 the A at 440 Hz
 velocity :1 to 127
 status :0, or jab.sys.sound.open's code
macro jab.sys.midi.note.on channel u8,note u8,velocity u8 > status a0 u64,scratch a1-a3,a7 [411:418] :jab.sys.midi.note with on set
macro jab.sys.midi.note.off channel u8,note u8 > status a0 u64,scratch a1-a3,a7 [420:427] :jab.sys.midi.note with on and the velocity 0
macro jab.sys.midi.control channel u8,control u8,value u8 > status a0 u64,scratch a1-a2,a7 [429:435] :the channel's controller takes the value
 control :a JAB_MIDI_CC_*; any other is taken without effect
 value :0 to 127
 status :0, or jab.sys.sound.open's code
macro jab.sys.midi.bend channel u8,value u16 > status a0 u64,scratch a1,a7 [437:442] :the channel's pitch bend, for the notes sounding and the notes after
 value :14 bits, JAB_MIDI_BEND_CENTER for none, two semitones at either end
 status :0, or jab.sys.sound.open's code
macro jab.sys.midi.instrument program u8,spec addr > status a0 u64,scratch a1,a7 [444:449] :that General MIDI program plays the instrument the spec describes, for the notes after
 spec :JAB_MIDI_INSTRUMENT_ENTRY bytes inside the program's window
 status :0, or jab.sys.sound.open's code
macro jab.sys.midi.silence > status a0 u64,scratch a7 [451:454] :stops the piece, frees every voice at once, and puts every channel's controllers back to their defaults, the programs kept
 status :0, or jab.sys.sound.open's code
macro jab.sys.midi.play source addr,length u64 > status a0 u64,scratch a1,a7 [456:461] :plays the Standard MIDI File, whatever was playing stopped with its notes released
 source :inside the program's window, unchanged while it plays
 status :0; jab.sys.sound.open's code; 3 when the file is not one the player takes
macro jab.sys.midi.stop > status a0 u64,scratch a7 [463:466] :the piece stops where it is, its notes released
 status :0, or jab.sys.sound.open's code
macro jab.sys.midi.playing > playing a0 bool,scratch a7 [468:471]
 playing :1 while a piece plays, 0 once it has ended
macro jab.sys.midi.soundfont buffer addr,length u64 > status a0 u64,presets a1 u64,instruments a2 u64,samples a3 u64,scratch a7 [473:478] :the notes after play through the SoundFont 2 file's sampled voices; the notes sounding stop at once
 buffer :the file, inside the program's window on a 4-byte boundary, unchanged while it is loaded
 length :0 unloads the file, and the chip-tune voices play again
 status :0; jab.sys.sound.open's code; 3 when the bytes are not a SoundFont 2 file; 4 when the file is unsound
 presets :the file's, 0 unless a file loaded, as are instruments and samples
macro jab.sys.harts > discovered a0 u64,online a1 u64,failed a2 u64,scratch a7 [480:483] :the machine's harts as masks, bit n for hart n
 discovered :the harts the device tree lists, below JAB_HARTS_MAX
 failed :harts that failed to start, every listed one but hart 0 when the tree has a topology problem; a hart listed and neither online nor failed is parked
macro jab.sys.pad.axis buffer addr,code imm > status a0 u64,range 0(buffer),scratch a1,a7 [485:490] :the pad's own range for the axis
 buffer :JAB_PAD_AXIS_ENTRY bytes on a 4-byte boundary
 code :a JAB_ABS_*
 status :0 with the record written; 1 when the machine carries no pad; 2 when the pad has no such axis
 range :min, max, fuzz, flat, and resolution as the pad reports them
macro jab.sys.api.write buffer addr,length u64 > status a0 u64,scratch a1,a7 [492:497] :sends the bytes to the host, returning once the device has taken them
 status :0; 1 when the machine has no API port; 2 when the port failed during the send, some of the bytes perhaps at the host, every write after it answering 1
macro jab.sys.api.read buffer addr,capacity imm > count a0 u64,waiting a1 u64,data 0(buffer),scratch a7 [499:504] :takes the bytes the host has sent, oldest first, at most capacity of them; never waits
 count :the bytes written, 0 when none wait or the machine has no API port
 waiting :how many still wait after them
macro jab.sys.block.list buffer addr,at=zero u64,capacity=JAB_BLOCK_MAX imm > count a0 u64,next a1 u64,records 0(buffer),scratch a2,a7 [506:512] :writes a JAB_BLOCK_ENTRY record per disk into the buffer
 at :the id of the disk to start at, zero for the first
 capacity :how many records the buffer holds
 next :the id to pass as at next time, or 0 once the last disk is in the buffer
macro jab.sys.block.find serial label > id a0 u64,scratch a7 [514:518]
 serial :NUL-terminated
 id :the first disk carrying the serial, or 0 when none does
macro jab.sys.block.read buffer addr,id u64,sector u64,count u64 > status a0 u64,data 0(buffer),scratch a1-a3,a7 [520:527] :reads count sectors of JAB_BLOCK_SECTOR bytes from the disk, from that sector, straight into the buffer
 status :0; 1 when no disk carries the id; 2 when that disk would not come up; 3 when the device reported an error; 4 when those sectors are not on it, a count of 0 among them
macro jab.sys.block.write buffer addr,id u64,sector u64,count u64 > status a0 u64,scratch a1-a3,a7 [529:536] :jab.sys.block.read the other way, the disk written from the buffer
 status :jab.sys.block.read's codes
macro jab.sys.romfs.list buffer addr,id u64,directory u64,offset=zero u64,capacity=JAB_ROMFS_PAGE imm > count a0 u64,next a1 u64,records 0(buffer),scratch a2-a4,a7 [538:546] :writes a JAB_ROMFS_ENTRY record per entry of the directory into the buffer
 directory :a header's offset, JAB_ROMFS_ROOT for the volume's root
 offset :where the page starts, zero for the directory's first entry, else the next of the page before
 capacity :how many records the buffer holds
 next :the offset to start the next page at, 0 once the directory has ended
macro jab.sys.romfs.find buffer addr,id u64,directory u64,path label > status a0 u64,offset a1 u64,record 0(buffer),scratch a2-a3,a7 [548:555] :looks for the path from the directory, a leading / starting at the root instead; a hard link is followed, so . and .. lead where romfs points them
 buffer :one JAB_ROMFS_ENTRY record
 status :0 with the record written; 1 when nothing of that name is there; 2 when a component along the way is not a directory
 offset :the entry's own header, to list or read it with
macro jab.sys.tar.list buffer addr,archive addr,length u64,offset=zero u64,capacity=JAB_TAR_PAGE imm > count a0 u64,next a1 u64,records 0(buffer),scratch a2-a4,a7 [557:565] :writes a JAB_TAR_ENTRY record per entry of a tar archive the program already holds into the buffer
 offset :the header the page starts at, zero for the first
 capacity :how many records the buffer holds
 next :the offset to start the next page at, 0 once the archive has ended
macro jab.sys.tar.find buffer addr,archive addr,length u64,path label > status a0 u64,offset a1 u64,record 0(buffer),scratch a2-a3,a7 [567:574] :looks for the path in the archive; a directory's trailing separator is ignored
 buffer :one JAB_TAR_ENTRY record
 status :0 with the record written, or 1 when the archive holds no such name
 offset :the entry's own header
macro jab.sys.checksum bytes addr,size u64 > lane0 a0 u64,lane1 a1 u64,lane2 a2 u64,lane3 a3 u64,scratch a7 [576:581] :the SHA3-256 of the bytes
 lane0 :the digest's first eight bytes, then lane1 to lane3; stored with four sd in order they are the digest as anything else computes it
macro jab.sys.hash bytes addr,size u64 > hash a0 u64,scratch a1,a7 [583:588]
 hash :the XXH3-64 of the bytes
macro jab.sys.gz.size source addr,length u64 > size a0 u64,status a1 u64,scratch a7 [590:595]
 size :the length the gzip's contents will be, from its trailer; 0 with JAB_GZ_NOT_GZIP
 status :JAB_GZ_OK or JAB_GZ_NOT_GZIP
macro jab.sys.gz.read buffer addr,source addr,length u64,capacity u64 > count a0 u64,status a1 u64,contents 0(buffer),scratch a2-a3,a7 [597:604] :inflates the gzip into the buffer in one call, checking its CRC-32 and its length against what came out
 capacity :how many bytes the buffer holds
 count :the bytes written
 status :a JAB_GZ_* code
macro jab.sys.romfs.read buffer addr,id u64,file u64,offset u64,length u64 > count a0 u64,next a1 u64,data 0(buffer),scratch a2-a4,a7 [606:614] :reads at most length bytes of the file, from that byte of it, into the buffer
 file :a header's offset, as a record's JAB_ROMFS_OFFSET carries
 count :the bytes written
 next :the offset to read from next, 0 at the file's end
macro jab.sys.png.size source addr,length u64 > width a0 u64,height a1 u64,status a2 u64,scratch a7 [616:621] :the size of a PNG the program holds, from its header
 status :JAB_PNG_OK; or with width and height 0, JAB_PNG_NOT_PNG, JAB_PNG_TRUNCATED, JAB_PNG_CRC, or JAB_PNG_UNSUPPORTED
macro jab.sys.sprite.png sprite addr,source addr,length u64,capacity imm,frames=1 imm > status a0 u64,record 0(sprite),scratch a1-a4,a7 [623:631] :decodes the PNG into the sprite record as a sheet of frames stacked top to bottom, with the span table
 capacity :how many bytes the record's buffer holds, at least JAB_SPRITE_PIXELS + height * (width * 4 + 4)
 frames :how many frames the sheet is cut into; the PNG's height must divide by it
 status :JAB_PNG_OK with the record filled, JAB_PNG_FRAMES when the height does not divide, JAB_PNG_SIZE when the buffer is too small, the other JAB_PNG_* codes what is wrong with the file
macro jab.sys.sprite.load sprite addr,id u64,path label,capacity imm > status a0 u64,record 0(sprite),scratch a1-a3,a7 [633:640] :fills the sprite record from a directory on the disk, its frames the files 0.png, 1.png, and on, in order until one is missing, each decoded straight off the disk; every frame must be one size
 path :the directory, from the volume's root
 capacity :how many bytes the record's buffer holds, at least JAB_SPRITE_PIXELS + frames * height * (width * 4 + 4)
 status :JAB_PNG_OK with the record filled, JAB_PNG_NOT_FOUND when the directory or its 0.png is not there, JAB_PNG_FRAMES when a frame's size differs from the first's, JAB_PNG_SIZE when the buffer is too small, else a frame's own code
macro jab.sys.sprite.draw sprite addr,frame u64,x i64,y i64,tint u32,scale u64,pose u64 > status a0 u64,framebuffer JAB_DISPLAY_BASE,scratch a1-a7 [642:664] :blends a frame of the sprite onto the framebuffer with its top left at x, y, what falls off an edge clipped; nothing is presented
 x :negative or past the screen allowed; y likewise
 tint :a colour, 0x00RRGGBB, each of a pixel's channels multiplied by it over 255; JAB_SPRITE_PLAIN when left out
 scale :256ths, JAB_SPRITE_SCALE_ONE when left out
 pose :clockwise degrees in the low sixteen bits with JAB_SPRITE_FLIP_H, JAB_SPRITE_FLIP_V, and JAB_SPRITE_SOLID above, 0 when left out
 status :0; 1 when the frame is not in the sprite; 2 when the scale is past JAB_SPRITE_SCALE_MAX
