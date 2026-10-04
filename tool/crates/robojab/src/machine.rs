use crate::*;

/// Linux's non-blocking open flag, for a fifo that may have no reader.
const O_NONBLOCK: i32 = 0o4000;

/// A word for the QEMU monitor's command line, which splits on spaces: in
/// double quotes, a backslash and a double quote inside escaped, so a path
/// with spaces in it stays one argument.
pub(crate) fn hmp_quoted(text: &str) -> String {
    format!("\"{}\"", text.replace('\\', "\\\\").replace('"', "\\\""))
}

/// A file read from where the last read left off.
pub(crate) struct Tail {
    path: PathBuf,
    offset: u64,
    partial: Vec<u8>,
}

impl Tail {
    pub(crate) fn new(path: PathBuf) -> Tail {
        Tail { path, offset: 0, partial: Vec::new() }
    }

    /// The bytes written since the last read; none while the file is absent.
    pub(crate) fn bytes(&mut self) -> RoboResult<Vec<u8>> {
        let Ok(mut file) = fs::File::open(&self.path) else { return Ok(Vec::new()) };
        file.seek(SeekFrom::Start(self.offset)).map_err(RoboError::io(self.path.display().to_string()))?;
        let mut out = Vec::new();
        file.read_to_end(&mut out).map_err(RoboError::io(self.path.display().to_string()))?;
        self.offset += out.len() as u64;
        Ok(out)
    }

    /// The whole lines written since the last read, a partial one kept.
    pub(crate) fn lines(&mut self) -> RoboResult<Vec<String>> {
        let fresh = self.bytes()?;
        self.partial.extend_from_slice(&fresh);
        let mut lines = Vec::new();
        while let Some(at) = self.partial.iter().position(|b| *b == b'\n') {
            let line: Vec<u8> = self.partial.drain(..=at).collect();
            lines.push(String::from_utf8_lossy(&line[..line.len() - 1]).into_owned());
        }
        Ok(lines)
    }
}

/// The running machine: QEMU under `timeout` for the bound.
pub(crate) struct Machine {
    pub(crate) plan: Plan,
    child: Child,
    started: Instant,
    pub(crate) pad: Option<Pad>,
    api_in: Option<fs::File>,
    serial: Tail,
    debug: Option<Tail>,
    api_out: Option<Tail>,
    pending_serial: Vec<String>,
    pub(crate) faults: Vec<String>,
    exit: Option<i32>,
    shots: u32,
}

impl Machine {
    /// QEMU started from the plan under `timeout`, as the SDK's launch runs
    /// it, a previous run's files retired first (retire), its pipes kept.
    pub(crate) fn start(plan: Plan, seconds: u64) -> RoboResult<Machine> {
        let root = plan.target()?;
        let stdout_path = plan.out.join("robojab.stdout");
        let stderr_path = plan.out.join("robojab.stderr");
        let qemu_log = plan.qemu.iter().position(|a| a == "-D").and_then(|at| plan.qemu.get(at + 1)).map(PathBuf::from);
        for path in [Some(&plan.pidfile), Some(&plan.serial_log), plan.api_out.as_ref(), plan.debug_log.as_ref(), plan.sound.as_ref(), qemu_log.as_ref(), Some(&stdout_path), Some(&stderr_path)].into_iter().flatten() {
            retire(path, &root)?;
        }
        for path in [&plan.api_out, &plan.debug_log].into_iter().flatten() {
            fs::write(path, b"").map_err(RoboError::io(path.display().to_string()))?;
        }
        let stdout = fs::File::create(&stdout_path).map_err(RoboError::io("robojab.stdout"))?;
        let stderr = fs::File::create(&stderr_path).map_err(RoboError::io("robojab.stderr"))?;
        let mut command = Command::new("timeout");
        command
            .arg("--signal=TERM")
            .arg(seconds.to_string())
            .arg(&plan.qemu_binary)
            .args(&plan.qemu)
            .envs(&plan.env)
            .stdin(Stdio::null())
            .stdout(stdout)
            .stderr(stderr);
        let child = command.spawn().map_err(RoboError::io(format!("timeout {}", plan.qemu_binary)))?;
        let started = Instant::now();
        let mut machine = Machine {
            serial: Tail::new(plan.serial_log.clone()),
            debug: plan.debug_log.clone().map(Tail::new),
            api_out: plan.api_out.clone().map(Tail::new),
            plan,
            child,
            started,
            pad: None,
            api_in: None,
            pending_serial: Vec::new(),
            faults: Vec::new(),
            exit: None,
            shots: 0,
        };
        machine.wait_up()?;
        machine.pad = Pad::open(&machine.plan)?;
        if let Some(path) = &machine.plan.api_in {
            machine.api_in = Some(fs::OpenOptions::new().read(true).write(true).open(path).map_err(RoboError::io(path.display().to_string()))?);
        }
        Ok(machine)
    }

    /// Until the pid file appears, five seconds at most.
    fn wait_up(&mut self) -> RoboResult<()> {
        for _ in 0..100 {
            if self.plan.pidfile.exists() {
                return Ok(());
            }
            if let Some(status) = self.child.try_wait().map_err(RoboError::io("qemu"))? {
                let said = fs::read_to_string(self.plan.out.join("robojab.stderr")).unwrap_or_default();
                return Err(RoboError::Machine(format!("qemu ended with {status} before it was up: {said}")));
            }
            thread::sleep(Duration::from_millis(50));
        }
        Err(RoboError::Machine("qemu wrote no pid file in five seconds".to_owned()))
    }

    /// Seconds since the start.
    pub(crate) fn elapsed(&self) -> f32 {
        self.started.elapsed().as_secs_f32()
    }

    /// Whether QEMU still runs; its exit code kept once it does not.
    pub(crate) fn alive(&mut self) -> bool {
        if self.exit.is_some() {
            return false;
        }
        match self.child.try_wait() {
            Ok(Some(status)) => {
                self.exit = Some(status.code().unwrap_or(-1));
                false
            }
            Ok(None) => true,
            Err(_) => false,
        }
    }

    pub(crate) fn exit_code(&self) -> Option<i32> {
        self.exit
    }

    /// A command into the monitor's pipe, opened without blocking.
    pub(crate) fn monitor(&mut self, command: &str) -> RoboResult<()> {
        let path = PathBuf::from(format!("{}.in", self.plan.monitor.display()));
        let mut pipe = fs::OpenOptions::new().write(true).custom_flags(O_NONBLOCK).open(&path).map_err(RoboError::io("the monitor"))?;
        pipe.write_all(format!("{command}\n").as_bytes()).map_err(RoboError::io("the monitor"))
    }

    /// Bytes into the API's pipe.
    pub(crate) fn api_send(&mut self, bytes: &[u8]) -> RoboResult<usize> {
        let Some(pipe) = &mut self.api_in else { return Err(RoboError::Command("the machine has no API port".to_owned())) };
        pipe.write_all(bytes).map_err(RoboError::io("the API"))?;
        pipe.flush().map_err(RoboError::io("the API"))?;
        Ok(bytes.len())
    }

    /// The program's bytes over the API since the last receive.
    pub(crate) fn api_recv(&mut self) -> RoboResult<Vec<u8>> {
        match &mut self.api_out {
            Some(tail) => tail.bytes(),
            None => Err(RoboError::Command("the machine has no API port".to_owned())),
        }
    }

    pub(crate) fn has_api(&self) -> bool {
        self.api_out.is_some()
    }

    /// The UART read up to now, its new lines kept and its faults noted.
    pub(crate) fn poll(&mut self) -> RoboResult<()> {
        let lines = self.serial.lines()?;
        for line in &lines {
            if line.starts_with("jab: ") {
                self.faults.push(line.clone());
            }
        }
        self.pending_serial.extend(lines);
        Ok(())
    }

    /// The UART's lines since the last `serial`.
    pub(crate) fn serial(&mut self) -> RoboResult<Vec<String>> {
        self.poll()?;
        Ok(std::mem::take(&mut self.pending_serial))
    }

    /// The debug channel's new lines, none without the channel.
    pub(crate) fn debug(&mut self) -> RoboResult<Vec<String>> {
        match &mut self.debug {
            Some(tail) => tail.lines(),
            None => Ok(Vec::new()),
        }
    }

    /// The screen through the monitor into a fresh PPM beside the plan's
    /// files, a previous run's of that name retired.
    pub(crate) fn screendump(&mut self) -> RoboResult<PathBuf> {
        self.shots += 1;
        let path = self.plan.out.join(format!("shot_{}.ppm", self.shots));
        retire(&path, &self.plan.target()?)?;
        self.monitor(&format!("screendump {}", hmp_quoted(&path.display().to_string())))?;
        let mut last = 0u64;
        for _ in 0..200 {
            thread::sleep(Duration::from_millis(50));
            if let Ok(meta) = fs::metadata(&path) {
                let size = meta.len();
                if size > 0 && size == last {
                    return Ok(path);
                }
                last = size;
            }
        }
        Err(RoboError::Machine("no screendump landed in ten seconds".to_owned()))
    }

    /// The run ended, by the monitor's quit, then TERM, then a kill.
    pub(crate) fn quit(&mut self) -> RoboResult<i32> {
        if !self.alive() {
            return Ok(self.exit.unwrap_or(-1));
        }
        let _ = self.monitor("quit");
        for _ in 0..60 {
            if !self.alive() {
                return Ok(self.exit.unwrap_or(-1));
            }
            thread::sleep(Duration::from_millis(50));
        }
        if let Ok(pid) = fs::read_to_string(&self.plan.pidfile) {
            let _ = Command::new("kill").arg("-TERM").arg(pid.trim()).status();
        }
        for _ in 0..60 {
            if !self.alive() {
                return Ok(self.exit.unwrap_or(-1));
            }
            thread::sleep(Duration::from_millis(50));
        }
        let _ = self.child.kill();
        let _ = self.child.wait();
        self.exit = Some(-9);
        Ok(-9)
    }

    /// A fault line's routine and offset from the ELF's symbols through nm.
    pub(crate) fn resolve(fault: &str, elf: Option<&Path>, prefix: &str) -> Option<String> {
        let elf = elf?;
        let epc = fault.split("epc=").nth(1)?.split_whitespace().next()?;
        let at = u64::from_str_radix(epc.trim_start_matches("0x"), 16).ok()?;
        let listing = Command::new(format!("{prefix}nm")).arg("-n").arg(elf).output().ok()?;
        let text = String::from_utf8_lossy(&listing.stdout);
        let mut best: Option<(u64, String)> = None;
        for line in text.lines() {
            let mut parts = line.split_whitespace();
            let (Some(address), Some(kind), Some(name)) = (parts.next(), parts.next(), parts.next()) else { continue };
            if kind != "t" && kind != "T" {
                continue;
            }
            let Ok(address) = u64::from_str_radix(address, 16) else { continue };
            if address <= at && best.as_ref().is_none_or(|(b, _)| address >= *b) {
                best = Some((address, name.to_owned()));
            }
        }
        best.map(|(address, name)| format!("{name} + {}", at - address))
    }
}
