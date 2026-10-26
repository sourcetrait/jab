macro owner_pixel colour reg,surface 32(sp) u64 > pixel colour u64 [815:819]
 colour :the pixel a loop is about to store
 surface :span_fill's slot holding the polygon's surface index
 pixel :under OWNER the surface's index in place of the colour, else the colour as it was
macro levels_pixel colour reg,scratch reg,code 32(sp) u64 > pixel colour u32,scratch scratch [821:829]
 colour :the pixel a loop is about to store
 code :span_fill's slot holding the block's level over the span's index
 pixel :under LEVELS the code with the pixel's offset in its block, s11 less t2, in place of the colour, else the colour as it was
macro section_at kind imm,dst reg > section dst addr [831:834]
 kind :a KIND_*
macro section_count kind imm,dst reg > count dst u64 [836:839]
 kind :a KIND_*
