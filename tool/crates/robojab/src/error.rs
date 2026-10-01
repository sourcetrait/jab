use crate::*;

/// What stops the harness: the invocation, a file, the plan, the machine,
/// a command, or an image.
#[derive(Debug)]
pub(crate) enum RoboError {
    Usage(String),
    Io { what: String, source: io::Error },
    Plan(String),
    Machine(String),
    Command(String),
    Image(String),
}

pub(crate) type RoboResult<T> = Result<T, RoboError>;

impl RoboError {
    /// An io error with the path or the act it happened on.
    pub(crate) fn io(what: impl Into<String>) -> impl FnOnce(io::Error) -> RoboError {
        let what = what.into();
        move |source| RoboError::Io { what, source }
    }
}

impl fmt::Display for RoboError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            RoboError::Usage(message) => write!(f, "usage: {message}"),
            RoboError::Io { what, source } => write!(f, "{what}: {source}"),
            RoboError::Plan(message) => write!(f, "plan: {message}"),
            RoboError::Machine(message) => write!(f, "machine: {message}"),
            RoboError::Command(message) => write!(f, "{message}"),
            RoboError::Image(message) => write!(f, "image: {message}"),
        }
    }
}

impl Error for RoboError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            RoboError::Io { source, .. } => Some(source),
            _ => None,
        }
    }
}
