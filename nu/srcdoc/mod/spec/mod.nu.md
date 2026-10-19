# spec

## display_size

The display's size, jab.inc's JAB_DISPLAY_WIDTH by JAB_DISPLAY_HEIGHT:
every screen a launch takes is this many pixels.

## harts_allowed

The harts a machine takes, up to the eight of JAB_HARTS_MAX in jab.inc,
the most the ABI names: a named spec's cores, or a custom machine's
count, which its record labels diagnostic whatever it is.

## row

A spec's row from the workspace's spec data (spec data), its name matched
in any case, held to what the launcher can provision: its cores within
the harts a machine takes (harts_allowed), and the ABI's display, 1920 by
1080 (display_size); otherwise refused, naming the spec and why.

## configured

The default spec: JAB_SPEC where it is set, else `spec` in
`jab/config.toml` under the XDG config home, $XDG_CONFIG_HOME or
~/.config, which is checked and never made; `jab/` under it is made, and
the file, where there is none, seeded from the workspace's
asset/default/config.toml, never over one there.

## read

The system specifications as the tools read them. doc/SPEC.md is the
authority, TheUser's, and the workspace's asset/spec.nuon carries its
definitions for the tools, a table of one row a spec, held to
asset/spec.nutype, the type the table takes, which is read from its file
with the data and kept nowhere in this tool. `spec read` reads any such
pair and `spec data` the workspace's own, the one reader the launcher, a
build's checks, and an image's list share. Every value is checked
against the type field by field: a field missing, a value of another
type, and a field the type does not name, at any depth, are each refused
naming the row and the field, which nushell's own check of a type does
not name. Past the type, the rows must mean something: a spec at least,
every name given and none twice without regard to case, since a
program's manifest names its specs in any case, and every count, clock,
rate, and size the type names above zero, the VRAM only where a spec
gives one. A file that does not parse is refused naming it, NUON's own
refusal of a field given twice in a record among them. Every problem
found is named, a line each. The rows come back as the file has them.
Untyped because it ends in an error.

## data

The workspace's spec data, its asset/spec.nuon held to its
asset/spec.nutype (spec read). Untyped because it ends in an error.

## spec-label

A spec's row as a problem names it: its place, and its name when it
has one.

## spec-meaning

What a spec table means that its type cannot say, a line each: every
name given and none twice without regard to case; each count, clock,
rate, and size the type names above zero, the VRAM only where a spec
gives one. `named` are the type's fields, so a rule for a field the type
no longer names is passed over.
