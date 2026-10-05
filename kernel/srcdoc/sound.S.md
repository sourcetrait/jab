# sound.S

The sound device: QEMU's virtio-sound over the mmio transport, id 25, its
playback stream driven in Jab's one format, 48 kHz stereo signed 16-bit
interleaved (jab.inc), TheUser's ruling. The control queue carries the
stream's set-up, SET_PARAMS, PREPARE, and START, each a request the device
answers with a status; the tx queue carries the samples in periods of
JAB_SOUND_PERIOD frames, each a chain of two descriptors, the stream id and
the samples the device reads and a status it writes back, returned once the
host's backend has consumed it on its own timer. The stream runs on that
clock: JAB_SOUND_PERIODS periods are in flight, and each one returned raises
the device's line, which the kernel takes wherever it is, in a wait or in
the program through the trap vector (trap.S), and fills and offers again
from the mix of two sources: the frames a program has queued with
jab.sys.sound.write, a ring of JAB_SOUND_RING of them played in order as
they reach the front, and the synthesizer's voices (synth.S). A dry ring and
no voice is silence, never a fault. Once the stream is live the external
interrupt stays enabled in sie for good, so the waits leave it set
(timer.S, virtio.S). Every period the device returns is looked at: its
status is counted, and the time of the last return is what tells a stalled
backend, one that has returned nothing for SOUND_STALL_TICKS while periods
were in flight, from a slow one; a stalled stream is declared dead, with a
line on the UART, rather than holding a wait forever. A long call looks at
the stream from inside its loops through sound_tick, so the lead is never
spent by the kernel's own work.

## .set SOUND_STREAM

`u32`: the playback stream's id.

## .set PERIOD_BYTES

`u64`: a period's samples in bytes.

## .set PERIOD_STRIDE

`u64`: a period's transfer, the stream id then the samples.

## .set RING_MASK

`u64`: an index's place in the ring.

## .set ACCUM_BYTES

`u64`: the mixer's accumulator, two 32-bit samples a frame.

## .set SOUND_STALL_TICKS

`u64`: how long a backend with periods in flight may return nothing before it has stopped.

## .set SOUND_POLL_TICKS

`u64`: how often a wait on the stream alone wakes to look for a stall.

## .set SOUND_DRAIN_PERIODS

`u64`: the periods of silence the exit plays past the last with content.

So the host's own buffer behind the device, 92 ms on ALSA, has played what
it held before QEMU ends.

## .set SOUND_FLUSH_TICKS

`u64`: the longest the exit waits for the ring and the voices to end.

## sys_sound_write

The count is capped to the room before it is multiplied, so a count that
would wrap the byte size is never the one the bounds see.

## sound_open

The stream's parameters are the one format, the period, and the lead. The
period chains are laid out once: descriptor 2i the stream id and the
samples, 2i+1 the status. Then the synthesizer is reset, the line stays
enabled from here on, and the stream is primed with every period.

## msg_sound_at

`15 u8`: the debug line naming the device's transport, under DEBUG only.

## msg_no_sound

`15 u8`: the debug line for a machine without one, under DEBUG only.

## msg_sound_refused

`20 u8`: the debug line for a device that refused, under DEBUG only.

## sound_service

Called wherever the device's line is taken (virtio.S), in a wait or from the
trap vector, which is why it keeps every register but the t registers and
a0.

## sound_mix

The ring's frames, as many as it holds up to the period, go into the
accumulator scaled by four, silence after them; the synthesizer's voices
are added at full scale; the sum comes back down by four, clipped. So a
program's frames pass through unchanged and four voices at full scale reach
it.

## sound_drain

The status sits after the samples, written by the device; a status other
than OK is counted as failed, and every return is counted and stamps the
time of the last.

## sound_stalled

A dead stream's refills stop, the calls answer 2 from then on, the wait
drops its bit, and "jab: sound stalled" goes to the UART in every build,
under the line lock (uart.S), since a program that hears nothing deserves
the reason.

## sound_tick

The calls run with interrupts off, so a call that outlasts the lead could
starve the stream without it; it is cheap when nothing came. Callers keep
values in t registers across it (png.S, sprite.S, xxh3.S).

## sound_wait

The poll timer is armed so a dead device cannot hold the halt, and cleared
after.

## sound_flush

Every voice goes to its release first, so a note the program left held ends;
then three waits, each ended early by a stall: until the ring is empty and
no voice sounds, the refills going on, for at most SOUND_FLUSH_TICKS; then
SOUND_DRAIN_PERIODS more returns past the periods then in flight, every
refill silence by then, so the host's own buffer has played the last
content before QEMU ends; then, the refills stopped, until every period has
come back, a stall there being the device keeping a period, after which the
exit goes on. With DEBUG the counts go to the debug channel.

## msg_sound_counts

`22 u8`: the debug line on the stream's counts, under DEBUG only.

## msg_sound_returned

`11 u8`: that line's returned field.

## msg_sound_failed

`9 u8`: that line's failed field.

## sound_control_queue

The control queue's record.

## sound_queue

The tx queue's record.

## sound_periods

The periods, each the stream id then its samples, PERIOD_STRIDE apart.

## sound_status

Each period's status record, written by the device.

## sound_request

`24 u8`: a control request.

## sound_response

`u32`: its status.

## sound_base

`addr`: the device's transport.

## sound_state

`u64`: 0 until opened, then sound_open's answer plus 1, and 3 once the
stream stalls or its source stuck (aia.S).

## sound_live

`u64`: 1 while the stream runs.

## sound_head

`u64`: the count of frames put in the ring.

## sound_tail

`u64`: the count taken from it.

## sound_ring

`16384 i16`: the frames queued, left then right.

## sound_accum

`1920 i32`: the mixer's accumulator.

## sound_busy

`8 u8`: 1 for each period in flight.

## sound_submitted

`u64`: the periods offered.

## sound_returned

`u64`: the periods returned.

## sound_failed

`u64`: the returns whose status was not OK.

## sound_last_return

`u64`: the time of the last return.

## msg_sound_stalled

`20 u8`: the line a stalled stream ends with on the UART.
