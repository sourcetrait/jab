# nuance.nu

The kernel's commands for development, each verb one call of a module of
the kernel's nu tree.

## main font

`font`, the font module's `main`: `kernel/nu/bin/nuance.nu font
<spleen-12x24.bdf>` regenerates `kernel/src/font.S` from a Spleen 12x24
BDF, a relative path the caller's. The BDF comes from Spleen's release
tarball, fetched to scratch when the font is regenerated.
