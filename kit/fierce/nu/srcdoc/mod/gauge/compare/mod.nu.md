# gauge/compare

## WORKSPACE

The workspace's root, the checkout this module lies in, from the module's own
file at parse time.

## HARTS

the harts of the one machine before named specs, 1KA1's three: a legacy
record of another count, marked diagnostic, is read as one of those

## PHASE_FIELDS

the drawing's parts whose meaning moved with the packets (compare): the
phases, holding their rendering before the packets and preparation
alone from them on; and the remainder, holding no rendering at schemas
1 and 3 and the raster in f59f7a7, the packet core before its record,
which writes schema 2 with its phases preparation alone

## TILE_FIELDS

the fields whose meaning moved with the tile pool at schema 5: below it
the tiles were built inside the plane and wall phases, a cell a frame
counted, in an arena; from it the pool's boundary is a part of its own,
its builds whole tiles, its bytes its slots'

## REFUSED

the standings a comparison refuses unless admitted as a diagnostic, and
those it refuses even then, holding nothing a comparison can read or
legs not the route's that played (unrouted); a run missing a leg is
refused unless admitted too, whatever its standing

## UNKNOWN_WORKERS

a run's workers and grain below schema 4 when its records cannot show
them (effective-workers), a build of its own

## main

Set builds' captures side by side: each run of each gauge.nuon a
measurement, a build an image on its kernel, none for an identity
recording no kernel, at the cadence its runs played
(effective-cadence) by the workers at the grain they played
(effective-workers) on the machine and the route their identities
record under their selection, automatic or forced, its runs its
batches, named by the label less a trailing _<n>, one name a build and
one build a name, so a label whose runs mix selections is refused as two
builds whatever they played; each run keeping its selection and the
cadence, the workers, and the grain its identity asked beside those it
played, all read through run-request with its identity's source,
binding, passes, and corrections named, and a build whose runs'
identities differ in its flags or its ELF refused; for each leg a value
of `field` a run, a leg
whose eye travels one bin or more taken per bin of its path over the
bins every run of its route reached, a shorter one over its frames, so
a leg's value is its path's and not its frame count's. Every run is
classified before any leg is measured (standing-of): one measured
incomplete, invalid, or unchecked, one that cannot be paired, or one on
a diagnostic machine or with QEMU words of its launch's own is refused
unless `diagnostic` admits it, and one empty, unclassified, or unusable
is refused even then, as is one unrouted, its identity's recorded route
missing, of another digest, or not naming every leg its rows hold
(route-of). A run's expected legs are its route's, or for a run whose
identity records none every leg any such compared run holds, and one
missing any is refused unless `diagnostic` admits it, its missing legs
then an explicit missing result in its run and in its build's row in
place of a value, never a mean over fewer batches, a leg no run reached
missing in its route's common entry too. The comparison fails with
every refused run's file, run, and reasons. Runs on more than one
machine, a recorded one or none, or on more than one route, are refused
unless `diagnostic` admits them, the routes then kept apart. A
comparison on a phase of the drawing or its remainder, whose meanings
moved with the packets, is refused, `diagnostic` or not, when its runs'
classes differ or any is unknown (parts-meaning), each run keeping its
classes. The method with the machines, the routes and their expected
legs, the bins, every run's standing, selection, cadences, machine,
route, expected and missing legs, and bins with their medians, and the
table, each row naming its build's selection, machine, and route, its
batches' standings, and the batches missing its leg, come back
together.

- each route's expected legs: the route's own, or for the runs whose
  identities record none every leg any of them holds
- a leg's kind and the bins every run reached, within its route's runs;
  a leg no run reached an explicit missing result

## standing-of

A run's standing in a comparison, from its measurement and its own
rows for the compared field: unclassified, its measurement recording no
clocked, true or false; empty, no rows; unusable, a value of the field
that is not a number or a leg holding no number in it; unpaired, a
build older than the clock records, read from its states alone;
incomplete, with the problems; unchecked, complete but measured before
the analyzer recorded validity; invalid, with the reasons; unpaired, a
run that cannot be paired with another (unpaired-reasons); diagnostic,
a run on a custom machine, its harts and RAM named, one whose legacy
record, from before named specs, marks it diagnostic, a hart count other
than the specification's three named, one whose machine was launched
with QEMU words of its own, or one whose identity carries such words,
the words named; or valid.

- `m`: the run's measurement as its gauge.nuon holds it
- `rows`: the run's rows
- `field`: the column compared
- `requested`: the cadence the run's identity asked for, null when it names none
- `asked`: the workers and grain its identity asked for, each null when it names
  none
- `machine`: the machine the run's identity records, null when it records none
- `overrides`: the QEMU words its identity records, null when it records none

## unpaired-reasons

Why a clocked run cannot be paired with another, none when it can: its
seed and cadence (cadence-unpaired), then its workers and grain
(workers-unpaired).

## cadence-unpaired

Why a clocked run's seed or cadence keeps it from pairing, none when
they do not: no seed answered before its first frame, or one answered
after it; below schema 2, an identity asking a cadence other than 0,
which a program writing schema 1 cannot play, the request read as the
identity holds it before effective-cadence puts 0 in its place; and
from schema 2, no cadence asked before its first frame, or one asked
after it, an identity asking no cadence from 0 to 2, or a frame at a
cadence other than the one asked. A measurement written before schema 2
was read is at schema 1.

## effective-cadence

The cadence a run played, the one a build is named by: the one its
identity asked from schema 2; below it 0, the one cadence a program
writing schema 1 or no clock records has, set only after
unpaired-reasons has held the request to it. A measurement written
before schema 2 was read is at schema 1.

## workers-unpaired

Why a clocked run's workers keep it from pairing, none when they do
not. Below schema 4 the records hold no workers: a run legacy-serial
holds to the serial backend pairs; an identity asking workers above 0
asks what such a capture cannot show; any other run's workers are
unknown, since 1a9986e drew with workers at schema 3 where every older
build drew with the serial backend, and the reasons say why: none asked,
no W 0 answered before the first frame, or a W after it. From schema 4
with workers asked, no W answered before the first frame, one answered
after it, or a frame drawn by other workers or at another grain than
asked; with none asked, a W answered after the first frame, or frames
drawn by more than one count of workers or at more than one grain.

## legacy-serial

Whether a run below schema 4 drew with the serial backend: W 0 asked,
answered before its first frame, and no W after it. An older build has
no other raster, and 1a9986e takes a W 0 to the serial backend.

## effective-workers

The workers and grain a run played, which a build is named by beside
its cadence: below schema 4 the serial backend, 0 workers at grain 0
whatever grain it asked, for a run legacy-serial holds to it, and
UNKNOWN_WORKERS for both otherwise, which workers-unpaired refuses and
--diagnostic admits as a build of its own; from schema 4 the one count
its frames were drawn by, the grain theirs above 0 workers and 0 at
none, each null where its frames hold more than one, which
workers-unpaired refuses.

## unusable-reasons

Why a run's rows give nothing to compare in `field`, read from the rows'
own values: a value that is not a number, and a leg holding no number
in it; none when they give something.

## leg-measure

A leg's frames reduced for a comparison: the eye's travel in metres,
and either its frames' median, standing, or its path cut into bins of
`bin_cm` with each bin's frames and their median.

## report

Set builds' captures side by side (compare), a build an image at a
cadence: every leg's value of `--field` a run, a build's mean and half
spread a leg, printed, marked with its runs' standings other than
valid; a run measured incomplete, invalid, or before validity was
recorded, one that cannot be paired, one missing a leg its route names,
or runs on more than one route, refused unless `--diagnostic` admits
it, and one with nothing to compare or unrouted refused even then, each
named with its file, its run, and the reasons; under `--diagnostic` a
leg some batch of a build is missing prints as missing in place of a
value; the method, the routes, the bins every run reached, each run's
standing, route, expected and missing legs, and bins with their
medians, and the table go to `--out`, a previous comparison there
retired.

- `...files`: the gauge.nuon files compared
- `--field`: the row's column compared
- `--bin-cm`: a walked leg's bin, in centimetres of its path
- `--out`: where the comparison lands, compare.nuon in the program's gauge shard
  of the target unless given
- `--diagnostic`: admit runs measured incomplete, invalid, unchecked, or
  unpaired, missing a leg, or on another route, marked
