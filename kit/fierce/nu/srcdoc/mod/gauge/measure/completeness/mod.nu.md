# gauge/measure/completeness

What keeps a capture's window from complete, read from the records before
its end marker.

## window-problems

What keeps a window from being complete, read from the records before
its end marker alone: no marker, a capture whose schema this reader
does not take, a clock record at a schema other than the capture's, a
record numbered out of order or twice, and a frame short of a record or
one too many, the presentation records counted from schema 2, the
packet records from schema 3, the tile and storage records from schema
5, the harts records from schema 6, the receipt records from schema
7, and a SERVICE build's service records, one a frame as the frame's
ninth record, whenever the capture holds any, beside which a load record,
one and before the first state, is held;
from 5 a frame with no configuration in force, none from it
or before, leaves the window incomplete too, as does a configuration
arriving other than after exactly `from` state records and `from` frame
records: the program writes one at the boundary of the first frame it
governs, after the frame before's records and before that frame's state
record, so a later one governed frames it followed and an earlier one
names a frame not begun.
