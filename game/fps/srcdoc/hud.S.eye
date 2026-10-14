call local hud_draw frame u32 > screen JAB_DISPLAY_BASE u32,clobber a0-a1 [10:61] :on a debug build hud_stamp_draw first, then the crosshair over the frame, a disc at the screen's centre
 frame :the frame's number, handed on to the stamp on a debug build alone
 screen :each pixel under the disc halved and added to half of white; on a debug build with hud_stamp set, the stamp's cells over the top-left
call local hud_stamp_draw frame u32 > screen JAB_DISPLAY_BASE u32 [62:93] :a debug build's: with hud_stamp set, the frame's number over the top-left, nothing otherwise
 frame :its low STAMP_BITS bits drawn
 screen :STAMP_BITS cells of STAMP_CELL pixels square, white for a one and black for a zero
