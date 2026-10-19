# plan.nu

The SDK's machine planner as a standalone script, a harness's input
rather than a command of the workspace's two bins (NuLayout's
`nu/bin/nuance/`), one call of `program plan`.

## main

`program plan`: the program at the directory given built with the
symbols `--set` names, its kernel beside it in the same tree, and the
headless machine a launch would run prepared and printed as JSON, the
record `launch plan` returns, for robojab or any harness in another
language to run and drive. `--out` is the machine's directory, under the
program's build tree unless given; `--disk` and `--serial` the program's
disk and the serial the guest finds it by; `--api`, `--gamepad`,
`--pad-port`, `--no-kbm`, and `--sound` the ports and devices; `--spec`,
`--harts`, and `--bootargs` the machine as a launch takes them.
