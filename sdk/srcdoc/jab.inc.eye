set JAB_PROGRAM_BASE address [4] :where the loader places the program, the start of the window it owns
set JAB_PROGRAM_SIZE u64 [5] :the bytes the program owns from JAB_PROGRAM_BASE
set JAB_STACK_TOP address [6] :sp at the program's start, the end of RAM and of the window
set JAB_DISPLAY_BASE address [8] :the framebuffer, a pixel the little-endian word 0x00RRGGBB
set JAB_DISPLAY_WIDTH u64 [9] :the framebuffer's width in pixels
set JAB_DISPLAY_HEIGHT u64 [10] :the framebuffer's height in pixels
set JAB_DISPLAY_PITCH u64 [11] :a row's bytes, four a pixel
set JAB_DISPLAY_SIZE u64 [12] :the framebuffer's bytes
set JAB_DISPLAY_FPS_TARGET u64 [13] :the frame rate a program is built to hold
set JAB_DISPLAY_FPS_CAP u64 [14] :the most flips a second
set JAB_TIME_HZ u64 [16] :the ticks a second of the time counter rdtime reads
set JAB_AWAIT_DISPLAY u64 [18] :the display's next frame tick
set JAB_AWAIT_KEYBOARD u64 [19] :a key event waiting
set JAB_AWAIT_API u64 [20] :bytes from the host waiting on the API
set JAB_AWAIT_PAD u64 [21] :a pad event waiting
set JAB_AWAIT_SOUND u64 [22] :room in the sound stream for a period
set JAB_SYS_EXIT u64 [24]
set JAB_SYS_PRINT u64 [25]
set JAB_SYS_UART_PRINT u64 [26]
set JAB_SYS_DISPLAY_OPEN u64 [27]
set JAB_SYS_DISPLAY_READY u64 [28]
set JAB_SYS_DISPLAY_FLIP u64 [29]
set JAB_SYS_DISPLAY_PRINT u64 [30]
set JAB_SYS_AWAIT u64 [31]
set JAB_SYS_DISPLAY_FLIP_RECT u64 [32]
set JAB_SYS_KEYBOARD_INPUT u64 [33]
set JAB_SYS_BLOCK_LIST u64 [34]
set JAB_SYS_BLOCK_FIND u64 [35]
set JAB_SYS_BLOCK_READ u64 [36]
set JAB_SYS_BLOCK_WRITE u64 [37]
set JAB_SYS_ROMFS_LIST u64 [38]
set JAB_SYS_ROMFS_FIND u64 [39]
set JAB_SYS_ROMFS_READ u64 [40]
set JAB_SYS_TAR_LIST u64 [41]
set JAB_SYS_TAR_FIND u64 [42]
set JAB_SYS_GZ_SIZE u64 [43]
set JAB_SYS_GZ_READ u64 [44]
set JAB_SYS_CHECKSUM u64 [45]
set JAB_SYS_HASH u64 [46]
set JAB_SYS_API_WRITE u64 [47]
set JAB_SYS_API_READ u64 [48]
set JAB_SYS_PNG_SIZE u64 [49]
set JAB_SYS_SPRITE_PNG u64 [50]
set JAB_SYS_SPRITE_DRAW u64 [51]
set JAB_SYS_SPRITE_LOAD u64 [52]
set JAB_SYS_DISPLAY_FLIP_RECTS u64 [53]
set JAB_SYS_KERNEL_FLAGS u64 [54]
set JAB_SYS_PAD_READ u64 [55]
set JAB_SYS_PAD_INPUT u64 [56]
set JAB_SYS_PAD_AXIS u64 [57]
set JAB_SYS_DISPLAY_TEXT u64 [58]
set JAB_SYS_PAD_NAME u64 [59]
set JAB_SYS_RANDOM u64 [60]
set JAB_SYS_SOUND_OPEN u64 [61]
set JAB_SYS_SOUND_WRITE u64 [62]
set JAB_SYS_SOUND_READY u64 [63]
set JAB_SYS_MIDI_PROGRAM u64 [64]
set JAB_SYS_MIDI_NOTE u64 [65]
set JAB_SYS_MIDI_CONTROL u64 [66]
set JAB_SYS_MIDI_BEND u64 [67]
set JAB_SYS_MIDI_INSTRUMENT u64 [68]
set JAB_SYS_MIDI_SILENCE u64 [69]
set JAB_SYS_MIDI_PLAY u64 [70]
set JAB_SYS_MIDI_STOP u64 [71]
set JAB_SYS_MIDI_PLAYING u64 [72]
set JAB_SYS_MIDI_SOUNDFONT u64 [73]
set JAB_TEXT_WIDTH u64 [75] :a text cell's width in pixels at JAB_TEXT_SCALE_ONE
set JAB_TEXT_HEIGHT u64 [76] :a text cell's height in pixels at JAB_TEXT_SCALE_ONE
set JAB_TEXT_SCALE_ONE u64 [77] :the font's own size, the scale in 256ths as a sprite's
set JAB_TEXT_SCALE_MAX u64 [78] :the largest text scale
set JAB_TEXT_PLAIN u32 [79] :the console's white, the text colour when left out
set JAB_TEXT_BOLD u64 [80] :the style bit striking each glyph twice a pixel apart
set JAB_PAD_NAME_BYTES u64 [82] :the most a pad's name takes, its terminator included
set JAB_SOUND_RATE u64 [84] :the one format's frames a second
set JAB_SOUND_CHANNELS u64 [85] :signed 16-bit samples a frame, interleaved left then right
set JAB_SOUND_FRAME_BYTES u64 [86] :a frame's bytes
set JAB_SOUND_PERIOD u64 [87] :a period's frames, 20 ms
set JAB_SOUND_PERIODS u64 [88] :the periods in flight
set JAB_SOUND_RING u64 [89] :the frames the ring behind jab.sys.sound.write holds
set JAB_MIDI_CHANNELS u64 [91] :the channels, 0 to 15
set JAB_MIDI_VOICES u64 [92] :the chip-tune notes sounding at once
set JAB_MIDI_FONT_VOICES u64 [93] :the SoundFont notes sounding at once
set JAB_MIDI_TRACKS u64 [94] :the most tracks a Standard MIDI File may carry
set JAB_MIDI_PERCUSSION u64 [95] :the drum kit's channel, its notes naming drums
set JAB_MIDI_BEND_CENTER u16 [96] :the bend for none
set JAB_MIDI_CC_BANK u8 [97] :the bank select, picking a SoundFont preset's bank
set JAB_MIDI_CC_VOLUME u8 [98] :the volume, scaling the channel's notes
set JAB_MIDI_CC_PAN u8 [99] :the pan, 64 the middle
set JAB_MIDI_CC_EXPRESSION u8 [100] :the expression, scaling the channel's notes
set JAB_MIDI_CC_PEDAL u8 [101] :the pedal, down from 64, holding every note released until it lifts
set JAB_MIDI_CC_ALL_SOUND_OFF u8 [102] :frees the channel's voices at once
set JAB_MIDI_CC_RESET u8 [103] :puts the channel's controllers back to their defaults
set JAB_MIDI_CC_ALL_NOTES_OFF u8 [104] :releases the channel's notes
set JAB_MIDI_WAVE u8 [105] :an instrument spec's wave, a JAB_WAVE_*
set JAB_MIDI_DUTY u8 [106] :the square's duty in 256ths of a cycle
set JAB_MIDI_ATTACK u16 [107] :the attack in milliseconds
set JAB_MIDI_DECAY u16 [108] :the decay in milliseconds
set JAB_MIDI_RELEASE u16 [109] :the release in milliseconds
set JAB_MIDI_SUSTAIN u8 [110] :the sustain in 256ths of full
set JAB_MIDI_VIBRATO u8 [111] :the vibrato's depth in 256ths of about a semitone
set JAB_MIDI_VIBRATO_RATE u8 [112] :the vibrato's rate in hertz
set JAB_MIDI_INSTRUMENT_ENTRY u64 [113] :an instrument spec's bytes, the last one spare
set JAB_WAVE_SQUARE u8 [114]
set JAB_WAVE_TRIANGLE u8 [115]
set JAB_WAVE_SAW u8 [116]
set JAB_WAVE_SINE u8 [117]
set JAB_WAVE_NOISE u8 [118]
set JAB_PAD_ENTRY u64 [120] :a pad state record's bytes, on a 4-byte boundary
set JAB_PAD_KEYS u32 [121] :the gamepad's keys held, bit n for the code JAB_BTN_GAMEPAD + n
set JAB_PAD_AXES 64 i16 [122] :every axis at its JAB_ABS_* code, -JAB_PAD_FULL through JAB_PAD_FULL
set JAB_PAD_AXIS_COUNT u64 [123] :the axes a state record holds
set JAB_PAD_FULL i16 [124] :an axis's full scale either way
set JAB_PAD_AXIS_ENTRY u64 [125] :an axis range record's bytes, on a 4-byte boundary
set JAB_PAD_AXIS_MIN i32 [126] :the axis's least reading, as virtio reports it
set JAB_PAD_AXIS_MAX i32 [127] :the axis's greatest reading
set JAB_PAD_AXIS_FUZZ i32 [128] :the axis's noise
set JAB_PAD_AXIS_FLAT i32 [129] :the band about the middle that reads as rest
set JAB_PAD_AXIS_RES i32 [130] :the axis's resolution
set JAB_KERNEL_DEBUG u64 [132] :the kernel was built with DEBUG, its own lines on its debug channel
set JAB_SPRITE_WIDTH u32 [134] :one frame's width
set JAB_SPRITE_HEIGHT u32 [135] :one frame's height
set JAB_SPRITE_FRAMES u32 [136] :the frame count
set JAB_SPRITE_FLAGS u32 [137] :JAB_SPRITE_SPANNED or 0
set JAB_SPRITE_PIXELS u32 [138] :the pixels, 0xAARRGGBB, frame after frame, each frame's rows top to bottom
set JAB_SPRITE_SPANNED u32 [139] :the flag saying the span table follows the pixels
set JAB_RECT_X u32 [141] :the rectangle's left column
set JAB_RECT_Y u32 [142] :the rectangle's top row
set JAB_RECT_WIDTH u32 [143]
set JAB_RECT_HEIGHT u32 [144]
set JAB_RECT_SIZE u64 [145] :a rectangle record's bytes
set JAB_SPRITE_PLAIN u32 [147] :white, the tint that draws a sprite as it is
set JAB_SPRITE_SCALE_ONE u64 [148] :a frame's own size, the scale in 256ths
set JAB_SPRITE_SCALE_MAX u64 [149] :the largest sprite scale
set JAB_SPRITE_FLIP_H u64 [150] :the pose bit mirroring the frame left to right
set JAB_SPRITE_FLIP_V u64 [151] :the pose bit mirroring the frame top to bottom
set JAB_SPRITE_SOLID u64 [152] :the pose bit writing the tint over every pixel the frame covers
set JAB_PNG_OK u64 [154]
set JAB_PNG_NOT_PNG u64 [155] :no PNG signature
set JAB_PNG_UNSUPPORTED u64 [156] :a form the decoder does not take, 16 bits a sample or Adam7 interlace among them
set JAB_PNG_TRUNCATED u64 [157] :the file ends early
set JAB_PNG_CRC u64 [158] :a chunk's CRC-32 fails
set JAB_PNG_ZLIB u64 [159] :the zlib stream's header or Adler-32 fails
set JAB_PNG_LENGTH u64 [160] :the image data inflates to the wrong size
set JAB_PNG_FILTER u64 [161] :a row's filter type does not exist
set JAB_PNG_PALETTE u64 [162] :an indexed image with no palette or an index past it
set JAB_PNG_FRAMES u64 [163] :the height does not divide by the frames, or a frame's size differs from the first's
set JAB_PNG_SIZE u64 [164] :the sprite's buffer is short of the rule
set JAB_PNG_NOT_FOUND u64 [165] :the directory or its 0.png is not on the disk
set JAB_PNG_INPUT u64 [166] :the DEFLATE stream ends in the middle of something
set JAB_PNG_OUTPUT u64 [167] :the DEFLATE stream overruns the image
set JAB_PNG_BLOCK u64 [168] :a DEFLATE block type that does not exist
set JAB_PNG_STORED u64 [169] :a stored block's length disagrees with itself
set JAB_PNG_CODES u64 [170] :a code table that is not a Huffman code
set JAB_PNG_SYMBOL u64 [171] :a symbol no table can produce
set JAB_PNG_DISTANCE u64 [172] :a distance reaching before the output
set JAB_GZ_OK u64 [174]
set JAB_GZ_NOT_GZIP u64 [175] :no gzip header of deflated data, or too short for a trailer
set JAB_GZ_TRUNCATED u64 [176] :the header runs past the end, or no compressed bytes follow it
set JAB_GZ_CRC u64 [177] :the contents' CRC-32 is not the trailer's
set JAB_GZ_LENGTH u64 [178] :the contents' length is not the trailer's
set JAB_GZ_INPUT u64 [179] :the DEFLATE stream ends in the middle of something
set JAB_GZ_OUTPUT u64 [180] :the buffer cannot hold the contents
set JAB_GZ_BLOCK u64 [181] :a DEFLATE block type that does not exist
set JAB_GZ_STORED u64 [182] :a stored block's length disagrees with itself
set JAB_GZ_CODES u64 [183] :a code table that is not a Huffman code
set JAB_GZ_SYMBOL u64 [184] :a symbol no table can produce
set JAB_GZ_DISTANCE u64 [185] :a distance reaching before the output
set JAB_TAR_ENTRY u64 [187] :a tar record's bytes
set JAB_TAR_PAGE u64 [188] :the records jab.sys.tar.list writes when the capacity is left out
set JAB_TAR_LIST_SIZE u64 [189] :the bytes a page of records takes
set JAB_TAR_BLOCK u64 [190] :a header's bytes and every block's, so every offset is a multiple of it
set JAB_TAR_OFFSET u64 [191] :the entry's header, an offset into the archive
set JAB_TAR_DATA u64 [192] :the entry's data, an offset into the archive, where it already sits
set JAB_TAR_SIZE u64 [193] :the data's bytes
set JAB_TAR_TYPE u8 [194] :tar's own type byte, a JAB_TAR_* digit character; an old archive's zero reads JAB_TAR_REGULAR
set JAB_TAR_NAME 264 u8 [195] :the path, NUL-terminated, a ustar prefix joined on with a separator
set JAB_TAR_NAME_BYTES u64 [196] :the name field's bytes
set JAB_TAR_REGULAR u8 [197]
set JAB_TAR_HARDLINK u8 [198]
set JAB_TAR_SYMLINK u8 [199]
set JAB_TAR_CHAR u8 [200] :a character device
set JAB_TAR_BLOCKDEV u8 [201] :a block device
set JAB_TAR_DIRECTORY u8 [202]
set JAB_TAR_FIFO u8 [203]
set JAB_BLOCK_MAX u64 [205] :the most disks, their ids 1 to JAB_BLOCK_MAX
set JAB_BLOCK_SECTOR u64 [206] :a sector's bytes, virtio's unit for every capacity and request
set JAB_BLOCK_ENTRY u64 [207] :a disk record's bytes
set JAB_BLOCK_LIST_SIZE u64 [208] :the bytes that hold every disk's record
set JAB_BLOCK_ID u8 [209] :the disk's id
set JAB_BLOCK_KIND u8 [210] :what the kernel found on the disk, a JAB_BLOCK_KIND_*
set JAB_BLOCK_SECTORS u64 [211] :the capacity in sectors
set JAB_BLOCK_SERIAL 20 u8 [212] :the device ID string, at most 20 characters
set JAB_BLOCK_SERIAL_BYTES u64 [213] :the serial field's bytes
set JAB_BLOCK_KIND_NONE u8 [214] :nothing found, or a disk that would not come up
set JAB_BLOCK_KIND_RAW u8 [215] :a disk with no romfs on it
set JAB_BLOCK_KIND_ROMFS u8 [216] :a romfs image
set JAB_ROMFS_ENTRY u64 [218] :a romfs record's bytes
set JAB_ROMFS_PAGE u64 [219] :the records jab.sys.romfs.list writes when the capacity is left out
set JAB_ROMFS_LIST_SIZE u64 [220] :the bytes a page of records takes
set JAB_ROMFS_OFFSET u32 [221] :the entry's own header, its offset in the image
set JAB_ROMFS_NEXT u32 [222] :the next header's offset, the mode in its low four bits
set JAB_ROMFS_SPEC u32 [223] :romfs's spec info, a directory's first entry or a hard link's target
set JAB_ROMFS_SIZE u32 [224] :the file's bytes
set JAB_ROMFS_NAME 128 u8 [225] :the name, NUL-terminated
set JAB_ROMFS_NAME_BYTES u64 [226] :the name field's bytes, 127 characters and the terminator
set JAB_ROMFS_ROOT u64 [227] :the volume's first header, its root directory
set JAB_ROMFS_TYPE u32 [228] :the mask of JAB_ROMFS_NEXT's type
set JAB_ROMFS_EXEC u32 [229] :JAB_ROMFS_NEXT's executable bit
set JAB_ROMFS_HARDLINK u32 [230]
set JAB_ROMFS_DIRECTORY u32 [231]
set JAB_ROMFS_REGULAR u32 [232]
set JAB_ROMFS_SYMLINK u32 [233]
set JAB_ROMFS_BLOCK u32 [234] :a block device
set JAB_ROMFS_CHAR u32 [235] :a character device
set JAB_ROMFS_SOCKET u32 [236]
set JAB_ROMFS_FIFO u32 [237]
macro jab.sys.exit status=0 imm > scratch a0,a7 [239:243] :ends the program with the status, the sound stream played out first; never returns
macro jab.sys.print message label > status a0 u64,framebuffer JAB_DISPLAY_BASE,scratch a7 [245:249] :writes the string to the screen console once the display is open, else to the UART
 message :NUL-terminated, inside the program's window
 status :0
 framebuffer :the console's text, once the display is open
macro jab.sys.uart.print message label > status a0 u64,scratch a7 [251:255] :writes the string to the UART
 message :NUL-terminated, inside the program's window
 status :0
macro jab.sys.display.open > status a0 u64,scratch a7 [257:260] :brings the display up and shows the framebuffer
 status :0, also when open already; 1 with no virtio-gpu; 2 when the device refuses the kernel; 3 when a command fails
macro jab.sys.display.ready > ready a0 bool,scratch a7 [262:265]
 ready :1 when a flip would go through now, 0 while the cap holds it back
macro jab.sys.display.flip > status a0 u64,scratch a7 [267:270] :shows the framebuffer; never waits
 status :0 when the frame went to the host; 1 when it came before the cap allows, nothing shown; 2 when the display is not open; 3 when the device refused it
macro jab.sys.display.flip.rect > status a0 u64,scratch a7 [272:275] :shows only the rectangle the program has in a0 to a3, x, y, width, height in pixels
 status :jab.sys.display.flip's codes, and 4 when the rectangle is empty or reaches outside the screen
macro jab.sys.display.flip.rects buffer address,count u64 > status a0 u64,scratch a1,a7 [277:282] :shows that many rectangles of the framebuffer as one flip
 buffer :the rectangles, JAB_RECT_SIZE bytes each
 status :jab.sys.display.flip's codes, and 4 when the count is 0 or more than the window could hold, or any rectangle is empty or reaches outside the screen, nothing shown then
macro jab.sys.kernel.flags > flags a0 u64,scratch a7 [284:287]
 flags :the mask of what the kernel was built with, JAB_KERNEL_* bits
macro jab.sys.display.print message label > status a0 u64,framebuffer JAB_DISPLAY_BASE,scratch a7 [289:293] :writes the string to the screen console, opening the display first; a newline ends the line, and the console scrolls at the bottom
 message :NUL-terminated, inside the program's window
 status :0, or jab.sys.display.open's code
macro jab.sys.display.text message label,x i64,y i64,color u32,style u64,scale u64 > width a0 u64,height a1 u64,framebuffer JAB_DISPLAY_BASE,scratch a2-a5,a7 [295:316] :draws the string into the framebuffer with the console's font, the glyphs' own pixels only; nothing is presented
 message :NUL-terminated, inside the program's window
 x :the top left's column, negative or past the screen allowed, what falls off clipped; y likewise
 color :0x00RRGGBB, JAB_TEXT_PLAIN when left out
 style :JAB_TEXT_BOLD or 0, 0 when left out
 scale :256ths of a JAB_TEXT_WIDTH by JAB_TEXT_HEIGHT cell, JAB_TEXT_SCALE_ONE when left out, held at JAB_TEXT_SCALE_MAX
 width :the pixels drawn across
 height :a cell's height at the scale
macro jab.sys.keyboard.input > key a0 u16,value a1 i32,scratch a7 [318:321] :takes the next key event; the keyboard comes up on the first call, and a machine with none never has an event
 key :a JAB_KEY_*, or 0 when no event is waiting
 value :JAB_KEY_PRESSED, JAB_KEY_RELEASED, or JAB_KEY_HELD
macro jab.sys.await mask imm > events a0 u64,scratch a7 [323:327] :halts until an event in the mask, bringing each input named up; how a program idles between frames
 mask :JAB_AWAIT_* bits, the inputs the program reads and the display's tick; a source the machine lacks drops out
 events :the bits that fired; 0 when nothing in the mask can happen, at once for a mask of 0
macro jab.sys.display.await > events a0 u64,scratch a7 [329:331] :jab.sys.await for the display's frame tick
macro jab.sys.keyboard.await > events a0 u64,scratch a7 [333:335] :jab.sys.await for a key event
macro jab.sys.api.await > events a0 u64,scratch a7 [337:339] :jab.sys.await for bytes from the host over the API
macro jab.sys.pad.await > events a0 u64,scratch a7 [341:343] :jab.sys.await for a pad event
macro jab.sys.pad.read record address > status a0 u64,state 0(record),scratch a7 [345:349] :the pad's state now; the pad comes up on the first pad call
 record :JAB_PAD_ENTRY bytes on a 4-byte boundary
 status :0 with the record written, or 1 when the machine carries no pad
 state :the keys held and every axis normalised
macro jab.sys.pad.input > type a0 u16,code a1 u16,value a2 i32,scratch a7 [351:354] :takes the next pad event, in evdev's own terms; a machine with no pad never has one
 type :JAB_EV_KEY or JAB_EV_ABS, or 0 when no event is waiting
 code :a JAB_BTN_* or JAB_ABS_*
 value :for a key JAB_KEY_PRESSED, JAB_KEY_RELEASED, or JAB_KEY_HELD; for an axis the raw reading the pad sent
macro jab.sys.pad.name buffer address > status a0 u64,length a1 u64,name 0(buffer),scratch a7 [356:360]
 buffer :JAB_PAD_NAME_BYTES
 status :0 with the name written, or 1 when the machine carries no pad
 name :NUL-terminated, as the device reports it
macro jab.sys.random buffer address,length u64 > status a0 u64,given a1 u64,bytes 0(buffer),scratch a7 [362:367] :fills the buffer from the machine's entropy device
 status :0 with the bytes written, or 1 when the machine carries no rng device
 given :how many bytes the device gave, the whole length from QEMU; 0 with no device
macro jab.sys.sound.open > status a0 u64,scratch a7 [369:372] :brings the sound device up with its stream started in the one format; every other sound call opens it the same way on its first call
 status :0; 1 when the machine carries no sound device; 2 when the device refuses the kernel or the format, or once the stream has stalled
macro jab.sys.sound.write buffer address,frames u64 > status a0 u64,taken a1 u64,scratch a7 [374:379] :queues frames of the one format into the stream's ring, as many as it has room for
 status :0, or jab.sys.sound.open's code
 taken :how many frames the ring took; 0 on a refusal
macro jab.sys.sound.ready > status a0 u64,room a1 u64,scratch a7 [381:384]
 status :0, or jab.sys.sound.open's code
 room :how many frames jab.sys.sound.write would take now
macro jab.sys.sound.await > events a0 u64,scratch a7 [386:390] :halts until the ring has room for a period
 events :JAB_AWAIT_SOUND, or 0 with no sound device or a stalled stream
macro jab.sys.midi.program channel u8,program u8 > status a0 u64,scratch a1,a7 [392:397] :the channel's instrument becomes that General MIDI program for the notes after
 status :0, or jab.sys.sound.open's code
macro jab.sys.midi.note channel u8,note u8,velocity u8,on bool > status a0 u64,scratch a1-a3,a7 [399:406] :with on set and a velocity the note starts on the channel's instrument, taking a voice; with either 0 every voice sounding that note on the channel goes to its release, or waits for the pedal while it is down
 note :0 to 127, 69 the A at 440 Hz
 velocity :1 to 127
 status :0, or jab.sys.sound.open's code
macro jab.sys.midi.note.on channel u8,note u8,velocity u8 > status a0 u64,scratch a1-a3,a7 [408:415] :jab.sys.midi.note with on set
macro jab.sys.midi.note.off channel u8,note u8 > status a0 u64,scratch a1-a3,a7 [417:424] :jab.sys.midi.note with on and the velocity 0
macro jab.sys.midi.control channel u8,control u8,value u8 > status a0 u64,scratch a1-a2,a7 [426:432] :the channel's controller takes the value
 control :a JAB_MIDI_CC_*; any other is taken without effect
 value :0 to 127
 status :0, or jab.sys.sound.open's code
macro jab.sys.midi.bend channel u8,value u16 > status a0 u64,scratch a1,a7 [434:439] :the channel's pitch bend, for the notes sounding and the notes after
 value :14 bits, JAB_MIDI_BEND_CENTER for none, two semitones at either end
 status :0, or jab.sys.sound.open's code
macro jab.sys.midi.instrument program u8,spec address > status a0 u64,scratch a1,a7 [441:446] :that General MIDI program plays the instrument the spec describes, for the notes after
 spec :JAB_MIDI_INSTRUMENT_ENTRY bytes inside the program's window
 status :0, or jab.sys.sound.open's code
macro jab.sys.midi.silence > status a0 u64,scratch a7 [448:451] :stops the piece, frees every voice at once, and puts every channel's controllers back to their defaults, the programs kept
 status :0, or jab.sys.sound.open's code
macro jab.sys.midi.play source address,length u64 > status a0 u64,scratch a1,a7 [453:458] :plays the Standard MIDI File, whatever was playing stopped with its notes released
 source :inside the program's window, unchanged while it plays
 status :0; jab.sys.sound.open's code; 3 when the file is not one the player takes
macro jab.sys.midi.stop > status a0 u64,scratch a7 [460:463] :the piece stops where it is, its notes released
 status :0, or jab.sys.sound.open's code
macro jab.sys.midi.playing > playing a0 bool,scratch a7 [465:468]
 playing :1 while a piece plays, 0 once it has ended
macro jab.sys.midi.soundfont buffer address,length u64 > status a0 u64,presets a1 u64,instruments a2 u64,samples a3 u64,scratch a7 [470:475] :the notes after play through the SoundFont 2 file's sampled voices; the notes sounding stop at once
 buffer :the file, inside the program's window on a 4-byte boundary, unchanged while it is loaded
 length :0 unloads the file, and the chip-tune voices play again
 status :0; jab.sys.sound.open's code; 3 when the bytes are not a SoundFont 2 file; 4 when the file is unsound
 presets :the file's, 0 unless a file loaded, as are instruments and samples
macro jab.sys.pad.axis buffer address,code imm > status a0 u64,range 0(buffer),scratch a1,a7 [477:482] :the pad's own range for the axis
 buffer :JAB_PAD_AXIS_ENTRY bytes on a 4-byte boundary
 code :a JAB_ABS_*
 status :0 with the record written; 1 when the machine carries no pad; 2 when the pad has no such axis
 range :min, max, fuzz, flat, and resolution as the pad reports them
macro jab.sys.api.write buffer address,length u64 > status a0 u64,scratch a1,a7 [484:489] :sends the bytes to the host, returning once the device has taken them
 status :0, or 1 when the machine has no API port
macro jab.sys.api.read buffer address,capacity imm > count a0 u64,waiting a1 u64,data 0(buffer),scratch a7 [491:496] :takes the bytes the host has sent, oldest first, at most capacity of them; never waits
 count :the bytes written, 0 when none wait or the machine has no API port
 waiting :how many still wait after them
macro jab.sys.block.list buffer address,at=zero u64,capacity=JAB_BLOCK_MAX imm > count a0 u64,next a1 u64,records 0(buffer),scratch a2,a7 [498:504] :writes a JAB_BLOCK_ENTRY record per disk into the buffer
 at :the id of the disk to start at, zero for the first
 capacity :how many records the buffer holds
 next :the id to pass as at next time, or 0 once the last disk is in the buffer
macro jab.sys.block.find serial label > id a0 u64,scratch a7 [506:510]
 serial :NUL-terminated
 id :the first disk carrying the serial, or 0 when none does
macro jab.sys.block.read buffer address,id u64,sector u64,count u64 > status a0 u64,data 0(buffer),scratch a1-a3,a7 [512:519] :reads count sectors of JAB_BLOCK_SECTOR bytes from the disk, from that sector, straight into the buffer
 status :0; 1 when no disk carries the id; 2 when that disk would not come up; 3 when the device reported an error; 4 when those sectors are not on it, a count of 0 among them
macro jab.sys.block.write buffer address,id u64,sector u64,count u64 > status a0 u64,scratch a1-a3,a7 [521:528] :jab.sys.block.read the other way, the disk written from the buffer
 status :jab.sys.block.read's codes
macro jab.sys.romfs.list buffer address,id u64,directory u64,offset=zero u64,capacity=JAB_ROMFS_PAGE imm > count a0 u64,next a1 u64,records 0(buffer),scratch a2-a4,a7 [530:538] :writes a JAB_ROMFS_ENTRY record per entry of the directory into the buffer
 directory :a header's offset, JAB_ROMFS_ROOT for the volume's root
 offset :where the page starts, zero for the directory's first entry, else the next of the page before
 capacity :how many records the buffer holds
 next :the offset to start the next page at, 0 once the directory has ended
macro jab.sys.romfs.find buffer address,id u64,directory u64,path label > status a0 u64,offset a1 u64,record 0(buffer),scratch a2-a3,a7 [540:547] :looks for the path from the directory, a leading / starting at the root instead; a hard link is followed, so . and .. lead where romfs points them
 buffer :one JAB_ROMFS_ENTRY record
 status :0 with the record written; 1 when nothing of that name is there; 2 when a component along the way is not a directory
 offset :the entry's own header, to list or read it with
macro jab.sys.tar.list buffer address,archive address,length u64,offset=zero u64,capacity=JAB_TAR_PAGE imm > count a0 u64,next a1 u64,records 0(buffer),scratch a2-a4,a7 [549:557] :writes a JAB_TAR_ENTRY record per entry of a tar archive the program already holds into the buffer
 offset :the header the page starts at, zero for the first
 capacity :how many records the buffer holds
 next :the offset to start the next page at, 0 once the archive has ended
macro jab.sys.tar.find buffer address,archive address,length u64,path label > status a0 u64,offset a1 u64,record 0(buffer),scratch a2-a3,a7 [559:566] :looks for the path in the archive; a directory's trailing separator is ignored
 buffer :one JAB_TAR_ENTRY record
 status :0 with the record written, or 1 when the archive holds no such name
 offset :the entry's own header
macro jab.sys.checksum address address,size u64 > lane0 a0 u64,lane1 a1 u64,lane2 a2 u64,lane3 a3 u64,scratch a7 [568:573] :the SHA3-256 of the bytes
 lane0 :the digest's first eight bytes, then lane1 to lane3; stored with four sd in order they are the digest as anything else computes it
macro jab.sys.hash address address,size u64 > hash a0 u64,scratch a1,a7 [575:580]
 hash :the XXH3-64 of the bytes
macro jab.sys.gz.size source address,length u64 > size a0 u64,status a1 u64,scratch a7 [582:587]
 size :the length the gzip's contents will be, from its trailer; 0 with JAB_GZ_NOT_GZIP
 status :JAB_GZ_OK or JAB_GZ_NOT_GZIP
macro jab.sys.gz.read buffer address,source address,length u64,capacity u64 > count a0 u64,status a1 u64,contents 0(buffer),scratch a2-a3,a7 [589:596] :inflates the gzip into the buffer in one call, checking its CRC-32 and its length against what came out
 capacity :how many bytes the buffer holds
 count :the bytes written
 status :a JAB_GZ_* code
macro jab.sys.romfs.read buffer address,id u64,file u64,offset u64,length u64 > count a0 u64,next a1 u64,data 0(buffer),scratch a2-a4,a7 [598:606] :reads at most length bytes of the file, from that byte of it, into the buffer
 file :a header's offset, as a record's JAB_ROMFS_OFFSET carries
 count :the bytes written
 next :the offset to read from next, 0 at the file's end
macro jab.sys.png.size source address,length u64 > width a0 u64,height a1 u64,status a2 u64,scratch a7 [608:613] :the size of a PNG the program holds, from its header
 status :JAB_PNG_OK; or with width and height 0, JAB_PNG_NOT_PNG, JAB_PNG_TRUNCATED, JAB_PNG_CRC, or JAB_PNG_UNSUPPORTED
macro jab.sys.sprite.png sprite address,source address,length u64,capacity imm,frames=1 imm > status a0 u64,record 0(sprite),scratch a1-a4,a7 [615:623] :decodes the PNG into the sprite record as a sheet of frames stacked top to bottom, with the span table
 capacity :how many bytes the record's buffer holds, at least JAB_SPRITE_PIXELS + height * (width * 4 + 4)
 frames :how many frames the sheet is cut into; the PNG's height must divide by it
 status :JAB_PNG_OK with the record filled, JAB_PNG_FRAMES when the height does not divide, JAB_PNG_SIZE when the buffer is too small, the other JAB_PNG_* codes what is wrong with the file
macro jab.sys.sprite.load sprite address,id u64,path label,capacity imm > status a0 u64,record 0(sprite),scratch a1-a3,a7 [625:632] :fills the sprite record from a directory on the disk, its frames the files 0.png, 1.png, and on, in order until one is missing, each decoded straight off the disk; every frame must be one size
 path :the directory, from the volume's root
 capacity :how many bytes the record's buffer holds, at least JAB_SPRITE_PIXELS + frames * height * (width * 4 + 4)
 status :JAB_PNG_OK with the record filled, JAB_PNG_NOT_FOUND when the directory or its 0.png is not there, JAB_PNG_FRAMES when a frame's size differs from the first's, JAB_PNG_SIZE when the buffer is too small, else a frame's own code
macro jab.sys.sprite.draw sprite address,frame u64,x i64,y i64,tint u32,scale u64,pose u64 > status a0 u64,framebuffer JAB_DISPLAY_BASE,scratch a1-a7 [634:656] :blends a frame of the sprite onto the framebuffer with its top left at x, y, what falls off an edge clipped; nothing is presented
 x :negative or past the screen allowed; y likewise
 tint :a colour, 0x00RRGGBB, each of a pixel's channels multiplied by it over 255; JAB_SPRITE_PLAIN when left out
 scale :256ths, JAB_SPRITE_SCALE_ONE when left out
 pose :clockwise degrees in the low sixteen bits with JAB_SPRITE_FLIP_H, JAB_SPRITE_FLIP_V, and JAB_SPRITE_SOLID above, 0 when left out
 status :0; 1 when the frame is not in the sprite; 2 when the scale is past JAB_SPRITE_SCALE_MAX
