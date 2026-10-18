# differ.rs

The pictures criterion's instrument: two colour captures of one pose, the
estimator's two builds, compared pixel for pixel with the stamp's cells
skipped, and every differing pixel gathered into a region to box and read.
A whole screen is two million pixels, past what nushell compares in a
reasonable time.

## const CELL

16 pixels, a block's length: the differing pixels are counted into cells
of that side, and cells holding any join their eight neighbours into one
region, so a level change over neighbouring blocks reads as one region and
two far apart as two.

## struct Region

`x1` and `y1` are one past the region's last differing pixel; `largest`
the largest channel difference among its pixels.

## fn Region::empty

## fn Region::take

## fn channel_difference

## fn differ

Regions come in the order of their first cell, row by row. Captures of two
sizes are refused.
