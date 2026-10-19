# probe.nu

The SDK's probe as a standalone script, a command of my own rather than
one of the workspace's two bins (NuLayout's `nu/bin/nuance/`), one call
of `probe` over the workspace this file sits in.

## main

`probe`, the probe module's `main`: the program at a path from the
workspace's root, or a program's directory by its absolute path
(`workspace subject`), built release unless `--set` says otherwise, then
probed under a window for `--seconds`, and one NUON record printed on how
its flips reached the window. `sdl` is the one kind, Linux only; `--api`
puts the API's port on, `--send <file>` writes the file's bytes into it,
and `--trace` has QEMU trace the device's flushes and set_scanouts
beside the shim's log.
