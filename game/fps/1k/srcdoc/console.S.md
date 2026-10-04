# console.S

The console, a test channel over the API's input: CONSOLE_FRAME-byte frames by
kind, P placing the camera, T a trace, F a round, N a noise, L the tiles reset
with the lumels bright, the tiles held off, or the levels built capped, R the
generator seeded, E the gauge's measurement closed, each reported back as
REPORT_CONSOLE.

R takes the 64 bits in bytes 4 to 11 as the seed of the generator the
androids draw from, so runs sent one seed before their first frame start
alike; its answer before the first state record is the proof it came in
time. E closes the measurement on the frame that reads it: that frame's
records go out at the next frame's start and the end marker right after
them (main.S's frame_records), the game going on.

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
fixture reads against the tiled one. Byte 6, on a debug build alone, caps the
levels a surface builds, 0 for every level: at 1 a surface builds level 0 and
stops, so a block asking a coarser level takes the chain at it, which the
alpha fixture reads against the lit loop's picture too. The bytes exist for
the test; play never sends the frame.

## .set CONSOLE_FRAME

A console frame's bytes.

## .set CONSOLE_CAPACITY

The console buffer's bytes.

## console_read

The partial frame is moved to the front of the buffer.

## console_frame

L: the tiles forgotten and rebuilt under no budget from the next frame, every
lumel set full bright first when the frame's byte 4 is 1, so a capture reads
the texture sampled as the lit one is; under a budget of nothing instead when
byte 5 is 1, so every surface stays on the lit loop; and on a debug build the
levels a surface builds held to byte 6 when it is not 0.

## k_thousand_d

`f64`: millimetres a metre.

## console_buf

`CONSOLE_CAPACITY u8`: the bytes from the host, a partial frame at the front.

## console_record

`REPORT_SIZE u8`: the console's answer.

## console_pending

`u32`: the bytes kept.

## report_pending

`u8`: 1 when the next frame is reported on the UART.

## measure_end

`u8`: set by an E, cleared once the end marker has gone out.
