# suite/service

RegressionSuite's fixture, CoordinatorWait at the game's scale: Render
Zero under its default two workers through ten seconds of play, the sound
recorded and a pad table driving the play, a debug build so the kernel's
counts read, the run ended by the console's Z so the exit writes them. And
SceneOwnership's fixtures, a SERVICE build's set alone (`./do test
kit/fierce --set service`): the ring's static order check, the three loads
under LOCKSTEP, the corruption case, the stop's two endings, and the
refusal on three harts.

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

## CONSOLE_V

The V frame's command byte, its answer's kind-11 record carrying it.

## SERVICE_AT

When a V starts the service, past the load with the frames running.

## SERVICE_HARTS

The machine the service's fixtures run on, four harts, diagnostic: the
main hart, the two graphics harts the reservation keeps, and hart 3 the io
hart the feature claims.

## LOCKSTEP_LOADS

SceneOwnership's three offered loads under LOCKSTEP, each its total over its
quota frames, the stop's time past its drain, and the plan's accepted and
dropped totals the model must reproduce: steady 2 a frame for 60 frames;
the burst's 1,000 in six quotas, 167 four times then 166 twice; and the
overload's 300 a frame for 60 frames.

## CORRUPT_LOAD

Two quotas of 32 under LOCKSTEP with sequence 40 corrupted, so the second
quota's boundary consumes 31 applied and the one rejected.

## CANCEL_LOAD

One quota of 100,000 at 200 us a message, longer than the run, so the stop
always lands mid-quota and the cancel is taken at the next message.

## FORCED_LOAD

Half a second spun before each message, so a stop landing in the spin finds
the producer past WORK_STOP_TICKS and the kernel forces it.

## STEADY_OFFERING_US

The steady load's offering time bound beside the frame's period: two messages
offered and the producer woken.

## ORDER_BETWEEN

The instructions an index access may stand from its fence by, address and
value work alone, test/purity's OrderCheck's form.

## ORDER_COUNTS

service.S's index stores and loads, five and four, so a new one fails until
it is placed on purpose.

## holds

The SERVICE set's fixtures in order: the order check, the three loads, the
corruption case, the stop mid-quota, the forced stop, and the refusal on
three harts, Render Zero's tree on a disk of its own.

## order-holds

Every store of a ring index in service.S, a `sd` at LINE_INDEX, follows
`fence rw, w` and every load precedes `fence r, rw`, nothing but
ORDER_BETWEEN's address and value work between, and the counts are
ORDER_COUNTS. TCG runs every fence as one full barrier, so no run can show a
missing one; the check proves each sits where service.S.md's argument needs
it and claims nothing more.

## lockstep-model

LOCKSTEP's arithmetic, a boundary at a time from the start's next frame: the
quota offered at boundary b is the schedule's b - 2, the total over its
frames with the first total mod frames one more; the ring takes what its
room allows and drops the rest; the boundary applies at most APPLY_MAX; the
model ends once the last quota is offered and the ring is empty.

## service-run

A launch of the suite's image with its V frames, the sound recorded, the API
on, on Render Zero's disk, the harts given, bounded three seconds past the
last send: QEMU's log empty, no fault line, its records through the stream
and the frames that answered each V.

## witness-holds

Every service record's packet word its boundary's last applied sequence,
none marked torn, and no boundary consuming past APPLY_MAX slots.

## flags-hold

The service records' flags frame by frame: idle before the start's frame,
running from it to the stop's, marked started and stopped at those two, and
LOCKSTEP while running as the launch asked.

## harts-hold

The harts records frame by frame on four harts: hart 3 under the claim from
the start's frame to the stop's, the grant and the started harts 1 and 2
then, harts 1, 2, and 3 otherwise.

## window-holds

A closed window: a valid handoff, its counts the expected, offered conserved
as applied, dropped, rejected, and discarded, the last sequence the offered
count's, hart 0's applied chain the producer's expected chain, and the gaps
the dropped, rejected, and discarded.

## lockstep-holds

A load under LOCKSTEP on four harts: the model's totals the plan's; the start
answered on hart 3 and the stop with a valid handoff; every modelled
boundary's applied, rejected, depth, offered, dropped, and skipped exactly
the model's, of the window's generation; nothing left after the drain; the
witness, the flags, and the harts; one window closed with the expected
counts, no quota skipped, nothing corrupted, published and expected chains
equal, nothing rejected; and on the steady load every message applied at the
boundary after its offer, its age under the frame's period and
STEADY_OFFERING_US.

## corrupt-holds

The corruption case: one rejection, the corrupted sequence of the window's
generation, at the second quota's boundary, counted among its frame's
APPLY_MAX; the window conserved with the one rejected; the producer's
corrupted list that one sequence; the published chain apart from the
expected; the witness and the flags.

## cancel-holds

The stop mid-quota: started and stopped with a valid handoff, the quota cut
short, offered conserved, nothing discarded, the chains equal, the gaps the
dropped and rejected, quotas skipped while the one ran, a reduced load; the
witness, the flags, and the harts.

## forced-holds

The forced stop: answered SERVICE_FORCED, the window forced and incomplete,
its last sequence and chains unknown, what the ring held discarded, the flags
and the harts, hart 3 back to the raster from the stop's frame.

## refusal-holds

The service on three harts: the start refused under the floor with no hart,
the take's refusal on the UART, no frame with the service running, no window
opened, every frame on harts 1 and 2 with nothing claimed, and the game
playing on past it.
