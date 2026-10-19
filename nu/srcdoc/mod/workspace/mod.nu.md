# workspace

## workspace-dir

The nearest parent of `dir` holding workspace.jab.toml, or null.

## workspace-of

The workspace a kernel or a program builds against: the nearest
parent holding workspace.jab.toml, else the one the manifest's
`workspace` names, relative to the manifest, for a program that lives
outside any. Its kernel is built there with the same symbols and
found in that workspace's tree, and its generic disk, its toolchain
link, its shims, and discovery come from there, and the program's own
output lands in that workspace's target at the program's path
(shard-of). Under a workspace the key is not read. Null with neither.

## member-of

Whether `dir` is one of the workspace's own, its kernel or a program
workspace.jab.toml lists, by its workspace-relative path, which is how
an image built before its `home` marker is placed (image home).

## is-workspace

Whether `dir` is a workspace's root, holding workspace.jab.toml.

## programs-of

Every program of the workspace at `ws` by its path from it: the members
workspace.jab.toml lists, then the programs under its directory it does
not list, the game's among them, found by their manifests outside the
target, the cargo trees, and extern/.

- glob's exclusions as a filter on each path's words below the workspace

## path-words

A path given as words, each split on its slashes, so `example bounce`,
`example/bounce`, and `kit/fierce` all read; "" for none.

## program-path

A program's path in the workspace from words (path-words), a word the
workspace's `shortcuts` table names standing for its path: `fierce` for
kit/fierce.

## programs-under

The programs at or under a path in the workspace, every program for no
path; a path matching none is an error naming them all. Untyped because
it ends in an error.

## program-at

The one program at a path in the workspace, its directory. Untyped
because it ends in an error.

## is-test

Whether a program, by its path from the workspace, is a test: one under
a `test` directory, which `just test` runs and `just run` does not.

## run-target

The one program `just run` takes at a path in the workspace, its
directory: any program but a test (is-test). Untyped because it ends
in an error.
