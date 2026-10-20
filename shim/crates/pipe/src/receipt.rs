//! A launch's readiness, its startup's outcome, and its exit receipt.

/// The startup's one decision, published before the supervisor acts on it.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone, PartialEq, Eq)]
pub(crate) struct Outcome {
    pub token: String,
    /// `go`, `cancelled`, or `expired`.
    pub decision: String,
    /// The realtime clock as the go was decided, for dates alone; null otherwise.
    pub go_utc: Option<String>,
}

/// The supervisor's readiness, the run's ownership record.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct Readiness {
    pub token: String,
    pub supervisor: Process,
    pub gate: Gate,
}

/// A process by its pid and the start the process table gives it.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone, PartialEq, Eq)]
pub(crate) struct Process {
    pub pid: i64,
    pub start: Option<u64>,
}

/// The gate: its pid, its group, and its start.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone, PartialEq, Eq)]
pub(crate) struct Gate {
    pub pid: i64,
    pub group: Option<i64>,
    pub start: Option<u64>,
}

/// A request naming the launch it is for: the caller's go, or its cancel.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct Authorization {
    pub token: String,
}

/// A payload's account: its bytes accepted, its first attempt, its completion.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone, Default)]
pub(crate) struct Done {
    pub kind: String,
    pub index: u64,
    pub due_ns: u64,
    pub length: u64,
    pub accepted: u64,
    /// `complete`, `incomplete`, or `unattempted`.
    pub state: String,
    pub first_ns: Option<u64>,
    pub done_ns: Option<u64>,
    /// A screen's: when its file was seen whole, and whether it was.
    pub whole_ns: Option<u64>,
    pub whole: Option<bool>,
}

/// The action the hold stopped at, and why.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct Held {
    pub kind: String,
    pub index: u64,
    pub why: String,
}

/// One thread of a reading.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone, PartialEq)]
pub(crate) struct Thread {
    pub id: String,
    pub name: String,
    pub cpu: f64,
}

/// A thread reading as taken: asked, started, ended, its threads; or never taken.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct Taken {
    pub kind: String,
    pub index: u64,
    pub requested_ns: u64,
    pub start_ns: Option<u64>,
    pub end_ns: Option<u64>,
    pub threads: Option<Vec<Thread>>,
}

/// A required relay: its connection and its end.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct RelayEnd {
    pub endpoint: String,
    pub name: String,
    pub connected_ns: Option<u64>,
    pub ended_ns: Option<u64>,
    /// `clean`, `failed`, `stopped`, or `never`.
    pub state: String,
    pub said: String,
}

/// A helper's run: its start, its end, and how it ended.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct HelperEnd {
    pub name: String,
    pub pid: Option<i64>,
    pub started_ns: Option<u64>,
    pub ended_ns: Option<u64>,
    pub status: Option<i32>,
    /// `clean`, `failed`, `stopped`, or `never`.
    pub state: String,
    pub said: String,
}

/// The clock every time of the receipt is on.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct Clock {
    pub origin: String,
    pub unit: String,
    pub go_utc: Option<String>,
}

/// The supervisor's exit receipt.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct Receipt {
    pub token: String,
    pub outcome: Outcome,
    pub header: Option<Done>,
    pub actions: Vec<Done>,
    pub held: Option<Held>,
    pub readings: Vec<Taken>,
    pub relays: Vec<RelayEnd>,
    pub helpers: Vec<HelperEnd>,
    /// The run's end, the child reaped once nothing it owns runs; null with no run.
    pub end_ns: Option<u64>,
    pub cpu_seconds: Option<f64>,
    pub qemu_pid: Option<i64>,
    /// The measured command's exit: its status, or the signal that ended it.
    pub status: Option<i32>,
    pub signal: Option<i32>,
    pub stdout: String,
    pub stderr: String,
    /// What failed the launch, named; null for a run that ended as it should.
    pub failure: Option<String>,
    /// When the caller's cancel was read after the go; null when none was.
    pub cancelled_ns: Option<u64>,
    /// The startup's length: the supervisor's start to its decision.
    pub startup_ns: u64,
    pub clock: Clock,
}
