# gauge/cpu

## CPU_FROM

the CPU readings' whole window opens here, past the load (gauge cpu requests)

## outcome

What a launch came to: its status, a fault line on the UART, the CPU
and wall seconds, its end, each QEMU thread's CPU over a second `jab
launch --threads` held with that span, empty and null when none was
held, every reading `--threads-at` asked for kept whole, and the machine
it ran on, its line and its record. Its end is the supervisor's: when
the stop's quit went in (`quit_seconds`), the actions left unfinished
with their states, what ended a run that left no receipt
(`incomplete`), and the launch's own record, `launch.nuon` (`launch`).
Every time is seconds from the go, on the supervisor's clock.

## requests

The times a run's CPU is read at, the readings cpu-windows reads:
CPU_FROM, every placement of the route, and the route's end, each once,
in order.

## windows

A run's CPU readings as windows, the CPU contract. A reading's times are
host seconds from the launch's start, which comes before QEMU's spawn
where the frames' clock begins at the program's start; it is taken as
the launch polls, every 100 ms, so its actual time trails its request;
and a placement takes effect at the frame after it, so a window is host
time near the legs and never a count of the guest's frames. The whole
window runs from the reading at CPU_FROM to the one at the route's end;
a leg's window from its first placement's reading to the next leg's
first placement's, the last leg's to the end, the readings at a leg's
further placements its subwindows; CPU_FROM's reading bounds the whole
window alone. A window gives its actual interval and each thread's CPU
seconds, the counters' difference, with its utilization, those seconds
over the interval, null for a thread absent from either bound; a window
whose bound is missing is missing, never bridged across.

## cpu-window

One CPU window between two readings (gauge cpu windows): missing when either
reading is absent or was never taken.
