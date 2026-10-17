#![cfg_attr(not(windows), allow(dead_code, unused_imports))]

pub(crate) use std::{
    env,
    error::Error,
    fmt,
    fs::{File, OpenOptions},
    io::{self, Read, Write},
    path::Path,
    process::ExitCode,
    thread,
    time::{Duration, Instant},
};

pub(crate) use tokio::io::{AsyncReadExt, AsyncWriteExt};

#[cfg(windows)]
pub(crate) mod r {
    pub(crate) mod np {
        pub(crate) use tokio::net::windows::named_pipe::ClientOptions;
    }
}

mod connect;
mod error;
mod relay;
mod run;

pub(crate) use relay::*;

pub use connect::{connect, pipe_path};
pub use error::{PipeError, PipeResult};
pub use run::run;

#[cfg(test)]
mod tests {
    mod connect;
    mod relay;
}
