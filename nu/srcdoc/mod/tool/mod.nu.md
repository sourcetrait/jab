# tool

## disco-build

The jabdisco binary, one package of the tool workspace (tool-build).

## robojab

The robojab binary, the play harness, one package of the tool workspace
(tool-build): its path, for a script that serves a planned machine to
an agent.

## pair

The jabpair binary, the pairing's exact bracket, one package of the tool
workspace (tool-build): its path, for `sdl pair` to send its pairings to
on stdin.

## tool-build

A package of the tool workspace, tool/ in the jab workspace, built with
cargo into its own target/ on first use and whenever it changes, so a
`cargo build --release` there is the same build: the binary's path,
named as the package is. `without` says what to do with no workspace.

## shim

A shim, one package of the workspace's shim/ workspace, built with
cargo into the target's shim/ on first use and whenever it changes:
the path of its shared library, to preload into QEMU, or with --bin
of its binary, named as the host names an executable (exe-name);
--static builds a binary non-PIE, through `cargo rustc` with the
static relocation model.
