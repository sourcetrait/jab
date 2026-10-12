# owners.S

Hart ownership by role: every online secondary has an owner, kept in its
record's HART_OWNER (hart.inc), and four calls work over it, hart 0's
alone, a worker's answered JAB_DENIED by the trap's call classes.
JAB_OWNER_NONE is the unowned, JAB_OWNER_RESERVED the program's graphics
reservation, and a claim's id, 2 up, an optional feature's. A grant is
computed at each read from the records of the harts online then
(owned_mask), with no table, so a hart that fails leaves its grant with
nothing written and is never granted again. Hart 0, the main hart, belongs
to no grant. Every refusal is decided before anything is written, and a
hart moves between owners only with no worker on it (working). Once a
reservation stands, the start (workers.S) holds every worker to its hart's
owner. Under DEBUG each change is a line on the debug channel: `jab: harts
reserved <count> grant <mask>`, `jab: harts claimed <id> <mask>`, and `jab:
harts released <id> <mask>`, each mask 0x and sixteen digits.

## sys_harts_reserve

The reservation, once a run: every online secondary, unowned until then,
to JAB_OWNER_RESERVED, the count its floor. ALREADY is checked first, so a
second reservation is refused whatever else holds; SHORT reserves nothing,
so a smaller count may follow. Under DEBUG the knob `jab.claimids=<n>`,
read here, sets owners_next to CLAIM_IDS less n, leaving n claim ids, so a
test proves the limit without 2^63 claims; a count past the range leaves
every id.

## sys_harts_claim

The checks in code order: a reservation; the mask nonempty and inside the
grant, which keeps out hart 0, an offline or failed hart, and a claimed
one; no worker on a hart of it; the grant left at its floor or above; an
id left. The id is owners_next plus OWNER_FIRST_CLAIM, and owners_next
moves on only once every check has passed, so a refusal leaves the counter
and every owner as they stood, and once owners_next reaches CLAIM_IDS every
claim is refused JAB_CLAIM_SPENT.

## sys_harts_release

An id below OWNER_FIRST_CLAIM, none or the reservation, is no claim's and
is refused unknown, as is one no online hart holds, a released or spent
id among them.

## working

The read of each hart's HART_WORK is followed by `fence r, rw`, pairing
with worker_leave's release as the start's busy check does, so a moved
hart's last worker's exit is ordered before what its new owner does.

## knob_claimids

`14 u8`: the claimids knob's name, under DEBUG only.

## msg_reserved

`21 u8`: the reservation's debug line's prefix, under DEBUG only.

## msg_grant

`8 u8`: the word before the reservation's grant, under DEBUG only.

## msg_claimed

`20 u8`: a claim's debug line's prefix, under DEBUG only.

## msg_released

`21 u8`: a release's debug line's prefix, under DEBUG only.

## owners_reserved

`u64`: 1 once the reservation stands; global, since the start reads it.

## owners_floor

`u64`: the reservation's count, the floor no claim takes its grant below.

## owners_next

`u64`: the claims issued this run, a claim's id this plus
OWNER_FIRST_CLAIM.
