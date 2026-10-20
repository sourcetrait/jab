# suite/service

RegressionSuite's fixture, CoordinatorWait at the game's scale: Render
Zero under its default two workers through ten seconds of play, the sound
recorded and a pad table driving the play, a debug build so the kernel's
counts read, the run ended by the console's Z so the exit writes them.

## SOUND_HEARD

The peak a 50 ms window must reach to be heard, out of 32767, sound's own.

## REPORT_HZ

The reference pad's reports a second, 125.

## REPORTS

The play's reports, ten seconds at REPORT_HZ.

## PLAY_FROM

The first report's time from the run's go, after the load and the first
frame's look have opened the pad: an event the device receives before its
driver is ready is dropped by QEMU unseen.

## END_AT

The Z frame's time, a second past the last report, so every event is taken.

## SECONDS

The run's bound, past the exit's flush of the sound.

## WINDOW_SECONDS

A recording window's seconds, the length of the gap the continuity check can
see.

## HEARD_TO

The recording's second up to which every window is read, the play's end less
a second.

## AXES

The axes each report moves: the left stick's X and Y and the right stick's Z.

## QUEUE_FULL

QEMU's trace event for a report virtio-input dropped for want of buffers,
logged with the guest's errors in `qemu.log`.

## PICK_FRAMES

The frames apart a window's picks sit, a coarse read of each window.

## play-table

The pad's table: REPORTS reports from PLAY_FROM, REPORT_HZ a second, each the
three axes of AXES on sweeps of their own, so every report differs and the
player walks and turns about the bay.

## window-peaks

A recording's 50 ms windows' peaks from its first frame, the left channel
read every PICK_FRAMES frames.

## regression

The launch: the table on the pad through the evdev shim, the sound recorded,
the API on for the Z frame at END_AT, QEMU tracing QUEUE_FULL. Held: QEMU
lists the event; no report dropped by the device's queue and nothing else in
the log; the run's status 0 from the Z frame, no fault line; the exit's pad
counts once, nothing dropped by the kernel's ring, every event the table sent
accepted, every accepted event taken by the program; the exit's sound counts
once, no service finding the queue empty after its drain, no period failed;
and the recording heard in every 50 ms window from the ambient's first to
HEARD_TO, a coarse continuity check a shorter gap passes. The exhaustion
count's definition, its one-shot late case, and that case's control are the
kernel's test/sound's (ServiceQuotas).
