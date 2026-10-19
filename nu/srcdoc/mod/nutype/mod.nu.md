# nutype

## spec_scalars

The scalar types a spec's type may name.

## model

A type's text as nushell writes it, comment lines aside, as its parts:
`table` and `record` with their fields in order, `list` with its
element, `oneof` with its members, and a scalar by its name. Only that
much of the type grammar is read, and anything else is refused naming
it, so a type the tools cannot hold a spec to never passes as one they
can. Untyped because it ends in an error.

## type-parse

The type that starts at word `at` of a type's words, and the word after
it. Untyped because it ends in an error.

## type-name

A type's part as nushell writes it.

## field-path

A field's path below `at`, "" being a row's own.

## record-problems

What is wrong with a record against its fields, a line each, `at` the
path to it: a field missing, a value of another type, and a field the
type does not name.

## value-problems

What is wrong with a value against its part of a type, a line each, `at`
its path; none when it holds.

## problems

A value held to a type's text: the text parsed into its parts (model),
then every problem of the value against them, a line each, the path to
each part leading it; none when the value holds. DataModels' records and
the spec data are held to their `.nutype` this way.
