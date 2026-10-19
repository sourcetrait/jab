# snapshot.S

The presented frames' snapshots, a debug build's instrument under SNAPSHOTS,
set on a LEVELS build and on a debug OWNER build (render.inc), for
FootprintEstimate's reference (SpanEndpoint, JudgedPopulation). Each frame's
snapshot holds its span table, x0, x1, and row of every span its one packet
drew, on a LEVELS build alone, and every actor it drew, as sprite_draw drew
it: the actor's index and the scratch entity's feet, yaw, size, material,
and flags. A ring holds the last SNAPSHOT_RING frames presented, and the
console's X writes every held frame to the API, the oldest first, as span
records, actor records, and an end record carrying the table's CRC-32; the
reader takes the frame the screen's stamp binds.

A ring rather than one snapshot: under cadence 1 the next frame starts the
moment a flip presents, so a frame is already drawing when the screen is
taken, and the X, sent once the screen's file is whole, is read at the start
of a frame at least two past the screen's; one snapshot of the frame last
presented would never be the screen's. The ring is buffer indices over
SNAPSHOT_RING + 1 buffers, the spare one the frame in hand's, so a present
swaps an index and copies nothing.

The frame loop opens the frame's snapshot before its drawing
(snapshot_begin), packet_render copies its packet's spans before emptying it
(snapshot_spans), actors_draw records each actor it drew (snapshot_actor),
and after the flip a presented frame takes the oldest slot
(snapshot_present). A frame drawn from more than one packet keeps its last
packet's spans and a sequence past 0, which the reader refuses, a LEVELS
frame being drawn from one packet.

## .macro snapshot_of

## snapshots_init

The CRC table is CRC-32's by the reflected polynomial 0xEDB88320, eight
shifts a byte value, the table-driven form walk's crc32 computes bitwise.

## snapshot_begin

## snapshot_spans

The span record's own row, x0, and x1, as packet_render and band_render pass
them to span_fill; the index is the entry's place.

## snapshot_actor

The entry is written only while the snapshot has room, MAX_ACTORS, every
actor; the index is the actor's place in actors, the one actors_draw adds to
SURFACE_ACTORS for the OWNER surface.

## snapshot_present

## snapshot_export

## snapshot_write

Each record is cleared first, so a span record's entries past the count and
every unused field read zero; the CRC covers the count's entries, the bytes
the reader reassembles. One write a snapshot from snapshot_stage, the API
taking a whole buffer as one descriptor; sixteen LEVELS snapshots of some
40,000 spans each are about 5 MB.

## record_clear

## crc32

## snapshots

`(SNAPSHOT_RING + 1) * SNAPSHOT_SIZE u8`: the buffers, about 6.7 MB on a
LEVELS build.

## snapshot_stage

`SNAPSHOT_STAGE * REPORT_SIZE u8`: one snapshot's records.

## snapshot_ring

`SNAPSHOT_RING u32`: each slot's buffer, the oldest at snapshot_head.

## crc_table

`256 u32`: CRC-32's table.

## snapshot_drawn

`u32`: the buffer the frame in hand fills.

## snapshot_head

`u32`: the oldest slot, the next a presented frame takes.
