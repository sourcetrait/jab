//! The relay's two directions between a pipe and its two files.

use crate::*;

/// How often the in-file is read for what was appended to it since.
pub(crate) const POLL: Duration = Duration::from_millis(10);

/// How long the pipe's output may go on arriving once it refused a write.
pub(crate) const GRACE: Duration = Duration::from_secs(1);

/// What the pipe gives, appended to `output` as it arrives, until it ends.
pub(crate) async fn drain<R: tokio::io::AsyncRead + Unpin>(pipe: &mut R, output: &mut File, outward: &Path) -> PipeResult<u64> {
    let mut buffer = vec![0u8; 4096];
    let mut total = 0;
    loop {
        let read = match pipe.read(&mut buffer).await {
            Ok(0) => return Ok(total),
            Ok(read) => read,
            Err(error) if error.kind() == io::ErrorKind::BrokenPipe => return Ok(total),
            Err(error) => return Err(PipeError::Pipe(error)),
        };
        output.write_all(&buffer[..read]).map_err(PipeError::io(outward.display().to_string()))?;
        total += read as u64;
    }
}

/// Every byte appended to `input`, read every `poll`, written into the pipe.
pub(crate) async fn forward<W: tokio::io::AsyncWrite + Unpin>(
    input: &mut File,
    pipe: &mut W,
    inward: &Path,
    poll: Duration,
) -> PipeError {
    let mut buffer = vec![0u8; 4096];
    loop {
        match input.read(&mut buffer) {
            Ok(0) => tokio::time::sleep(poll).await,
            Ok(read) => {
                if let Err(error) = pipe.write_all(&buffer[..read]).await {
                    return PipeError::Pipe(error);
                }
            }
            Err(error) if error.kind() == io::ErrorKind::Interrupted => {}
            Err(source) => return PipeError::Io { what: inward.display().to_string(), source },
        }
    }
}

/// A pipe relayed with its files until it ends, the in-file in, the pipe out.
pub(crate) async fn relay<R, W>(
    mut from: R,
    mut to: W,
    inward: &Path,
    outward: &Path,
    poll: Duration,
    grace: Duration,
) -> PipeResult<()>
where
    R: tokio::io::AsyncRead + Unpin,
    W: tokio::io::AsyncWrite + Unpin,
{
    let mut input = File::open(inward).map_err(PipeError::io(inward.display().to_string()))?;
    let mut output = OpenOptions::new()
        .append(true)
        .create(true)
        .open(outward)
        .map_err(PipeError::io(outward.display().to_string()))?;
    let drained = drain(&mut from, &mut output, outward);
    let forwarded = forward(&mut input, &mut to, inward, poll);
    tokio::pin!(drained, forwarded);
    tokio::select! {
        biased;
        end = &mut drained => end.map(|_| ()),
        end = &mut forwarded => match end {
            PipeError::Pipe(refused) => match tokio::time::timeout(grace, drained).await {
                Ok(end) => end.map(|_| ()),
                Err(_) => Err(PipeError::Pipe(refused)),
            },
            other => Err(other),
        },
    }
}

/// The relay over one duplex pipe, split into its reading and writing halves.
pub(crate) async fn relay_duplex<P>(pipe: P, inward: &Path, outward: &Path) -> PipeResult<()>
where
    P: tokio::io::AsyncRead + tokio::io::AsyncWrite,
{
    let (from, to) = tokio::io::split(pipe);
    relay(from, to, inward, outward, POLL, GRACE).await
}
