//! The host's launch lock: one supervised bounded launch at a time.

use crate::*;

/// How long a call tries for the lock before it answers busy.
pub(crate) const LOCK_BOUND: Duration = Duration::from_secs(1);

/// How often a call tries the lock while another holds it.
pub(crate) const LOCK_RETRY: Duration = Duration::from_millis(10);

/// The coordination file, made when absent and never removed or replaced.
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

/// A lock call's one answer, its outcome, why, and the record named.
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

/// `jabpipe lock acquire|state|release ...`, its answer one line of JSON.
pub(crate) fn lock(args: Vec<String>) -> ExitCode {
    let answer = lock_home().and_then(|home| lock_answered(&home, args)).unwrap_or_else(|error| Answer { outcome: "error", why: error.to_string(), record: None });
    println!("{}", serde_json::to_string(&answer).unwrap_or_default());
    if answer.outcome == "ok" { ExitCode::SUCCESS } else { ExitCode::from(1) }
}

/// The lock's directory: `JAB_LAUNCH_LOCK`, else the state home's `jab/launch`.
pub(crate) fn lock_home() -> PipeResult<PathBuf> {
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
    fs::create_dir_all(&home).map_err(PipeError::io(home.display().to_string()))?;
    Ok(home)
}

/// The state home: XDG's, else `~/.local/state`; on Windows `LOCALAPPDATA`.
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
pub(crate) fn lock_answered(home: &Path, args: Vec<String>) -> PipeResult<Answer> {
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
        "acquire" => lock_acquire(home, &token, caller.ok_or_else(usage)?),
        "state" => {
            let state = state.ok_or_else(usage)?;
            if !["running", "cleanup"].contains(&state.as_str()) {
                return Err(usage());
            }
            lock_set_state(home, &token, &state, readiness.as_deref())
        }
        "release" => lock_release(home, &token),
        _ => Err(usage()),
    }
}

/// A transaction under the lock, tried every 10 ms for a second, else busy.
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
            Err(TryLockError::WouldBlock) if tried.elapsed() < LOCK_BOUND => thread::sleep(LOCK_RETRY),
            Err(TryLockError::WouldBlock) => {
                return Ok(Answer { outcome: "busy", why: format!("{} stayed held past {} s", path.display(), LOCK_BOUND.as_secs()), record: None });
            }
            Err(TryLockError::Error(source)) => return Err(PipeError::Io { what: path.display().to_string(), source }),
        }
    }
    let answer = body(home);
    let _ = file.unlock();
    answer
}

/// The record as it stands: free, unreadable, or an owner's.
enum Record {
    Free,
    Unreadable(String),
    Owned(Owner),
}

fn read_record(home: &Path) -> Record {
    let path = home.join(OWNER);
    match fs::read(&path) {
        Err(error) if error.kind() == io::ErrorKind::NotFound => Record::Free,
        Err(error) => Record::Unreadable(format!("{}: {error}", path.display())),
        Ok(bytes) => match serde_json::from_slice::<Owner>(&bytes) {
            Ok(owner) if owner.state == "released" => Record::Free,
            Ok(owner) => Record::Owned(owner),
            Err(error) => Record::Unreadable(format!("{}: {error}", path.display())),
        },
    }
}

fn write_owner(home: &Path, owner: &Owner) -> PipeResult<()> {
    write_json(&home.join(OWNER), owner)
}

/// Whether a record's run is gone: caller, supervisor, and group alike.
fn stale(owner: &Owner) -> Result<bool, String> {
    let gone = |h: &Holder| !is_running(h.pid, h.start);
    if !gone(&owner.caller) || owner.supervisor.as_ref().is_some_and(|s| !gone(s)) {
        return Ok(false);
    }
    match owner.gate.as_ref().and_then(|g| g.group) {
        Some(group) if cfg!(unix) => running_members(group)
            .map(|running| running.is_empty())
            .map_err(|error| format!("its group {group} could not be read: {error}")),
        _ => Ok(true),
    }
}

/// The lock taken: a free record taken, a stale one replaced, a live one refused.
pub(crate) fn lock_acquire(home: &Path, token: &str, caller: i64) -> PipeResult<Answer> {
    let start = process_start(caller).ok_or_else(|| PipeError::Host(format!("the caller {caller} is not in the process table")))?;
    transaction(home, |home| {
        let mut owner = Owner {
            token: token.to_owned(),
            state: "starting".to_owned(),
            caller: Holder { pid: caller, start: Some(start) },
            supervisor: None,
            gate: None,
            replaced: None,
            utc: utc_now(),
        };
        match read_record(home) {
            Record::Free => {}
            Record::Unreadable(why) => return Ok(Answer::refused(format!("the lock's record cannot be settled: {why}"), None)),
            Record::Owned(held) => {
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
        write_owner(home, &owner)?;
        let why = match &owner.replaced {
            Some(_) => "taken, a stale record replaced",
            None => "taken",
        };
        Ok(Answer::ok(why, Some(&owner)))
    })
}

/// The record's state moved while it carries the token, the readiness copied in.
pub(crate) fn lock_set_state(home: &Path, token: &str, state: &str, readiness: Option<&Path>) -> PipeResult<Answer> {
    let copied = match readiness {
        Some(path) => Some(read_json::<Readiness>(path)?.ok_or_else(|| PipeError::Host(format!("no readiness at {}", path.display())))?),
        None => None,
    };
    transaction(home, |home| match read_record(home) {
        Record::Owned(mut owner) if owner.token == token => {
            owner.state = state.to_owned();
            if let Some(readiness) = &copied {
                if readiness.token != token {
                    return Ok(Answer::refused(format!("the readiness names the token {}, not {token}", readiness.token), None));
                }
                owner.supervisor = Some(Holder { pid: readiness.supervisor.pid, start: readiness.supervisor.start });
                owner.gate = Some(readiness.gate.clone());
            }
            owner.utc = utc_now();
            write_owner(home, &owner)?;
            Ok(Answer::ok(format!("now {state}"), Some(&owner)))
        }
        Record::Owned(owner) => Ok(Answer::refused(format!("the lock is the launch {}'s, not this one's", owner.token), serde_json::to_value(&owner).ok())),
        Record::Free => Ok(Answer::refused("the lock holds no record of this launch", None)),
        Record::Unreadable(why) => Ok(Answer::refused(format!("the lock's record cannot be settled: {why}"), None)),
    })
}

/// The lock released while its record carries the token: marked released.
pub(crate) fn lock_release(home: &Path, token: &str) -> PipeResult<Answer> {
    transaction(home, |home| match read_record(home) {
        Record::Owned(mut owner) if owner.token == token => {
            owner.state = "released".to_owned();
            owner.utc = utc_now();
            write_owner(home, &owner)?;
            Ok(Answer::ok("released", Some(&owner)))
        }
        Record::Owned(owner) => Ok(Answer {
            outcome: "late",
            why: format!("the lock is the launch {}'s now, left whole", owner.token),
            record: serde_json::to_value(&owner).ok(),
        }),
        Record::Free => Ok(Answer { outcome: "late", why: "the lock holds no record of this launch".to_owned(), record: None }),
        Record::Unreadable(why) => Ok(Answer::refused(format!("the lock's record cannot be settled: {why}"), None)),
    })
}
