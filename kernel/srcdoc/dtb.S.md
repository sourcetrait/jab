# dtb.S

A reader of the flattened device tree, generic and privilege-neutral: plain
loads over memory with no CSR, no system call, and no knowledge of any
machine, every routine a leaf using the t registers and its own a
registers, with no stack. So machine mode's bootstrap runs it on the tree
QEMU hands hart 0, and a program assembles the same file in (test/dtb)
and runs it on trees of its own. Words are big-endian, read by dtb_be32's
`lwu` and `rev8` (Zbb, which RVA23 carries in both profiles).

A node is named by its offset in the tree, at its BEGIN_NODE token, so 0,
inside the header, means none. The lookups take a tree dtb_check has
passed and lean on what it held: every token, name, and value inside the
structure, every property's name inside the strings, and a node's
properties before its children, so a property belongs to the node opened
last.

## dtb_check

The header first, each field against the bound the caller vouches for:
the magic, the version, the total size, then the reservation block walked
to its empty entry, the strings, and the structure, each inside the total
size. Then the structure whole, token by token: every read inside the
structure, a name NUL-terminated before its end, a property's value inside
it and its name inside the strings, nesting within DTB_DEPTH, and the shape
the format requires, one root, every property inside a node and before its
children, and an END with every node closed. a7 carries a bit a depth, set
once the node open there has closed a child, so a property after a child
is caught as it comes.

## dtb_path

One pass over the structure, with no stack: the depth, the depth matched so
far, and the path's next component. A node one deeper than the last match
is compared with the component; a match deepens the match, and the path
whole is the answer. The node matched last closing short of the path means
no such node.

## dtb_child

From the node's body past its name, or past the whole subtree of the child
before, to the next BEGIN_NODE at the node's own level; an END_NODE there is
the node's end.

## dtb_prop

The node's own properties, which come before its children, so the walk
stops at the first child or the node's end.

## dtb_phandle

The whole structure, every property named phandle of four bytes against
the value, the owner the node opened last.

## dtb_word_phandle

`8 u8`: the property dtb_phandle looks for.
