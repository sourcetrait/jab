# control.rs

A supervised launch's control files: JSON in the run's directory, each
named by the launch's token, `launch-<token>.<kind>.json`, so a caller
can name every one before the supervisor exists. Each is written whole:
a temporary name beside it, synced, renamed over it, the directory synced
after, so a reader sees no file or the whole of one and never a part.

## const SCHEDULE

## const READINESS

## const AUTHORIZATION

## const CANCEL

## const OUTCOME

## const RECEIPT

## fn token_ok

Sixteen lowercase hex digits, as the SDK writes a token (`nonce hex`),
none all zero.

## fn control_path

## fn write_whole

The temporary's name carries the writer's pid, so two writers never
share one.

## fn write_json

## fn read_json

A file not there is None; any other failure, or text that is no JSON of
the type, is an error naming the file.

## fn utc_now

The realtime clock as RFC 3339 UTC with microseconds, for dates and
provenance alone: no time of the run is ever taken from it.

## fn civil_of

The days-to-civil conversion of the proleptic Gregorian calendar, by
eras of 400 years, so no date library is needed.
