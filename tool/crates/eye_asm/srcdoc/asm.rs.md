# asm.rs

## struct Stmt

## struct Param

## enum Section

## enum Def

## struct Symbol

## struct Source

## fn scan_asm

A statement belongs to the label current in its own section, so a string
pushed into `.rodata` from inside a routine neither ends the routine's range
nor joins its statements. A macro defined twice keeps its first definition;
the second's body is skipped. A label containing a backslash is a
per-expansion label inside a macro body (`name_\@`), not a symbol; `.L` and
numeric labels are local by the assembler's own rules. A range runs from the
definition to the last statement attributed to it, or to `.endm`. A constant,
`.set` or a `name = value` assignment, is no symbol and joins no label's
statements, so it neither extends a range nor turns a table into code.

## fn param

## fn globals

## fn section_name

## fn section_of

## fn is_ident_char

## fn is_label_char

## fn is_local_label

## fn take_label

## fn assignment

## fn strip_comment

## fn statements

## fn parse_stmt

The op is lowercased, so a macro named in mixed case would not match its
uses.
