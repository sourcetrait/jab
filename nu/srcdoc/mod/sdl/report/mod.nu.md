# sdl/report

## main

The report on a shim log (sdl classify): how the flips reached the
window, one record, or the refusal saying why the log cannot be read.
A flip's uploads within 5 ms of the previous belong to one flip;
switches and the console's own never join one. A drawn frame with a
flip's upload under 3 ms on each side sits inside a flip, which is the
half-drawn tick to look for.

- which guest frame each render showed: the flips whose last upload
  landed since the render before it; none is the frame before shown
  again, one is that flip shown, more is every one but the last
  skipped, so a beat between the guest's cadence and the window's
  timer reads as skips or repeats at a steady interval and a stall
  as a burst of them
