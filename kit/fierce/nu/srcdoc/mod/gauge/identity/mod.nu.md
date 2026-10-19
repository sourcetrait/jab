# gauge/identity

## SCHEMAS

the clock records' layouts this reader takes, 1 to 8; a capture's sit at
one

## AUTOMATIC

a run's selection of its raster's workers (gauge identity request): automatic
when its identity asks none, forced when it asks a count

## CORRECTABLE

the identity's fields a correction may change: the build's flags and its
ELF's SHA-256, each read from beside the image at the run's start

## FROM_FILE

where a run's effective identity came from (gauge identity of), none where
its report holds no identity evidence (no-evidence)

## ALONE

the identity a reading with no evidence carries, the capture alone's,
its report's identity and never its run's (read-run)

## BOUND_HASH

how a found identity file binds to its report's run, strongest first
(binding-of): the SHA-256 of the file the run records; the identity the
run embeds, on every field but CORRECTABLE's; the report's one
identity over LEGACY_FIELDS, the weaker binding; none where the report
holds nothing to bind it to

## LEGACY_FIELDS

the report's one identity's fields a legacy binding compares, the mode
less its seed, which is held against the run's own recorded seed

## new

What a run was, written beside its capture before it starts: the
records' schemas this reader takes and the clock, the workspace the SDK
and kernel come from, the program's own source, the build, the assets,
the route, the cap, the machine (`machine of`'s record: a named
spec's, its name, cores, RAM, and display, or a custom machine's, its
harts and RAM, diagnostic; -machine, the CPU, and the accelerator with
its thread mode, and the words beside them),
the QEMU words of the launch's own (`overrides`), the host, the
toolchain with its as, ld, and objcopy, each the file its prefix resolves
to with its SHA-256 (gauge identity resolved-file), and the mode: the window,
the sound, the pad, the seed, the
cadence asked for, the workers and grain asked for, null for none, and
when the measurement closes. The build's flags are null, unknown, with
no `flags` beside the image, and its provenance the `provenance.nuon`
beside the image (ImageProvenance), null without one. The QEMU, the
machine, and the words are the launch's, written in when it returns
(launched-identity).

## qemu-of

The QEMU a launch ran, the binary it resolved, that binary's version,
and the SHA-256 of the file it resolves to (gauge identity resolved-file).

## resolved-file

The file a command resolves to, the path given where it names one, else
the one the path finds, and that file's SHA-256, both null where it
resolves to none.

## launched-identity

A run's identity once its launch returns: the QEMU it ran (qemu-of),
and the machine and the words the launch's result carries in place of
the ones asked for, and the capture's fields as the launch recorded them
(jab capture-identity): the profile, the capture nonce, QEMU's pid read
while it lived, the shim's log and library, the window, the API's port,
and the sends.

## image-flags

An image's build flags, the first line of the `flags` its build wrote
beside it, or null, unknown, where there is none.

## contradiction

Why an image's build flags contradict the tree a run asks for, none
where they do not: DEBUG defined on a release run, or absent on a debug
one. Flags missing are unknown and contradict nothing.

## corrected

A run's identity file read with the correction beside it applied. The
sidecar, identity_correction.nuon, names the identity file's SHA-256 and
the image's (`build.image_sha256`), and for CORRECTABLE's fields alone
the old value the file holds and the new one; a sidecar naming another
file or image, an old value the file does not hold, no field, or a
field outside CORRECTABLE stops the read. The corrections, null with no
sidecar: the sidecar, its SHA-256, each field's old and new values, and
the evidence it records.

## write

A run's identity written as its identity.nuon in `dir`, and the
SHA-256 of the file's bytes as written, which the run's report records
(RunBinding).

## dirs

The directories a report's run may hold its identity file in, in the
order identity-of tries them: beside the report, the directory named as
the last component of the `out` the report recorded, or the report's
own when the names match, so a moved report keeps its runs; then that
recorded `out` itself. Expanded, each once; none without an `out`.

## holds-field

Whether `r` holds the dotted field `name`, key by key, a null value
held as any other.

## differing

The leaf fields where `a` and `b` differ, each named dotted from `at`
with both values: two records compared key by key over both sides'
keys, a key one side lacks read as null, anything else compared whole.

## less-seed

A record less its seed, anything else as it is.

## legacy-differences

Where a file's identity, `found`, differs from a report's one identity,
`batch`, over LEGACY_FIELDS: each field the batch holds compared, the
mode less its seed, the file's seed against `seed`, the run's recorded
one; the fields the batch lacks, and the seed when the run records
none, unrecorded and not compared.

## no-evidence

Whether an identity, a report's or the one embedded for a run, is no
evidence of its run: absent, or the placeholder a read of the capture
alone writes, `launched` false (ALONE, and in a run as 7c37b3b's read
embedded it).

## evidence-of

An identity as evidence of its run, or null where it is none
(no-evidence).

## less-correctable

An identity less CORRECTABLE's fields, the two a correction may change.

## binding-of

How an identity file found for a report's run binds to it: at
BOUND_HASH when the run records `identity_sha256`, the file's raw
SHA-256, `sha`, equal to it; else at BOUND_EMBEDDED when the run embeds
an identity that is evidence (evidence-of), a placeholder none, the
file's identity as parsed, `found`, equal to it on
every field but CORRECTABLE's; else at BOUND_LEGACY against the
report's one identity, `legacy` (legacy-differences); else at
BOUND_NONE, nothing to bind it to, no evidence (no-evidence) and the
file taken unverified. Decided before any correction. `found` is null
for a file that does not parse, `error` why, which binds at no strength
but the hash. Bound or not, with the reasons it is not and the fields
unrecorded.

## of

A run's effective identity and where it came from. The run's identity
file, tried in each of its directories (gauge identity dirs), when it binds to
the run (binding-of), read with its correction applied (gauge identity
corrected); else the identity the report embedded for the run where it is
evidence (evidence-of), its correction provenance and its recorded
`identity_sha256` with it; else the report's one identity, as a report
from before per-run identities holds it; else, with no evidence
(no-evidence), ALONE from `none`, a file found against no evidence
still from the file, bound at BOUND_NONE, unverified. A
directory whose file does not bind is passed over, named with its
strength and reasons, its sidecar never read; a bound file that does
not parse, or whose correction fails its checks, stops the read, never
a fallback. The `identity_sha256` is the bound file's raw SHA-256, an
embedded one as recorded, or null: never made from a parsed or corrected
identity. The binding: the strength and the fields unrecorded, null
without a file. The run's recorded seed beside it.

## request

A report's run as its own identity asks it (SelectionIdentity), the one
reader of a run's selection and request: the identity identity-of
resolves, with its provenance as identity-of gives it, the report's
summary only that identity's fallback, and the fields read from it: the
selection, AUTOMATIC when it asks no workers and FORCED when it asks a
count, the cadence, the workers, the grain, the machine, the kernel's
SHA-256 (null for an identity recording none), the QEMU's version, the
pad, and the cap.

## read

The identity a capture in `dir` was launched under. The reports it
belongs to: gauge.nuon beside it and in its parent directory, a report
belonging when one of its runs' directories (gauge identity dirs) is the
capture's, two such runs in one report stopping the read. Each belonging run
read through identity-of, two reconciled (reconcile). With none, the
capture's own identity.nuon read with its correction applied
(gauge identity corrected), bound to nothing, BOUND_NONE, a parse or correction
failure stopping the read; with no file, the capture alone, from
`none`. Beside the identity-of fields, the reports read.

## correction-key

A correction's substance, what two reports must agree on: its fields
with their old and new values, the sidecar's SHA-256, and its evidence,
the sidecar's path apart, so a relocated sidecar stays the same
correction; null for none.

## shared-differences

Where two readings of one run differ over LEGACY_FIELDS and
CORRECTABLE's two, the comparison reconcile makes when either is a
report's one identity: each field both identities hold, the mode less
its seed, and each reading's seed, the run's recorded one for a report's
one identity, else its identity's. A report's one identity holds its
image's flags and ELF, one build for every run of its batch, so they
compare here and reach `explains`, though binding leaves them out.

## explains

Whether `c`, a reading's corrections, changed `field` from `from`, the
other reading's value, to `to`, its own.

## kept-of

The reading reconcile keeps, the recorded `identity_sha256` with it,
both readings' passed directories, and both reports.

## reconcile

Two reports' readings of one capture's run made one (gauge identity read). A
reading from `none`, no evidence, yields to one with evidence, and of
two such the report beside the capture is kept. Otherwise, their
recorded `identity_sha256`, where both hold one, equal; their
corrections, where both hold one, the same correction (correction-key).
Their identities compared on every field, or over LEGACY_FIELDS and
CORRECTABLE's two with each side's recorded seed where either is a
report's one identity (shared-differences); each
difference stands only where one side's correction changed that field
from the other side's value to its own, a correction merely present
explaining nothing. Anything else stops the read as ambiguous, naming
both reports and each field with both values. The reading kept: the
side whose correction explains the differences, else the one holding a
correction, else the stronger source, the file before the embedded
identity before the report's one, else the report beside the capture;
the `identity_sha256` the one recorded, both readings' passes, and
both reports.

## repo-of

The workspace's commit and whether its tree held changes: where the
SDK and the kernel came from.

## moved

A path a record wrote under the game's old place, `game/fps`, read at
its new one, `kit/fierce`, when the old is gone: the move of KitFierce.
A route or a pad table under the game's `test/`, `route_<name>.nuon` or
`table_<name>.nuon`, read at FierceTools' place for it,
`nu/nuon/route/` or `nu/nuon/table/`, by the same name, so an older run's
recorded route reads at the bytes its SHA-256 names. Any other path, and
one still there, as written.

## program-of

The program an image was built from: the directory its build wrote
beside it as `home`, read through the move (moved), else, for an image
built before that, the directory the image's nearest `.target` sits in.

## program-source

The program's source revision: the commit an exported tree's
source.nuon names, else the commit of the repository that tracks the
program's manifest and main source, with whether they held changes;
unknown otherwise. A repository merely enclosing an export, which
tracks none of it, says nothing about it.

## digest

A file's SHA-256, or null when it is not there.

## tree-digest

A tree's digest: every file's path under it and its SHA-256, one a
line in path order, hashed.
