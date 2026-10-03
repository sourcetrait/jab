# infer.rs

## const FRAME_SLOT

## struct Tree

## struct Gen

## fn tree

## fn gens

## fn line

## fn generated

A label's syntax is certain only when something calls it. A label that
returns is taken for a routine however it is reached, since a tail jump and
a branch to a shared exit look alike; a label in a table of addresses for a
system call handler; anything else for a jump target. The uncertain cases
defer to the existing .eye in the merge.

## fn is_data

## fn frame_slot

## fn routine

The arguments are the a registers read before they are written, in text
order, not along the flow. A register saved to the stack and restored from
the same slot is not read; a register read after an ecall is that call's
result. A handler reads its arguments from the trap frame's slots, from
FRAME_SLOT up, and its results are its stores to them. All of this only
seeds a new entry: an existing entry's signature always stands.

## fn result

## fn data_type

A label's directives give a type when they agree on a width; a mix, a record
of fields, gives none, its size still feeding the merge.

## fn number

## fn string_bytes

## fn type_bytes
