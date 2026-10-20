//! A payload on its way into one of QEMU's pipes, its progress kept across its attempts.

use crate::*;
use crate::link::{Carry, Link};
use crate::receipt::Done;

/// Where a payload goes: a fifo QEMU reads, or the connection a relay holds.
enum Route {
    Fifo { path: PathBuf, open: Option<File> },
    Link { link: usize, carry: Option<Carry> },
}

/// What an attempt left: the payload whole, still waiting, or its pipe broken once bytes went in.
#[derive(Debug, PartialEq, Eq)]
pub(crate) enum Step {
    Whole,
    Waiting,
    Broken(String),
}

/// A payload's bytes, its route, and its account: accepted bytes, its first attempt, its completion.
pub(crate) struct Payload {
    pub done: Done,
    bytes: Arc<[u8]>,
    route: Route,
    pipe: String,
}

impl Payload {
    /// A payload for the pipe `pipe`, its end `path`: a relay's endpoint, else a fifo's path.
    pub(crate) fn new(kind: &str, index: u64, due_ns: u64, bytes: &[u8], pipe: &str, path: &str, links: &[Link]) -> Payload {
        let route = match links.iter().position(|l| l.endpoint == path) {
            Some(link) => Route::Link { link, carry: None },
            None => Route::Fifo { path: PathBuf::from(path), open: None },
        };
        let done = Done {
            kind: kind.to_owned(),
            index,
            due_ns,
            length: bytes.len() as u64,
            state: "unattempted".to_owned(),
            ..Done::default()
        };
        Payload { done, bytes: Arc::from(bytes), route, pipe: pipe.to_owned() }
    }

    /// One attempt, every write without blocking: what remains goes in, on the open it began with.
    pub(crate) fn attempt(&mut self, go: Instant, links: &[Link]) -> Step {
        if self.done.first_ns.is_none() {
            self.done.first_ns = Some(since(go));
        }
        let step = match &mut self.route {
            Route::Fifo { path, open } => fifo_attempt(path, open, &self.bytes, &mut self.done.accepted, &self.pipe),
            Route::Link { link, carry } => {
                let carry = carry.get_or_insert_with(|| links[*link].carry(self.bytes.clone()));
                self.done.accepted = carry.accepted();
                match carry.result() {
                    None => Step::Waiting,
                    Some((at, Ok(()))) => {
                        self.done.done_ns = Some(at.saturating_duration_since(go).as_nanos() as u64);
                        Step::Whole
                    }
                    Some((_, Err(_))) if self.done.accepted == 0 => Step::Waiting,
                    Some((_, Err(error))) => Step::Broken(format!("the {} pipe failed with {} of {} bytes in: {error}", self.pipe, self.done.accepted, self.done.length)),
                }
            }
        };
        if step == Step::Whole && self.done.done_ns.is_none() {
            self.done.done_ns = Some(since(go));
        }
        step
    }

    /// The payload's account as the receipt carries it: complete, incomplete, or unattempted.
    pub(crate) fn account(&self) -> Done {
        let mut done = self.done.clone();
        done.state = if done.done_ns.is_some() {
            "complete"
        } else if done.first_ns.is_some() {
            "incomplete"
        } else {
            "unattempted"
        }
        .to_owned();
        done
    }
}

/// Nanoseconds since the go, read now.
pub(crate) fn since(go: Instant) -> u64 {
    go.elapsed().as_nanos() as u64
}

/// A fifo attempt: opened for writing without blocking, held until the payload is whole.
fn fifo_attempt(path: &Path, open: &mut Option<File>, bytes: &[u8], accepted: &mut u64, pipe: &str) -> Step {
    #[cfg(unix)]
    use std::os::unix::fs::OpenOptionsExt;
    if open.is_none() {
        let mut options = OpenOptions::new();
        options.write(true);
        #[cfg(unix)]
        options.custom_flags(libc::O_NONBLOCK);
        match options.open(path) {
            Ok(file) => *open = Some(file),
            #[cfg(unix)]
            Err(error) if error.raw_os_error() == Some(libc::ENXIO) => return Step::Waiting,
            Err(error) => return Step::Broken(format!("the {pipe} pipe, {}: {error}", path.display())),
        }
    }
    let Some(file) = open.as_mut() else {
        return Step::Waiting;
    };
    while (*accepted as usize) < bytes.len() {
        match file.write(&bytes[*accepted as usize..]) {
            Ok(0) => return Step::Waiting,
            Ok(wrote) => *accepted += wrote as u64,
            Err(error) if error.kind() == io::ErrorKind::WouldBlock => return Step::Waiting,
            Err(error) if error.kind() == io::ErrorKind::Interrupted => {}
            Err(_) if *accepted == 0 => {
                *open = None;
                return Step::Waiting;
            }
            Err(error) => {
                *open = None;
                return Step::Broken(format!("the {pipe} pipe failed with {} of {} bytes in: {error}", accepted, bytes.len()));
            }
        }
    }
    *open = None;
    Step::Whole
}
