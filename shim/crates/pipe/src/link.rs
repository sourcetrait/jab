//! A supervised launch's required relays, each its pipe's one client, run in-process.

use crate::*;
use std::sync::atomic::{AtomicU64, Ordering};
use tokio::sync::mpsc;

/// How a relay ended: its pipe closed, its connection or I/O failed, or stopped by the supervisor.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) enum Ending {
    Clean,
    Failed(String),
    Stopped,
}

/// What a relay's task tells the supervisor: its connection and its end, each when it happened.
#[derive(Debug, Default)]
pub(crate) struct Seen {
    pub connected: Option<Instant>,
    pub ended: Option<(Instant, Ending)>,
}

/// A carry's end and when: written whole, or the error that stopped it.
pub(crate) type Finished = Option<(Instant, Result<(), String>)>;

/// A payload handed to a relay's writer, the bytes its pipe accepted and its end shared.
#[derive(Clone)]
pub(crate) struct Carry {
    bytes: Arc<[u8]>,
    accepted: Arc<AtomicU64>,
    result: Arc<Mutex<Finished>>,
}

impl Carry {
    pub(crate) fn new(bytes: Arc<[u8]>) -> Carry {
        Carry { bytes, accepted: Arc::new(AtomicU64::new(0)), result: Arc::new(Mutex::new(None)) }
    }

    /// The bytes the pipe has accepted so far.
    pub(crate) fn accepted(&self) -> u64 {
        self.accepted.load(Ordering::SeqCst)
    }

    /// The carry's end and when, once the writer has finished with it.
    pub(crate) fn result(&self) -> Finished {
        self.result.lock().map(|r| r.clone()).unwrap_or(None)
    }

    /// The payload written whole by an explicit loop of writes, each one's bytes counted.
    async fn write<W: tokio::io::AsyncWrite + Unpin>(&self, to: &mut W) -> io::Result<()> {
        let mut at = self.accepted() as usize;
        while at < self.bytes.len() {
            let wrote = to.write(&self.bytes[at..]).await?;
            if wrote == 0 {
                return Err(io::ErrorKind::WriteZero.into());
            }
            at += wrote;
            self.accepted.store(at as u64, Ordering::SeqCst);
        }
        to.flush().await
    }

    /// The carry's end set once, the first word standing.
    fn finish(&self, end: Result<(), String>) {
        if let Ok(mut result) = self.result.lock()
            && result.is_none()
        {
            *result = Some((Instant::now(), end));
        }
    }
}

/// A carry in the writer's hands: ended by the pipe's end if the write never finished it.
struct InHand(Carry);

impl Drop for InHand {
    fn drop(&mut self) {
        self.0.finish(Err("the pipe ended before it went in whole".to_owned()));
    }
}

/// A relay the supervisor runs: its endpoint, its pipe's name, what it saw, and its writer's queue.
pub(crate) struct Link {
    pub endpoint: String,
    pub name: String,
    seen: Arc<Mutex<Seen>>,
    queue: mpsc::UnboundedSender<Carry>,
    task: tokio::task::JoinHandle<()>,
}

impl Link {
    /// A relay started on `runtime`: connected by `connector` before `deadline`, then relayed.
    pub(crate) fn start<C, S>(
        runtime: &tokio::runtime::Runtime,
        endpoint: &str,
        name: &str,
        connector: C,
        inward: Option<PathBuf>,
        outward: PathBuf,
        deadline: Instant,
    ) -> Link
    where
        C: FnMut() -> io::Result<S> + Send + 'static,
        S: tokio::io::AsyncRead + tokio::io::AsyncWrite + Send + 'static,
    {
        let seen = Arc::new(Mutex::new(Seen::default()));
        let (queue, carries) = mpsc::unbounded_channel();
        let task = runtime.spawn(serve(connector, seen.clone(), carries, inward, outward, deadline));
        Link { endpoint: endpoint.to_owned(), name: name.to_owned(), seen, queue, task }
    }

    /// A payload queued for the pipe, written after the ones before it.
    pub(crate) fn carry(&self, bytes: Arc<[u8]>) -> Carry {
        let carry = Carry::new(bytes);
        if self.queue.send(carry.clone()).is_err() {
            carry.finish(Err("the relay had ended".to_owned()));
        }
        carry
    }

    /// When it connected, and when and how it ended, as its task saw them.
    pub(crate) fn seen(&self) -> (Option<Instant>, Option<(Instant, Ending)>) {
        match self.seen.lock() {
            Ok(seen) => (seen.connected, seen.ended.clone()),
            Err(_) => (None, Some((Instant::now(), Ending::Failed("its state was lost".to_owned())))),
        }
    }

    /// The relay stopped where it stands, an end not yet seen recorded as stopped.
    pub(crate) fn stop(&self) {
        self.task.abort();
        if let Ok(mut seen) = self.seen.lock()
            && seen.ended.is_none()
        {
            seen.ended = Some((Instant::now(), Ending::Stopped));
        }
    }
}

/// A relay's whole life: the connection's tries, then both directions until the pipe ends.
async fn serve<C, S>(
    mut connector: C,
    seen: Arc<Mutex<Seen>>,
    carries: mpsc::UnboundedReceiver<Carry>,
    inward: Option<PathBuf>,
    outward: PathBuf,
    deadline: Instant,
) where
    C: FnMut() -> io::Result<S>,
    S: tokio::io::AsyncRead + tokio::io::AsyncWrite,
{
    let ended = |end: Ending| {
        if let Ok(mut seen) = seen.lock()
            && seen.ended.is_none()
        {
            seen.ended = Some((Instant::now(), end));
        }
    };
    let stream = loop {
        match connector() {
            Ok(stream) => break stream,
            Err(error) if connect::waiting(&error) && Instant::now() < deadline => {
                tokio::time::sleep(connect::CONNECT_RETRY).await;
            }
            Err(error) if connect::waiting(&error) => {
                return ended(Ending::Failed(format!("no connection within its allowance: {error}")));
            }
            Err(error) => return ended(Ending::Failed(error.to_string())),
        }
    };
    if let Ok(mut seen) = seen.lock() {
        seen.connected = Some(Instant::now());
    }
    let end = match relay_carrying(stream, carries, inward.as_deref(), &outward, POLL, GRACE).await {
        Ok(()) => Ending::Clean,
        Err(error) => Ending::Failed(error.to_string()),
    };
    ended(end);
}

/// One pipe relayed with its files and its queue until it ends, the drain biased as `relay` is.
pub(crate) async fn relay_carrying<S>(
    stream: S,
    carries: mpsc::UnboundedReceiver<Carry>,
    inward: Option<&Path>,
    outward: &Path,
    poll: Duration,
    grace: Duration,
) -> PipeResult<()>
where
    S: tokio::io::AsyncRead + tokio::io::AsyncWrite,
{
    let (mut from, mut to) = tokio::io::split(stream);
    let mut output = OpenOptions::new()
        .append(true)
        .create(true)
        .open(outward)
        .map_err(PipeError::io(outward.display().to_string()))?;
    let input = match inward {
        Some(path) => Some((File::open(path).map_err(PipeError::io(path.display().to_string()))?, path)),
        None => None,
    };
    let drained = drain(&mut from, &mut output, outward);
    let written = write_side(&mut to, input, carries, poll);
    tokio::pin!(drained, written);
    tokio::select! {
        biased;
        end = &mut drained => end.map(|_| ()),
        end = &mut written => match end {
            PipeError::Pipe(refused) => match tokio::time::timeout(grace, drained).await {
                Ok(end) => end.map(|_| ()),
                Err(_) => Err(PipeError::Pipe(refused)),
            },
            other => Err(other),
        },
    }
}

/// The writing half: the in-file's appended bytes and each queued payload, one at a time, in order.
async fn write_side<W: tokio::io::AsyncWrite + Unpin>(
    to: &mut W,
    mut input: Option<(File, &Path)>,
    mut carries: mpsc::UnboundedReceiver<Carry>,
    poll: Duration,
) -> PipeError {
    let mut buffer = vec![0u8; 4096];
    let mut queued = true;
    loop {
        if let Some((file, path)) = input.as_mut() {
            loop {
                match file.read(&mut buffer) {
                    Ok(0) => break,
                    Ok(read) => {
                        if let Err(error) = to.write_all(&buffer[..read]).await {
                            return PipeError::Pipe(error);
                        }
                    }
                    Err(error) if error.kind() == io::ErrorKind::Interrupted => {}
                    Err(source) => return PipeError::Io { what: path.display().to_string(), source },
                }
            }
        }
        tokio::select! {
            carry = carries.recv(), if queued => match carry {
                Some(carry) => {
                    let held = InHand(carry);
                    let end = held.0.write(to).await;
                    held.0.finish(end.as_ref().map(|_| ()).map_err(|e| e.to_string()));
                    if let Err(error) = end {
                        return PipeError::Pipe(error);
                    }
                }
                None => queued = false,
            },
            _ = tokio::time::sleep(poll) => {}
        }
    }
}
