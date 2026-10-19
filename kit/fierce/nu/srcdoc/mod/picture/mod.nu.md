# picture

## FIXTURE_CROSSHAIR

The radius a sample must lie outside of about the screen's centre,
the crosshair's five and a pixel of rounding

## STAMP_BITS

hud.S's stamp: STAMP_BITS cells of STAMP_CELL pixels square along the
screen's top-left, the n-th from the left the frame number's n-th bit

## project

A world point's pixel from an eye at a yaw with no pitch or roll: the
point's right and up over its depth times the focal length from the
screen's centre; null behind the near plane or off the screen by a
block's margin.

## project-x

A point of the plan's screen column from an eye at a yaw, as `project`
finds it, on the screen or off it; null behind the near plane.

## block-sum

The sum of every channel over the 3 by 3 block of pixels about a point
of a capture, the capture's bytes whole.

## records

The records of an API capture, the clock's kinds left to gauge.nu: the
kind, the sector, the eye, the angles in degrees, the times, and an
event's five fields.

## stamp

The frame number a debug build's HUD stamped on a capture held whole
(raise-frame's `--stamp`): the low STAMP_BITS bits, a cell of
STAMP_CELL pixels square a bit along the top-left, the n-th from the
left the n-th bit, STAMP_ONE for a one and STAMP_ZERO for a zero; null
when a cell is not wholly one or the other.

## region-delta

How two captures differ over a rectangle, [x0, y0, x1, y1] with the
pixel past the last: its pixels, the pixels whose colours differ, and
the largest difference in any channel, of 255.

## fixture-opening

The screen rectangle of the fixture wall's opening from an eye facing
it at yaw 0, [x0, y0, x1, y1] with the pixel past the last, inset by
FIXTURE_INSET and clamped to the screen: the wall's two vertices at
the ceiling and the floor of the sector across its portal, projected.

## rows-differ

The rows of a rectangle over which two captures differ, each row's
bytes within the rectangle compared whole.

## unstamped-differ

The rows over which two captures differ outside the HUD's stamp, its
cells along the top-left skipped: the picture contract's comparison of
two bound captures.

## sound-level

The level of a run's recording between two seconds: the peak and the
mean of the left channel's samples' magnitudes, every 97th frame.

## mean-brightness

The mean of the channels over a block of a capture, [x, y, w, h],
every fourth pixel of every fourth row.

## pixel

A pixel of a capture as its three bytes.

## ppm-head

The bytes of a capture's header, the three lines before its pixels.

## pixel-at

A pixel of a capture held whole, as its three bytes.
