//! A launch's helpers: run beside its child from the go, each watched and ended with the run.

use crate::*;
use crate::receipt::HelperEnd;
use crate::schedule::Helper;

/// How long a helper has to end on its own once the run has.
pub(crate) const HELPER_END: Duration = Duration::from_secs(1);

/// How a helper stands: running, or ended clean, failed, stopped, or never started.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Standing {
    Running,
    Clean,
    Failed,
    Stopped,
    Never,
}

/// A helper's process and its account, from its start to its end.
pub(crate) struct Running {
    name: String,
    stderr: String,
    process: Option<std::process::Child>,
    started: Option<Instant>,
    ended: Option<Instant>,
    status: Option<i32>,
    standing: Standing,
    refused: Option<String>,
}

impl Running {
    /// The helper started, its stderr a fresh file; one that cannot start stands never started.
    pub(crate) fn start(helper: &Helper) -> Running {
        let mut running = Running {
            name: helper.name.clone(),
            stderr: helper.stderr.clone(),
            process: None,
            started: None,
            ended: None,
            status: None,
            standing: Standing::Never,
            refused: None,
        };
        let spawned = OpenOptions::new().write(true).create_new(true).open(&helper.stderr).and_then(|said| {
            std::process::Command::new(&helper.command[0])
                .args(&helper.command[1..])
                .stdin(std::process::Stdio::null())
                .stdout(std::process::Stdio::null())
                .stderr(said)
                .spawn()
        });
        match spawned {
            Ok(process) => {
                running.process = Some(process);
                running.started = Some(Instant::now());
                running.standing = Standing::Running;
            }
            Err(error) => running.refused = Some(error.to_string()),
        }
        running
    }

    pub(crate) fn standing(&self) -> Standing {
        self.standing
    }

    /// Its end, read without waiting: the standing it ended in, or none while it runs.
    pub(crate) fn poll(&mut self) -> Option<Standing> {
        if self.standing != Standing::Running {
            return None;
        }
        let ended = self.process.as_mut()?.try_wait().ok()??;
        self.ended = Some(Instant::now());
        self.status = ended.code();
        self.standing = if ended.success() { Standing::Clean } else { Standing::Failed };
        Some(self.standing)
    }

    /// What its stderr said last, a line or two.
    fn said(&self) -> String {
        if let Some(refused) = &self.refused {
            return refused.clone();
        }
        let text = std::fs::read(&self.stderr).map(|b| String::from_utf8_lossy(&b).into_owned()).unwrap_or_default();
        let lines: Vec<&str> = text.lines().filter(|l| !l.trim().is_empty()).collect();
        lines[lines.len().saturating_sub(2)..].join("; ")
    }

    /// The failure the launch names for it.
    pub(crate) fn failure(&self) -> String {
        match (self.standing, self.status) {
            (Standing::Never, _) => format!("the {} could not start: {}", self.name, self.said()),
            (_, Some(status)) => format!("the {} failed with status {status}: {}", self.name, self.said()),
            _ => format!("the {} failed: {}", self.name, self.said()),
        }
    }

    /// The helper stopped where it stands and reaped.
    pub(crate) fn stop(&mut self) {
        if self.standing != Standing::Running {
            return;
        }
        if let Some(process) = self.process.as_mut() {
            let _ = process.kill();
            let _ = process.wait();
        }
        self.ended = Some(Instant::now());
        self.standing = Standing::Stopped;
    }

    /// Its account as the receipt carries it, times from the go.
    pub(crate) fn end(&self, go: Instant) -> HelperEnd {
        let at = |t: Instant| t.saturating_duration_since(go).as_nanos() as u64;
        let state = match self.standing {
            Standing::Running | Standing::Stopped => "stopped",
            Standing::Clean => "clean",
            Standing::Failed => "failed",
            Standing::Never => "never",
        };
        HelperEnd {
            name: self.name.clone(),
            pid: self.process.as_ref().map(|p| p.id() as i64),
            started_ns: self.started.map(at),
            ended_ns: self.ended.map(at),
            status: self.status,
            state: state.to_owned(),
            said: self.said(),
        }
    }
}
