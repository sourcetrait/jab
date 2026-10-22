# main.S

walk: a large busy sidewalk. The walker sprite, sixteen frames of a
walk cycle, loads off the romfs straight from its directory; then
eight horizontal lanes carry walkers, each entering from a random
side of the screen, in a random colour, at a random size from five
feet to seven if the frame is six, walking to the other side and
leaving. A lane holds up to a few walkers at once: when the side
chosen for a new one is clear, no walker in the lane within a stride
of that edge, one enters, at once for an empty lane and otherwise
after a random wait, so the crowd staggers. A walker entering from
the right is the same frames mirrored. The screen stays black, as
the framebuffer starts. Each frame the clock is read, and
everything moves by the time since the frame before, never by a
count of frames: every walker's last shape is cleared by drawing the
same frame solid in black, which touches its own pixels and not its
whole box, it is moved by its speed over that time and its animation
stepped by it, the area where it was and where it is noted as one
rectangle, then every one is drawn top lane to bottom so nearer
walkers cover farther ones, and the noted rectangles are flipped as
one, so the host copies and paints the walkers' own areas and not
the screen. Over the API, when a run has it, a record per walker
that enters and per walker that leaves, for the test.

Each frame works first and waits after: it clears, moves, and draws,
then waits for the tick every iteration, one with nothing noted too, and
flips the noted rectangles, waiting again if the flip comes back early.

CADENCE is the measurement build, a symbol as WHOLE is one, and a
release build carries none of it. Before the anchor the program reads
the capture nonce, the 16-byte WNON frame, from the API, and under
REPLAY the replay stream after it, by one bounded wait: exit 6 without
the frame, 5 without the stream. The seed is CADENCE_SEED, or the
stream's. Then ANCHOR_PERIODS waits with no flip, so the display's open,
present ordinal 1, and frame 0's first flip stand apart, and the origin,
the clock that every stamp counts from. Each frame of the window keeps
an F_SIZE record: its start, its flip call's end, the receipt the flip
answered or the last ordinal with none issued, the workload, and with
TIMING its wait, its work's end, and its call's start. The events go to
a buffer in place of their writes, so no write falls inside the window.
The window closes at a frame's end: at WINDOW_TICKS, or under REPLAY
after the stream's frames; at a full frame buffer; at too little event
room; at an offset past 2^32 ticks. TRAIL_PERIODS waits with no flip
follow it, then the export, then the exit. The loop takes the await order,
the wait at its head, or with PREPARE the ordinary build's, the work first
and one wait every iteration before the flip. CADENCE_TEST makes the build its own
fixture: a window of ten seconds, QUIET_FRAMES with no walker, the
stall frames, and the clamp frame. EVENT_ROOM, one of CADENCE_TEST's
variants, shrinks the event buffer to four past the headroom, so the
eight entries of the first frame that admits close the window by its
event room with nothing omitted.

## .set DISK

`u8`: the romfs disk's id.

## .set FRAME_W

`u32`: a walker frame's width in pixels.

## .set FRAME_H

`u32`: a walker frame's height in pixels.

## .set FRAMES

`u32`: the frames of the walk cycle.

## .set SPRITE_BYTES

`u64`: the sprite buffer jab.sys.sprite.load needs for the frames.

## .set LANES

`u64`: the lanes, top to bottom.

## .set LANE_H

`u64`: a lane's height in pixels.

## .set PER_LANE

`u64`: the most walkers a lane holds at once.

## .set SCALE_MIN

`u64`: the least a walker is drawn at, five feet, in 256ths.

A six-foot walker at a quarter of the frame is 160 pixels, so five feet to
seven is 53 to 75 in 256ths.

## .set SCALE_MAX

`u64`: the most a walker is drawn at, seven feet, in 256ths.

## .set STRIDE

`u64`: astra's stride, pixels of travel a walk cycle at the frame's own size.

A walker at the frame's own size covers the stride in a second, so a
walker's speed is the stride scaled to its size.

## .set ENTRY_GAP

`i64`: the pixels a new walker needs clear at its edge.

## .set ENTRY_WAIT

`u64`: the most a lane waits after an entry before another, four seconds in ticks.

## .set ANIM_TICKS

`u64`: the animation's step, sixteen frames a second in ticks.

## .set DT_MAX

`u64`: the most time one frame moves anybody, a tenth of a second in ticks.

A frame's time is held to a tenth of a second, so a stall moves nobody
further than that.

## .set BACKGROUND

`u32`: the screen's colour, black.

## .set W_X

`i64`: the left edge, in 256ths of a pixel.

## .set W_DIR

`i64`: 1 walking right, -1 walking left.

## .set W_SCALE

`u64`: the scale in 256ths.

## .set W_TINT

`u64`: the colour, 0x00RRGGBB.

## .set W_FRAME

`u64`: the animation's frame.

## .set W_TICK

`u64`: the animation's time since its last frame.

## .set W_DW

`u64`: the drawn width.

## .set W_DH

`u64`: the drawn height.

## .set W_Y

`i64`: the top, the feet on the lane's floor.

## .set W_ACTIVE

`u64`: 1 while the place holds a walker.

## .set W_SPEED

`u64`: 256ths of a pixel a second.

## .set W_SIZE

`u64`: a walker record's bytes.

## .set LANE_WAIT

`i64`: the ticks until the lane may take another, after its walkers.

## .set LANE_SIZE

`u64`: a lane's bytes.

## .set R_KIND

`u8`: 1 a walker entered, 2 one left.

## .set R_LANE

`u8`: the lane.

## .set R_SIDE

`u8`: the side it entered from, 0 the left, 0 for a leaving.

## .set R_SCALE

`u8`: its scale in 256ths, 0 for a leaving.

## .set R_TINT

`u32`: its colour, 0 for a leaving.

## .set R_SIZE

`u64`: an API record's bytes.

## .set CADENCE_SEED

`u64`: CADENCE's one generator state at the start, in place of the clock.

## .set REPLAY_WAIT

`u64`: the bounded wait's length, ten seconds in ticks, for the nonce frame and REPLAY's stream together.

## .set ANCHOR_PERIODS

`u64`: the waits with no flip between the display's open and frame 0.

## .set TRAIL_PERIODS

`u64`: the waits with no flip after the window, a second and a half, so the
host's log runs at least the pairing's second past the window's last upload:
the trail counts from that flip's tick, its upload lands inside its call
after the acceptance, and the shim logs an idle window every 30 ms, so sixty
waits left a probed run's log 0.995 s past it.

## .set WINDOW_TICKS

`u64`: the measurement window from the origin, 120 seconds in ticks, 10 under CADENCE_TEST.

## .set WINDOW_FIELD

`u32`: the header's window, WINDOW_TICKS, or 0 under REPLAY, whose window is its stream's frames.

## .set CADENCE_FRAMES

`u64`: the frame records the buffer holds, 120 seconds at sixty with room for catch-up flips; a replay stream's most frames too.

## .set EVENTS_MAX

`u64`: the event records the buffer holds, 4096, or under EVENT_ROOM four past EVENT_HEADROOM.

## .set EVENT_HEADROOM

`u64`: the most events a frame adds, eight lanes of three walkers each leaving and entering once.

## .set EXPORT_CHUNK

`u64`: the most bytes of one export write.

## .set SCHEMA

`u32`: the frame record's and the export's schema, 4.

## .set MAGIC

`u32`: the export's magic, WCAD as a le32.

## .set NONCE_MAGIC

`u32`: the nonce frame's magic, WNON as a le32.

## .set REPLAY_MAGIC

`u32`: the replay stream's magic, WRPL as a le32.

## .set QUIET_FRAMES

`u64`: under CADENCE_TEST, the first frames, admitting no walker, so none flips.

## .set STALL_FIRST

`u64`: under CADENCE_TEST, the stall's first frame.

## .set STALL_LAST

`u64`: under CADENCE_TEST, the stall's last frame.

## .set STALL_TICKS

`u64`: under CADENCE_TEST, the stall frames' work, 25 ms in ticks.

## .set CLAMP_FRAME

`u64`: under CADENCE_TEST, the frame whose work makes the next one's elapsed pass DT_MAX.

## .set CLAMP_TICKS

`u64`: under CADENCE_TEST, the clamp frame's work, 150 ms in ticks.

## .set FLAG_BITS

`u32`: the build's flags in the header: TIMING 1, REPLAY 2, PREPARE 4, CADENCE_TEST 8, EVENT_ROOM 16.

## .set F_KIND

`u8`: a frame record's kind, 1.

## .set F_ISSUED

`u8`: 1 when the frame issued a flip, 0 when its list was empty.

## .set F_STATUS

`u8`: the final flip's status, 0 to 4, NO_STATUS with none issued.

## .set F_WALKERS

`u8`: the walkers drawn.

## .set F_FRAME

`u32`: the frame's number from 0.

## .set F_START

`u32`: the frame's start, elapsed's clock, in ticks from the origin.

## .set F_CALL_END

`u32`: the flip call's end in ticks from the origin, taken at the skip with none issued.

## .set F_WAIT_START

`u32`: under TIMING, the wait's start in ticks from the origin; 0 without it.

## .set F_WAIT_END

`u32`: under TIMING, the wait's end, the last wait's after an early refusal; 0 without it.

## .set F_WORK_END

`u32`: under TIMING, the work's end, the drawing's; 0 without it.

## .set F_CALL_START

`u32`: under TIMING, the flip call's start, at the skip with none issued; 0 without it.

## .set F_RAW

`u32`: the ticks elapsed measured before DT_MAX holds them, saturating.

## .set F_DT

`u32`: the dt the animation integrated, under REPLAY the stream's.

## .set F_RECTS

`u16`: the rectangles in the list.

## .set F_ENTERS

`u8`: the walkers that entered this frame.

## .set F_LEAVES

`u8`: the walkers that left this frame.

## .set F_RECT_AREA

`u32`: the rectangles' summed area.

## .set F_S

`u64`: the receipt's acceptance, its rdtime unconverted; 0 with none issued.

## .set F_T

`u64`: the receipt's eligibility tick, unconverted; 0 with none issued.

## .set F_ORDINAL

`u32`: the receipt's present ordinal, or the last the program knows with none issued.

## .set F_DRAWN

`u32`: the walkers' drawn area, DW by DH summed.

## .set F_WAITED

`u8`: 1 when the frame made its presentation wait, which every frame makes.

## .set F_SCHEMA

`u32`: the record's schema, 4.

## .set F_SIZE

`u64`: a frame record's bytes.

## .set H_KIND

`u8`: the header's kind, 4.

## .set H_ENDED

`u8`: what ended the window, an ENDED_* value.

## .set H_ANCHORS

`u16`: ANCHOR_PERIODS.

## .set H_MAGIC

`u32`: MAGIC.

## .set H_SCHEMA

`u32`: SCHEMA.

## .set H_FRAMES

`u32`: the frame records that follow.

## .set H_EVENTS

`u32`: the event records that follow them.

## .set H_RATE

`u32`: the clock's ticks a second.

## .set H_SEED

`u64`: the generator's state at the start.

## .set H_WINDOW

`u32`: WINDOW_FIELD.

## .set H_FRAME_SIZE

`u16`: F_SIZE.

## .set H_EVENT_SIZE

`u16`: R_SIZE.

## .set H_FLAGS

`u32`: FLAG_BITS.

## .set H_TRAIL

`u16`: TRAIL_PERIODS.

## .set H_HEADER_SIZE

`u16`: H_SIZE.

## .set H_ORIGIN

`u64`: the origin, an absolute rdtime.

## .set H_OPENED

`u64`: the display open's end, an absolute rdtime, before the waits and the anchor.

## .set H_NONCE

`u64`: the capture nonce WNON carried, never 0.

## .set H_SIZE

`u64`: the header's bytes, the last eight zero.

## .set E_KIND

`u8`: the end record's kind, 5.

## .set E_MAGIC

`u32`: MAGIC.

## .set E_SCHEMA

`u32`: SCHEMA.

## .set E_FRAMES

`u32`: the header's frames.

## .set E_EVENTS

`u32`: the header's events.

## .set E_CRC

`u32`: the CRC-32 of every byte from the header's first through the last event record's.

## .set E_OMITTED

`u32`: the events past the buffer, never written.

## .set E_SIZE

`u64`: the end record's bytes, past E_OMITTED zero.

## .set N_MAGIC

`u32`: the nonce frame's NONCE_MAGIC.

## .set N_ZERO

`u32`: the nonce frame's zero word.

## .set N_NONCE

`u64`: the nonce frame's nonce.

## .set N_SIZE

`u64`: the nonce frame's bytes.

## .set RP_MAGIC

`u32`: the replay stream header's REPLAY_MAGIC.

## .set RP_SCHEMA

`u32`: its schema, 1.

## .set RP_FRAMES

`u32`: its dt values that follow, 1 to CADENCE_FRAMES.

## .set RP_SEED

`u64`: the reference run's seed.

## .set RP_SIZE

`u64`: the stream header's bytes, the reference record's SHA-256 at 32.

## .set ENDED_DURATION

`u8`: the window reached WINDOW_TICKS.

## .set ENDED_FRAMES

`u8`: the frame buffer filled.

## .set ENDED_EVENTS

`u8`: fewer than EVENT_HEADROOM event slots remained.

## .set ENDED_REPLAY

`u8`: REPLAY's stream's frames were all taken.

## .set ENDED_RANGE

`u8`: an offset reached 2^32 ticks.

## .set NO_STATUS

`u8`: F_STATUS with no flip issued.

## _start

The seed, never zero, is the clock with its low bit set, and the clock is
noted for the first frame's time. Under CADENCE the display open's end goes
into the header and cadence_setup sets the seed, the origin, and the first
frame's time instead.

## frame

Every lane in turn: its walkers moved along, and one in when there is room.
For each walker, the shape it drew last tick is cleared: the same frame,
place, size, and pose, drawn solid in the background's colour, which touches
its own pixels and not its whole box. It moves by its speed over the frame's
time, and the animation steps when its own time has come. The area that
changed, where it was and where it is, is noted as one rectangle. Off the far
side, the place is free and the host is told.

Then every walker is drawn, top lane first, and the changed areas go as one
flip; with WHOLE set, the whole screen instead, for measuring the difference.
A frame with nothing noted flips nothing.

Under CADENCE the frame's record is made ready first, the wait is stamped
where its order puts it, the frame's start follows elapsed, and
frame_present ends the frame; the loop goes on until a window's end holds,
then to trail. The phases in the await order: the wait's start, its end, the
frame's start, the work's end, the call's start, its end; with PREPARE: the
frame's start, the work's end, the wait's start, its end, the call's start,
its end. The drawing is the work's end less the frame's start in both.
Under CADENCE_TEST the quiet frames call no admit.

## present

Without CADENCE: the frame's one wait, then its flip from the
rectangles noted, or WHOLE's whole flip; the image stays as drawn across a
second wait after an early answer.

## bad_sprite

The code, one or two digits, is written after the message.

## admit

First a free place, and whether the lane is empty; an empty lane waits for
nothing. Then the side, and the edge must be clear: no walker within the gap
of it. In it comes, and the lane's wait starts again.

## enter

Its colour has every channel bright enough to see, 64 to 255.

## cadence_setup

One deadline for every bounded wait: each pass reads the API without
waiting, checks the clock against it, then waits for the display or the API,
so the display's tick wakes the hart at least once a period whatever the API
does; a wait on the API alone arms no timer. Under REPLAY the stream's
header is held to its magic, its schema, and 1 to CADENCE_FRAMES frames
before its dt values are read.

## api_fill

A read takes what has come, at most what is still wanted, and a partial
frame stays in hand for the next pass.

## frame_present

The receipt is kept in s7 to s10 across the stamp after the call. Under
PREPARE an early refusal, which the loop cannot meet since nothing moves the
tick between the fired wait and the flip, is waited again and the same image
flipped again, the call re-stamped and the last wait's end kept; a status of
2 to 4 is recorded as it came. With no rectangle the skip's one clock is the
call's start and its end.

## frame_end

The window closes at a frame's end, never inside one: the checks run after
the record is whole, an offset's range first, so a replay that also ran its
frames out at that frame still reads as ended by its range.

## export

The CRC runs over the three spans in order with one state. No write is
retried; api_out exits at the first failure, so the reader finds no end
record and the exit names the failure.

## path_walker

`8 u8`: the romfs directory holding the walker's frames.

## msg_no_display

`18 u8`: the line for a machine with no display.

## msg_no_nonce

`43 u8`: the line for a nonce frame that never came whole.

## msg_bad_nonce

`36 u8`: the line for a nonce frame with the wrong magic, a nonzero word, or a nonce of 0.

## msg_no_replay

`45 u8`: the line for a replay stream that never came whole.

## msg_bad_replay

`47 u8`: the line for a replay stream whose header is not one.

## msg_bad_sprite

`38 u8`: the line for a walker that would not load, its code following.

## msg_bad_sprite_code

`4 u8`: the code's digits, a newline, and the terminator, written by bad_sprite.

## seed

`u64`: the random sequence's state, never zero.

## last_time

`u64`: the clock at the frame before, in ticks.

## dt

`u64`: the frame's time in ticks, at most DT_MAX.

## record

`8 u8`: the API record being sent.

## rect_count

`u64`: the rectangles noted this frame.

## rects

`96 u32`: the rectangles to flip, one a walker at most.

## lanes

`272 u64`: the lanes' walker records and waits.

## origin

`u64`: the clock after the anchor, every stamp's zero.

## raw_elapsed

`u64`: the frame's elapsed ticks before DT_MAX holds them.

## last_ordinal

`u64`: the last present ordinal the program knows, 1 from the display's open, then each flip's.

## range_hit

`u64`: 1 once a stamp reached 2^32 ticks from the origin.

## ended_by

`u64`: what closed the window, an ENDED_* value.

## event_count

`u64`: the event records in the buffer.

## event_omitted

`u64`: the event records past the buffer, not written.

## frame_enters

`u64`: the frame's walkers entered.

## frame_leaves

`u64`: the frame's walkers left.

## frame_walkers

`u64`: the frame's walkers drawn.

## frame_drawn

`u64`: the frame's drawn area.

## frame_rect_area

`u64`: the frame's rectangles' area.

## nonce_frame

`16 u8`: the nonce frame as it came.

## header

`80 u8`: the export's header.

## end_record

`64 u8`: the export's end record.

## frames

`655360 u8`: the frame records, CADENCE_FRAMES of F_SIZE.

## events

`32768 u8`: the event records, EVENTS_MAX of R_SIZE, 416 under EVENT_ROOM.

## replay_head

`64 u8`: under REPLAY, the stream's header.

## replay_dts

`8192 u32`: under REPLAY, the stream's dt values, one a frame.

## sprite

`19701776 u8`: the walker sprite.
