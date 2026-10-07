use crate::*;

/// What stops a rasterisation: the invocation, a file, the SVG, or the pixmap.
#[derive(Debug)]
pub(crate) enum Svg2PngError {
    Usage,
    Io { path: PathBuf, source: io::Error },
    Svg { path: PathBuf, source: resvg::usvg::Error },
    Size { width: f32, height: f32 },
    Png { path: PathBuf, message: String },
}

pub(crate) type Svg2PngResult<T> = Result<T, Svg2PngError>;

impl fmt::Display for Svg2PngError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Svg2PngError::Usage => write!(f, "usage: svg2png <in.svg> <out.png> [scale]"),
            Svg2PngError::Io { path, source } => write!(f, "{}: {source}", path.display()),
            Svg2PngError::Svg { path, source } => write!(f, "{}: {source}", path.display()),
            Svg2PngError::Size { width, height } => write!(f, "no pixmap of {width} by {height}"),
            Svg2PngError::Png { path, message } => write!(f, "{}: {message}", path.display()),
        }
    }
}

impl Error for Svg2PngError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Svg2PngError::Usage | Svg2PngError::Size { .. } | Svg2PngError::Png { .. } => None,
            Svg2PngError::Io { source, .. } => Some(source),
            Svg2PngError::Svg { source, .. } => Some(source),
        }
    }
}
