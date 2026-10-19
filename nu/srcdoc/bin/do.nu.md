# do.nu

The workspace's casual driver, the end user's, each verb one call of an
SDK module over the workspace this file sits in (NuLayout's bins). The
root's `do` links to it; `nu nu/bin/do.nu` is the form on Windows, where
git checks a symlink out as a text file.

nushell's `path self` names the path a script was run by, the link and
not its target: run through the root's `do`, `path self ../mod/build`
reads beside the root's parent (measured on nushell 0.115.1). So the bin
resolves its own path first, `HERE` (`path self | path expand | path
dirname`, the link followed), and binds each import and the workspace
from there, `($HERE | path join ../mod/build | path expand)`; each module
path comes out as the modules' own `path self` imports write it, so each
module is parsed once.

A verb's words are a program's path from the workspace's root, its words
spaced or joined by slashes, or a shortcut, `kit/fierce` or `fierce`, as
the justfile's were. A first word that is an absolute path names a
workspace's, the kernel's, or a program's directory instead (`workspace
subject`): a candidate's copy, an export, or a program outside the
workspace builds, tests, or runs by its path, and a caller of the
earlier `build <dir>` form keeps working.

## main build

`build`, the build module's `main`: the kernel and every program, or the
programs at or under a path, each prepared first; a program's directory
by its absolute path, that program alone; with `--kernel` and the
kernel's directory, the kernel. Release unless `--set` names DEBUG; what
is up to date is skipped.

## main test

`program test`: DEBUG set beside whatever `--set` names; every program's
test, or those at or under a path, each one's output and then a summary,
failing if any fails; a program's directory by its absolute path, its
`test/test.nu` on the debug kernel. `--spec` names the spec every launch
of the tests runs that names none of its own.

## main run

`program boot`: one program built, then run in its window with the UART
on stdio, the program at a path and never a test, or a program's
directory by its absolute path; release unless `--set` says otherwise.
`--api`, `--kbm` and `--no-kbm`, `--pad` and `--no-pad`, `--no-sound`,
and `--spec` or `--harts` choose the machine as the module's mirror
says. QEMU's exit code is the program's status.

## main bench

`bench`, the bench module's `main`: with no name the list of the
workspace's benches, else the bench `<program>/<bench>` built in its
tree and run step by step, its report after, the run packed into one tar
whose path the last line names; `--only` the steps its comma-separated
labels name. A run with a failed step or report exits 1 once everything
is recorded.

## main watch

`watcher`, the watcher module's `main`: the running Jab QEMU found from
any shell and recorded per thread once a second to the target's
`watch.nuonl`, then, the moment the run ends, its report printed as one
NUON record to paste, the first `--skip` seconds dropped as the load.
The bench's watch is the root's `nuance.nu watch bench`.
