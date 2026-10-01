# map.inc

The offsets mirror the map format: every number 32-bit and little-endian,
floats singles, positions metres, z up; a surface is 24 bytes wherever it
appears, a sector light 4. The limits are this build's, each a number to
raise; the loader refuses a count past one with exit 8.
