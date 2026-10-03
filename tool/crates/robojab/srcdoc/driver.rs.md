# driver.rs

## const HEX_SHOWN

The rest of the bytes past it waits for `api recv` or a record size.

## struct Look

## struct Frame

## struct Driver

Started from its plan on the first command, restarted on request, ended by
quit or by the bound. `api_partial` is the trailing part of a record the
last read cut short: the machine's tail has already moved past those bytes,
so dropping them would start every later record mid-record. Every API read,
a frame's, `api records`, and `api recv`, takes them back first (`held`).

### fn machine

One that ended stays ended until restart.

### fn start

### fn seconds

### fn alive

### fn elapsed

### fn quit

### fn line

A failing command reports and the rest of the line still runs.

### fn command

### fn frame

Whether the machine runs and for how long, its faults resolved, what the
UART, the debug channel, and the API said since the last frame, the sound's
level over that span, and the screen, kept beside the plan's files as
`frame_<n>`.

### fn pad

### fn faults

### fn held

### fn records

Records are numbered from the first the machine ever sent. `bytes` is the
bytes cut into records this time and `remainder` the bytes kept for the next
read, so a record is never split across two answers. A read with a size of
zero keeps every byte and refuses.

### fn status

The UART is read for faults and its lines kept for `serial`.

## fn split

## fn lock
