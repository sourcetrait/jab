//! A supervised launch's schedule, as the SDK prepares it before the spawn.

use crate::*;

/// The launch's kind: bounded, in a group of its own, or the terminal's.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone, Copy, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub(crate) enum Mode {
    Bounded,
    Interactive,
}

/// Everything the supervisor does, from the spawn to the receipt.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct Schedule {
    /// The launch's control token, sixteen lowercase hex digits.
    pub token: String,
    pub mode: Mode,
    /// The run's directory: the control files and the child's streams.
    pub dir: String,
    /// The measured command the gate runs: the bound's `timeout` and QEMU, or QEMU.
    pub command: Vec<String>,
    /// The child's environment beside the caller's; the supervisor's own untouched.
    #[serde(default)]
    pub env: Vec<Variable>,
    /// Where a bounded child's stdout and stderr go, "" for a terminal's.
    #[serde(default)]
    pub stdout: String,
    #[serde(default)]
    pub stderr: String,
    /// QEMU's pidfile, "" with none.
    #[serde(default)]
    pub pidfile: String,
    /// Each pipe an action writes: a fifo's path, or a Windows relay's endpoint.
    #[serde(default)]
    pub pipes: Vec<PipeEnd>,
    /// The pad port's header, written once QEMU is alive, ahead of every action.
    #[serde(default)]
    pub header: Option<PipeBytes>,
    /// The timed actions in their order, each when due and after the one before.
    #[serde(default)]
    pub actions: Vec<Action>,
    /// The thread readings asked, each at its time beside the actions.
    #[serde(default)]
    pub readings: Vec<Reading>,
    /// The relays a Windows launch requires, one a pipe with no client of its own.
    #[serde(default)]
    pub relays: Vec<Relay>,
    /// The helpers run beside the child from the go, the pad bridge among them.
    #[serde(default)]
    pub helpers: Vec<Helper>,
    pub bounds: Bounds,
}

/// A helper run beside the child: its name, command, and stderr's file.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct Helper {
    pub name: String,
    pub command: Vec<String>,
    pub stderr: String,
}

/// One variable of the child's environment.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct Variable {
    pub name: String,
    pub value: String,
}

/// A pipe an action writes: off Windows a fifo QEMU reads; on Windows a relay's.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct PipeEnd {
    pub name: String,
    pub path: String,
}

/// Bytes into one of the launch's pipes.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct PipeBytes {
    pub pipe: String,
    pub bytes: Vec<u8>,
}

/// A timed action: a key, a send, a pad group, the screen, or a `quit`.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct Action {
    pub kind: String,
    /// Its index in its own table: the keys', the sends', the pad's groups'.
    pub index: u64,
    /// When it falls due, in nanoseconds from the go.
    pub due_ns: u64,
    pub pipe: String,
    pub bytes: Vec<u8>,
    /// A screen's file and what makes it whole.
    #[serde(default)]
    pub screen: Option<Screen>,
}

/// A screen's file, its expected header, and its whole size.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct Screen {
    pub file: String,
    pub header: Vec<u8>,
    pub size: u64,
}

/// A thread reading: `held`, of `--threads`, or `at`, of `--threads-at`.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct Reading {
    pub kind: String,
    pub index: u64,
    pub requested_ns: u64,
}

/// A relay a launch requires: its endpoint, pipe name, in-file, and out-file.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct Relay {
    pub endpoint: String,
    pub name: String,
    #[serde(default)]
    pub inward: String,
    pub outward: String,
}

/// The bounds, each in nanoseconds.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct Bounds {
    /// The startup's allowance: the readiness, the go, every relay's receipt.
    pub startup_ns: u64,
    /// How often a waiting payload is tried again while QEMU lives.
    pub retry_ns: u64,
    /// How long a screen is looked for whole, and how often.
    pub screen_ns: u64,
    pub screen_poll_ns: u64,
    /// How often QEMU's CPU seconds are sampled.
    pub cpu_ns: u64,
    /// A relay's clean end while QEMU runs: the grace before it fails the launch.
    pub grace_ns: u64,
    /// A termination's grace between TERM and KILL.
    pub term_ns: u64,
}

impl Schedule {
    /// The schedule a file holds, held to what the supervisor needs of it.
    pub(crate) fn load(path: &Path) -> PipeResult<Schedule> {
        let schedule: Schedule = read_json(path)?.ok_or_else(|| PipeError::Usage(format!("no schedule at {}", path.display())))?;
        let problems = schedule.problems();
        if !problems.is_empty() {
            return Err(PipeError::Usage(format!("{}: {}", path.display(), problems.join("; "))));
        }
        Ok(schedule)
    }

    /// What keeps the schedule from being run, each named.
    pub(crate) fn problems(&self) -> Vec<String> {
        let mut problems = Vec::new();
        if !token_ok(&self.token) {
            problems.push(format!("the token {:?} is no sixteen lowercase hex digits", self.token));
        }
        if self.command.is_empty() {
            problems.push("no command to run".to_owned());
        }
        if self.mode == Mode::Bounded && (self.stdout.is_empty() || self.stderr.is_empty()) {
            problems.push("a bounded launch names the files its child's stdout and stderr go to".to_owned());
        }
        for (at, relay) in self.relays.iter().enumerate() {
            if self.relays[..at].iter().any(|r| r.endpoint == relay.endpoint) {
                problems.push(format!("the relay endpoint {:?} named twice", relay.endpoint));
            }
        }
        for helper in &self.helpers {
            if helper.command.is_empty() || helper.stderr.is_empty() {
                problems.push(format!("the helper {:?} names no command or no file for its stderr", helper.name));
            }
        }
        let named = |pipe: &str| self.pipes.iter().any(|p| p.name == pipe);
        for action in &self.actions {
            if !named(&action.pipe) {
                problems.push(format!("the {} {} writes the pipe {:?}, which the schedule names no end of", action.kind, action.index, action.pipe));
            }
            if action.kind == "screen" && action.screen.is_none() {
                problems.push(format!("the screen {} names no file", action.index));
            }
        }
        if let Some(header) = &self.header
            && !named(&header.pipe)
        {
            problems.push(format!("the header writes the pipe {:?}, which the schedule names no end of", header.pipe));
        }
        if self.mode == Mode::Interactive && (!self.actions.is_empty() || !self.readings.is_empty() || self.header.is_some()) {
            problems.push("an interactive launch carries no timed action or reading".to_owned());
        }
        problems
    }

    /// The pipe an action names.
    pub(crate) fn pipe(&self, name: &str) -> Option<&PipeEnd> {
        self.pipes.iter().find(|p| p.name == name)
    }
}

/// A bound in nanoseconds as a duration.
pub(crate) fn from_ns(value: u64) -> Duration {
    Duration::from_nanos(value)
}
