//! What ends the relay or a client's connection.

use crate::*;

/// What ends the relay: its invocation, its host, its pipe, or a file.
#[derive(Debug)]
pub enum PipeError {
    Usage(String),
    Host(String),
    Connect { pipe: String, within: Option<Duration>, source: io::Error },
    Pipe(io::Error),
    Io { what: String, source: io::Error },
}

/// A relay's or a client's result.
pub type PipeResult<T> = Result<T, PipeError>;

impl PipeError {
    /// An io error with the path or the act it happened on.
    pub(crate) fn io(what: impl Into<String>) -> impl FnOnce(io::Error) -> PipeError {
        let what = what.into();
        move |source| PipeError::Io { what, source }
    }

    /// The relay's exit status for it: 2 where it cannot run, 1 for the rest.
    pub(crate) fn exit_code(&self) -> u8 {
        match self {
            PipeError::Usage(_) | PipeError::Host(_) => 2,
            _ => 1,
        }
    }
}

impl fmt::Display for PipeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            PipeError::Usage(message) => write!(f, "usage: {message}"),
            PipeError::Host(message) => write!(f, "{message}"),
            PipeError::Connect { pipe, within: Some(bound), source } => {
                write!(f, "{pipe}: no connection within {} s: {source}", bound.as_secs_f32())
            }
            PipeError::Connect { pipe, within: None, source } => write!(f, "{pipe}: {source}"),
            PipeError::Pipe(source) => write!(f, "the pipe: {source}"),
            PipeError::Io { what, source } => write!(f, "{what}: {source}"),
        }
    }
}

impl Error for PipeError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            PipeError::Connect { source, .. } | PipeError::Pipe(source) | PipeError::Io { source, .. } => Some(source),
            PipeError::Usage(_) | PipeError::Host(_) => None,
        }
    }
}
