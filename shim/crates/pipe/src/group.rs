//! A caller's forced path: a run's group ended by the record it kept.

use crate::*;

/// How long the group has between TERM and KILL.
const TERM_GRACE: Duration = Duration::from_secs(1);

/// How long the group has to empty once KILLed.
const KILL_BOUND: Duration = Duration::from_secs(2);

/// How often the group is read while it empties.
const LOOK: Duration = Duration::from_millis(10);

/// `jabpipe group terminate --group --leader --start`, one answer as JSON.
pub(crate) fn group(args: Vec<String>) -> ExitCode {
    let (outcome, why, running) = match parsed(args) {
        Ok((group, leader, start)) => group_terminate(group, leader, start),
        Err(error) => ("error", error.to_string(), Vec::new()),
    };
    let answer = serde_json::json!({ "outcome": outcome, "why": why, "running": running });
    println!("{answer}");
    if outcome == "ok" { ExitCode::SUCCESS } else { ExitCode::from(1) }
}

fn parsed(args: Vec<String>) -> PipeResult<(i64, i64, u64)> {
    let usage = || PipeError::Usage("jabpipe group terminate --group <g> --leader <pid> --start <start>".to_owned());
    let mut args = args.into_iter();
    if args.next().as_deref() != Some("terminate") {
        return Err(usage());
    }
    let (mut group, mut leader, mut start) = (None, None, None);
    while let Some(flag) = args.next() {
        let value = args.next().ok_or_else(usage)?;
        match flag.as_str() {
            "--group" => group = value.parse::<i64>().ok(),
            "--leader" => leader = value.parse::<i64>().ok(),
            "--start" => start = value.parse::<u64>().ok(),
            _ => return Err(usage()),
        }
    }
    match (group, leader, start) {
        (Some(group), Some(leader), Some(start)) if group > 1 && leader > 1 => Ok((group, leader, start)),
        _ => Err(usage()),
    }
}

/// The group TERMed, KILLed, and read empty; one the record does not name refused.
pub(crate) fn group_terminate(group: i64, leader: i64, start: u64) -> (&'static str, String, Vec<i64>) {
    if process_state(leader) == State::Gone || process_start(leader) != Some(start) || group_of(leader) != Some(group) {
        let running = running_members(group).unwrap_or_default();
        return ("refused", format!("the group {group} is not the record's: its leader {leader} is gone or another process"), running);
    }
    for (signal, bound) in [(libc::SIGTERM, TERM_GRACE), (libc::SIGKILL, KILL_BOUND)] {
        unsafe { libc::kill(-(group as libc::pid_t), signal) };
        let sent = Instant::now();
        loop {
            match running_members(group) {
                Ok(running) if running.is_empty() => return ("ok", format!("the group {group} holds no running member"), running),
                Ok(running) if sent.elapsed() >= bound && signal == libc::SIGKILL => {
                    return ("left", format!("the group {group} still runs {} past its KILL", running.len()), running);
                }
                Ok(_) if sent.elapsed() >= bound => break,
                Ok(_) => thread::sleep(LOOK),
                Err(error) => return ("error", format!("the group {group} could not be read: {error}"), Vec::new()),
            }
        }
    }
    ("left", format!("the group {group} still runs"), running_members(group).unwrap_or_default())
}
