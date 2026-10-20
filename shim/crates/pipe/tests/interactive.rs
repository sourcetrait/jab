//! The interactive launch under a PTY: the supervisor in the terminal's foreground group,
//! the terminal's input and output carried, Ctrl-C ending the child, the terminal put back.
#![cfg(target_os = "linux")]

use serde_json::json;
use std::fs::{self, File};
use std::os::unix::io::{FromRawFd, RawFd};
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

const BIN: &str = env!("CARGO_BIN_EXE_jabpipe");

const MS: u64 = 1_000_000;

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

/// A PTY's two ends, the master non-blocking for the test's reads.
fn pty() -> (RawFd, RawFd) {
    let (mut master, mut slave) = (-1, -1);
    let opened = unsafe { libc::openpty(&mut master, &mut slave, std::ptr::null_mut(), std::ptr::null(), std::ptr::null()) };
    assert_eq!(opened, 0, "openpty");
    unsafe { libc::fcntl(master, libc::F_SETFL, libc::fcntl(master, libc::F_GETFL) | libc::O_NONBLOCK) };
    (master, slave)
}

/// The terminal's attributes as bytes, for comparing before and after.
fn attributes(fd: RawFd) -> Vec<u8> {
    let mut t = std::mem::MaybeUninit::<libc::termios>::zeroed();
    assert_eq!(unsafe { libc::tcgetattr(fd, t.as_mut_ptr()) }, 0, "tcgetattr");
    let t = unsafe { t.assume_init() };
    let mut bytes = Vec::new();
    for word in [t.c_iflag, t.c_oflag, t.c_cflag, t.c_lflag] {
        bytes.extend(word.to_le_bytes());
    }
    bytes.extend(t.c_cc);
    bytes
}

/// The terminal's foreground group, read on the master.
fn foreground(master: RawFd) -> libc::pid_t {
    let mut group: libc::pid_t = 0;
    assert_eq!(unsafe { libc::ioctl(master, libc::TIOCGPGRP, &mut group) }, 0, "TIOCGPGRP");
    group
}

/// What the terminal shows, read until it holds `needle` or `within` passes.
fn expect(master: RawFd, seen: &mut String, needle: &str, within: Duration) -> bool {
    let deadline = Instant::now() + within;
    let mut buffer = [0u8; 4096];
    while !seen.contains(needle) {
        if Instant::now() >= deadline {
            return false;
        }
        let read = unsafe { libc::read(master, buffer.as_mut_ptr().cast(), buffer.len()) };
        if read > 0 {
            seen.push_str(&String::from_utf8_lossy(&buffer[..read as usize]));
        } else {
            std::thread::sleep(Duration::from_millis(10));
        }
    }
    true
}

fn type_in(master: RawFd, bytes: &[u8]) {
    assert_eq!(unsafe { libc::write(master, bytes.as_ptr().cast(), bytes.len()) }, bytes.len() as isize, "the keys typed");
}

/// An interactive schedule over a stand-in for QEMU, its helpers as given.
fn schedule(dir: &Path, token: &str, qemu: &str, helpers: serde_json::Value) -> PathBuf {
    let planned = json!({
        "token": token, "mode": "interactive", "dir": dir, "command": ["sh", "-c", qemu],
        "env": [], "stdout": "", "stderr": "", "pidfile": "", "pipes": [], "header": null,
        "actions": [], "readings": [], "relays": [], "helpers": helpers,
        "bounds": { "startup_ns": 3000 * MS, "retry_ns": 10 * MS, "screen_ns": 5000 * MS, "screen_poll_ns": 50 * MS, "cpu_ns": 100 * MS, "grace_ns": 2000 * MS, "term_ns": 1000 * MS },
    });
    let path = dir.join(format!("launch-{token}.schedule.json"));
    fs::write(&path, serde_json::to_vec(&planned).unwrap()).unwrap();
    path
}

/// A stand-in shell leading the PTY's session, trapping its interrupt, running the supervisor in its foreground.
fn shell(slave: RawFd, token: &str, schedule: &Path) -> std::process::Child {
    let script = format!("trap 'echo shell-interrupted' INT; '{BIN}' supervise --token {token} --schedule '{}'; echo \"supervised $?\"; sleep 1", schedule.display());
    let end = || unsafe { Stdio::from(File::from_raw_fd(libc::dup(slave))) };
    let mut command = Command::new("sh");
    command.arg("-c").arg(script).stdin(end()).stdout(end()).stderr(end());
    unsafe {
        command.pre_exec(|| {
            if libc::setsid() < 0 || libc::ioctl(0, libc::TIOCSCTTY, 0) < 0 {
                return Err(std::io::Error::last_os_error());
            }
            Ok(())
        });
    }
    command.spawn().expect("the stand-in shell")
}

#[test]
fn an_interactive_run_carries_the_terminal_and_ends_on_its_interrupt() {
    let dir = scratch("interactive");
    let (master, slave) = pty();
    let before = attributes(slave);
    let qemu = "stty -icanon -echo; echo ready; read line; echo \"got $line\"; exec sleep 30";
    let path = schedule(&dir, "00000000000000c1", qemu, json!([]));
    let mut leader = shell(slave, "00000000000000c1", &path);
    let mut seen = String::new();
    assert!(expect(master, &mut seen, "ready", Duration::from_secs(5)), "the child's output carried as it runs: {seen:?}");
    let group = foreground(master);
    assert_eq!(group, leader.id() as libc::pid_t, "the foreground group the shell's, unchanged by the launch");
    type_in(master, b"hello\n");
    assert!(expect(master, &mut seen, "got hello", Duration::from_secs(5)), "the terminal's input carried to the child: {seen:?}");
    type_in(master, &[0x03]);
    assert!(expect(master, &mut seen, "supervised 130", Duration::from_secs(5)), "Ctrl-C ended the child, its status the supervisor's: {seen:?}");
    assert!(seen.contains("shell-interrupted"), "the shell took the interrupt and went on: {seen:?}");
    assert_eq!(attributes(slave), before, "the terminal's attributes as the launch found them");
    assert_eq!(foreground(master), group, "the foreground group as it was");
    let ended = leader.wait().unwrap();
    assert!(ended.success(), "the shell ended on its own: {ended}");
    unsafe {
        libc::close(master);
        libc::close(slave);
    }
}

#[test]
fn an_interactive_abort_escalates_on_a_child_refusing_term_and_puts_the_terminal_back() {
    let dir = scratch("interactiveabort");
    let (master, slave) = pty();
    let before = attributes(slave);
    let qemu = "trap '' TERM; stty -icanon -echo; echo ready; while :; do sleep 0.1; done";
    let helpers = json!([{ "name": "pad bridge", "command": ["sh", "-c", "sleep 0.3; echo gone >&2; exit 3"], "stderr": dir.join("bridge.stderr") }]);
    let path = schedule(&dir, "00000000000000c2", qemu, helpers);
    let started = Instant::now();
    let mut leader = shell(slave, "00000000000000c2", &path);
    let mut seen = String::new();
    assert!(expect(master, &mut seen, "ready", Duration::from_secs(5)), "{seen:?}");
    let group = foreground(master);
    assert!(expect(master, &mut seen, "supervised 1", Duration::from_secs(10)), "the abort's status the supervisor's: {seen:?}");
    let took = started.elapsed();
    assert!(seen.contains("the pad bridge failed with status 3: gone"), "the failure named: {seen:?}");
    assert!(took >= Duration::from_secs(3), "the grace, then TERM refused and KILL after its second: {took:?}");
    assert_eq!(attributes(slave), before, "the terminal's attributes put back after the KILL");
    assert_eq!(foreground(master), group, "the foreground group as it was");
    assert!(leader.wait().unwrap().success(), "the shell lived through the cleanup");
    unsafe {
        libc::close(master);
        libc::close(slave);
    }
}
