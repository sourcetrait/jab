# lib.rs

The manifest: the std items the crate uses at global scope, the two
modules, and the one public face, `run`. `io` comes in as a module
because `io::Error` would collide with `std::error::Error`.
