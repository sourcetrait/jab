# play

The game handed to a player that is not a hand on a pad: a machine planned for a
map on the debug kernel, with the API's port, the pad, and the sound device,
served through robojab, the harness that takes commands and gives frames back.
`serve --target mcp` prints the MCP server line and the config record a subagent
template takes, so an agent plays the game as a tool; any other `--target` is a
socket path to serve on in the foreground, for a script. The plan and everything
the run writes land in `out`; a fault on the UART is resolved to its routine
from the ELF beside the image through the toolchain the build's flags name.
nuance.nu's `play` builds and runs it (game's `play`).
