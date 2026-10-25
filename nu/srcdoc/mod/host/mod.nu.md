# host

## roles

The roles a machine declares (DeclaredConditions, TheUser's design):
`unknown`, the default, which a run's record treats as no declaration;
`container`, a machine running Jab inside a container, the box among
them; `desktop`, a developer's own desktop, its window and live audio;
and `metal`, a console's own hardware under Jab Metal.

## exe-name

An executable's file name on this host: `<name>.exe` on Windows, which
a path checked for the file has to name whole.

## role

This machine's declared role, `role` under `[system]` in `jab/debug.toml`
under the XDG config home (config-file). Where the file is missing it is
written from the workspace's `asset/default/debug.toml`, `role =
'unknown'`, never over one there, and the machine's user sets the role once,
TheUser's design for a developer's tool, whose tests are never run by
accident. A role outside `roles`, or none, is refused naming the file. The
machine declares it, so nothing infers it from the machine's surroundings;
a record of a run keeps the role its run read, and a reader of the record
never reads its own machine's.

## system-alias

This system's alias, `alias` under `[system]` in `lowkick/config.toml`
under the XDG config home: the nickname its user gives the system in place
of its hostname, which no record carries (HostnamesOut). Where the file is
missing it is written with `alias = 'lowkick'`, the default, and the user
changes it once, as a hostname is changed. A file naming no alias, or an
empty one, is refused naming the file. An alias is an operator's label,
never an attestation of the hardware.

## config-file

A file in `dir` under the XDG config home, `$XDG_CONFIG_HOME` or
`~/.config`, which is checked and never made, as `spec configured` holds
it; `dir` under it is made, our leaf, and the file is the caller's to read
or write.

## system-key

A TOML file's value at `key` under `[system]`, null where it names none; a
file that is no TOML the tools read is refused naming it.
