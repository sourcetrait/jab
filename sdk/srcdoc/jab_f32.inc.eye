macro jab.f32.PI dst reg > pi dst f32,scratch t0 [1:4]
 pi :0x40490fdb
macro jab.f32.TAU dst reg > tau dst f32,scratch t0 [6:9]
 tau :two pi, 0x40c90fdb
macro jab.f32.FRAC_PI_2 dst reg > half_pi dst f32,scratch t0 [11:14]
 half_pi :pi over two, 0x3fc90fdb
macro jab.f32.rad dst reg,src f32 > radians dst f32,scratch t0,ft0 [16:20]
 src :degrees
macro jab.f32.deg dst reg,src f32 > degrees dst f32,scratch t0,ft0 [22:26]
 src :radians
macro jab.f32.sin dst reg,src f32 > sine dst f32,scratch t0,ft0-ft4 [28:68]
 src :radians, any size
macro jab.f32.cos dst reg,src f32 > cosine dst f32,scratch t0-t1,ft0-ft4 [70:111]
 src :radians, any size
macro jab.f32.atan2 dst reg,y f32,x f32 > angle dst f32,scratch t0-t2,ft0-ft5 [113:170] :the angle of the point x, y from the x axis, counter-clockwise
 angle :radians within a half turn either way; 0 for both zero, and a zero y of either sign reads as zero
macro jab.f32.vec3.dot dst reg,a addr,b addr > dot dst f32,scratch ft0-ft1 [172:182]
 a :three singles, as is b
macro jab.f32.vec3.reg.dot dst reg,ax f32,ay f32,az f32,bx f32,by f32,bz f32 > dot dst f32 [184:188]
 dst :none of the operands
macro jab.f32.vec3.reg.sqrlen dst reg,x f32,y f32,z f32 > sqrlen dst f32 [190:194]
 dst :none of the operands
macro jab.f32.vec3.reg.len dst reg,x f32,y f32,z f32 > length dst f32 [196:201]
 dst :none of the operands
macro jab.f32.vec3.reg.norm x f32,y f32,z f32 > x x f32,y y f32,z z f32,scratch t0,ft0-ft1 [203:217] :scales the vector to unit length in place; a zero vector is left as it is
 x :outside ft0 and ft1, as are y and z
macro jab.f32.vec2.reg.sqrlen dst reg,x f32,y f32 > sqrlen dst f32 [219:222]
 dst :none of the operands
macro jab.f32.vec2.reg.len dst reg,x f32,y f32 > length dst f32 [224:228]
 dst :none of the operands
