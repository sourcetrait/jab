# map.inc

The Jab FPS map, <name>.jabfps.map, as byte offsets, and the program's limits
on what a map may hold.

The offsets mirror the map format: every number 32-bit and little-endian,
floats singles, positions metres, z up; a surface is 24 bytes wherever it
appears, a sector light 4. The limits are this build's, each a number to
raise; the loader refuses a count past one with exit 8.

## .set MATERIAL_NAME

The name is the romfs stem the texture loads from, with .png appended.
