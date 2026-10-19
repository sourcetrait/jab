# game

The game's commands for development, which nuance.nu's `render`, `pose`,
`smoke`, and `play` run: the content rendered, a capture of placed poses, the
smoke test, and robojab's play. A command that runs the program builds it first
through the SDK's tool, its maps compiled with it.

## places

The game's directory, the workspace's, and the SDK's tool.

## build

The game built through the SDK with the symbols `set` names, its maps
compiled first.

## render

Every asset under content/ rendered to the file beside it the engine
reads: an SVG to a PNG at its own size through rust/svg2png, built when
it is not there; an ambient note list to a MIDI file through
ambient's `render`; a sound recipe to PCM through sound's `render`

## pose

Build with the symbols given, then capture a map from placed camera
poses, a NUON list of {name, x, y, z, yaw, pitch}, as PNGs under out:
`nuance.nu pose render_1 poses.nuon out`; `--set debug,owner` captures the
surface each pixel belongs to

## smoke

Build with DEBUG set, then play Render Zero on the pad from seeded
random tables for that many seconds a seed, the seeds separated by
commas, a fault resolved to its routine: `nuance.nu smoke 1,2,3 60`

## play

Build with DEBUG set, then hand a map to robojab for an agent or a
script to play: `nuance.nu play` prints the MCP server line and config
record for a subagent; `nuance.nu play <socket>` serves commands on that
socket in the foreground; `nuance.nu play mcp render_1 300` another map
and bound
