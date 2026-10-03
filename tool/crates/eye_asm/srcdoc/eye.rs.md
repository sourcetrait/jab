# eye.rs

## enum Syntax

### fn parse

### fn word

### fn is_signature

### fn is_code

## struct Arg

## enum Out

## enum Shape

## struct Entry

### fn names

## struct Eye

### fn parse

## fn parse_head

The summary starts at the first ` :`, which nothing before it contains, so a
summary may hold colons, and a line entry's type is everything between its
name and its range.

## fn split_range

## fn parse_signature

A one-word item after a register list continues that list: every result has
a name and a location, so a lone word can only be a register.
