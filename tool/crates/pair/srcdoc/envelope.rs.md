# envelope.rs

## struct Line

## struct Envelope

The offset's ceiling is the least of the lines h_hi - b l over the pairs and
its floor the greatest of h_lo - b u. Each is a hull of lines sorted by x,
O(n log n), its breaks increasing, so its value at any b is one line found
by binary search. The greatest is the least of the negated lines, its sign
kept to turn values and lines back.

### fn min

### fn max

### fn hull

Of lines with equal x only the binding one stays, the least c for the
least and the greatest for the greatest. A line meeting the hull at a single
point is dropped: its value there is the envelope's, and the binding pairs
are found by evaluating every pair, never from the hull.

### fn breaks

### fn at

At a break the two lines agree, so either serves.

### fn after

The line just past b, the one the margin is linear in up to the next
candidate; `zero_after` takes its zero from it.

### fn index

## fn crossing
