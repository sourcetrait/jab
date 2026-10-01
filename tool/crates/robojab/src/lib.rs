pub(crate) use std::{
    collections::HashMap,
    error::Error,
    fmt, fs,
    io::{self, BufRead, BufReader, Read, Seek, SeekFrom, Write},
    os::unix::{
        fs::OpenOptionsExt,
        net::{UnixListener, UnixStream},
    },
    path::{Path, PathBuf},
    process::{Child, Command, ExitCode, Stdio},
    sync::{Arc, Mutex, MutexGuard},
    thread,
    time::{Duration, Instant},
};

pub(crate) use base64::Engine;
pub(crate) use image::ImageEncoder;
pub(crate) use rmcp::ServiceExt;

pub(crate) mod r {
    pub(crate) mod b64 {
        pub(crate) use base64::engine::general_purpose::STANDARD;
    }
    pub(crate) mod img {
        pub(crate) use image::{
            ExtendedColorType,
            codecs::{jpeg::JpegEncoder, png::PngEncoder},
        };
    }
    pub(crate) mod mcp {
        pub(crate) use rmcp::{
            ServerHandler,
            handler::server::{router::tool::ToolRouter, wrapper::Parameters},
            model::{CallToolResult, ContentBlock, Implementation, ServerCapabilities, ServerConfig},
            tool, tool_handler, tool_router,
            transport::stdio,
        };
    }
}

mod client;
mod driver;
mod error;
mod machine;
mod mcp;
mod pad;
mod plan;
mod run;
mod screen;
mod socket;

pub(crate) use client::*;
pub(crate) use driver::*;
pub(crate) use error::*;
pub(crate) use machine::*;
pub(crate) use mcp::*;
pub(crate) use pad::*;
pub(crate) use plan::*;
pub(crate) use screen::*;
pub(crate) use socket::*;

pub use run::run;
