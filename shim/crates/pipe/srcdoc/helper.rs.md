# helper.rs

A launch's helpers: processes run beside its child from the go, the pad
bridge among them, each the supervisor's own child, watched and ended
with the run. On Windows the bridge is the pad pipe's one client, so a
bridge that fails before it connects would leave QEMU waiting on the pipe
for good; supervising it ends the launch instead, naming it.

## const HELPER_END

## enum Standing

## struct Running

### fn start

Its stderr a fresh file the schedule names, its stdin and stdout empty.
One that cannot start stands never started, and the launch fails at
once.

### fn standing

### fn poll

### fn said

What its stderr said last, a line or two, which the failure names.

### fn failure

### fn stop

### fn end
