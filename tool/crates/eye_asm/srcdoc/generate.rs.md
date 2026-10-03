# generate.rs

## fn generate

The whole source directory is scanned even for one file, since whether a
label is called, and what a nested macro writes, come from every source.

## fn read_if_present

## fn ignored_names

An ignore file is written by hand and only ever read. Its lines match by
name alone, since a label's syntax word may differ from the generator's
guess.
