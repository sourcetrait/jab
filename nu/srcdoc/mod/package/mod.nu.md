# package

A host package: the frozen guest bytes a bench runs and the inputs its
consumers read, made on the box into one tar a host extracts and runs
from its own checkout, so a host's run takes the freeze's artifacts and
never a build of its own (FrameCeiling's HostPackage). The host's QEMU,
launcher, shim, and backends are its own and recorded as its own by the
preflight, beside the guest artifacts and never compared with them.

## WORKSPACE

## MANIFEST

`package.nuon` at the package's root: its schema, name, when it was made
and by which checkout (identity reader), every artifact's role, path,
length, SHA-256, and the meta its maker gave, and the identities the
maker names, each with the check that uses it.

## INPUTS

The flags a run takes its guest inputs by: the image, the kernel, and the
asset tree, which every packaged step names, and the route, which a
route run (`gauge run`) names, each taken from the package.

## file-of

## make

The spec names every artifact by its role, the file or tree it comes
from, and where it lies in the package, a tree laid file by file with
its role. Files of equal content are hard-linked to the first, so the
tar, which stores a hard link as a link, holds each content once; GNU
tar here and bsdtar on macOS and Windows extract the links. The stage is
a fresh directory the caller names and keeps, since the tooling deletes
nothing; the tar is made from inside it with relative names, the
package's directory at its top.

## check

Every artifact at its path with its length and SHA-256, never its
modification time, since a correctly extracted file can be newer than
its archive; and every file the package holds an artifact of the
manifest, so a stray file is never taken for one.

## verify

The bin's check (check): each problem printed, the call refused when there
is one, else the artifacts counted.

## artifact

A file's row at the path, or a tree's rows beneath it, since a tree is laid
file by file, every one of them of the role the preflight takes, else the
path is named.

## rebuild-problems

A packaged step that names no image, kernel, or asset tree, or a route
run that names no route, would take the tree's build or the checkout's
shard and route, and one whose image, kernel, asset tree, or route lies
outside the package would run something the package does not hold:
either is a rebuild by accident, refused before any run. A step's words
are read as the bench reads them, `{package}` and each `{build:<name>}`,
the package's `build/<name>`, in place (bench built-words). Gate steps,
the preflight itself, are left out. A step whose script is one of
POSITIONAL, walk's cadence wrapper `example/walk/test/cadence.nu`, names
its image and kernel as its first two words rather than by flag, its disk
and flags read from beside the image, so it is held to those two words
alone: both given, and both inside the package.

## preflight

A packaged bench's first step, a gate (the bench module's `gate`), short
and refusing: the package checked whole; the named spec's row and the
machine it resolves to on this host, a host with fewer cores than the
spec's harts or less memory refused; no Jab QEMU already running, whose
ports and pipes a run would share; the launch as it will run, planned
over the packaged kernel, image, and a disk made from the packaged tree
(launch plan with the bench's window and live audio): the QEMU it
resolves with its version and file's SHA-256, the timeout every bound
takes (bound timeout, refusing an unusable one), the window, the audio
backend, and the environment, SDL_VIDEODRIVER, JAB_DISPLAY, and
JAB_AUDIO recorded as found, so an offscreen run with `--host` is
recorded as one; on Linux the capture path, one short probed launch of
the packaged image under the sdl shim, generic profile, bundled and its
bundle checked, the shim's SHA-256 kept; elsewhere the platform's
declared limit in its place; and no rebuild (rebuild-problems). Every
refusal is named and the preflight fails, ending the bench before any
run; `preflight.nuon` in its `out` holds every reading, the launcher's
identity taken as the preflight starts, where its code is read, and the
package's manifest is copied beside it, so the bench run carries the
identities it ran under for whatever reads it after.
