# Route.nutype

The shape of a gauge route, `nu/nuon/route/<name>.nuon`: the map it plays
on, the `end` at which the E closes the measurement, and its legs in order.
A leg is a name, its placements (`at`, the eye's `x`, `y`, and `z`, its
`yaw` and `pitch`), and its pad events (`at`, the evdev `type`, `code`,
and `value`), with or without console sends of a bare kind (`at`, `kind`),
so a leg is one of two records of exactly those fields. `route read` holds
a route to it through the SDK's `nutype problems`.
