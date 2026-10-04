macro sprite_round255 product reg,tmp reg > quotient product u8,scratch tmp [6:11]
 product :of two bytes, on the way in
 quotient :the product divided by 255 and rounded
ecall sys_sprite_draw sprite addr,frame u64,x i64,y i64,tint u32,scale u64,pose u64 > status a0 u64 [16:287] :blends a frame of the sprite onto the framebuffer, its top left at x, y, clipped at the edges, or with JAB_SPRITE_SOLID writes the tint over every pixel the frame covers
 sprite :ends the run unless it lies inside the program's window, or when a side or the frame count is past SPRITE_SIDE_MAX
 tint :0x00RRGGBB each pixel is multiplied by, JAB_SPRITE_PLAIN for none
 scale :in 256ths, JAB_SPRITE_SCALE_ONE for the frame's own size
 pose :JAB_SPRITE_FLIP_H, JAB_SPRITE_FLIP_V, and JAB_SPRITE_SOLID, and a clockwise turn in degrees in the low sixteen bits
 status :0, 1 when the frame is not in the sprite, 2 when the scale is past JAB_SPRITE_SCALE_MAX
j local sprite_bad [289:290] :a record that is no sprite, the run ended as bad_address ends it
j local sprite_turned > status a0 u64 [292:459] :the turned draw, each pixel of the turned rectangle's bounding box mapped back through the inverse turn
 status :in the frame's a0 slot, 0
call local sprite_blend pixel addr,screen addr,alpha u8 > word 0(screen) u32,clobber a4-a6 [461:524] :blends a source pixel over the screen word, the tint multiplied in first
 pixel :in a1, screen in a2, alpha in a7
call sprite_spans record addr > flags JAB_SPRITE_FLAGS(record) u32,clobber a0-a3 [525:586] :writes the span table after the pixels of a record whose header and pixels are in place, and sets JAB_SPRITE_SPANNED
call local sprite_trig angle u64 > sine a0 i64,cosine a1 i64 [588:619]
 angle :0 to 359 degrees
 sine :signed 16.16, as the cosine is
call local sprite_le32 at addr > word a0 u32 [621:632]
