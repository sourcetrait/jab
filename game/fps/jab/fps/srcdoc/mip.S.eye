rodata local msg_mips 11 u8 [3:4]
rodata local word_chains 10 u8 [5:6]
rodata local word_levels 10 u8 [7:8]
rodata local word_texels_in 12 u8 [9:10]
rodata local word_ms_end 4 u8 [11:13]
macro texel_shrink above_left a0 u32,above_right a7 u32,below_left t2 u32,below_right t3 u32,scale s6 u32 > texel a2 u32,scratch t0,t4-t6,a1,a3-a5 [17:136] :a coarser texel from the two by two under it, the colour weighted by the alphas when they differ, the alpha their mean scaled by the level's factor and capped at 255
 scale :the level's alpha scale, 16.16
call local mip_levels width u32,height u32 > levels a0 u64,clobber a1 [138:152] :the levels a texture's chain has, one and one more for every halving while both sides stay two texels or more, MIP_LEVELS at most
call local mips_build > chains material_mips MAX_MATERIALS*MIP_LEVELS address,counts material_mip_count MAX_MATERIALS u64,cursor mip_cursor address,levels mip_arena MIP_ARENA_BYTES u8,clobber a0-a7 [154:334] :every material's chain built, the map's and the engine's images', each coarser level half a side from the one before by texel_shrink under the level's alpha scale, into the arena while both sides stay two texels or more and the arena holds it; a line on the UART of a debug build
 counts :the levels each material has, one for the texture alone
bss local material_mips MAX_MATERIALS*MIP_LEVELS address [338:339] :each material's chain, the texels of every level, level 0 the record's own
bss local material_mip_count MAX_MATERIALS u64 [340:341] :the levels each material has
bss local mip_cursor address [342:344] :the arena's next free byte
bss local mip_arena MIP_ARENA_BYTES u8 [345:346] :the chains' coarser levels
