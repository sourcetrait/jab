# eye.rs

## enum Syntax

The ways an item is entered, the flow a reader follows to find code before
reading a source. A constant, a data label, or a linker symbol is no entry;
its words live in the source's `.md`. A line naming one is refused, so an
.eye written before the change fails to parse rather than losing its words
quietly at the next stub.

### fn parse

### fn word

### fn is_code

## struct Arg

## enum Out

## struct Entry

### fn names

## struct Eye

### fn parse

## fn parse_head

The summary starts at the first ` :`, which nothing before it contains, so a
summary may hold colons.

## fn split_range

## fn parse_signature

A one-word item after a register list continues that list: every result has
a name and a location, so a lone word can only be a register.
