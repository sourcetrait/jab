# console.S

A frame is 64 bytes: a kind byte, three of padding, the rest by the kind, zero
to the end; a partial frame is kept until the rest arrives. P carries six
floats from byte 4, the eye's x, y, z then the yaw, pitch, and roll in
degrees; its sector is found from the whole map and its basis derived at
once, so a command in the same batch reads the placed camera, and the next
frame is reported on the UART as the first was. The console's record carries
the command's byte where the state's sector sits, which is how a test counts
the placements apart from the traces.
