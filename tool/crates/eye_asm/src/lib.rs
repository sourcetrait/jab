pub(crate) use std::{
    collections::{BTreeSet, HashMap, HashSet},
    error::Error,
    fmt, fs, io,
    path::{Component, Path, PathBuf},
};

mod asm;
mod done;
mod effect;
mod error;
mod eye;
mod generate;
mod infer;
mod listing;
mod merge;
mod regs;
mod srcdoc;

pub(crate) use asm::*;
pub(crate) use effect::*;
pub(crate) use eye::*;
pub(crate) use infer::*;
pub(crate) use merge::*;
pub(crate) use regs::*;
pub(crate) use srcdoc::*;

pub use done::done;
pub use error::{EyeError, EyeResult};
pub use generate::generate;
pub use listing::{Listing, listing};

#[cfg(test)]
mod tests {
    mod asm;
    mod effect;
    mod eye;
    mod infer;
    mod merge;
    mod regs;
    mod srcdoc;
}
