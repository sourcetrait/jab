# gauge/measure/receipt

The receipt stage from schema 7: what makes a window invalid in its
receipts and its recorded calls' bounds, whether the acceptance intervals
stand and what they are, the presentation contract read at eps, the wake
delays, and the presents in order with their calls' bounds.

## TICKS_PER_US

the guest clock's ticks a microsecond, its 10 MHz, the unit of a
receipt's acceptance stamps; an acceptance interval keeps the tenth of a
microsecond

## US_TICKS

the program's own US_TICKS, the same ten as an integer, which a
microsecond field multiplies back to ticks for bounds kept exact

## HZ

the guest clock's ticks a second, its 10 MHz; a period in ticks is it
over the cap, 166,666 at 60, the kernel's TICK

## flips

A measurement's presents in order with each one's call bounds in ticks on
the guest's clock, the flips `sdl pair` takes (PairBracket): the load's
two, the title and the cleared screen, then every frame, each its status,
its present ordinal, `lo` and `hi`, and `bound`, what the bounds are.

At schema 8 they are recorded: the load's calls from the bounds record,
each attempted frame's final attempt from its receipt, the origin the
bounds record's.

At schema 7 they are derived. The origin, the program's start (s11), is
written to no record there, and every end and every call's length is a
microsecond count truncated from ticks, so a field f stands for ticks
10 f to 10 f + 9 past the origin. The origin is the interval every receipt
the run records admits, each decision stamp inside its call: the title's
call lies after the origin, read before the display opens, and ends by its
end's 10 E + 9; the cleared screen's lies after the title's end; and an
attempted frame's, presented or refused, ends by its end's 10 F + 9 and
starts no earlier than that end less 10 D + 9, D every attempt's call. The
interval is kept whole, its width the uncertainty of where on the guest's
clock the bounds lie, and an empty one is refused as receipts admitting no
common origin, the two presents binding it named. The bounds sit on its
least value, a common shift the bracket's free offset absorbs, so they are
widened by the truncation alone: a single attempt's call `derived`, its end
less its call; a retried frame's `outer`, its end less every attempt's
call, which holds the final attempt with the awaits between; the title's
`outer`, from the origin, since the display's open before it records no
end; the cleared screen's `outer`, from the title's end.

A frame that made no attempt carries no call, `none` with 0 and 0. Refused
with its reason and no presents: a schema below 7, or a capture whose
present sequence is not whole (acceptance-of).

## receipt-invalidity

What makes a complete window at schema 7 invalid in its receipts, the
receipt stage (ProbeRuns), past the cadence's status, attempt, and
refusal rules from schema 2, which stand: a frame without its receipt
record; the present sequence broken (jab ordinal-violations) from
`anchor`, the load record's cleared screen's ordinal, over every frame, a
presented one, status 0, one past the last and every other the last, so
frame 0's first present reads the anchor plus one; a presented frame
whose first attempt's ordinal is not its own where it presented at once,
its one attempt, nor the last before it where a refusal came first; and
a presented frame whose decision's stamp comes before its eligibility
tick. Each broken sequence a present the records do not hold. With no
anchor, no load record before the frames, the sequence is named
unanchored and read no further; the window's completeness refuses such
a capture first.

## bracket-invalidity

What makes a complete window at schema 8 invalid in its recorded calls'
bounds, at the receipt stage beside receipt-invalidity (PairBracket): the
load's bounds record missing; the origin after any call's start; the
load's calls out of order, the title's start at or before its end, its
end before the cleared screen's start, that at or before its end; a load
decision outside its call; an attempted frame's decision outside its
final attempt's call, its start at or before the stamp and the stamp at
or before its end; and a frame that made no attempt carrying a call's
bounds. A schema 7 window is read under its own rules, never with these.

## acceptance-of

Whether a measurement's acceptance intervals stand (AcceptanceInterval):
only at schema 7 or later, the capture complete and its receipt stage
passed; else unavailable, its reason the schema carrying no receipt, the
present sequence not whole, or the receipt sequence invalid. An
unavailable acceptance leaves every row's `acceptance_interval_us` null,
never filled from the completions, so a comparison on it refuses the run
as holding no number in the field.

## accepted

Each presented frame's `acceptance_interval_us`: its receipt's
acceptance stamp less the present's before it, the first frame's from
the load record's cleared screen, consecutive by their present ordinals,
in microseconds to the tenth. A frame that refused its flip or made none
adds no present and breaks no adjacency: its field stays null and the
interval across it lands on the next present.

## contract-of

The presentation contract read on a measurement's receipts at eps
(JointTiming), only where the acceptance stands, so on a present sequence
the receipt stage passed: its eps, the period in ticks (HZ over the cap),
`available` and `reason` as acceptance-of gives them, and then:

- `k_violations`: K's violations over the presented frames' acceptances
  in order (jab's `present k-violations`), every later flip short of K
  against the running maximum counted, so on a kernel that kept the tick
  on its grid after a late flip, as kernels before the frame rule's
  FRAME_EPS did, that late flip is the witness of every on-grid flip after
  it; `k_first` the first eight, each with its frame and its witness's
  frame
- `late_wakes`: the wake delays at or past eps (wake-delays), the flips
  the frame rule re-anchors
- `catch_ups`: the presented frames accepted under half a period after
  the present before them, by their acceptance intervals; K at eps under
  half a period admits none, so any is a grid-keeping kernel's catch-up,
  a flip let through soon after a late one

Unavailable, the three are null and `k_first` empty. The bench's own
`catch_up` (gauge bench) is another count: presenting calls' intervals
under half a period after a frame past the period, read from the calls'
starts, never from the receipts.

## wake-delays

A measurement's wake delays, s less T in ticks: its frames at
CADENCE_IF_EARLY that waited and presented, each its receipt's
acceptance less the tick it was judged against. The population eps is
calibrated from (jab-stress's timing selector) and the late wakes count
in; frames that never waited are left out, their s less T lateness
rather than a wake.
