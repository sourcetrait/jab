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

## main bench

`bench`, the bench module's `main`: with no name the list of the
workspace's benches, else the bench `<program>/<bench>` built in its
tree and run step by step, its report after, the run packed into one tar
whose path the last line names; `--only` the steps its comma-separated
labels name. A run with a failed step or report exits 1 once everything
is recorded.
