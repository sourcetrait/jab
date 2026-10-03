set SPRITE_SIDE_MAX u64 [4] :the most a record's width, height, and frame count may each be
macro sprite_round255 reg reg,tmp reg > quotient reg u8,scratch tmp [6:11]
 reg :a product of two bytes on the way in
 quotient :the product divided by 255 and rounded
ecall sys_sprite_draw sprite address,frame u64,x i64,y i64,tint u32,scale u64,pose u64 > status a0 u64 [16:287] :blends a frame of the sprite onto the framebuffer, its top left at x, y, clipped at the edges, or with JAB_SPRITE_SOLID writes the tint over every pixel the frame covers
 sprite :ends the run unless it lies inside the program's window, or when a side or the frame count is past SPRITE_SIDE_MAX
 tint :0x00RRGGBB each pixel is multiplied by, JAB_SPRITE_PLAIN for none
 scale :in 256ths, JAB_SPRITE_SCALE_ONE for the frame's own size
 pose :JAB_SPRITE_FLIP_H, JAB_SPRITE_FLIP_V, and JAB_SPRITE_SOLID, and a clockwise turn in degrees in the low sixteen bits
 status :0, 1 when the frame is not in the sprite, 2 when the scale is past JAB_SPRITE_SCALE_MAX
j local sprite_bad [289:290] :a record that is no sprite, the run ended as bad_address ends it
j local sprite_turned > status a0 u64 [292:459] :the turned draw, each pixel of the turned rectangle's bounding box mapped back through the inverse turn
 status :in the frame's a0 slot, 0
call local sprite_blend pixel address,screen address,alpha u8 > word 0(screen) u32,clobber a4-a6 [461:524] :blends a source pixel over the screen word, the tint multiplied in first
 pixel :in a1, screen in a2, alpha in a7
call sprite_spans record address > flags JAB_SPRITE_FLAGS(record) u32,clobber a0-a3 [525:586] :writes the span table after the pixels of a record whose header and pixels are in place, and sets JAB_SPRITE_SPANNED
call local sprite_trig angle u64 > sine a0 i64,cosine a1 i64 [588:619]
 angle :0 to 359 degrees
 sine :signed 16.16, as the cosine is
call local sprite_le32 at address > word a0 u32 [621:632]
rodata local sprite_sine 91 u32 [636:649] :the sine of 0 to 90 degrees in 16.16 fixed point, rounded
bss local sprite_tinted u64 [653:654] :0 when the tint is white, so nothing is tinted
bss local sprite_tint_r u64 [655:656] :the tint's red
bss local sprite_tint_g u64 [657:658] :its green
bss local sprite_tint_b u64 [659:660] :its blue
bss local sprite_flips u64 [661:662] :the pose's flips, 1 across and 2 down
bss local sprite_solid u64 [663:664] :nonzero for a solid draw
bss local sprite_solid_word u64 [665:666] :the tint a solid draw writes
bss local sprite_flags u64 [667:668] :the record's flags
bss local sprite_spans_row address [669:670] :the frame's rows of the span table
bss local sprite_stepabs u64 [671:672] :the column step, 16.16, unsigned
bss local sprite_x i64 [673:674] :the draw's x
bss local sprite_angle u64 [675:676] :the turn, 0 to 359 degrees
bss local sprite_last_col u64 [677:678] :the frame's last column
bss local sprite_last_row u64 [679:680] :the frame's last row
bss local sprite_hw u64 [681:682] :half the drawn width, 16.16
bss local sprite_hh u64 [683:684] :half the drawn height, 16.16
bss local sprite_dw16 u64 [685:686] :the drawn width, 16.16
bss local sprite_dh16 u64 [687:688] :the drawn height, 16.16
bss local sprite_sin i64 [689:690] :the turn's sine, 16.16
bss local sprite_cos i64 [691:692] :its cosine
