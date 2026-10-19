# do.nu

The workspace's casual driver, each verb one call of an SDK module
(NuLayout's bins). While the justfile stands, its recipes call these
verbs with the workspace's directory first, as they called
`sdk/nu/jab.nu`'s, and the verbs take the same words.

## main build

`build`, the build module's `main`: at a workspace's root the kernel and
every program, or the programs at or under a path, each prepared first;
at a program's directory that program; with `--kernel` the kernel at its
directory. Release unless `--set` names DEBUG; what is up to date is
skipped.

## main test

`program test`: DEBUG set beside whatever `--set` names; at a
workspace's root every program's test, or those at or under a path, each
one's output and then a summary, failing if any fails; at a program's
directory its `test/test.nu` on the debug kernel. `--spec` names the spec
every launch of the tests runs that names none of its own.

## main run

`program boot`: one program built, then run in its window with the UART
on stdio, at a workspace's root the program at a path and never a test,
at a program's directory that program; release unless `--set` says
otherwise. `--api`, `--kbm` and `--no-kbm`, `--pad` and `--no-pad`,
`--no-sound`, and `--spec` or `--harts` choose the machine as the
module's mirror says. QEMU's exit code is the program's status.

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
