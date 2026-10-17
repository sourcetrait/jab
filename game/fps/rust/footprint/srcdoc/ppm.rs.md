# ppm.rs

QEMU's monitor writes its screendump as a P6 PPM through an r8g8b8 line
buffer, three bytes a pixel, so a LEVELS code's 24 bits cross whole and the
framebuffer word's fourth byte never does.

## const STAMP_W

## const STAMP_H

The debug HUD's stamp, STAMP_BITS cells of STAMP_CELL pixels along the
top-left (test.nu's constants, hud.S): 16 cells of 4, so 64 by 4. A white
cell reads as the sentinel in a LEVELS capture but a black one as level 0
at span 0, so every reading skips the cells rather than trusting them.

## struct Image

## fn Image::rgb

## fn Image::word

An OWNER capture's pixel is the surface index the loop stored, blue, green,
and red from the low byte as the framebuffer holds them.

## fn in_stamp

## fn read_ppm

## fn parse_ppm

The header's four fields, comments skipped, then exactly one whitespace
byte before the pixels, as the format has it; a maxval other than 255 is
refused, since a code is three bytes.
