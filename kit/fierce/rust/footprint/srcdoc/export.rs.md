# export.rs

SpanEndpoint's and JudgedPopulation's export as the program writes it under
the console's X (`snapshot.S`): for each presented frame its ring holds,
oldest first, the span records (kind 23: the frame at 4, the first entry's
index at 8, eight entries of x0, x1, and row, a u16 each, from 12), the
actor records (kind 25: the frame, then the actor's index and the scratch
entity's fields as sprite_draw drew them, from 8), and the end (kind 24:
the frame, the packet's sequence at 8, the span count at 12, the table's
CRC-32 at 16, the actor count at 20); every record 64 bytes, the schema at
60.

## const RECORD

## const KIND_SPANS

## const KIND_SNAPSHOT_END

## const KIND_ACTOR

## const SPANS_A_RECORD

## const SPAN_ENTRY

## struct SpanEnd

`x1` is the pixel past the span's last, the packet's own span record's.

## struct Snapshot

## fn crc32

The program's crc32 is table-driven over the same reflected polynomial,
0xEDB88320, initial and final all ones; this bitwise form is the same
function, and walk's reader's `cksum -a crc32b` too.

## fn word_at

## fn half_at

## fn single_at

## fn actor_of

The entity sprite_draw received for the actor: its feet, its yaw in
degrees, its width and height, its material, frame_base plus the frame's
index, and its flags, so the reference lays the actor's quad by the
sprite's rule from the frame's own attributes.

## fn snapshots

Every record of the export's kinds read in order: a snapshot's records run
unbroken to its end, its span records' first indices follow each other by
eight, the entries received fill the records its count needs, the last
record's tail padding, and the CRC-32 over the count's entries and the
actor count match the end's; anything else refuses the export, naming the
frame.

## fn snapshot_of

The table binds only when its frame is the screen's. The launch takes the
screen, then sends X once the screen's file is whole, polled every 50 ms,
and the frames go on presenting until the X is read, so the program keeps
its last sixteen presented frames, about 267 ms, and the screen's is taken
from among them; none is a refusal and the capture is made again. A frame
drawn from one packet holds sequence 0; each span's x0 at most its x1 and
its row inside the screen.
