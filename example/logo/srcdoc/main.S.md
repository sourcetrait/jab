# main.S

logo: a PNG straight from GIMP 3, drawn in the middle of the screen.
The repository's logo directory ships as this program's romfs; the
program finds the PNG on it by name, reads it into memory, decodes it
into a sprite of one frame, opens the display, draws the sprite
centred, flips, and idles until the window closes.

## .set DISK

`u8`: the romfs disk's id.

## .set WIDTH

`u32`: the logo's width in pixels.

## .set HEIGHT

`u32`: the logo's height in pixels.

## .set SPRITE_BYTES

`u64`: the sprite one frame of the logo needs.

The file is 480 by 640, so the sprite is that at four bytes a pixel and four
bytes a row past the header, the rule for one frame, and the PNG itself is
under 32 KiB.

## .set PNG_BYTES

`u64`: room for the PNG, 32 KiB.

## .set X

`i64`: the logo's left, centred on the screen.

## .set Y

`i64`: the logo's top, centred on the screen.

## _start

The PNG comes out of the romfs and into memory, a read at a time from the
offset the one before returned, then is decoded into the sprite in place.

## path

`21 u8`: the PNG's path on the romfs.

## msg_no_file

`35 u8`: the line for a romfs without the PNG.

## msg_bad_png

`32 u8`: the line for a PNG that would not decode.

## msg_no_display

`18 u8`: the line for a machine with no display.

## rec

`144 u8`: the PNG's romfs record.

## png

`32768 u8`: the PNG as read.

## sprite

`1231376 u8`: the logo as a sprite of one frame.
