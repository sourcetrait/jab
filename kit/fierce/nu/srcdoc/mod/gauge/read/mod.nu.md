# gauge/read

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

## read-run

The run record `read` writes for a reading (gauge identity read): the seed
its report recorded, else, for the run's own identity, read from its
file or embedded, that identity's, else null, never a report's one
identity's; the identity the run's own for a file or an embedded
reading, else null, a report's one identity or the placeholder its
report's identity alone; the corrections, hash, source, binding, passes,
and reports as read; the capture's directory, outcome, measurement, and
CPU windows.
