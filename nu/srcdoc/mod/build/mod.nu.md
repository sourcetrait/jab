# build

## march_program

The assembler takes the same profile, so the source may use whatever
the CPU carries: the user profile for a program, which runs in U-mode,
and the supervisor profile for the kernel.

## symbols

The build symbols named by `--set`: comma separated, in any case,
each made screaming snake case (debug, Debug and some-thing become
DEBUG and SOME_THING), sorted so order cannot matter, and refused when
the assembler would not take the name, which it would only say much
later.

## with-debug

A test build's symbols: whatever was asked, and DEBUG.

## profile

Which tree a build lands in: debug with DEBUG set, else release.

## defsyms

The symbols as the assembler takes them.

## program-shard

A program's directory in the target for one purpose, whatever the
tree: `<target>/<purpose>/<its shard>`, or `<its own>/<purpose>` for
a program inside the target. The purposes: asset, the trees its
content compiles to; bench, the benches' runs; gauge, measurements
kept by name; candidates, measured copies of it; scratch.

## program-out

Where a program's build of `tree`, release or debug, lands, its tests'
and runs' output beside it.

## program-kernel

The kernel a program runs on in `tree` (kernel-elf).

## context

The kernel's or a program's context for a build with `names` set:
manifest, workspace (workspace-of), toolchain, symbols, the target
(target-root, the workspace's or a lone program's own), the tree in
it (debug or release), and the output directory, the tree's shard
(shard-of).

## kernel-elf

The kernel ELF a program runs on: the workspace's, in the same tree
of that workspace's target, or JAB_KERNEL. Left untyped because it
ends in an error, which the output check rejects.

## spec-inputs

The spec data a program's build reads when its manifest lists `specs`:
the workspace's asset/spec.nuon and asset/spec.nutype, inputs of its
build, so a changed definition or a changed type alone builds it again
rather than leaving an image built under the old ones standing; none
for a program that lists no specs. A program listing specs whose
workspace has no spec data is refused naming where it looked.

## build-program

Builds a program's image when stale, and writes beside it `home`, the
program's directory, which image-home reads back from the image. A
program declaring its demand (program-demand) has it checked at every
build and assembles with its constants (demand-include), written ahead
of the staleness check and counted among the build's inputs, so a
change in the text the SDK generates builds the image again; a build of
one declaring none retires the constants an earlier declaration left.
Every image begins with its first page (header-source), the jump to its
code, the header, and its declaration (image-declaration), generated and
counted among the inputs the same way and linked ahead of the program's
own object, so a change to a listed spec's row builds the image again
with the new declaration, and a build with nothing changed builds
nothing. Every build writes `demand.nuon` beside the image, the demand
recorded with it (image-demand), and a cached image is taken only beside
a record that holds and names the build's demand, any other building
again whole, the image and its record together.

## prepare

A program's preparation before it is built, tested, or run: the script
its manifest's `prepare` names, relative to the manifest, run from the
program's directory with the phase, build, test, or run; nothing
without one. A preparation that fails stops the command with its
output.

## build-under

Build the kernel, then the programs at or under a path in the
workspace, every program for none, each prepared first, with `names`.

## clean

`just clean` and `just do clean`, one verb with or without a path, the
SDK's `main clean` merged into it: the workspace checked first, then with
no path the whole target (`target clean`); with one, the build outputs of
the programs at or under it, or the kernel's with `kernel`, in both trees
or the one `--tree` names, each retired (`target retire`) under one stamp.
A program's output holds the outputs of the programs under it, which go
with it. `--tree` and its tree arrive among the words, which a bin passes
through by `--wrapped`.

## main

Build: at a workspace's root the kernel and every program, or the
programs at or under a path (`example`, `example/bounce`,
`kit/fierce`), each prepared first; at a program's directory that
program, prepared; with --kernel at the kernel's, the kernel. Release
unless --set says otherwise.

## retire

Delete everything retired (`target retire-all`): `just retire`, the
workspace checked first.
