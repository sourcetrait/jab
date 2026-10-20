//! The host's launch lock: one supervised bounded launch at a time, its owner's record beside it.

use crate::*;
use crate::receipt::{Gate, Readiness};
use crate::table;

/// How long a call tries for the lock before it answers busy.
pub(crate) const LOCK_BOUND: Duration = Duration::from_secs(1);

/// How often a call tries the lock while another holds it.
pub(crate) const LOCK_RETRY: Duration = Duration::from_millis(10);

/// The coordination file, made when absent and never removed, renamed, or replaced.
pub(crate) const LOCK: &str = "lock";

/// The run's ownership record, replaced whole at each write.
pub(crate) const OWNER: &str = "owner.nuon";

/// A process by its pid and its start, as the record keeps it.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone, PartialEq, Eq)]
pub(crate) struct Holder {
    pub pid: i64,
    pub start: Option<u64>,
}

/// The run's ownership record.
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub(crate) struct Owner {
    pub token: String,
    /// `starting`, `running`, `cleanup`, or `released`.
    pub state: String,
    pub caller: Holder,
    pub supervisor: Option<Holder>,
    pub gate: Option<Gate>,
    /// The stale record this one replaced, as it stood.
    pub replaced: Option<serde_json::Value>,
    /// The realtime clock at the write, for dates alone.
    pub utc: String,
}

/// A lock call's one answer: `ok`, `busy`, `refused`, `late`, or `error`, why, and the record named.
#[derive(serde::Serialize, Debug)]
pub(crate) struct Answer {
    pub outcome: &'static str,
    pub why: String,
    pub record: Option<serde_json::Value>,
}

impl Answer {
    fn ok(why: impl Into<String>, record: Option<&Owner>) -> Answer {
        Answer { outcome: "ok", why: why.into(), record: record.and_then(|r| serde_json::to_value(r).ok()) }
    }

    fn refused(why: impl Into<String>, record: Option<serde_json::Value>) -> Answer {
        Answer { outcome: "refused", why: why.into(), record }
    }
}

/// `jabpipe lock acquire|state|release ...`, one outcome printed as one line of JSON.
pub(crate) fn lock(args: Vec<String>) -> ExitCode {
    let answer = home().and_then(|home| answered(&home, args)).unwrap_or_else(|error| Answer { outcome: "error", why: error.to_string(), record: None });
    println!("{}", serde_json::to_string(&answer).unwrap_or_default());
    if answer.outcome == "ok" { ExitCode::SUCCESS } else { ExitCode::from(1) }
}

/// The lock's directory: `JAB_LAUNCH_LOCK` when set, else `jab/launch` under the state home.
pub(crate) fn home() -> PipeResult<PathBuf> {
    if let Ok(named) = env::var("JAB_LAUNCH_LOCK")
        && !named.is_empty()
    {
        let named = PathBuf::from(named);
        if !named.is_dir() {
            return Err(PipeError::Host(format!("JAB_LAUNCH_LOCK names {}, which is no directory", named.display())));
        }
        return Ok(named);
    }
    let state = state_home()?;
    if !state.is_dir() {
        return Err(PipeError::Host(format!("{} is no directory: the launch lock lives under the state home, which this host's user lacks", state.display())));
    }
    let home = state.join("jab").join("launch");
    std::fs::create_dir_all(&home).map_err(PipeError::io(home.display().to_string()))?;
    Ok(home)
}

/// The state home: XDG's, else `~/.local/state`; on Windows the local application data.
#[cfg(unix)]
fn state_home() -> PipeResult<PathBuf> {
    if let Ok(set) = env::var("XDG_STATE_HOME")
        && !set.is_empty()
        && Path::new(&set).is_absolute()
    {
        return Ok(PathBuf::from(set));
    }
    let home = env::var("HOME").map_err(|_| PipeError::Host("no HOME, so no state home for the launch lock".to_owned()))?;
    Ok(Path::new(&home).join(".local").join("state"))
}

#[cfg(windows)]
fn state_home() -> PipeResult<PathBuf> {
    env::var("LOCALAPPDATA").map(PathBuf::from).map_err(|_| PipeError::Host("no LOCALAPPDATA, so no state home for the launch lock".to_owned()))
}

/// The call the arguments name, answered.
pub(crate) fn answered(home: &Path, args: Vec<String>) -> PipeResult<Answer> {
    let usage = || {
        PipeError::Usage("jabpipe lock acquire --token <t> --caller <pid> | state --token <t> --state <running|cleanup> [--readiness <file>] | release --token <t>".to_owned())
    };
    let mut args = args.into_iter();
    let verb = args.next().ok_or_else(usage)?;
    let (mut token, mut caller, mut state, mut readiness) = (None, None, None, None);
    while let Some(flag) = args.next() {
        let value = args.next().ok_or_else(usage)?;
        match flag.as_str() {
            "--token" => token = Some(value),
            "--caller" => caller = Some(value.parse::<i64>().map_err(|_| usage())?),
            "--state" => state = Some(value),
            "--readiness" => readiness = Some(PathBuf::from(value)),
            _ => return Err(usage()),
        }
    }
    let token = token.ok_or_else(usage)?;
    match verb.as_str() {
        "acquire" => acquire(home, &token, caller.ok_or_else(usage)?),
        "state" => {
            let state = state.ok_or_else(usage)?;
            if !["running", "cleanup"].contains(&state.as_str()) {
                return Err(usage());
            }
            set_state(home, &token, &state, readiness.as_deref())
        }
        "release" => release(home, &token),
        _ => Err(usage()),
    }
}

/// A transaction under the lock: tried every 10 ms for at most a second, else busy.
fn transaction(home: &Path, body: impl FnOnce(&Path) -> PipeResult<Answer>) -> PipeResult<Answer> {
    let path = home.join(LOCK);
    let file = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .open(&path)
        .map_err(PipeError::io(path.display().to_string()))?;
    let tried = Instant::now();
    loop {
        match file.try_lock() {
            Ok(()) => break,
            Err(std::fs::TryLockError::WouldBlock) if tried.elapsed() < LOCK_BOUND => thread::sleep(LOCK_RETRY),
            Err(std::fs::TryLockError::WouldBlock) => {
                return Ok(Answer { outcome: "busy", why: format!("{} stayed held past {} s", path.display(), LOCK_BOUND.as_secs()), record: None });
            }
            Err(std::fs::TryLockError::Error(source)) => return Err(PipeError::Io { what: path.display().to_string(), source }),
        }
    }
    let answer = body(home);
    let _ = file.unlock();
    answer
}

/// The record as it stands: none, or one whose text the tools cannot read, or the owner.
enum Standing {
    Free,
    Unreadable(String),
    Owned(Owner),
}

fn standing(home: &Path) -> Standing {
    let path = home.join(OWNER);
    match std::fs::read(&path) {
        Err(error) if error.kind() == io::ErrorKind::NotFound => Standing::Free,
        Err(error) => Standing::Unreadable(format!("{}: {error}", path.display())),
        Ok(bytes) => match serde_json::from_slice::<Owner>(&bytes) {
            Ok(owner) if owner.state == "released" => Standing::Free,
            Ok(owner) => Standing::Owned(owner),
            Err(error) => Standing::Unreadable(format!("{}: {error}", path.display())),
        },
    }
}

fn write(home: &Path, owner: &Owner) -> PipeResult<()> {
    control::write_json(&home.join(OWNER), owner)
}

/// Whether a record's run is gone: its caller and its supervisor gone, its group running nothing.
fn stale(owner: &Owner) -> Result<bool, String> {
    let gone = |h: &Holder| !table::is_running(h.pid, h.start);
    if !gone(&owner.caller) || owner.supervisor.as_ref().is_some_and(|s| !gone(s)) {
        return Ok(false);
    }
    match owner.gate.as_ref().and_then(|g| g.group) {
        Some(group) if cfg!(unix) => table::running_members(group)
            .map(|running| running.is_empty())
            .map_err(|error| format!("its group {group} could not be read: {error}")),
        _ => Ok(true),
    }
}

/// The lock taken for a launch: a free record its, a stale one replaced, a live one refused.
pub(crate) fn acquire(home: &Path, token: &str, caller: i64) -> PipeResult<Answer> {
    let start = table::start(caller).ok_or_else(|| PipeError::Host(format!("the caller {caller} is not in the process table")))?;
    transaction(home, |home| {
        let mut owner = Owner {
            token: token.to_owned(),
            state: "starting".to_owned(),
            caller: Holder { pid: caller, start: Some(start) },
            supervisor: None,
            gate: None,
            replaced: None,
            utc: control::utc_now(),
        };
        match standing(home) {
            Standing::Free => {}
            Standing::Unreadable(why) => return Ok(Answer::refused(format!("the lock's record cannot be settled: {why}"), None)),
            Standing::Owned(held) => {
                let record = serde_json::to_value(&held).ok();
                if held.token == token {
                    return Ok(Answer::refused("the lock is this launch's already", record));
                }
                match stale(&held) {
                    Ok(true) => owner.replaced = record,
                    Ok(false) => return Ok(Answer::refused(format!("the launch {} holds the lock, its state {}", held.token, held.state), record)),
                    Err(why) => return Ok(Answer::refused(format!("the launch {}'s record cannot be settled: {why}", held.token), record)),
                }
            }
        }
        write(home, &owner)?;
        let why = match &owner.replaced {
            Some(_) => "taken, a stale record replaced",
            None => "taken",
        };
        Ok(Answer::ok(why, Some(&owner)))
    })
}

/// The record's state moved while it carries the launch's token, the readiness copied in.
pub(crate) fn set_state(home: &Path, token: &str, state: &str, readiness: Option<&Path>) -> PipeResult<Answer> {
    let copied = match readiness {
        Some(path) => Some(control::read_json::<Readiness>(path)?.ok_or_else(|| PipeError::Host(format!("no readiness at {}", path.display())))?),
        None => None,
    };
    transaction(home, |home| match standing(home) {
        Standing::Owned(mut owner) if owner.token == token => {
            owner.state = state.to_owned();
            if let Some(readiness) = &copied {
                if readiness.token != token {
                    return Ok(Answer::refused(format!("the readiness names the token {}, not {token}", readiness.token), None));
                }
                owner.supervisor = Some(Holder { pid: readiness.supervisor.pid, start: readiness.supervisor.start });
                owner.gate = Some(readiness.gate.clone());
            }
            owner.utc = control::utc_now();
            write(home, &owner)?;
            Ok(Answer::ok(format!("now {state}"), Some(&owner)))
        }
        Standing::Owned(owner) => Ok(Answer::refused(format!("the lock is the launch {}'s, not this one's", owner.token), serde_json::to_value(&owner).ok())),
        Standing::Free => Ok(Answer::refused("the lock holds no record of this launch", None)),
        Standing::Unreadable(why) => Ok(Answer::refused(format!("the lock's record cannot be settled: {why}"), None)),
    })
}

/// The lock released while its record carries the launch's token: the record marked released.
pub(crate) fn release(home: &Path, token: &str) -> PipeResult<Answer> {
    transaction(home, |home| match standing(home) {
        Standing::Owned(mut owner) if owner.token == token => {
            owner.state = "released".to_owned();
            owner.utc = control::utc_now();
            write(home, &owner)?;
            Ok(Answer::ok("released", Some(&owner)))
        }
        Standing::Owned(owner) => Ok(Answer {
            outcome: "late",
            why: format!("the lock is the launch {}'s now, left whole", owner.token),
            record: serde_json::to_value(&owner).ok(),
        }),
        Standing::Free => Ok(Answer { outcome: "late", why: "the lock holds no record of this launch".to_owned(), record: None }),
        Standing::Unreadable(why) => Ok(Answer::refused(format!("the lock's record cannot be settled: {why}"), None)),
    })
}
