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
