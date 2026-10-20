//! The client end of a pipe QEMU's pipe chardev serves on Windows.

use crate::*;

/// How long a client waits between tries while the pipe cannot take it.
pub(crate) const CONNECT_RETRY: Duration = Duration::from_millis(50);

/// How long a client keeps trying before it gives up on the pipe.
pub(crate) const CONNECT_BOUND: Duration = Duration::from_secs(10);

/// Win32's ERROR_PIPE_BUSY: the pipe is there and its one instance taken.
const ERROR_PIPE_BUSY: i32 = 231;

/// The Win32 path of the pipe a chardev's `path` option names.
pub fn pipe_path(name: &str) -> String {
    format!(r"\\.\pipe\{name}")
}

/// Whether an open's failure means only that the pipe cannot take a client yet.
pub(crate) fn pipe_waiting(error: &io::Error) -> bool {
    error.kind() == io::ErrorKind::NotFound || error.raw_os_error() == Some(ERROR_PIPE_BUSY)
}

/// The client end of the pipe `name`, tried with `open` until it connects.
pub fn connect<T>(name: &str, open: impl FnMut(&str) -> io::Result<T>) -> PipeResult<T> {
    connect_within(name, CONNECT_BOUND, CONNECT_RETRY, open)
}

/// The client end of the pipe `name`, tried every `retry` for at most `bound`.
pub(crate) fn connect_within<T>(
    name: &str,
    bound: Duration,
    retry: Duration,
    mut open: impl FnMut(&str) -> io::Result<T>,
) -> PipeResult<T> {
    let pipe = pipe_path(name);
    let started = Instant::now();
    loop {
        match open(&pipe) {
            Ok(end) => return Ok(end),
            Err(source) if pipe_waiting(&source) => {
                if started.elapsed() >= bound {
                    return Err(PipeError::Connect { pipe, within: Some(bound), source });
                }
                thread::sleep(retry);
            }
            Err(source) => return Err(PipeError::Connect { pipe, within: None, source }),
        }
    }
}
