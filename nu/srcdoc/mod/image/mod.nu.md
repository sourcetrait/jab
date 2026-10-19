# image

## home

Where a launch looks for extern/qemu before the workspace, as a run
does: the directory of the program a built image came from, which the
build writes beside the image as `home`. An image built before that
is read from its path: a member's under the workspace's .target at the
member's path, any other program's under the program's own .target,
and an image under no .target is taken to sit beside its program.

## workspace

The workspace a launch belongs to, whose generic disk rides along and
whose shims play a pad: the one the image's program builds against
(workspace-of, through the manifest at the image's home), since the
target an image and a kernel sit in can lie outside every workspace;
else the one above the kernel's ELF, else the one above `out`.

## manifest

The manifest of the program an image was built from (image-home), for
the window it names; an empty record when there is none.
