# main.S

checksum: SHA3-256. Takes the digest of four things and writes each
out as hex, `d <64 hex digits>`: nothing at all, the three bytes the
standard's own vector uses, a short ramp, and a long one that runs to
many blocks. The test holds the first two against the published
answers and the others against what the host computes.

## _start

The ramps are filled before anything is taken of them. Nothing at all is the
short ramp at length 0.

## digest

The digest's four registers are stored to out in order, which is the order
anything else computes it, and printed a byte at a time.
