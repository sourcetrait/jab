# suite/tiles

The suite's tile cases, each a `[context, records]` case the suite's
orchestrator calls as `tiles <case>`: handoff, block, packet, frozen, pool,
and builder. The cases stay here, the part's api the orchestrator and the
import map's case rule read; the fixtures they run lie in the children,
and two of those are re-exported for a consumer outside fierce's tree,
jab-stress's handoff probe, in one import of `suite/tiles`:

- `handoff-holds`: suite/tiles/handoff's `handoff-holds`.
- `builder-holds`: suite/tiles/builder's `builder-holds`.

No child imports it; each imports its siblings by path. Its children:
suite/tiles/builder, the builder wall's fixture and the tile geometry the
handoff shares; suite/tiles/handoff, the handoff's measurement, tiled
against lit, head-on and oblique; suite/tiles/pool, the pool's own
fixtures from cold starts and the K and O frames' settings the other
cases share.

## block

one level a block, and the pool's tiles the chain's texels under
the bright frame: the still copy's spawn view settled on its tiles
against the tiles held off by frozen construction, identical over
the whole screen, every block at its own level reading the same
texel from its tile or the chain

## packet

the packet bounded: the same view settled on its tiles, drawn in
packets of a few commands and spans (PACKET_CAPS), each full packet
rendered whole before preparation goes on, the capture the uncapped
one's over the whole screen

## frozen

the frozen frame across flushes: frames whose boundary built tiles
drawn in flushed packets, the debug build holding the pool unchanged
at every packet's render through the run

## pool

the tile pool's own fixtures (pool-holds): the merge's rotation,
first sight settling, and the rings at the warming frame

## builder

the builder's assertion (suite tiles builder-holds): every tile of the builder
fixture's wall at every level of its chain, built by the B frame and
read back by the D frame under the bright, the gradient, and the
parity lumels, held texel by texel to the host's oracle of the light
of each texel's centre
