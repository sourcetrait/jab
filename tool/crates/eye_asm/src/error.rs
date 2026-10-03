use crate::*;

/// What stops an eye tool: the invocation, a path, a file, an .eye line, or
/// sources without the stubs a replacement needs.
#[derive(Debug)]
pub enum EyeError {
    Usage(String),
    Path(String),
    Io { what: String, source: io::Error },
    Parse { what: String, line: usize, message: String },
    MissingStubs(Vec<PathBuf>),
}

pub type EyeResult<T> = Result<T, EyeError>;

impl EyeError {
    /// An io error with the path it happened on.
    pub(crate) fn io(what: &Path) -> impl FnOnce(io::Error) -> EyeError {
        let what = what.display().to_string();
        move |source| EyeError::Io { what, source }
    }
}

impl fmt::Display for EyeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            EyeError::Usage(message) => write!(f, "usage: {message}"),
            EyeError::Path(message) => write!(f, "{message}"),
            EyeError::Io { what, source } => write!(f, "{what}: {source}"),
            EyeError::Parse { what, line, message } => write!(f, "{what}:{line}: {message}"),
            EyeError::MissingStubs(stubs) => {
                write!(f, "no .eye was replaced; these stubs are missing:")?;
                for stub in stubs {
                    write!(f, "\n  {}", stub.display())?;
                }
                Ok(())
            }
        }
    }
}

impl Error for EyeError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            EyeError::Io { source, .. } => Some(source),
            _ => None,
        }
    }
}
