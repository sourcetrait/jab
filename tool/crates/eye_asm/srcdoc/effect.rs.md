# effect.rs

## const STORES

## const BRANCHES

## const QUIET

`ecall` changes nothing itself: what a system call returns is its call's to
declare, in the handler's entry and the wrapping macro's results. Taken as
writing a0 and a1, it put them in every wrapping macro's scratch list. A
routine's argument detection treats an ecall separately, as writing a0 to
a7, since a register read after one is a result.

## const IMMEDIATE_LAST

## const TABLE

## const CONDITIONALS

## enum Kind

### fn word

## struct MacroFacts

## struct Effect

## fn is_call

## fn is_table

## fn is_return

## fn reads_only

## fn foreign

An op with a dot that no instruction family starts with is a macro from
outside the scanned tree: the SDK's `jab.*` seen from a program's src. It is
taken for a call, which may change any caller-saved register, and nothing is
known of its operands. The test is a prefix list, so a foreign macro named
like an instruction family (`v...`, `f...`) would read as an instruction.

## fn effect

## fn macro_effect

## struct Use

## fn macro_facts

An operand's first access decides it: read first, it is a value, changed in
place when the body also writes it; written first, it names the register a
result lands in. A use that settles the kind by itself overrides that: an
immediate in `li`, in an immediate's slot, in a data directive, or in a
memory operand's offset; a label in `la` or a relocation. A conditional
directive settles nothing. A nested macro passes its operands' facts
through, and the tree's four passes settle nesting four deep.

## fn memory_operand

Only a one-word base counts, so a parenthesised expression such as
`(\a + 1)` stays an immediate.

## fn mentions

## fn use_of
