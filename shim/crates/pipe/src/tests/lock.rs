use crate::*;
use std::{fs, path::PathBuf};

/// A fresh lock home under the shim workspace's own target for one test.
fn scratch(name: &str) -> PathBuf {
    let nanos = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
    let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .join("..")
        .join("target")
        .join("test")
        .join(format!("{name}-{}-{nanos}", std::process::id()));
    fs::create_dir_all(&dir).expect("the scratch directory");
    fs::canonicalize(dir).expect("the scratch directory's own path")
}

fn me() -> i64 {
    std::process::id() as i64
}

fn owner(home: &Path) -> serde_json::Value {
    serde_json::from_slice(&fs::read(home.join(OWNER)).expect("the record")).expect("its json")
}

fn outcome(answer: PipeResult<Answer>) -> (&'static str, String) {
    let answer = answer.expect("an answer");
    (answer.outcome, answer.why)
}

/// A running record under `00000000000000a1` whose caller and supervisor are gone.
fn stale_record(home: &Path) {
    let mut gone = std::process::Command::new("true").spawn().unwrap();
    let pid = gone.id() as i64;
    gone.wait().unwrap();
    let stale = serde_json::json!({
        "token": "00000000000000a1", "state": "running", "caller": { "pid": pid, "start": 1 },
        "supervisor": { "pid": pid, "start": 1 }, "gate": null, "replaced": null, "utc": "then",
    });
    fs::write(home.join(OWNER), serde_json::to_vec(&stale).unwrap()).unwrap();
}

#[test]
fn a_second_launch_is_refused_while_the_first_holds_the_lock() {
    let home = scratch("lockheld");
    assert_eq!(outcome(lock_acquire(&home, "00000000000000a1", me())).0, "ok");
    let (refused, why) = outcome(lock_acquire(&home, "00000000000000b2", me()));
    assert_eq!(refused, "refused");
    assert!(why.contains("00000000000000a1 holds the lock"), "{why}");
    assert_eq!(owner(&home)["token"], "00000000000000a1", "the holder's record whole");
}

#[test]
fn a_state_is_written_only_under_the_records_token() {
    let home = scratch("lockstate");
    lock_acquire(&home, "00000000000000a1", me()).unwrap();
    let readiness = home.join("readiness.json");
    fs::write(&readiness, br#"{"token":"00000000000000a1","supervisor":{"pid":10,"start":11},"gate":{"pid":12,"group":12,"start":13}}"#).unwrap();
    assert_eq!(outcome(lock_set_state(&home, "00000000000000a1", "running", Some(&readiness))).0, "ok");
    let record = owner(&home);
    assert_eq!(record["state"], "running");
    assert_eq!(record["gate"]["group"], 12);
    assert_eq!(outcome(lock_set_state(&home, "00000000000000b2", "cleanup", None)).0, "refused");
    assert_eq!(owner(&home)["state"], "running", "nothing changed by another token");
}

#[test]
fn a_release_frees_the_lock_and_a_late_one_leaves_its_successor_whole() {
    let home = scratch("lockrelease");
    lock_acquire(&home, "00000000000000a1", me()).unwrap();
    assert_eq!(outcome(lock_release(&home, "00000000000000a1")).0, "ok");
    assert_eq!(owner(&home)["state"], "released");
    assert_eq!(outcome(lock_acquire(&home, "00000000000000b2", me())).0, "ok", "a released record is free");
    assert_eq!(outcome(lock_release(&home, "00000000000000a1")).0, "late");
    assert_eq!(owner(&home)["token"], "00000000000000b2", "the successor's record whole");
    assert_eq!(owner(&home)["state"], "starting");
}

#[test]
fn a_stale_record_is_replaced_and_named() {
    let home = scratch("lockstale");
    stale_record(&home);
    let (taken, why) = outcome(lock_acquire(&home, "00000000000000b2", me()));
    assert_eq!(taken, "ok", "{why}");
    assert!(why.contains("stale record replaced"), "{why}");
    assert_eq!(owner(&home)["replaced"]["token"], "00000000000000a1");
}

#[test]
fn two_callers_over_one_stale_record_take_it_in_turn() {
    let home = scratch("lockstaletwo");
    stale_record(&home);
    let start = std::sync::Arc::new(std::sync::Barrier::new(2));
    let callers: Vec<_> = ["00000000000000b2", "00000000000000c3"]
        .into_iter()
        .map(|token| {
            let (home, start) = (home.clone(), start.clone());
            std::thread::spawn(move || {
                start.wait();
                let (answer, why) = outcome(lock_acquire(&home, token, me()));
                (token, answer, why)
            })
        })
        .collect();
    let answers: Vec<_> = callers.into_iter().map(|caller| caller.join().unwrap()).collect();
    let taken: Vec<_> = answers.iter().filter(|a| a.1 == "ok").collect();
    let refused: Vec<_> = answers.iter().filter(|a| a.1 == "refused").collect();
    assert_eq!((taken.len(), refused.len()), (1, 1), "{answers:?}");
    assert!(taken[0].2.contains("stale record replaced"), "{answers:?}");
    assert!(refused[0].2.contains(&format!("{} holds the lock", taken[0].0)), "the first's live record named: {answers:?}");
    let record = owner(&home);
    assert_eq!(record["token"], taken[0].0);
    assert_eq!(record["replaced"]["token"], "00000000000000a1", "the stale record kept whole in it");
}

#[test]
fn a_record_the_tools_cannot_read_refuses_the_launch() {
    let home = scratch("lockunreadable");
    fs::write(home.join(OWNER), b"{ not json").unwrap();
    let (refused, why) = outcome(lock_acquire(&home, "00000000000000a1", me()));
    assert_eq!(refused, "refused");
    assert!(why.contains("cannot be settled"), "{why}");
    assert_eq!(fs::read(home.join(OWNER)).unwrap(), b"{ not json", "left as it was");
}

#[test]
fn a_lock_held_past_its_second_answers_busy() {
    let home = scratch("lockbusy");
    let held = OpenOptions::new().read(true).write(true).create(true).truncate(false).open(home.join(LOCK)).unwrap();
    held.lock().unwrap();
    let started = Instant::now();
    let (busy, _) = outcome(lock_acquire(&home, "00000000000000a1", me()));
    assert_eq!(busy, "busy");
    assert!(started.elapsed() >= Duration::from_secs(1) && started.elapsed() < Duration::from_secs(3), "{:?}", started.elapsed());
    assert!(!home.join(OWNER).exists(), "nothing written");
    held.unlock().unwrap();
}

#[test]
fn a_release_held_past_its_second_answers_busy_and_leaves_the_record() {
    let home = scratch("lockreleasebusy");
    lock_acquire(&home, "00000000000000a1", me()).unwrap();
    let held = OpenOptions::new().read(true).write(true).create(true).truncate(false).open(home.join(LOCK)).unwrap();
    held.lock().unwrap();
    let (busy, _) = outcome(lock_release(&home, "00000000000000a1"));
    assert_eq!(busy, "busy");
    assert_eq!(owner(&home)["state"], "starting", "the record left for the recovery's test");
    held.unlock().unwrap();
    assert_eq!(outcome(lock_release(&home, "00000000000000a1")).0, "ok");
}
