pub(crate) use std::{
    io::{self, Write},
    path::Path,
    process::ExitCode,
};

pub(crate) use eye_asm as lib;

mod run;

pub use run::run;
