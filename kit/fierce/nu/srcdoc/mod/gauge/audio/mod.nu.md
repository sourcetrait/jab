# gauge/audio

RegressionSuite's play and its reading, shared by the suite's regression
case, which asserts each fact, and the bench's audio step (gauge play
audio), which keeps the reading for the qualification's audio row: a pad
table through ten seconds of play, the E closing the measurement, the Z's
exit writing the kernel's counts on a debug build, QEMU's dropped reports
traced into its log. The reading's limits are ServiceQuotas': no service
finding the sound's queue empty after its drain is not output underrun past
QEMU's backend, and the 50 ms windows are a coarse continuity check a
shorter gap passes, read only where the sound was recorded.

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

## MEASURED_TO

The E frame's time, half a second past the last report, so the capture
closes complete before the exit.

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

## sends

The play's console frames: the E at MEASURED_TO, then the Z at END_AT.

## window-peaks

A recording's 50 ms windows' peaks from its first frame, the left channel
read every PICK_FRAMES frames.

## heard

A recording's windows read for continuity: the first window at SOUND_HEARD
or past it, the ambient's first; whether the recording reaches HEARD_TO;
the windows read between; every quiet window among them; and the first
forty peaks for a message.

## counts

The kernel's exit lines a prefix starts on the debug channel, each parsed
into its counts.

## reading

A launch of the play read whole: whether its QEMU lists QUEUE_FULL, the
reports QEMU dropped, every other line of QEMU's log, the run's status, the
fault lines on the UART, the exit's pad counts and sound counts with how
many times each was written, and where the sound was recorded its windows
(heard); and each problem named: the trace unlisted, a report dropped,
QEMU's complaint, a status but the Z's 0, a fault, the counts written other
than once, an event lost by the ring, an event the table sent not taken
into it, one it held not taken by the program, a service finding the
sound's queue empty, a failed period, the ambient unheard, the recording
short, and a quiet window. A live run reads its counters alone.

## line

One line on a reading: held, or broken with its problems; the pad's and the
sound's counts; QEMU's dropped reports; the windows read and quiet, or the
continuity unread on live sound.
