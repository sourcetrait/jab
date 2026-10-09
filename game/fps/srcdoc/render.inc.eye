macro owner_pixel colour reg,surface 32(sp) u64 > pixel colour u64 [601:605]
 colour :the pixel a loop is about to store
 surface :span_fill's slot holding the polygon's surface index
 pixel :under OWNER the surface's index in place of the colour, else the colour as it was
macro section_at kind imm,dst reg > section dst addr [607:610]
 kind :a KIND_*
macro section_count kind imm,dst reg > count dst u64 [612:615]
 kind :a KIND_*
