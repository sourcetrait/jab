# sdl/pair

## workspace

The workspace the module ships in, four levels above its file, whose tool
workspace builds jabpair; a workbench importing the module from a sibling
checkout reaches jab's.

## pair_limits

The pairing's limits, printed with every reading (sdl pair): the binding
exact under its assumptions, the bracket a consistency check that cannot
prove the absence of compensating edits or reject every stream shift, the
host stamp's closed microsecond, stalls reported, walk's TIMING-off frame
bracket, the fit a diagnostic.

## main

A probed run's presents paired one for one with the host's flip uploads
(ProbeRuns, PairBracket), from the run's classified events, a validated
paired bundle's (sdl bundle-check) or `sdl classify`'s on the host with
the run's binding checked there, and the guest's flips in its window in
order, each its status, its present ordinal, and its call's bounds on the
guest's clock in ticks, `lo` and `hi`: schema 8's recorded final attempt,
or a schema-7 stream's bounds its reader derives and labels. A flip that
is no present (status 1, 255) is never read as a call.

The binding decides which upload is which present, as before: 1, the
presented flips' ordinals each one past the one before (present
ordinal-violations); 2, the uploads numbered from the log's first, 1 on;
3, the present of ordinal k paired with upload k, the log holding every
ordinal through the window's last present and going on at least 1 s past
it. Refused, each named and counted, all found: an ordinal gap; the log
short of an ordinal; a duplicated event; a stamp going backwards; a
device error in the window; the log ending under 1 s past the window's
last upload; fewer than two presents.

The bracket checks the binding's pairing on top (brackets, jabpair): over
`--drift-ppm` either way, 50 by default and frozen for the protocol,
whether one offset and one drift put every upload inside its call, the
host stamp read as the closed microsecond after it. Infeasible, it refuses
in one of two words (bracket-refusal): drift past the declared bound where
the wide range, a half to two, holds; else the clock model holding at no
drift, a pause, a real-clock step, or an upload outside its call, never a
slip. The same check over the stream shifted an upload each way: a
shifted pairing feasible too leaves the bracket unable to tell the shift,
the reading `ambiguous` and the binding deciding. The P/2 residual rule is
retired: a stall is one negative residual alone, which it could not tell
from a slip's first pair, so it refused honest runs.

The reading: `verdict`, admitted, ambiguous, or refused, `ok` unless
refused; the refusals; the bracket, its status, best drift and margin, the
feasible drifts with the offset's envelope, the wide range's, and the
presents binding it by ordinal; the shifts' statuses; the stalls, each
present whose call runs past the run's median call by more than
`--stall-ms`, 4.2 ms (P/4) by default, with its upload's place; the pairs,
each with its call in ms, its upload's earliest and latest place in the
call over the feasible set, and its residual from the fit; the fit, least
squares of the uploads on the calls' ends, a diagnostic and never a rule;
the window's ordinals; and the limits.

## micros

The host stamp as whole microseconds: the event's stamp text, the shim's
`<seconds>.<six digits>`, read exactly; an `sdl classify` event's float
seconds rounded, which recovers the logged microsecond, the double's error
at today's epoch about a tenth of one.

## brackets

## bracket-refusal

## fit-of
