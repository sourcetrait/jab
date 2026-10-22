# gauge/report

## WORKSPACE

The workspace's root, the checkout this module lies in, from the module's own
file at parse time.

## run-line

One line on a run: complete or not and why, valid or not and why, a
valid run's critical path at the median against the ceiling (`under`)
with its tail beside it, the schema, the critical path's spread, the
seed, the cadence from schema 2, the workers and grain from schema 4, a
program fault.

## outcome-line

One line on what a run played and on what: the rounds by what they
met, the androids' events, the times the player was struck, the
pickups, the window, and the audio backend's driver.

## service-line

One line on a run's service, a SERVICE build's
(gauge/measure/service's service-of): each window's frames, its handoff,
its offered count and rate, its
applied, dropped, rejected, and discarded, the quotas skipped, its apply
phase in microseconds, and its oldest applied message's age; a reduced
load named; held, or broken with its problems; a start refused with its
status; null for a capture without the service's records.

## contract-line

One line on a run's presentation contract at its eps (gauge measure
contract-of): K's violations, the first named by its frame and its
witness's with their gap and K's bound, the late wakes, and the
catch-ups; or not read, with the acceptance's reason. A line of its own
beside run-line, which other tools parse and which stays as it was.

## spread

A spread in milliseconds: least, median, 95th, 99th, greatest.

## ms

Microseconds as milliseconds to a tenth, or a dash for none.

## report-doc

A report's document: the label, the first run's identity as the
report's one, the ceiling, every run with its outcome, its measurement
less its rows, its effective identity and correction provenance, the
SHA-256 of its identity file as recorded, null where none is, and from
a read where the identity came from, its binding, the directories
passed over, and the reports read, its CPU windows, null without
readings, and an audio run's reading, null for any other, and every row
with its run. A report made again from kept runs
(read's batch) carries `reread`, the reader's revision, the step it read,
and when, so its bytes name their own analysis and the old report's
SHA-256 the old one.

## under-ceiling

A critical path's median under the ceiling, the rule a measurement's
`under`, a leg's line, and a bench's pool are judged by.

## against-ceiling

The ceiling's words for a critical path's median (gauge report under-ceiling).

## leg-text

A leg's line under a run as the report prints it: a capture with no
clock its drawing and game spreads; else its critical path's median
against the ceiling, its tail, the frames at or over the ceiling, beside
its frames, the fast frames, the critical path's spread, the medians of the
drawing, its parts, and the frame's phases, the tiles built, named
cells below schema 5 and tiles at it, with the frames building them,
the pixels tiled and lit by the fallback, the flips early and refused,
and the most unattributed.

## write

The report: every run's measurement and outcome under the identity
(report-doc), written as gauge.nuon in `out`, a previous one there
retired, its legs (leg-text) and its outliers printed; `--reread` the
revision of a report made again (report-doc).

## legs-for

The legs a capture's frames are assigned to, from the route that
played it: the route given, else the copy kept beside the capture,
else the file the identity names, and whichever it is must have the
SHA-256 the identity recorded, or the read stops naming both; its legs
come through `route read`, the route held to its model. A capture whose
identity records no route is one leg, play, unless a route is given,
which then goes unchecked.

## route-of

A compared run's route (RouteLegs): the SHA-256 its identity recorded,
held as legs-for holds it against the route.nuon beside the run's bound
identity file, else in the first of its run-dirs holding one, else the
file its identity names; its legs the route's names in order, read
through `route read`. A recorded route missing, of another digest,
breaking its model, or naming no legs is the run's problem, its file and
digests named; an identity recording no route has no digest and no
legs.

## route-text

A route as a comparison names it (compare's routes), in words: its
SHA-256 and a file holding it, or none recorded.

## machine-text

A machine as a run's identity records it, in words: its harts, then a
named spec's name and RAM, a custom machine's RAM and its standing,
diagnostic, or a legacy record, written before named specs, named so
with its standing as it marks it; -machine, the CPU, and the
accelerator; or unrecorded for an identity older than the record.
