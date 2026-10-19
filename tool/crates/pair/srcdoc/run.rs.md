# run.rs

## const USAGE

## fn run

The request comes on stdin, never as an argument, since a run's pairs are
thousands of records. Exit 0 with every case answered, an unresolved case
included; 1 for a request that does not parse or a broken invariant; 2 for
any argument.
