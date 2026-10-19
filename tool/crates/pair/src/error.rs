use crate::*;

/// What stops a bracket: the request, an input past the limits, the model, a bug.
#[derive(Debug)]
pub enum PairError {
    Request(String),
    Unresolvable { step: &'static str, detail: String },
    Model(String),
    Internal(String),
    Io(io::Error),
}

pub type PairResult<T> = Result<T, PairError>;

impl PairError {
    /// A checked operation's overflow, named by its step.
    pub(crate) fn overflow(step: &'static str) -> PairError {
        PairError::Unresolvable {
            step,
            detail: "the arithmetic overflows i128".to_owned(),
        }
    }
}

impl fmt::Display for PairError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            PairError::Request(message) => write!(f, "the request: {message}"),
            PairError::Unresolvable { step, detail } => {
                write!(f, "unresolvable at {step}: {detail}")
            }
            PairError::Model(message) => write!(f, "the model: {message}"),
            PairError::Internal(message) => write!(f, "a broken invariant: {message}"),
            PairError::Io(source) => write!(f, "{source}"),
        }
    }
}

impl Error for PairError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            PairError::Io(source) => Some(source),
            _ => None,
        }
    }
}
