# console.S

A frame is 64 bytes: a kind byte, three of padding, the rest by the kind, zero
to the end; a partial frame is kept until the rest arrives. P carries six
floats from byte 4, the eye's x, y, z then the yaw, pitch, and roll in
degrees; its sector is found from the whole map and its basis derived at
once, so a command in the same batch reads the placed camera, and the next
frame is reported on the UART as the first was. The console's record carries
the command's byte where the state's sector sits, which is how a test counts
the placements apart from the traces.

L is the test's hand on the tile cache. Byte 4 set runs `lumels_bright` first,
so a capture after it reads every texel as the texture holds it, times one,
and the lit reading over the bright one is the light alone. The reset and the
budget come after in every case. Byte 5 set leaves the frame's budget at zero
in place of unbound, so no surface ever completes level 0 and every span takes
the lit loop: the lit loop's picture from the same build, which the alpha
fixture reads against the tiled one. Both bytes exist for the test; play never
sends the frame.
