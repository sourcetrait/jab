//! The launch's supervisor: its child's owner from the spawn to the receipt.

use crate::*;

/// The exit for a startup that did not go, or a run its caller cancelled.
pub(crate) const ENDED_EARLY: u8 = 3;

/// The supervisor's exit for a launch it aborted, the failure named on stderr.
pub(crate) const ABORTED: u8 = 1;

/// The longest the loop sleeps between its looks.
const TICK: Duration = Duration::from_millis(10);

/// How long a relay has to see its pipe end once the child has exited.
const RELAY_END: Duration = Duration::from_secs(1);

/// `jabpipe supervise --token <t> --schedule <file>`, run to the child's reap.
pub(crate) fn supervise(args: Vec<String>) -> ExitCode {
    let started = Instant::now();
    match supervised(args, started) {
        Ok(code) => code,
        Err(error) => {
            eprintln!("jabpipe supervise: {error}");
            ExitCode::from(error.exit_code())
        }
    }
}

/// The token and the schedule's path the arguments name.
fn parsed(args: Vec<String>) -> PipeResult<(String, PathBuf)> {
    let usage = || PipeError::Usage("jabpipe supervise --token <token> --schedule <file>".to_owned());
    let (mut token, mut schedule) = (None, None);
    let mut args = args.into_iter();
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--token" => token = args.next(),
            "--schedule" => schedule = args.next(),
            _ => return Err(usage()),
        }
    }
    Ok((token.ok_or_else(usage)?, PathBuf::from(schedule.ok_or_else(usage)?)))
}

/// A test's pause at a named point, `JABPIPE_TEST_PAUSE=<point>:<ms>`.
fn pause(point: &str) {
    if let Ok(asked) = env::var("JABPIPE_TEST_PAUSE")
        && let Some((at, ms)) = asked.split_once(':')
        && at == point
        && let Ok(ms) = ms.parse::<u64>()
    {
        thread::sleep(Duration::from_millis(ms));
    }
}

/// Whether a request file there names this launch's token.
fn requested(path: &Path, token: &str) -> bool {
    matches!(read_json::<Authorization>(path), Ok(Some(request)) if request.token == token)
}

/// The startup's one decision and when it was decided: go, cancelled, or expired.
fn startup(schedule: &Schedule, dir: &Path, started: Instant) -> (&'static str, Instant) {
    let allowance = from_ns(schedule.bounds.startup_ns);
    let token = &schedule.token;
    loop {
        if started.elapsed() >= allowance {
            return ("expired", Instant::now());
        }
        if requested(&control_path(dir, token, CANCEL), token) {
            return ("cancelled", Instant::now());
        }
        if requested(&control_path(dir, token, AUTHORIZATION), token) {
            return ("go", Instant::now());
        }
        thread::sleep(from_ns(schedule.bounds.retry_ns).min(TICK));
    }
}

fn supervised(args: Vec<String>, started: Instant) -> PipeResult<ExitCode> {
    let (token, path) = parsed(args)?;
    let schedule = Schedule::load(&path)?;
    if schedule.token != token {
        return Err(PipeError::Usage(format!("{} names the token {}, not {token}", path.display(), schedule.token)));
    }
    let dir = PathBuf::from(&schedule.dir);
    let file = |kind: &str| control_path(&dir, &token, kind);
    let interactive = schedule.mode == Mode::Interactive;
    if interactive {
        ignore_interrupts();
    }
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .map_err(PipeError::io("the supervisor's runtime"))?;
    let mut child = Child::spawn(&schedule)?;
    pause("readiness");
    let me = process::id() as i64;
    let readiness = Readiness {
        token: token.clone(),
        supervisor: Process { pid: me, start: process_start(me) },
        gate: Gate { pid: child.pid(), group: child.group(), start: child.start() },
    };
    if let Err(error) = write_json(&file(READINESS), &readiness) {
        return abandoned(&mut child, Err(error));
    }
    let (decision, go) = if interactive { ("go", Instant::now()) } else { startup(&schedule, &dir, started) };
    pause("outcome");
    let outcome = Outcome { token: token.clone(), decision: decision.to_owned(), go_utc: (decision == "go").then(utc_now) };
    if let Err(error) = write_json(&file(OUTCOME), &outcome) {
        return abandoned(&mut child, Err(error));
    }
    if decision != "go" {
        let ended = abandoned(&mut child, Ok(ExitCode::from(ENDED_EARLY)));
        let run = Run::new(&schedule, &runtime, go, started, Vec::new(), Vec::new());
        write_json(&file(RECEIPT), &run.receipt(outcome, None, None))?;
        return ended;
    }
    if let Err(error) = child.release() {
        return abandoned(&mut child, Err(error));
    }
    pause("run");
    let links = schedule
        .relays
        .iter()
        .map(|r| {
            let inward = (!r.inward.is_empty()).then(|| PathBuf::from(&r.inward));
            let deadline = started + from_ns(schedule.bounds.startup_ns);
            Link::start(&runtime, &r.endpoint, &r.name, connector(&r.name), inward, PathBuf::from(&r.outward), deadline)
        })
        .collect();
    let helpers = schedule.helpers.iter().map(Running::start).collect();
    let mut run = Run::new(&schedule, &runtime, go, started, links, helpers);
    let ended = run.until_end(&mut child, &dir)?;
    let receipt = run.receipt(outcome, Some(ended), Some(ns_since(go)));
    write_json(&file(RECEIPT), &receipt)?;
    Ok(run.exit(ended))
}

/// The gate abandoned and reaped, then the result given.
fn abandoned(child: &mut Child, result: PipeResult<ExitCode>) -> PipeResult<ExitCode> {
    child.abandon();
    let _ = child.reap();
    result
}

/// A relay's connector: a Windows named pipe's client, else a Unix socket's.
#[cfg(windows)]
fn connector(name: &str) -> impl FnMut() -> io::Result<r::np::NamedPipeClient> + Send + 'static {
    let pipe = pipe_path(name);
    move || r::np::ClientOptions::new().open(&pipe)
}

#[cfg(unix)]
fn connector(name: &str) -> impl FnMut() -> io::Result<tokio::net::UnixStream> + Send + 'static {
    let path = PathBuf::from(name);
    move || {
        let stream = UnixStream::connect(&path)?;
        stream.set_nonblocking(true)?;
        tokio::net::UnixStream::from_std(stream)
    }
}

/// A run in progress: its payloads, readings, relays, helpers, and its end.
struct Run<'a> {
    schedule: &'a Schedule,
    runtime: &'a tokio::runtime::Runtime,
    go: Instant,
    started: Instant,
    links: Vec<Link>,
    helpers: Vec<Running>,
    header: Option<Payload>,
    payloads: Vec<Payload>,
    cursor: usize,
    looking: Option<Instant>,
    next_look: Instant,
    held: Option<Held>,
    readings: Vec<Taken>,
    cpu: Option<f64>,
    next_cpu: Instant,
    qemu_pid: Option<i64>,
    failure: Option<String>,
    suspect: Option<(String, Instant)>,
    cancelled_ns: Option<u64>,
    ending: Option<(Signal, Instant)>,
    exited: Option<Instant>,
}

impl<'a> Run<'a> {
    fn new(schedule: &'a Schedule, runtime: &'a tokio::runtime::Runtime, go: Instant, started: Instant, links: Vec<Link>, helpers: Vec<Running>) -> Run<'a> {
        let end_of = |pipe: &str| schedule.pipe(pipe).map(|p| p.path.clone()).unwrap_or_default();
        let header = schedule.header.as_ref().map(|h| Payload::new("header", 0, 0, &h.bytes, &h.pipe, &end_of(&h.pipe), &links));
        let payloads = schedule
            .actions
            .iter()
            .map(|a| Payload::new(&a.kind, a.index, a.due_ns, &a.bytes, &a.pipe, &end_of(&a.pipe), &links))
            .collect();
        let readings = schedule
            .readings
            .iter()
            .map(|r| Taken { kind: r.kind.clone(), index: r.index, requested_ns: r.requested_ns, start_ns: None, end_ns: None, threads: None })
            .collect();
        Run {
            schedule,
            runtime,
            go,
            started,
            links,
            helpers,
            header,
            payloads,
            cursor: 0,
            looking: None,
            next_look: go,
            held: None,
            readings,
            cpu: None,
            next_cpu: go,
            qemu_pid: None,
            failure: None,
            suspect: None,
            cancelled_ns: None,
            ending: None,
            exited: None,
        }
    }

    /// The loop until the child is reaped, nothing it owns running.
    fn until_end(&mut self, child: &mut Child, dir: &Path) -> PipeResult<Ended> {
        let schedule = self.schedule;
        let bounds = &schedule.bounds;
        loop {
            let now = Instant::now();
            if child.exited() {
                let exited = *self.exited.get_or_insert(now);
                match child.running() {
                    Ok(running) if running.is_empty() => break,
                    Ok(_) if self.ending.is_none() && now.duration_since(exited) >= from_ns(bounds.grace_ns) => {
                        self.terminate(child, now);
                    }
                    Ok(_) => {}
                    Err(error) if self.ending.is_none() => {
                        self.fail(format!("the child's group could not be read: {error}"));
                        self.terminate(child, now);
                    }
                    Err(_) => {}
                }
            }
            self.find_qemu();
            self.sample(now);
            let live = self.qemu_live(child);
            self.read_threads(live);
            self.watch_links(child, now);
            self.watch_helpers(child, now);
            if live && self.exited.is_none() && self.ending.is_none() && self.failure.is_none() && self.suspect.is_none() && self.held.is_none() {
                self.act(child, now);
            }
            if let Some((why, suspected)) = self.suspect.clone()
                && self.exited.is_none()
                && self.ending.is_none()
                && now.duration_since(suspected) >= from_ns(bounds.grace_ns)
            {
                self.fail(why);
                self.terminate(child, now);
            }
            if schedule.mode == Mode::Bounded && self.ending.is_none() && requested(&control_path(dir, &schedule.token, CANCEL), &schedule.token) {
                self.cancelled_ns = Some(ns_since(self.go));
                self.terminate(child, now);
            }
            if let Some((Signal::Term, at)) = self.ending
                && now.duration_since(at) >= from_ns(bounds.term_ns)
                && child.running().is_ok_and(|r| !r.is_empty())
            {
                child.signal(Signal::Kill);
                self.ending = Some((Signal::Kill, Instant::now()));
            }
            let wait = self.next_wake(now).saturating_duration_since(Instant::now()).clamp(Duration::from_millis(1), TICK);
            self.idle(wait);
        }
        let ended = child.reap()?;
        self.close_links();
        self.close_helpers();
        Ok(ended)
    }

    /// A helper that never started fails the launch; a failing one starts the grace.
    fn watch_helpers(&mut self, child: &mut Child, now: Instant) {
        let mut failed = None;
        for helper in &mut self.helpers {
            let ended = helper.poll();
            if helper.standing() == Standing::Never && failed.is_none() {
                failed = Some(helper.failure());
            } else if ended == Some(Standing::Failed) && self.exited.is_none() && self.suspect.is_none() {
                self.suspect = Some((helper.failure(), now));
            }
        }
        if let Some(why) = failed
            && self.ending.is_none()
            && self.exited.is_none()
        {
            self.fail(why);
            self.terminate(child, now);
        }
    }

    /// The helpers given a second to end on their own, the rest stopped.
    fn close_helpers(&mut self) {
        let deadline = Instant::now() + HELPER_END;
        loop {
            for helper in &mut self.helpers {
                helper.poll();
            }
            if Instant::now() >= deadline || self.helpers.iter().all(|h| h.standing() != Standing::Running) {
                break;
            }
            thread::sleep(TICK);
        }
        for helper in &mut self.helpers {
            helper.stop();
        }
    }

    /// The loop's wait, the relays' tasks driven through it.
    fn idle(&self, wait: Duration) {
        self.runtime.block_on(async { tokio::time::sleep(wait).await });
    }

    /// QEMU's pid from its pidfile, kept from the first read finding it alive.
    fn find_qemu(&mut self) {
        if self.qemu_pid.is_some() || self.schedule.pidfile.is_empty() {
            return;
        }
        if let Ok(text) = fs::read_to_string(&self.schedule.pidfile)
            && let Ok(pid) = text.trim().parse::<i64>()
            && process_state(pid) == State::Live
        {
            self.qemu_pid = Some(pid);
        }
    }

    /// Whether QEMU runs: its pid live, or with no pidfile the child itself.
    fn qemu_live(&self, child: &mut Child) -> bool {
        if self.schedule.pidfile.is_empty() {
            return self.exited.is_none() && !child.exited();
        }
        self.qemu_pid.is_some_and(|pid| process_state(pid) == State::Live)
    }

    /// QEMU's CPU seconds, sampled at its cadence, the last sample kept.
    fn sample(&mut self, now: Instant) {
        if now < self.next_cpu {
            return;
        }
        self.next_cpu = now + from_ns(self.schedule.bounds.cpu_ns);
        if let Some(pid) = self.qemu_pid
            && let Some(cpu) = cpu_seconds(pid)
        {
            self.cpu = Some(cpu);
        }
    }

    /// Every reading due taken while QEMU runs, its start and end timed as it is taken.
    fn read_threads(&mut self, live: bool) {
        let Some(pid) = self.qemu_pid.filter(|_| live) else {
            return;
        };
        let go = self.go;
        for reading in self.readings.iter_mut().filter(|r| r.start_ns.is_none()) {
            if reading.requested_ns > ns_since(go) {
                continue;
            }
            let start_ns = ns_since(go);
            if let Some(threads) = process_threads(pid) {
                reading.threads = Some(threads);
                reading.start_ns = Some(start_ns);
                reading.end_ns = Some(ns_since(go));
            }
        }
    }

    /// A relay's failure aborts the launch; a clean end while QEMU runs, the grace.
    fn watch_links(&mut self, child: &mut Child, now: Instant) {
        let mut failed = None;
        for link in &self.links {
            match link.seen().1 {
                Some((_, Ending::Failed(why))) if failed.is_none() => {
                    failed = Some(format!("the {} pipe's relay, for {}, failed: {why}", link.endpoint, link.name));
                }
                Some((at, Ending::Clean)) if self.exited.is_none() && self.suspect.is_none() => {
                    self.suspect = Some((format!("the {} pipe ended while QEMU ran", link.endpoint), at));
                }
                _ => {}
            }
        }
        if let Some(why) = failed
            && self.ending.is_none()
            && self.exited.is_none()
        {
            self.fail(why);
            self.terminate(child, now);
        }
    }

    /// The header, then each action due in order, each written whole before the next.
    fn act(&mut self, child: &mut Child, now: Instant) {
        let go = self.go;
        let schedule = self.schedule;
        if let Some(header) = self.header.as_mut()
            && header.done.done_ns.is_none()
        {
            match header.attempt(go, &self.links) {
                Step::Whole => {}
                Step::Waiting => return,
                Step::Broken(why) => return self.broke(child, why, now),
            }
        }
        while self.cursor < self.payloads.len() {
            let action = &schedule.actions[self.cursor];
            if action.due_ns > ns_since(go) {
                return;
            }
            if let Some(looked) = self.looking {
                if now < self.next_look {
                    return;
                }
                let screen = action.screen.as_ref().expect("a screen action carries its screen");
                let payload = &mut self.payloads[self.cursor];
                match whole(&screen.file, &screen.header, screen.size) {
                    Some(true) => {
                        payload.done.whole_ns = Some(ns_since(go));
                        payload.done.whole = Some(true);
                        self.looking = None;
                        self.cursor += 1;
                        continue;
                    }
                    Some(false) => {
                        payload.done.whole = Some(false);
                        return self.hold(format!("the screen {} came at its whole size under another header", screen.file));
                    }
                    None if now.duration_since(looked) >= from_ns(schedule.bounds.screen_ns) => {
                        payload.done.whole = Some(false);
                        return self.hold(format!("the screen {} did not come whole within its allowance", screen.file));
                    }
                    None => {
                        self.next_look = now + from_ns(schedule.bounds.screen_poll_ns);
                        return;
                    }
                }
            }
            match self.payloads[self.cursor].attempt(go, &self.links) {
                Step::Whole if action.screen.is_some() => {
                    self.looking = Some(Instant::now());
                    self.next_look = Instant::now() + from_ns(schedule.bounds.screen_poll_ns);
                    return;
                }
                Step::Whole => self.cursor += 1,
                Step::Waiting => return,
                Step::Broken(why) => return self.broke(child, why, now),
            }
        }
    }

    /// A pipe broken with bytes in: the grace, then the launch failed.
    fn broke(&mut self, child: &mut Child, why: String, now: Instant) {
        if self.qemu_live(child) {
            self.suspect.get_or_insert((why.clone(), now));
        }
        self.hold(why);
    }

    /// Every later action held at the one that could not go in.
    fn hold(&mut self, why: String) {
        if self.held.is_none() {
            let (kind, index) = match self.payloads.get(self.cursor) {
                Some(p) => (p.done.kind.clone(), p.done.index),
                None => ("header".to_owned(), 0),
            };
            self.held = Some(Held { kind, index, why });
        }
    }

    fn fail(&mut self, why: String) {
        self.failure.get_or_insert(why);
    }

    /// The termination begun: TERM to what the child owns, KILL after the grace.
    fn terminate(&mut self, child: &mut Child, now: Instant) {
        if self.ending.is_none() {
            child.signal(Signal::Term);
            self.ending = Some((Signal::Term, now));
        }
    }

    /// When the loop next has something to do, the tick its latest.
    fn next_wake(&self, now: Instant) -> Instant {
        let mut next = now + TICK;
        let due = |due_ns: u64| self.go + from_ns(due_ns);
        if let Some(action) = self.schedule.actions.get(self.cursor)
            && self.held.is_none()
        {
            next = next.min(due(action.due_ns).max(now));
        }
        if let Some(reading) = self.readings.iter().filter(|r| r.start_ns.is_none()).map(|r| due(r.requested_ns)).min() {
            next = next.min(reading.max(now));
        }
        if self.looking.is_some() {
            next = next.min(self.next_look.max(now));
        }
        next.min(self.next_cpu.max(now))
    }

    /// The relays given a second to see their pipes end, the rest stopped.
    fn close_links(&mut self) {
        let deadline = Instant::now() + RELAY_END;
        while Instant::now() < deadline && self.links.iter().any(|l| l.seen().1.is_none()) {
            self.idle(TICK);
        }
        for link in &self.links {
            link.stop();
        }
    }

    /// The exit receipt: the outcome, every action, reading, relay, and helper.
    fn receipt(&self, outcome: Outcome, ended: Option<Ended>, end_ns: Option<u64>) -> Receipt {
        let go = self.go;
        let at = |t: Instant| t.saturating_duration_since(go).as_nanos() as u64;
        let relays = self
            .links
            .iter()
            .map(|link| {
                let (connected, ended) = link.seen();
                let (state, said) = match (&connected, &ended) {
                    (_, Some((_, Ending::Clean))) => ("clean", String::new()),
                    (_, Some((_, Ending::Failed(why)))) => ("failed", why.clone()),
                    (None, _) => ("never", String::new()),
                    (Some(_), _) => ("stopped", String::new()),
                };
                RelayEnd {
                    endpoint: link.endpoint.clone(),
                    name: link.name.clone(),
                    connected_ns: connected.map(at),
                    ended_ns: ended.map(|(t, _)| at(t)),
                    state: state.to_owned(),
                    said,
                }
            })
            .collect();
        let mut actions: Vec<_> = self.payloads.iter().map(Payload::account).collect();
        for (done, action) in actions.iter_mut().zip(&self.schedule.actions) {
            if action.screen.is_some() && done.whole.is_none() && done.state != "unattempted" {
                done.whole = Some(false);
            }
        }
        let ended = ended.unwrap_or_default();
        Receipt {
            token: self.schedule.token.clone(),
            clock: Clock { origin: "go".to_owned(), unit: "ns".to_owned(), go_utc: outcome.go_utc.clone() },
            outcome,
            header: self.header.as_ref().map(Payload::account),
            actions,
            held: self.held.clone(),
            readings: self.readings.clone(),
            relays,
            helpers: self.helpers.iter().map(|h| h.end(go)).collect(),
            end_ns,
            cpu_seconds: self.cpu,
            qemu_pid: self.qemu_pid,
            status: ended.status,
            signal: ended.signal,
            stdout: self.schedule.stdout.clone(),
            stderr: self.schedule.stderr.clone(),
            failure: self.failure.clone(),
            cancelled_ns: self.cancelled_ns,
            startup_ns: self.go.saturating_duration_since(self.started).as_nanos() as u64,
        }
    }

    /// The supervisor's exit: the failure's, a cancel's, else the child's own.
    fn exit(&self, ended: Ended) -> ExitCode {
        if let Some(failure) = &self.failure {
            let status = match (ended.status, ended.signal) {
                (Some(status), _) => format!("status {status}"),
                (None, Some(signal)) => format!("signal {signal}"),
                _ => "no status".to_owned(),
            };
            eprintln!("jabpipe: {failure}; the child ended with {status}");
            return ExitCode::from(ABORTED);
        }
        if self.cancelled_ns.is_some() {
            return ExitCode::from(ENDED_EARLY);
        }
        match (ended.status, ended.signal) {
            (Some(status), _) => ExitCode::from(u8::try_from(status).unwrap_or(ABORTED)),
            (None, Some(signal)) => ExitCode::from(u8::try_from(128 + signal).unwrap_or(ABORTED)),
            _ => ExitCode::from(ABORTED),
        }
    }
}

/// Whether a screen is whole by its size and header; None while it is short.
fn whole(file: &str, header: &[u8], size: u64) -> Option<bool> {
    let length = fs::metadata(file).ok()?.len();
    if length != size {
        return None;
    }
    let mut start = vec![0u8; header.len()];
    let read = File::open(file).and_then(|mut f| f.read_exact(&mut start));
    Some(read.is_ok() && start == header)
}
