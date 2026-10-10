call local hud_draw frame u32 > screen JAB_DISPLAY_BASE u32,clobber a0-a1 [10:86] :on a debug build the frame's stamp, then the crosshair over the frame, a disc at the screen's centre
 frame :the frame's number, read on a debug build alone
 screen :each pixel under the disc halved and added to half of white; on a debug build with hud_stamp set, the stamp's cells over the top-left
