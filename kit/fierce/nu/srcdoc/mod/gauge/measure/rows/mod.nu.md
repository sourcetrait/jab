# gauge/measure/rows

Every frame of the window as a row: its leg, its state, and its records'
columns, the columns of a record it lacks null.

## SPAN_RECORDS

the span records a frame holds before its spans go unrecorded

## rows-of

Every frame from 0 to `last` as one row: its leg (by the placements
answered before it), whether a placement opened it, its state, and
with the clock records its phases, the time it left unattributed, its
completion interval, its flip's end less the presented one's before,
its acceptance interval null for accepted to fill, and its latency from
its start, the drawing's parts, and the tile cache's counts; from
schema 2 its presentation too, the submission age from its simulation
to its presented flip's end and the residual its next start leaves past
its start, critical path, wait, and await; from schema 3 its packets,
the preparation, the raster, the commands, the flushes, the bindings
invalidated, the bytes, the snapshot, and what its drawing leaves past
its preparation and its raster, from schema 4 the workers, the grain,
and the rounds' slowest worker, busy time, dispatch, and barrier, from
schema 5 the tile record's columns, the storage record's, and the
configuration's in force, the last whose first frame is at or before
the row's, and at schema 6 the harts record's masks. Without the clock
records the clock's columns are null, the presentation's below schema 2
or without its record, the packets' below schema 3 or without theirs,
the workers' below schema 4, the pool's below schema 5 or without
theirs, and the masks below schema 6 or without theirs. A capture holding
service records, a SERVICE build's, gives every row the service columns,
the phase, the slots applied and rejected, the age, the depth, the quotas
skipped, and the flags, null for a frame without its record, and the time
left unattributed is the critical path less the phases and the service
phase, the service being a phase of its own (SceneOwnership); a capture
holding none gives its rows no service columns.

## receiptless

The receipt record's columns of a row below schema 7 or without its
record, all null, the call's bounds among them, which a row below schema
8 keeps null too.

## serviceless

The service record's columns of a row without its record on a capture
that holds some, all null.

## hartsless

The harts record's masks of a row below schema 6 or without its record,
all null.

## clockless

The clock's columns of a row with no clock records, all null, the
presentation's and the packets' among them.

## presentationless

The presentation's columns of a row below schema 2, all null.

## packetless

The packets' columns of a row below schema 3, all null, the workers'
among them.

## tileless

The tile record's columns of a row below schema 5 or without its
record, all null.

## storageless

The storage record's columns of a row below schema 5 or without its
record, all null.

## configless

The configuration's columns of a row below schema 5 or with none in
force, all null.
