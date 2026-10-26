macro owner_pixel colour reg,surface 32(sp) u64 > pixel colour u64 [815:819]
 colour :the pixel a loop is about to store
 surface :span_fill's slot holding the polygon's surface index
 pixel :under OWNER the surface's index in place of the colour, else the colour as it was
macro levels_pixel colour reg,scratch reg,code 32(sp) u64 > pixel colour u32,scratch scratch [821:829]
 colour :the pixel a loop is about to store
 code :span_fill's slot holding the block's level over the span's index
 pixel :under LEVELS the code with the pixel's offset in its block, s11 less t2, in place of the colour, else the colour as it was
macro row_derivative dst reg,coord i64,izb i64,uzb i64,z i64,s1 reg,s2 reg,saturate ? > derivative dst u64,scratch s1,s2 [831:857] :a coordinate's change a row from the row gradients of 1/z and of the coordinate over z
 coord :16.16 texels at level 0
 izb :1/z's change a row in 6.26, zero for the clamp's constant z
 uzb :the coordinate over z's change a row in 48.16
 z :the block's start z in 16.16
 derivative :|(uzb - ((coord izb) >> DEPTH_BITS)) z >> 16|, 16.16 texels a row
 saturate :taken where a product past 64 bits once shifted, the subtraction's overflow, or the most negative value leaves no answer
macro section_at kind imm,dst reg > section dst addr [859:862]
 kind :a KIND_*
macro section_count kind imm,dst reg > count dst u64 [864:867]
 kind :a KIND_*
