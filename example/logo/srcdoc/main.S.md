# main.S

logo: a PNG straight from GIMP 3, drawn in the middle of the screen.
The repository's logo directory ships as this program's romfs; the
program finds the PNG on it by name, reads it into memory, decodes it
into a sprite of one frame, opens the display, draws the sprite
centred, flips, and idles until the window closes.

## .set SPRITE_BYTES

The file is 480 by 640, so the sprite is that at four bytes a pixel and four
bytes a row past the header, the rule for one frame, and the PNG itself is
under 32 KiB.

## _start

The PNG comes out of the romfs and into memory, a read at a time from the
offset the one before returned, then is decoded into the sprite in place.
