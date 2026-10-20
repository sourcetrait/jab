# service.S

SceneOwnership's service boundary and its synthetic service, a SERVICE
build's alone: a producer on a claimed io hart publishes bounded messages
into a ring that hart 0 consumes at the simulation boundary, the boundary
every service crosses, NetworkService's among them. Hart 0 owns the game
state. The producer touches the ring's slots, its own line, its mailbox's own
words, its result block, and its own corrupted list, nothing else; it makes
no call hart 0 serves, so hart 0's join under LOCKSTEP cannot deadlock
(JoinDeadlock's rule).

The ring's order, the argument the fixture's order check holds the source to
(RVWMO's release and acquire, `isa/v20260120/unpriv/a-st-ext.md` and the
memory model's explanatory appendix):

- W, the write index, lives on the producer's line and only the producer
  stores it; R, the read index, lives on hart 0's line and only hart 0 stores
  it. Both are u64 counting from 0, a message's slot its index modulo
  MSG_SLOTS; the ring is empty when W equals R and full when W less R is
  MSG_SLOTS.
- Publication: the producer writes a slot, then `fence rw, w`, then stores
  W + 1; hart 0 loads W, then `fence r, rw`, before reading any slot below
  it, so the slot's contents reach hart 0 whole.
- Return: hart 0 reads the slots it consumes, then `fence rw, w`, then
  stores R; the producer loads R, then `fence r, rw`, before writing a slot,
  so its overwrite follows hart 0's reads of the old contents.
- A start's zeroed indexes and counts are hart 0's stores before the
  producer exists, each index store after its fence for the check's one
  form; the kernel's start orders them before the producer's first
  instruction (its `fence w, w` before STARTING, the worker's swap acquiring
  it).
- TCG runs every FENCE as one full barrier on this host, so no run shows
  the reordering a missing fence would allow; the order check proves each
  fence sits beside its index access, nothing but address and value work
  between, and claims nothing more.

A full ring drops the message and counts it, the producer never waiting on
hart 0; hart 0 never waits on the producer inside a frame but under the
LOCKSTEP fixture knob.

The pacing is jab_jobs.inc's mailbox, its generation protocol taken whole:
at each boundary after applying, a free mailbox gets the frame's quota in its
arguments and the producer's hart a wake; a busy one counts the quota
skipped. The producer offers the quota a message at a time, reading its
cancel before each, then completes with OK or CANCELLED and the count offered
in its own words.

The stop, at a mode transition between frames: the quota in flight
cancelled, then the kernel's bounded `jab.sys.worker.stop`. A producer in its
await answers the stop by writing its evidence, a fence, and its ready word,
then exits; one still offering takes the cancel at its next message and gets
there too. One that does neither within WORK_STOP_TICKS is forced at its next
trap boundary and writes nothing. After the stop returns, which acquires the
exit's release, the ready word set and nothing interrupted is a valid
handoff, the ring drained through the application path; else the stop was
forced and what the ring holds is discarded, the window incomplete. Only then
does the claim go back to the raster.

A message, MSG_BYTES: its sequence, every offer numbered, dropped ones
included; the window's generation; its production time, `rdtime`, one clock
across harts; a payload of MSG_PAYLOAD_WORDS words, the sequence plus the
word's index times SERVICE_GOLDEN; and its checksum, FNV-1a's fold over the
seven words before it.

The chains, each folded as its messages pass: the producer's published chain
over every message it publishes as built, its expected chain over those the
corruption knob left untouched, and hart 0's applied chain over each message
it applies, in application order. After a valid handoff's drain the applied
chain equals the expected one; the published chain stays the producer's
evidence of everything it put in the ring.

## service_frame

The record's counts are filled before the next quota is paced, so under
LOCKSTEP, the quota joined and the producer idle, the offered and dropped
counts and the depth are the boundary's exactly; outside it they are the
producer's counts as they stood, a reading and never a prediction. The phase
holds the join, the application, the fill, and the pacing.

## service_apply

A slot whose checksum fails is consumed and counted rejected, its sequence
read from it for the rejection's record, and is never applied: the word, the
chain, and the gaps move only on an applied message. The gap before an
applied message is its sequence less the sequence after the last applied, so
the leading gap and those between sum as the window goes; a rejected
message's sequence lies inside the next gap. The first applied message is the
frame's oldest, the ring being first in, first out.

## service_pace

The schedule moves a frame whether its quota is published or skipped, so a
skipped quota's messages are never offered and a run with any is a reduced
load, reported at its actual offered rate.

## service_start

The take is gfx_take's, the program's one claim, so an H frame's claim
standing refuses the service (GFX_STANDING) and on three harts the floor
refuses it (GFX_FLOOR) with nothing stopped or claimed.

## service_stop

The stop's drain has no per-frame limit: MSG_SLOTS covers what a ring can
hold.

## service_end

On a forced stop the producer's counts are those it last stored, its last
sequence and its chains unknown: the window is incomplete and the reader
holds no conservation over it.

## service_producer

The hold knob spins before each message after reading its cancel, so a stop
landing in a long spin takes the force, and a short spin a message lets a
cancel land mid-quota.

## service_offer

A corrupted message is folded into the published chain as built and kept
out of the expected one, then a payload byte is changed in its slot before
W publishes it, so hart 0's checksum check rejects it.

## service_line_w

`3 u64`: the producer's line, 64 bytes: W at LINE_INDEX, the messages
offered at LINE_COUNT, and those dropped at LINE_LOSS.

## service_line_r

`3 u64`: hart 0's line, 64 bytes: R at LINE_INDEX, the messages applied at
LINE_COUNT, and those rejected at LINE_LOSS.

## service_mailbox

`JAB_JOB_BYTES u8`: the producer's mailbox, the quota in its arguments
(SERVICE_QUOTA) and the count it offered in its own words
(SERVICE_JOB_OFFERED).

## service_result

`8 u64`: the producer's final evidence, written at its stop: the ready word,
the offered and dropped counts, the last sequence offered, the published and
expected chains, the corrupted sequence, and the corrupted count.

## service_header

`3 u64`: the window's generation, and a debug build's corrupted sequence and
hold ticks, hart 0's before each start, read once by the producer.

## service_ring

`MSG_SLOTS*MSG_BYTES u8`: the ring's slots.

## service_record

`REPORT_SIZE u8`: the frame's REPORT_SERVICE record as the boundary, a start
or stop, the snapshot, and the round's witness leave it, copied whole into
the frame's ninth record.

## service_end_records

`2*REPORT_SIZE u8`: a closed window's REPORT_SERVICE_END and
REPORT_SERVICE_EVIDENCE records.

## reject_record

`REPORT_SIZE u8`: a rejected message's REPORT_SERVICE_REJECT record.

## service_word

`u64`: the game state's service word, the last applied sequence,
SERVICE_NONE before any.

## service_read

`u64`: hart 0's own copy of R.

## service_next

`u64`: the sequence after the last applied, 0 before any.

## service_gaps

`u64`: the sequences' gaps summed so far, the leading one and those between
applied messages.

## service_chain

`u64`: hart 0's applied chain.

## service_skipped

`u64`: the quotas skipped in the window.

## service_harts

`u64`: the producer's hart's mask, 0 until a producer starts.

## service_frame_at

`u64`: the frame the boundary ran in, the frame a start's, a stop's, and a
rejection's records name.

## service_schedule

`3 u64`: the V frame's total and quota frames, and the frames paced so far.

## producer_corrupted

`2 u64`: the producer's corrupted sequence and count, its own until its
evidence.

## service_state

`u32`: SERVICE_ON while a window runs.

## service_lockstep

`u8`: a debug build's LOCKSTEP, from the V frame's byte 5.

## service_stack

`WORKER_STACK u8`: the producer's stack.
