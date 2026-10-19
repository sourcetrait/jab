# launch.nu

The SDK's headless launch as a standalone script, a harness's input rather
than a command of the workspace's two bins (NuLayout's `nu/bin/nuance/`), one
call of `nu/mod/nuance/launch`, the launch in its script form.

## main

A program's image run on a kernel under QEMU for at most `--seconds`, its
outputs under `--out`, and the record `launch` returns printed as NUON, the
API's bytes as binary. Every flag is `launch`'s own; those `launch` takes as
a table or a list, `--keys`, `--send`, `--threads-at`, and `--qemu`, take
their value as NUON text, a script's command line carrying strings alone:
`--send "[[at, bytes]; [200ms, 0x[57 4e 4f 4e]]]"`. A harness in another
checkout reaches a given jab's launch through this script, never by
importing that jab's modules, whose paths a parse fixes.
