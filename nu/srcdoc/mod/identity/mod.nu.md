# identity

## reader

A reader's identity, which a reading records beside its result: which
code produced it, read by a person and compared by no check, so a tool's
version or identity fails nothing. `roots` are the checkouts the
reader's code comes from, each recorded with its HEAD and whether it holds
changes, or for an export its `source.nuon`'s commit and no state;
`runtime` the interpreter running it, `$nu.current-exe` with its version
and SHA-256 (inside the Grammar MCP that is the MCP itself, beside
`/usr/bin/nu`, one version label on two executables), and with
`--launches` the `nu` its PATH resolves, the one a reader that launches a
script runs; `executables` the programs the reading runs, each by its
file's name and SHA-256, the file required; an interpreter whose
executable cannot be read keeps its version with a null SHA-256. A
reading made by other code is read again, never refused for it.
