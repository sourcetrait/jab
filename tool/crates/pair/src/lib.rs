pub(crate) use std::{
    cmp::Ordering,
    error::Error,
    fmt,
    io::{self, Read, Write},
    process::ExitCode,
};

mod envelope;
mod error;
mod ratio;
mod run;
mod solve;
mod wire;

pub(crate) use envelope::*;
pub(crate) use ratio::*;
pub(crate) use solve::*;
pub(crate) use wire::*;

pub use error::{PairError, PairResult};
pub use run::run;

#[cfg(test)]
mod tests {
    mod envelope;
    mod ratio;
    mod solve;
    mod wire;
}
