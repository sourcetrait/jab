# suite/tiles/pool

The tile pool's own fixtures from cold starts, and the console's K and O
settings the other cases share.

## PACKET_CAPS

The packet's bounds, through the console's K frame on a debug build.
The still copy of Render Zero's spawn view, settled on its tiles,
drawn in packets of at most PACKET_CAPS' commands and spans, so a frame
flushes many times, each full packet rendered whole before preparation
goes on: the capture the uncapped one's

## POOL_LIFTED

The tile pool's own fixtures (pool-holds) on the still copy's spawn
view, each a cold start through the console's O frame with the view
placed at POOL_PLACE_AT and the measurement closed at POOL_END_AT:
the O frame's modes, the quota, the allowance, and the merge's share
lifted, construction frozen, an eviction leaving its entries; the
rotation's admission, a tier of one request and an open ring of four
under a merge's share of a microsecond, so the ring overflows and the
merge stops after a surface, drawn by two workers in bands of 16 rows
in packets of PACKET_CAPS; and TILE_CONTEXTS, every context a tier
admits in, hart 0's and a slot's for each secondary the ABI allows, so
a surface merges at most its tier times them in a pass

## POOL_STALE_SLOTS

the stale entries' cap, under the 272 tiles the spawn view asks, so
every pass evicts and builds, and the capture's time, past the E since
a capture ends its run

## pool-trace

The passes a trace of the pool printed (pool-frame's `--trace`): each
frame's boundary with the surfaces whose requests its batch held, the
surfaces merged with their keys, and the surfaces whose tiles it built,
a list's lines joined.

## pool-holds

The tile pool's own fixtures on the still copy's spawn view, each
launch a cold start with the view placed (pool-frame's `--cold`), read
from the frame of the cold start, the configuration's first, through
gauge measure, complete and valid at CLOCK_SCHEMA:
- the rotation, under POOL_ROTATION's admission with the pool's trace:
  every surface the passes find requesting built within the most
  surfaces one pass found requesting of its first request, the merge's
  start moving on at every pass while two or more surfaces request, no
  surface merging past its tier in every context though its requests
  span bands and flushes, the ring overflowing and the merge stopping
  short;
- first sight under the ordinary budget: the cold start's frame drawing
  blocks without their tiles and asking for them, the view settled at a
  frame with no block drawn without its tile, no BUILDING tile, and
  nothing admitted, dropped, filtered, or built, read from the records,
  and every frame after it settled, the tiles built to it the slots it
  holds, none evicted;
- the rings under the lift with a tier of one request: the frame after
  first sight merging and building every request the cold start's frame
  made, past what the tiers can hold, and asking for none, the warming
  frame valid; the view settled at the frame after it;
- the stale entries: the bright view under the lift, the stale mode,
  and a cap of POOL_STALE_SLOTS, every pass evicting and building, each
  evicted tile's entry left naming its slot's next tile, the capture
  the lit loop's picture (`lit`) byte for byte and every frame valid,
  the generation check alone keeping a stale entry from its slot.
Returns the most surfaces a rotation pass found requesting and the
longest wait, the frames first sight took to settle and the slots it
holds, the keys the warming frame merged, and the stale run's evictions.

- a surface leads two passes running only after a pass that merged
  every requesting surface: a pass whose share runs out on the last
  surface of a wrapped scan resumes past it, and its first may lead
  again, every surface merged
