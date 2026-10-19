# bench

## benches-of

The benches of the workspace's programs, `<program>/<bench>` each: the
NUON files under a program's bench/ directory.

## packaged-words

A packaged bench names its package's files as `{package}/<path>`, since
where a package lies is known only where it is extracted; the run reads
each word with the package's directory in its place.

## bench-at

The bench `name` names, `<program>/<bench>`, the program by its path
or a shortcut (program-path): the program's path and directory, the
bench's name and file, and its definition, held to its shape: a
summary, and steps each with a label of its own and the script it runs
with its arguments; `build`, when given, tree or none. With `--package`
the bench is the package's own, `<package>/bench/<bench>.nuon`, its
words read at the package's directory (packaged-words), and it must say
`build: none`, since a packaged bench runs the frozen guest bytes the
package carries and a tree build beside them could stand in for them.
The program still names the scripts, which come from the checkout.
Untyped because it ends in an error.

## bench-home

Where a bench's runs land: the program's bench shard of the target
under the bench's name, each run a stamped directory in it, beside
state.nuon, which says what the latest run is doing for `watch bench`.

## bench-list

The list `./do bench` prints: each bench with its summary.

## bench-state

A bench's state file as its run last wrote it; null when there is
none.

## bench-live

Whether the run a state describes is under way: not finished, and its
process alive.

## bench-save-state

The state file written whole, through a file beside it moved over it,
so `watch bench` never reads half of one.

## bench-tar

A bench's run packed whole into one tar beside its directory in the
bench's home, so the run travels as one file: named for the bench, its
path's slashes as underscores, and the stamp, `<bench>-<stamp>.tar`,
the run's directory at the archive's top under its stamp. A tar of the
run already there, an earlier packing, is retired first (retire), since
nothing is deleted. The tar's path. Untyped because it can end in an
error.

## main

Run a bench, `./do bench <program>/<bench>`: the NUON file of that name
under the program's bench/ directory, with a summary, the tree, the
steps, each a label and the program's script with its arguments and,
for a step a person attends, `attend`, what they do; and the report, a
script run over the run's directory at the end. The program is built
in the tree, then every step runs in order with `--out` its own
directory and `--label` its label, an attended step announced and
counted down first, a step that fails recorded and the rest run; then
the report. A run is a stamped directory in the program's bench shard
of the target, its bench.nuon recording every step's outcome as it
lands, and state.nuon beside the stamps says what the run is doing,
for `nu/bin/nuance.nu watch bench`. At the end the run is packed whole
into one tar beside its directory (bench-tar), the file to copy off the
host, and
the last line names it; a watch recording the run packs it again when
it ends, its recording included. A run with a failed step or a failed
report exits 1 once everything is recorded, reported, packed, and said.
`--only` runs the steps its comma-separated labels name; with no bench,
the list. Nothing is deleted: a run writes its own directory, its tar,
and the state.

A bench saying `build: none` builds nothing before its steps, its steps
naming every image they run; a packaged bench says so (`--package`,
bench-at). A step marked `gate: true` ends the bench when it fails: no
step after it runs, each recorded `not run`, and the run fails, so a
package's preflight refuses before the long battery. bench.nuon records
the bench file's SHA-256, the build, the package's directory, and each
step's gate beside the rest.

## bench-qemus

The QEMUs of a bench's run, each its pid with its command line from
one look at the process table: those whose command lines name the
run's directory.

## bench-step-of

The step a QEMU of a bench's run belongs to, read from the command
line the process table showed with its pid (bench-qemus): the step
directory under the run's directory its pid file and its logs sit in,
every step writing under `<run>/<label>/`; `unknown` when the line
names none of the bench's steps.
