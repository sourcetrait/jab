//! The supervisor run as the binary is, over stand-ins for QEMU, its pipes, and its relays.
#![cfg(unix)]

use serde_json::{Value, json};
use std::fs;
use std::io::{Read, Write};
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, ExitStatus, Stdio};
use std::time::{Duration, Instant};

const BIN: &str = env!("CARGO_BIN_EXE_jabpipe");

/// A fresh directory under the shim workspace's own target for one test.
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

/// A token for one test: sixteen lowercase hex digits from the clock and the process.
fn token() -> String {
    let nanos = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(1);
    format!("{:016x}", (nanos as u64 ^ ((std::process::id() as u64) << 40)) | 1)
}

const MS: u64 = 1_000_000;

/// A bounded schedule over a stand-in command, the bounds a test may change.
fn schedule(dir: &Path, token: &str, command: &[&str]) -> Value {
    json!({
        "token": token,
        "mode": "bounded",
        "dir": dir,
        "command": command,
        "env": [],
        "stdout": dir.join("qemu.stdout"),
        "stderr": dir.join("qemu.stderr"),
        "pidfile": dir.join("qemu.pid"),
        "pipes": [],
        "header": null,
        "actions": [],
        "readings": [],
        "relays": [],
        "helpers": [],
        "bounds": {
            "startup_ns": 3000 * MS,
            "retry_ns": 10 * MS,
            "screen_ns": 5000 * MS,
            "screen_poll_ns": 50 * MS,
            "cpu_ns": 100 * MS,
            "grace_ns": 2000 * MS,
            "term_ns": 1000 * MS,
        },
    })
}

/// A file written whole: a temporary name beside it, renamed over it.
fn write_whole(path: &Path, value: &Value) {
    let temporary = path.with_extension("tmp");
    fs::write(&temporary, serde_json::to_vec(value).expect("json")).expect("the temporary");
    fs::rename(&temporary, path).expect("the rename");
}

/// A supervised launch as its caller drives it: the schedule written, the supervisor spawned.
struct Launch {
    dir: PathBuf,
    token: String,
    started: Instant,
    supervisor: Child,
}

impl Launch {
    fn start(dir: &Path, schedule: Value) -> Launch {
        Launch::start_with(dir, schedule, &[])
    }

    fn start_with(dir: &Path, schedule: Value, env: &[(&str, &str)]) -> Launch {
        let token = schedule["token"].as_str().expect("a token").to_owned();
        let path = dir.join(format!("launch-{token}.schedule.json"));
        write_whole(&path, &schedule);
        let started = Instant::now();
        let supervisor = Command::new(BIN)
            .args(["supervise", "--token", &token, "--schedule"])
            .arg(&path)
            .envs(env.iter().copied())
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .expect("the supervisor");
        Launch { dir: dir.to_owned(), token, started, supervisor }
    }

    fn file(&self, kind: &str) -> PathBuf {
        self.dir.join(format!("launch-{}.{kind}.json", self.token))
    }

    /// A control file's value once it is there, waited for at most `within`.
    fn wait_for(&self, kind: &str, within: Duration) -> Option<Value> {
        let deadline = Instant::now() + within;
        loop {
            if let Ok(bytes) = fs::read(self.file(kind)) {
                return Some(serde_json::from_slice(&bytes).expect("a control file's json"));
            }
            if Instant::now() >= deadline {
                return None;
            }
            std::thread::sleep(Duration::from_millis(5));
        }
    }

    fn request(&self, kind: &str) {
        write_whole(&self.file(kind), &json!({ "token": self.token }));
    }

    /// The go: the readiness read, then the authorization written.
    fn authorized(&self) -> Value {
        let readiness = self.wait_for("readiness", Duration::from_secs(5)).expect("the readiness");
        self.request("authorization");
        readiness
    }

    /// The supervisor's exit, its stderr, and its receipt, waited for at most `within`.
    fn finish(mut self, within: Duration) -> (ExitStatus, String, Value, Duration) {
        let deadline = Instant::now() + within;
        let status = loop {
            if let Some(status) = self.supervisor.try_wait().expect("the supervisor's wait") {
                break status;
            }
            if Instant::now() >= deadline {
                let _ = self.supervisor.kill();
                panic!("the supervisor did not end within {within:?}");
            }
            std::thread::sleep(Duration::from_millis(5));
        };
        let took = self.started.elapsed();
        let mut stderr = String::new();
        if let Some(mut err) = self.supervisor.stderr.take() {
            let _ = err.read_to_string(&mut stderr);
        }
        let receipt = self
            .wait_for("receipt", Duration::from_millis(10))
            .unwrap_or_else(|| panic!("no receipt; the supervisor ended with {status} saying: {stderr}"));
        (status, stderr, receipt, took)
    }
}

/// Whether a pid still runs, a zombie counted gone.
fn running(pid: i64) -> bool {
    match fs::read_to_string(format!("/proc/{pid}/stat")) {
        Ok(stat) => stat.rsplit_once(") ").is_some_and(|(_, rest)| !rest.starts_with('Z')),
        Err(_) => unsafe { libc::kill(pid as libc::pid_t, 0) == 0 },
    }
}

/// A named pipe made at `path`.
fn fifo(path: &Path) {
    let name = std::ffi::CString::new(path.as_os_str().as_encoded_bytes()).expect("a path");
    assert_eq!(unsafe { libc::mkfifo(name.as_ptr(), 0o600) }, 0, "mkfifo {}", path.display());
}

#[test]
fn a_go_runs_the_child_and_its_exit_is_received() {
    let dir = scratch("go");
    let token = token();
    let pid = dir.join("qemu.pid");
    let command = ["sh", "-c", "echo $$ > \"$0\"; echo said; echo told >&2; sleep 0.3; exit 7", pid.to_str().unwrap()];
    let launch = Launch::start(&dir, schedule(&dir, &token, &command));
    let readiness = launch.authorized();
    assert_eq!(readiness["token"], token.as_str());
    assert_eq!(readiness["gate"]["group"], readiness["gate"]["pid"], "the gate leads a group of its own");
    let (status, stderr, receipt, _) = launch.finish(Duration::from_secs(10));
    assert_eq!(status.code(), Some(7), "the child's status is the supervisor's: {stderr}");
    assert_eq!(receipt["outcome"]["decision"], "go");
    assert!(receipt["outcome"]["go_utc"].is_string());
    assert_eq!(receipt["status"], 7);
    assert!(receipt["failure"].is_null());
    assert!(receipt["end_ns"].as_u64().is_some_and(|end| end >= 300 * MS), "the run's end: {}", receipt["end_ns"]);
    assert_eq!(receipt["qemu_pid"].as_i64(), fs::read_to_string(&pid).unwrap().trim().parse::<i64>().ok());
    assert_eq!(fs::read_to_string(dir.join("qemu.stdout")).unwrap(), "said\n");
    assert_eq!(fs::read_to_string(dir.join("qemu.stderr")).unwrap(), "told\n");
    assert_eq!(receipt["clock"], json!({ "origin": "go", "unit": "ns", "go_utc": receipt["outcome"]["go_utc"] }));
}

#[test]
fn a_cancel_before_the_go_runs_nothing() {
    let dir = scratch("cancel");
    let token = token();
    let marker = dir.join("started");
    let command = ["sh", "-c", "touch \"$0\"; sleep 30", marker.to_str().unwrap()];
    let launch = Launch::start(&dir, schedule(&dir, &token, &command));
    let readiness = launch.wait_for("readiness", Duration::from_secs(5)).expect("the readiness");
    launch.request("cancel");
    let gate = readiness["gate"]["pid"].as_i64().unwrap();
    let (status, _, receipt, took) = launch.finish(Duration::from_secs(5));
    assert_eq!(status.code(), Some(3));
    assert_eq!(receipt["outcome"]["decision"], "cancelled");
    assert!(receipt["outcome"]["go_utc"].is_null());
    assert!(receipt["end_ns"].is_null(), "nothing ran");
    assert!(!marker.exists(), "the stand-in never started");
    assert!(!running(gate), "the gate exited");
    assert!(took < Duration::from_secs(2), "{took:?}");
}

#[test]
fn an_authorization_past_the_allowance_is_never_taken() {
    let dir = scratch("expired");
    let token = token();
    let marker = dir.join("started");
    let mut planned = schedule(&dir, &token, &["sh", "-c", "touch \"$0\"", marker.to_str().unwrap()]);
    planned["bounds"]["startup_ns"] = json!(400 * MS);
    let launch = Launch::start(&dir, planned);
    let outcome = launch.wait_for("outcome", Duration::from_secs(5)).expect("the outcome");
    assert_eq!(outcome["decision"], "expired");
    launch.request("authorization");
    let (status, _, receipt, took) = launch.finish(Duration::from_secs(5));
    assert_eq!(status.code(), Some(3));
    assert_eq!(receipt["outcome"]["decision"], "expired");
    assert!(!marker.exists(), "the late authorization was never taken");
    assert!(took >= Duration::from_millis(400), "{took:?}");
}

#[test]
fn a_cancel_after_the_go_ends_the_group_a_term_refused() {
    let dir = scratch("terminate");
    let token = token();
    let pid = dir.join("qemu.pid");
    let command = ["sh", "-c", "trap '' TERM; echo $$ > \"$0\"; sleep 30 & wait; wait", pid.to_str().unwrap()];
    let launch = Launch::start(&dir, schedule(&dir, &token, &command));
    launch.authorized();
    let deadline = Instant::now() + Duration::from_secs(5);
    while !pid.exists() && Instant::now() < deadline {
        std::thread::sleep(Duration::from_millis(5));
    }
    std::thread::sleep(Duration::from_millis(200));
    let cancelled = Instant::now();
    launch.request("cancel");
    let (status, _, receipt, _) = launch.finish(Duration::from_secs(10));
    let ended = cancelled.elapsed();
    assert_eq!(status.code(), Some(3), "a cancelled run's exit");
    assert!(receipt["cancelled_ns"].as_u64().is_some());
    assert_eq!(receipt["signal"], 9, "the group KILLed past its TERM's grace");
    assert!(ended >= Duration::from_secs(1) && ended < Duration::from_secs(3), "the grace, then the KILL: {ended:?}");
    let qemu: i64 = fs::read_to_string(&pid).unwrap().trim().parse().unwrap();
    assert!(!running(qemu), "the stand-in is gone");
}

#[test]
fn a_relay_failing_at_once_aborts_the_launch_naming_its_endpoint() {
    let dir = scratch("relayfail");
    let token = token();
    let refused = dir.join("not-a-socket");
    fs::write(&refused, b"").unwrap();
    let mut planned = schedule(&dir, &token, &["sleep", "30"]);
    planned["pidfile"] = json!("");
    planned["relays"] = json!([{ "endpoint": "api", "name": refused, "inward": "", "outward": dir.join("api.out") }]);
    let launch = Launch::start(&dir, planned);
    launch.authorized();
    let (status, stderr, receipt, took) = launch.finish(Duration::from_secs(10));
    assert_eq!(status.code(), Some(1), "{stderr}");
    let failure = receipt["failure"].as_str().expect("the failure named");
    assert!(failure.starts_with(&format!("the api pipe's relay, for {}, failed:", refused.display())), "{failure}");
    assert_eq!(receipt["relays"][0]["state"], "failed");
    assert!(took < Duration::from_secs(3), "aborted within the startup's allowance: {took:?}");
    assert_eq!(receipt["signal"], 15, "the child TERMed");
}

#[test]
fn a_relay_that_never_connects_aborts_at_the_allowance() {
    let dir = scratch("relaynever");
    let token = token();
    let mut planned = schedule(&dir, &token, &["sleep", "30"]);
    planned["pidfile"] = json!("");
    planned["bounds"]["startup_ns"] = json!(800 * MS);
    planned["relays"] = json!([{ "endpoint": "monitor", "name": dir.join("never"), "inward": "", "outward": dir.join("monitor.out") }]);
    let launch = Launch::start(&dir, planned);
    launch.authorized();
    let (status, _, receipt, took) = launch.finish(Duration::from_secs(10));
    assert_eq!(status.code(), Some(1));
    let failure = receipt["failure"].as_str().unwrap();
    assert!(failure.contains("the monitor pipe's relay") && failure.contains("no connection within its allowance"), "{failure}");
    assert!(took >= Duration::from_millis(800) && took < Duration::from_secs(3), "{took:?}");
}

/// A Unix socket served at `path` by a thread: one connection taken, held `hold`, then closed.
fn serve(path: &Path, hold: Duration) -> std::thread::JoinHandle<()> {
    let listening = path.with_extension("listening");
    let listener = std::os::unix::net::UnixListener::bind(&listening).expect("the stand-in's socket");
    fs::rename(&listening, path).expect("the socket in place");
    std::thread::spawn(move || {
        let (stream, _) = listener.accept().expect("the relay's connection");
        std::thread::sleep(hold);
        drop(stream);
    })
}

#[test]
fn a_clean_end_then_the_childs_exit_inside_the_grace_is_a_normal_end() {
    let dir = scratch("cleanend");
    let token = token();
    let socket = dir.join("api.sock");
    let served = serve(&socket, Duration::from_millis(200));
    let mut planned = schedule(&dir, &token, &["sh", "-c", "sleep 0.8; exit 0"]);
    planned["pidfile"] = json!("");
    planned["relays"] = json!([{ "endpoint": "api", "name": socket, "inward": "", "outward": dir.join("api.out") }]);
    let launch = Launch::start(&dir, planned);
    launch.authorized();
    let (status, stderr, receipt, _) = launch.finish(Duration::from_secs(10));
    served.join().unwrap();
    assert_eq!(status.code(), Some(0), "{stderr}");
    assert!(receipt["failure"].is_null(), "{}", receipt["failure"]);
    assert_eq!(receipt["relays"][0]["state"], "clean");
    assert!(receipt["relays"][0]["connected_ns"].as_u64().is_some());
}

#[test]
fn a_clean_end_while_the_child_runs_fails_after_the_grace() {
    let dir = scratch("cleanrun");
    let token = token();
    let socket = dir.join("api.sock");
    let served = serve(&socket, Duration::from_millis(100));
    let mut planned = schedule(&dir, &token, &["sleep", "30"]);
    planned["pidfile"] = json!("");
    planned["relays"] = json!([{ "endpoint": "api", "name": socket, "inward": "", "outward": dir.join("api.out") }]);
    let launch = Launch::start(&dir, planned);
    launch.authorized();
    let (status, _, receipt, took) = launch.finish(Duration::from_secs(10));
    served.join().unwrap();
    assert_eq!(status.code(), Some(1));
    assert_eq!(receipt["failure"], "the api pipe ended while QEMU ran");
    assert_eq!(receipt["signal"], 15);
    assert!(took >= Duration::from_secs(2) && took < Duration::from_secs(5), "after the grace: {took:?}");
}

#[test]
fn a_process_of_the_same_command_line_is_left_running_through_an_abort() {
    let dir = scratch("bystander");
    let token = token();
    let mut bystander = Command::new("sleep").arg("31.25").spawn().expect("the bystander");
    let refused = dir.join("not-a-socket");
    fs::write(&refused, b"").unwrap();
    let mut planned = schedule(&dir, &token, &["sleep", "31.25"]);
    planned["pidfile"] = json!("");
    planned["relays"] = json!([{ "endpoint": "api", "name": refused, "inward": "", "outward": dir.join("api.out") }]);
    let launch = Launch::start(&dir, planned);
    launch.authorized();
    let (status, _, _, _) = launch.finish(Duration::from_secs(10));
    assert_eq!(status.code(), Some(1));
    assert!(bystander.try_wait().unwrap().is_none(), "the bystander still runs");
    bystander.kill().unwrap();
    bystander.wait().unwrap();
}

/// A reader of a fifo, as QEMU holds one: opened read and write, read in pieces with stalls between.
fn reader(path: &Path, pieces: Vec<(usize, Duration)>) -> std::thread::JoinHandle<Vec<u8>> {
    let path = path.to_owned();
    std::thread::spawn(move || {
        let mut file = fs::OpenOptions::new().read(true).write(true).open(&path).expect("the fifo");
        let mut got = Vec::new();
        for (length, stall) in pieces {
            let mut piece = vec![0u8; length];
            file.read_exact(&mut piece).expect("a piece");
            got.extend(piece);
            std::thread::sleep(stall);
        }
        got
    })
}

/// A schedule's action: its kind, index, due time, pipe, and bytes.
fn action(kind: &str, index: u64, due_ms: u64, pipe: &str, bytes: &[u8]) -> Value {
    json!({ "kind": kind, "index": index, "due_ns": due_ms * MS, "pipe": pipe, "bytes": bytes })
}

#[test]
fn actions_go_in_whole_and_in_due_order_each_at_its_time() {
    let dir = scratch("actions");
    let token = token();
    let pid = dir.join("qemu.pid");
    let api = dir.join("api.in");
    fifo(&api);
    let read = reader(&api, vec![(14, Duration::ZERO)]);
    let mut planned = schedule(&dir, &token, &["sh", "-c", "echo $$ > \"$0\"; sleep 1", pid.to_str().unwrap()]);
    planned["pipes"] = json!([{ "name": "api", "path": api }]);
    planned["actions"] = json!([
        action("send", 0, 0, "api", b"one\n"),
        action("send", 1, 0, "api", b"two\n"),
        action("send", 2, 300, "api", b"three\n"),
    ]);
    let launch = Launch::start(&dir, planned);
    launch.authorized();
    let (status, _, receipt, _) = launch.finish(Duration::from_secs(10));
    assert_eq!(status.code(), Some(0));
    assert_eq!(read.join().unwrap(), b"one\ntwo\nthree\n");
    let actions = receipt["actions"].as_array().unwrap();
    assert!(actions.iter().all(|a| a["state"] == "complete" && a["accepted"] == a["length"]), "{actions:?}");
    let done: Vec<u64> = actions.iter().map(|a| a["done_ns"].as_u64().unwrap()).collect();
    assert!(done[0] <= done[1] && done[1] <= done[2], "{done:?}");
    assert!(done[2] >= 300 * MS, "the third at its time: {done:?}");
}

#[test]
fn a_payload_taken_in_pieces_with_stalls_goes_in_once_and_ahead_of_the_next() {
    let dir = scratch("pieces");
    let token = token();
    let pid = dir.join("qemu.pid");
    let api = dir.join("api.in");
    fifo(&api);
    let big: Vec<u8> = (0..262_144u32).map(|i| (i % 251) as u8).collect();
    let pieces = vec![(65_536, Duration::from_millis(1200)), (65_536, Duration::from_millis(100)), (131_072, Duration::ZERO), (5, Duration::ZERO)];
    let read = reader(&api, pieces);
    let mut planned = schedule(&dir, &token, &["sh", "-c", "echo $$ > \"$0\"; sleep 3", pid.to_str().unwrap()]);
    planned["pipes"] = json!([{ "name": "api", "path": api }]);
    planned["actions"] = json!([action("send", 0, 0, "api", &big), action("send", 1, 0, "api", b"tail\n")]);
    let launch = Launch::start(&dir, planned);
    launch.authorized();
    let (status, _, receipt, _) = launch.finish(Duration::from_secs(10));
    assert_eq!(status.code(), Some(0));
    let mut expected = big.clone();
    expected.extend(b"tail\n");
    assert_eq!(read.join().unwrap(), expected, "every byte once and in order, the tail after");
    assert_eq!(receipt["actions"][0]["state"], "complete");
    assert_eq!(receipt["actions"][0]["accepted"], 262_144);
    assert!(receipt["actions"][0]["done_ns"].as_u64().unwrap() >= 1200 * MS, "past the stall");
}

#[test]
fn a_reader_gone_mid_payload_aborts_the_launch_and_nothing_is_replayed() {
    let dir = scratch("gone");
    let token = token();
    let pid = dir.join("qemu.pid");
    let api = dir.join("api.in");
    fifo(&api);
    let big = vec![7u8; 262_144];
    let read = {
        let api = api.clone();
        std::thread::spawn(move || {
            let mut file = fs::OpenOptions::new().read(true).custom_flags(0).open(&api).expect("the fifo");
            let mut piece = vec![0u8; 65_536];
            file.read_exact(&mut piece).expect("a piece");
            piece.len()
        })
    };
    let mut planned = schedule(&dir, &token, &["sh", "-c", "echo $$ > \"$0\"; sleep 30", pid.to_str().unwrap()]);
    planned["pipes"] = json!([{ "name": "api", "path": api }]);
    planned["actions"] = json!([action("send", 0, 0, "api", &big), action("send", 1, 0, "api", b"never\n")]);
    let launch = Launch::start(&dir, planned);
    launch.authorized();
    let (status, _, receipt, _) = launch.finish(Duration::from_secs(10));
    assert_eq!(read.join().unwrap(), 65_536);
    assert_eq!(status.code(), Some(1));
    let failure = receipt["failure"].as_str().unwrap();
    assert!(failure.starts_with("the api pipe failed with"), "{failure}");
    assert_eq!(receipt["actions"][0]["state"], "incomplete");
    let accepted = receipt["actions"][0]["accepted"].as_u64().unwrap();
    assert!((65_536..262_144).contains(&accepted), "its bytes accepted: {accepted}");
    assert_eq!(receipt["actions"][1]["state"], "unattempted");
}

/// The screen's expected header, as the SDK writes it for the display's size.
const HEADER: &[u8] = b"P6\n4 2\n255\n";

#[test]
fn a_screen_of_the_whole_size_under_another_header_is_no_whole_screen() {
    let dir = scratch("screenheader");
    let token = token();
    let pid = dir.join("qemu.pid");
    let monitor = dir.join("monitor.in");
    let screen = dir.join("screen.ppm");
    fifo(&monitor);
    let read = reader(&monitor, vec![(19, Duration::ZERO)]);
    let size = HEADER.len() + 4 * 2 * 3;
    let mut wrong = b"P6\n2 4\n255\n".to_vec();
    wrong.resize(size, 0);
    let mut planned = schedule(&dir, &token, &["sh", "-c", "echo $$ > \"$0\"; sleep 1.5", pid.to_str().unwrap()]);
    planned["pipes"] = json!([{ "name": "monitor", "path": monitor }]);
    let mut shot = action("screen", 0, 100, "monitor", b"screendump \"s.ppm\"\n");
    shot["screen"] = json!({ "file": screen, "header": HEADER, "size": size });
    planned["actions"] = json!([shot, action("quit", 0, 100, "monitor", b"quit\n")]);
    let launch = Launch::start(&dir, planned);
    launch.authorized();
    assert_eq!(read.join().unwrap(), b"screendump \"s.ppm\"\n");
    fs::write(&screen, &wrong).unwrap();
    let (status, _, receipt, _) = launch.finish(Duration::from_secs(10));
    assert_eq!(status.code(), Some(0));
    assert_eq!(receipt["actions"][0]["whole"], false);
    assert_eq!(receipt["actions"][1]["state"], "unattempted", "the quit held behind the screen");
    assert_eq!(receipt["held"]["kind"], "screen");
}

#[test]
fn a_screen_found_whole_releases_the_quit_behind_it() {
    let dir = scratch("screenwhole");
    let token = token();
    let pid = dir.join("qemu.pid");
    let monitor = dir.join("monitor.in");
    let screen = dir.join("screen.ppm");
    fifo(&monitor);
    let read = reader(&monitor, vec![(19, Duration::ZERO), (5, Duration::ZERO)]);
    let size = HEADER.len() + 4 * 2 * 3;
    let mut whole = HEADER.to_vec();
    whole.resize(size, 9);
    let mut planned = schedule(&dir, &token, &["sh", "-c", "echo $$ > \"$0\"; sleep 1.5", pid.to_str().unwrap()]);
    planned["pipes"] = json!([{ "name": "monitor", "path": monitor }]);
    let mut shot = action("screen", 0, 100, "monitor", b"screendump \"s.ppm\"\n");
    shot["screen"] = json!({ "file": screen, "header": HEADER, "size": size });
    planned["actions"] = json!([shot, action("quit", 0, 100, "monitor", b"quit\n")]);
    let launch = Launch::start(&dir, planned);
    launch.authorized();
    std::thread::sleep(Duration::from_millis(400));
    fs::write(&screen, &whole).unwrap();
    let (status, _, receipt, _) = launch.finish(Duration::from_secs(10));
    assert_eq!(status.code(), Some(0));
    assert_eq!(read.join().unwrap(), b"screendump \"s.ppm\"\nquit\n");
    assert_eq!(receipt["actions"][0]["whole"], true);
    assert!(receipt["actions"][0]["whole_ns"].as_u64().unwrap() >= 400 * MS);
    assert_eq!(receipt["actions"][1]["state"], "complete");
}

#[test]
fn actions_due_before_qemu_lives_go_in_once_it_does_in_order() {
    let dir = scratch("late");
    let token = token();
    let pid = dir.join("qemu.pid");
    let api = dir.join("api.in");
    let pad = dir.join("padport.in");
    fifo(&api);
    fifo(&pad);
    let api_read = reader(&api, vec![(8, Duration::ZERO)]);
    let pad_read = reader(&pad, vec![(6, Duration::ZERO)]);
    let mut planned = schedule(&dir, &token, &["sh", "-c", "sleep 0.5; echo $$ > \"$0\"; sleep 1", pid.to_str().unwrap()]);
    planned["pipes"] = json!([{ "name": "api", "path": api }, { "name": "pad", "path": pad }]);
    planned["header"] = json!({ "pipe": "pad", "bytes": b"HEAD" });
    planned["actions"] = json!([
        action("send", 0, 0, "api", b"nonce..."),
        action("pad", 0, 100, "pad", b"P1"),
    ]);
    let launch = Launch::start(&dir, planned);
    launch.authorized();
    let (status, _, receipt, _) = launch.finish(Duration::from_secs(10));
    assert_eq!(status.code(), Some(0));
    assert_eq!(api_read.join().unwrap(), b"nonce...");
    assert_eq!(pad_read.join().unwrap(), b"HEADP1", "the header ahead of every pad event");
    let header_done = receipt["header"]["done_ns"].as_u64().unwrap();
    let first = receipt["actions"][0]["first_ns"].as_u64().unwrap();
    assert!(header_done >= 500 * MS && first >= 500 * MS, "nothing went in before QEMU lived: {header_done} {first}");
    assert!(receipt["actions"][1]["done_ns"].as_u64().unwrap() >= receipt["actions"][0]["done_ns"].as_u64().unwrap());
}

#[cfg(target_os = "linux")]
#[test]
fn readings_and_the_cpu_are_taken_beside_the_actions() {
    let dir = scratch("readings");
    let token = token();
    let pid = dir.join("qemu.pid");
    let mut planned = schedule(&dir, &token, &["sh", "-c", "echo $$ > \"$0\"; sleep 0.6", pid.to_str().unwrap()]);
    planned["readings"] = json!([
        { "kind": "at", "index": 0, "requested_ns": 200 * MS },
        { "kind": "at", "index": 1, "requested_ns": 60_000 * MS },
    ]);
    let launch = Launch::start(&dir, planned);
    launch.authorized();
    let (status, _, receipt, _) = launch.finish(Duration::from_secs(30));
    assert_eq!(status.code(), Some(0));
    let first = &receipt["readings"][0];
    assert!(first["start_ns"].as_u64().unwrap() >= 200 * MS && first["end_ns"].as_u64() >= first["start_ns"].as_u64());
    assert!(!first["threads"].as_array().unwrap().is_empty());
    assert!(receipt["readings"][1]["threads"].is_null(), "a reading past the run never taken");
    assert!(receipt["cpu_seconds"].as_f64().is_some());
}

#[test]
fn a_test_pause_before_the_readiness_delays_it() {
    let dir = scratch("pause");
    let token = token();
    let launch = Launch::start_with(&dir, schedule(&dir, &token, &["true"]), &[("JABPIPE_TEST_PAUSE", "readiness:600")]);
    assert!(launch.wait_for("readiness", Duration::from_millis(300)).is_none(), "no readiness through the pause");
    launch.authorized();
    let (status, _, receipt, _) = launch.finish(Duration::from_secs(5));
    assert_eq!(status.code(), Some(0));
    assert_eq!(receipt["outcome"]["decision"], "go");
}

/// A helper of the schedule: a name, a shell body, its stderr's file in `dir`.
fn helper(dir: &Path, name: &str, body: &str) -> Value {
    json!({ "name": name, "command": ["sh", "-c", body], "stderr": dir.join(format!("{}.stderr", name.replace(' ', "_"))) })
}

#[test]
fn a_helper_failing_while_the_child_runs_aborts_the_launch_past_the_grace() {
    let dir = scratch("helperfail");
    let token = token();
    let mut planned = schedule(&dir, &token, &["sleep", "30"]);
    planned["pidfile"] = json!("");
    planned["helpers"] = json!([helper(&dir, "pad bridge", "echo no pipe within 10 s >&2; exit 4")]);
    let launch = Launch::start(&dir, planned);
    launch.authorized();
    let (status, _, receipt, took) = launch.finish(Duration::from_secs(10));
    assert_eq!(status.code(), Some(1));
    assert_eq!(receipt["failure"], "the pad bridge failed with status 4: no pipe within 10 s");
    assert_eq!(receipt["helpers"][0]["state"], "failed");
    assert!(took >= Duration::from_secs(2) && took < Duration::from_secs(5), "after the grace: {took:?}");
}

#[test]
fn a_helper_that_cannot_start_aborts_the_launch_at_once() {
    let dir = scratch("helpernever");
    let token = token();
    let mut planned = schedule(&dir, &token, &["sleep", "30"]);
    planned["pidfile"] = json!("");
    planned["helpers"] = json!([{ "name": "pad bridge", "command": [dir.join("absent")], "stderr": dir.join("bridge.stderr") }]);
    let launch = Launch::start(&dir, planned);
    launch.authorized();
    let (status, _, receipt, took) = launch.finish(Duration::from_secs(10));
    assert_eq!(status.code(), Some(1));
    assert!(receipt["failure"].as_str().unwrap().starts_with("the pad bridge could not start:"), "{}", receipt["failure"]);
    assert_eq!(receipt["helpers"][0]["state"], "never");
    assert!(took < Duration::from_secs(2), "{took:?}");
}

#[test]
fn a_helper_ending_as_the_child_ends_is_no_failure_and_one_running_on_is_stopped() {
    let dir = scratch("helperend");
    let token = token();
    let mut planned = schedule(&dir, &token, &["sh", "-c", "sleep 0.5"]);
    planned["pidfile"] = json!("");
    planned["helpers"] = json!([helper(&dir, "pad bridge", "sleep 0.45; exit 1"), helper(&dir, "lingering", "exec sleep 31.75")]);
    let launch = Launch::start(&dir, planned);
    launch.authorized();
    let (status, stderr, receipt, _) = launch.finish(Duration::from_secs(10));
    assert_eq!(status.code(), Some(0), "{stderr}");
    assert!(receipt["failure"].is_null(), "{}", receipt["failure"]);
    assert_eq!(receipt["helpers"][0]["state"], "failed", "its own end kept");
    assert_eq!(receipt["helpers"][1]["state"], "stopped");
    let lingering = receipt["helpers"][1]["pid"].as_i64().unwrap();
    assert!(!running(lingering), "the helper running on is gone");
}

#[test]
fn the_child_writes_over_no_file_a_run_before_left() {
    let dir = scratch("fresh");
    let token = token();
    fs::write(dir.join("qemu.stdout"), b"a run before").unwrap();
    let launch = Launch::start(&dir, schedule(&dir, &token, &["true"]));
    let mut supervisor = launch.supervisor;
    let status = supervisor.wait().unwrap();
    let mut stderr = String::new();
    supervisor.stderr.take().unwrap().read_to_string(&mut stderr).unwrap();
    assert_eq!(status.code(), Some(1), "{stderr}");
    assert!(stderr.contains("qemu.stdout, the child's output, made fresh"), "{stderr}");
    assert_eq!(fs::read(dir.join("qemu.stdout")).unwrap(), b"a run before");
    let _ = std::io::stdout().flush();
}
