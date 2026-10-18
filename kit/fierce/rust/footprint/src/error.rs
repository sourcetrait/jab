use crate::*;

/// What stops the tool: the invocation, a file, or an input it refuses.
#[derive(Debug)]
pub(crate) enum FootprintError {
    Usage(String),
    Io { path: PathBuf, source: io::Error },
    Refused { path: PathBuf, message: String },
}

pub(crate) type FootprintResult<T> = Result<T, FootprintError>;

impl FootprintError {
    /// An io error with the path it happened on.
    pub(crate) fn io(path: &Path) -> impl FnOnce(io::Error) -> FootprintError {
        let path = path.to_path_buf();
        move |source| FootprintError::Io { path, source }
    }

    /// An input refused, with its path.
    pub(crate) fn refused(path: &Path, message: impl Into<String>) -> FootprintError {
        FootprintError::Refused { path: path.to_path_buf(), message: message.into() }
    }
}

impl fmt::Display for FootprintError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            FootprintError::Usage(message) => write!(f, "usage: {message}"),
            FootprintError::Io { path, source } => write!(f, "{}: {source}", path.display()),
            FootprintError::Refused { path, message } => write!(f, "{}: {message}", path.display()),
        }
    }
}

impl Error for FootprintError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            FootprintError::Io { source, .. } => Some(source),
            FootprintError::Usage(_) | FootprintError::Refused { .. } => None,
        }
    }
}
