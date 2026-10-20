#![cfg_attr(not(windows), allow(dead_code, unused_imports))]

pub(crate) use std::{
    env,
    error::Error,
    fmt,
    fs::{File, OpenOptions},
    io::{self, Read, Write},
    path::{Path, PathBuf},
    process::ExitCode,
    sync::{Arc, Mutex},
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

mod child;
mod connect;
mod control;
mod error;
#[cfg(unix)]
mod gate;
#[cfg(unix)]
mod group;
mod helper;
mod link;
mod lock;
mod payload;
mod receipt;
mod relay;
mod run;
mod schedule;
mod supervise;
mod table;

pub(crate) use relay::*;

pub use connect::{connect, pipe_path};
pub use error::{PipeError, PipeResult};
pub use run::run;

#[cfg(test)]
mod tests {
    mod connect;
    mod link;
    mod lock;
    mod relay;
}
