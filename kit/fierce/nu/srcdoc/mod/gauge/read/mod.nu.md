# gauge/read

## WORKSPACE

The workspace's root, the checkout this module lies in, whose revision a
reread names (identity repo-of).

## main

Read a capture, a run's api.out (read-capture).

- `api`: the capture
- `--route`: the route the capture played, for its legs
- `--out`: where gauge.nuon lands, beside the capture unless given
- `--label`: a name for the build in the summary

## read-capture

Read a capture, a run's api.out: under the identity it was launched
with (gauge identity read), through the reports it belongs to when there are
any, else its own identity.nuon with its correction applied, else what
the capture alone says, every directory passed over and every report
reconciled named, the reading from a report's one identity or no
evidence the report's identity and never the run's own (read-run); the
run.nuon its launch wrote beside it; the legs from `route`, else the
route kept beside the capture, else the one the identity names, refused
unless it is the route that played (gauge report legs-for), and one leg, play,
when no route is recorded; the report written in `out`, beside the capture
when empty.

## batch

A bench step's report made again from its kept runs, the batch reread
(RederivedChecks): `read-capture` reads one capture as its run 1, so a
step's streams read one by one rebuild neither the step nor its run
numbers. Each `run_<n>` under the step, in order, read by batch-run
under the step's label, the report's one identity its first run's as
`route` writes it, written by report's `write` with `--reread`, the
revision: this checkout's commit and state, the step it read, and when.
The kept inputs are each run's identity.nuon, run.nuon, api.out, and
route.nuon; the step's original gauge.nuon is never read, since the
retention keeps it as its SHA-256 alone (EvidenceRetention). A reread
reproduces the original's runs, seeds, frames, medians, legs, identity
hashes, and CPU windows where the readers agree, as 1KA1's preparation
auto_1 does exactly; its bytes differ by its paths and its revision by
design.

- `step`: a kept step's directory, its runs under it
- `--label`: the step's label, its directory's name unless given
- `--out`: where gauge.nuon lands, the step's directory unless given

## batch-run

One kept run read anew: its identity file with any correction sidecar
applied (identity corrected) and its raw SHA-256 the binding hash; its
legs from the route kept beside it, held to the identity's route
SHA-256 (report legs-for); its run.nuon the outcome; its stream
measured at the identity's cap; its CPU windows from the run record's
thread readings over the route's legs, none for a play or a run without
readings; its seed the identity's mode's.

## read-run

The run record `read` writes for a reading (gauge identity read): the seed
its report recorded, else, for the run's own identity, read from its
file or embedded, that identity's, else null, never a report's one
identity's; the identity the run's own for a file or an embedded
reading, else null, a report's one identity or the placeholder its
report's identity alone; the corrections, hash, source, binding, passes,
and reports as read; the capture's directory, outcome, measurement, and
CPU windows.
