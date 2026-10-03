set DURATION u64 [3] :a mode's run, three seconds of the clock
set PIXELS [4] :the screen's pixels
set ZBUF_BYTES [5] :the depth buffer's bytes, a word a pixel
set POLY_X f32 [6] :a vertex's screen x
set POLY_Y f32 [7] :its screen y
set POLY_IZ f32 [8] :its 1/z
set POLY_UZ f32 [9] :its u/z
set POLY_VZ f32 [10] :its v/z
set POLY_BR f32 [11] :its brightness
set POLY_VERTEX [12] :a vertex's bytes, six floats
set POLY_VERTICES [13] :the quad's vertices
set BLOCK [14] :a span block's pixels, the texture coordinates exact at each block's ends and stepped within
set POLY_FIXED u64 [15] :a polygon mode's flag, the depth an integer
set POLY_LIT u64 [16] :the flag for the pixels lit
set POLY_INTEGER u64 [17] :the flag for the blocks' ends in fixed point
set DEPTH_BITS [18] :1/z's fraction bits, 6.26
set Z_SHIFT [19] :z as 2^Z_SHIFT over 1/z, 48.16
set TEX_BITS [20] :the texture's side as a power of two
set TEX_SIDE [21] :the texture's side in pixels
set TEX_MASK [22] :a texture coordinate's wrap
set TEX_ROW_BYTES [23] :a texture row's bytes
set TEX_ROW_SHIFT [24] :a texture row's offset as a shift of its index
set TEX_STEP u32 [25] :a drawn pixel's step across the texture, half a texel in 16.16
set SPAN [26] :a perspective span's pixels
set SPANS [27] :the spans in a row
set LINE_BYTES [28] :the UART line's buffer
set DIGITS_BYTES [29] :append_dec's scratch
j _start [33:74] :the program, the display opened and each mode run in turn, the last mode's last frame left up
j local idle [75:77] :the last frame kept up, awaiting the display's tick forever
j local no_display [79:81] :exits 1, the machine having no display
call local mode_run routine addr,name addr,flip bool > count frames u64,elapsed elapsed u64,line line LINE_BYTES u8,clobber a0-a7,fa0-fa1 [83:146] :frames rendered by a routine for DURATION of the clock, the whole screen flipped after each when asked, then the mode's line on the UART
 routine :the frame routine
 name :the line's name, NUL-terminated
 count :the frames rendered so far, which the routines read
call local append_str cursor addr,string addr > cursor a0 addr,text 0(cursor) u8,clobber a1 [148:157] :the string copied to the cursor, which moves past it
 string :NUL-terminated
call local append_dec cursor addr,value u64 > cursor a0 addr,digits 0(cursor) u8,clobber a1 [159:178] :the value written in decimal at the cursor, which moves past the digits
call local make_texture > texture texture TEX_SIDE*TEX_SIDE u32 [180:203] :a checker of eight-pixel squares in two colours with a gradient across each row, so a scrolled texture shows motion
call local frame_fill count frames u64 > screen JAB_DISPLAY_BASE u32 [205:227] :the whole framebuffer one colour, a shade of the frame count, two pixels a store, eight stores a turn
call local frame_texture count frames u64 > screen JAB_DISPLAY_BASE u32,clobber a0,a2-a5 [229:259] :every row an affine span across the texture, u in 16.16 stepping TEX_STEP a pixel from an offset that scrolls a texel a frame, the row's texture row from the row and the frame; a texel read and a pixel stored each
call local frame_perspective count frames u64 > screen JAB_DISPLAY_BASE u32,clobber a0,a2-a7 [261:299] :the textured row in spans of SPAN pixels, each span's depth from a divide of a numerator by a 1/z that grows along the row and down the screen, its u and its step from that depth, then the span affine, the shape of a perspective-correct span
call local frame_polygon > screen JAB_DISPLAY_BASE u32,depth zbuf PIXELS u32,clobber a0-a7,fa0-fa1 [301:303] :the quad unlit with a float depth, through poly_frame
call local frame_fixed > screen JAB_DISPLAY_BASE u32,depth zbuf PIXELS u32,clobber a0-a7,fa0-fa1 [305:307] :the quad unlit with an integer depth, through poly_frame
call local frame_integer > screen JAB_DISPLAY_BASE u32,depth zbuf PIXELS u32,clobber a0-a7,fa0-fa1 [309:311] :the quad unlit with no float in the span, through poly_frame
call local frame_lit > screen JAB_DISPLAY_BASE u32,depth zbuf PIXELS u32,clobber a0-a7,fa0-fa1 [313:315] :the integer quad with its brightness multiplied into every pixel, through poly_frame
call local poly_frame flags u64 > screen JAB_DISPLAY_BASE u32,depth zbuf PIXELS u32,ends cross 12 f32,clobber a0-a7,fa0-fa1 [317:689] :the depth buffer cleared, then every row of the screen, the quad's span on it filled in blocks of BLOCK pixels, a texel read, a depth compare, and a pixel and depth store when nearer
 flags :POLY_FIXED, POLY_INTEGER, and POLY_LIT
call local frame_vector count frames u64 > screen JAB_DISPLAY_BASE u32 [690:709] :the whole framebuffer one colour through vector stores, built only with --set vector
bss local frames u64 [713:714] :the frame count, for the routines
bss local elapsed u64 [715:716] :the mode's ticks
bss local digits DIGITS_BYTES u8 [717:718] :append_dec's scratch, the digits built backwards from its end
bss local line LINE_BYTES u8 [719:721] :the UART line
bss local texture TEX_SIDE*TEX_SIDE u32 [722:723] :the texture
bss local cross 12 f32 [724:726] :a row's two crossings of the quad, an attribute set each
bss local zbuf PIXELS u32 [727:728] :the depth buffer, 1/z a pixel as a float or in 6.26
rodata local name_fill 5 u8 [731:732]
rodata local name_texture 8 u8 [733:734]
rodata local name_perspective 12 u8 [735:736]
rodata local name_polygon 8 u8 [737:738]
rodata local name_fixed 6 u8 [739:740]
rodata local name_integer 8 u8 [741:742]
rodata local name_lit 4 u8 [743:744]
rodata local name_vector 7 u8 [745:746]
rodata local name_textureflip 12 u8 [747:748]
rodata local word_frames 9 u8 [749:750]
rodata local word_shown 8 u8 [751:752]
rodata local word_ticks 8 u8 [753:754]
rodata local word_pixels 9 u8 [755:756]
rodata local msg_no_display 22 u8 [757:759]
rodata local poly 24 f32 [760:764] :the quad, at each vertex the screen x and y, 1/z, u/z, v/z, and the brightness
rodata local k_half f32 [765:766]
rodata local k_one f32 [767:768]
rodata local k_sixty_four_k f32 [769:770] :one in 16.16
rodata local k_depth_scale f32 [771:772] :2^26, 1/z into 6.26
