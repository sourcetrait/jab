# target

## root

The one build tree a workspace writes into, every build and every
tool's output sharded within it: `.target` at the workspace's root, or
where XDG_CACHE_HOME is set `$XDG_CACHE_HOME/jab/target/<checkout>`,
the checkout its directory's name and the first eight hex digits of the
SHA-256 of its path, so two checkouts on one machine never build over
each other. `anchor` is the workspace, or a program with none above it.

## is-target

Whether `dir` is a target this tool makes (target root): a `.target`
directory, or a checkout's under `jab/target` in the XDG cache, which
is never that directory's shared `tmp` (retire-home).

## target-of

The target a path lies in, the nearest of its parents that is one
(is-target), or null.

## retire-home

Where a target's retirements go: `tmp`, which `nu/bin/nuance.nu retire` empties,
beside every checkout's target under `jab/target` in the XDG cache,
else in the `.target` itself; `base` is the directory a retired path
keeps its place under, so a checkout's name rides along in the shared
one.

## retire

Moves `path` out of the way whole in place of deleting it, so nothing a
build, a test, a bench, or a clean clears away is lost: into the
retire home's `retired/<stamp>/` (retire-home) at its place under the
home's base, the target `root` when given, else the one the path lies
in (target-of); a path outside lands under `outside/` there at its
absolute path. A second retirement of one path within a second takes
a numbered name, and `--stamp` sets the stamp, so a clean's entries
share one. Nothing when nothing is there; a link is moved as a link.
A path in no target with no root given, or one already retired, is
left as it is and refused.

## shard-of

Where a kernel's or a program's output lives in the target `root`:
under its path relative to the workspace when it lies inside it,
member or not; beside its own source when it lies inside the target
itself, as a measured candidate's copy does, `inside`; under
`external/<name>-<the first eight hex digits of its path's SHA-256>`
when it lies outside both; under its name with no workspace.

## tree-symbols

The symbols that put a build in `tree`: DEBUG for debug, none for
release.

## under

Whether `dir` is `root` or lies under it.

## clean

`nu/bin/nuance.nu clean`: the workspace's target retired whole under one stamp
(retire), so the next build starts from nothing while nothing is
deleted: a checkout's target under the XDG cache moved as one into the
shared tmp beside it, a `.target`'s entries but its own tmp into that
tmp; only a directory that is a target this tool makes (is-target).

## retire-all

`nu/bin/nuance.nu retire`: everything retired deleted, the retire home's tmp
(retire-home) removed whole, the one thing this tool deletes; only a
directory named tmp in a `.target` or beside the checkouts under
`jab/target`, never a link, and nothing when it is not there.
