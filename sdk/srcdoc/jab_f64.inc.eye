macro jab.f64.PI dst reg > pi dst f64,scratch t0 [1:4]
 pi :0x400921fb54442d18
macro jab.f64.TAU dst reg > tau dst f64,scratch t0 [6:9]
 tau :two pi, 0x401921fb54442d18
macro jab.f64.FRAC_PI_2 dst reg > half_pi dst f64,scratch t0 [11:14]
 half_pi :pi over two, 0x3ff921fb54442d18
macro jab.f64.vec3.dot dst reg,a address,b address > dot dst f64,scratch ft0-ft1 [16:26]
 a :three doubles, as is b
macro jab.f64.vec3.sqrlen dst reg,a address > sqrlen dst f64,scratch ft0 [28:35]
 a :three doubles
macro jab.f64.vec3.len dst reg,a address > length dst f64,scratch ft0 [37:45]
 a :three doubles
macro jab.f64.vec3.norm dst address,a address > unit 0(dst) 3 f64,scratch t0,ft0,ft2-ft3 [47:70] :writes the vector at a scaled to unit length; a zero vector is written unchanged
 dst :three doubles, and may be a
 a :three doubles
macro jab.f64.vec2.sqrlen dst reg,a address > sqrlen dst f64,scratch ft0 [72:77]
 a :two doubles
macro jab.f64.vec2.len dst reg,a address > length dst f64,scratch ft0 [79:85]
 a :two doubles
macro jab.f64.vec3.reg.dot dst reg,ax f64,ay f64,az f64,bx f64,by f64,bz f64 > dot dst f64 [87:91]
 dst :none of the operands
macro jab.f64.vec3.reg.sqrlen dst reg,x f64,y f64,z f64 > sqrlen dst f64 [93:97]
 dst :none of the operands
macro jab.f64.vec3.reg.len dst reg,x f64,y f64,z f64 > length dst f64 [99:104]
 dst :none of the operands
macro jab.f64.vec3.reg.norm x f64,y f64,z f64 > x x f64,y y f64,z z f64,scratch t0,ft0-ft1 [106:120] :scales the vector to unit length in place; a zero vector is left as it is
 x :outside ft0 and ft1, as are y and z
macro jab.f64.vec2.reg.sqrlen dst reg,x f64,y f64 > sqrlen dst f64 [122:125]
 dst :none of the operands
macro jab.f64.vec2.reg.len dst reg,x f64,y f64 > length dst f64 [127:131]
 dst :none of the operands
