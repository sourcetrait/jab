use crate::*;

/// The API bytes a frame shows as hex when they are not cut into records.
const HEX_SHOWN: usize = 256;

/// How a frame looks: the screen, its reduction and encoding, the record size.
#[derive(Clone, Copy, Debug)]
pub(crate) struct Look {
    pub(crate) screen: bool,
    pub(crate) divisor: u32,
    pub(crate) quality: u8,
    pub(crate) format: Format,
    pub(crate) record_size: Option<usize>,
}

impl Default for Look {
    fn default() -> Look {
        Look { screen: true, divisor: 4, quality: 40, format: Format::Jpeg, record_size: None }
    }
}

/// One frame: what the machine shows and what it said since the last one.
pub(crate) struct Frame {
    pub(crate) value: serde_json::Value,
    pub(crate) shot: Option<Shot>,
}

/// The machine driven by commands, started on the first, ended by quit.
pub(crate) struct Driver {
    plan: Plan,
    elf: Option<PathBuf>,
    prefix: String,
    seconds: u64,
    machine: Option<Machine>,
    api_record: usize,
    api_partial: Vec<u8>,
    frames: u32,
    frame_at: f32,
}

impl Driver {
    pub(crate) fn new(plan: Plan, elf: Option<PathBuf>, prefix: String, seconds: u64) -> Driver {
        Driver { plan, elf, prefix, seconds, machine: None, api_record: 0, api_partial: Vec::new(), frames: 0, frame_at: 0.0 }
    }

    /// The machine, started when none runs yet.
    fn machine(&mut self) -> RoboResult<&mut Machine> {
        if self.machine.is_none() {
            self.start()?;
        }
        Ok(self.machine.as_mut().expect("a started machine"))
    }

    /// A fresh machine from the plan, any running one ended first.
    pub(crate) fn start(&mut self) -> RoboResult<()> {
        if let Some(machine) = &mut self.machine {
            let _ = machine.quit();
        }
        self.machine = Some(Machine::start(self.plan.clone(), self.seconds)?);
        self.api_record = 0;
        self.api_partial.clear();
        self.frame_at = 0.0;
        Ok(())
    }

    pub(crate) fn seconds(&self) -> u64 {
        self.seconds
    }

    /// Whether QEMU runs right now.
    pub(crate) fn alive(&mut self) -> bool {
        self.machine.as_mut().is_some_and(|m| m.alive())
    }

    /// Seconds since the machine started, none before it has.
    pub(crate) fn elapsed(&self) -> Option<f32> {
        self.machine.as_ref().map(|m| m.elapsed())
    }

    /// The run ended, with the exit code; -1 for a machine never started.
    pub(crate) fn quit(&mut self) -> RoboResult<i32> {
        match &mut self.machine {
            Some(machine) => machine.quit(),
            None => Ok(-1),
        }
    }

    /// A line of commands separated by `;`, each answered in order.
    pub(crate) fn line(&mut self, line: &str) -> Vec<serde_json::Value> {
        line.split(';')
            .map(str::trim)
            .filter(|c| !c.is_empty())
            .map(|c| {
                let words = split(c);
                match self.command(&words) {
                    Ok(value) => {
                        let mut record = serde_json::Map::new();
                        record.insert("ok".to_owned(), serde_json::Value::Bool(true));
                        record.insert("command".to_owned(), serde_json::Value::String(c.to_owned()));
                        if let serde_json::Value::Object(fields) = value {
                            record.extend(fields);
                        } else if !value.is_null() {
                            record.insert("value".to_owned(), value);
                        }
                        serde_json::Value::Object(record)
                    }
                    Err(error) => serde_json::json!({ "ok": false, "command": c, "error": error.to_string() }),
                }
            })
            .collect()
    }

    /// One command answered.
    pub(crate) fn command(&mut self, words: &[String]) -> RoboResult<serde_json::Value> {
        let w: Vec<&str> = words.iter().map(String::as_str).collect();
        match w.as_slice() {
            ["status"] => self.status(),
            ["wait", ms] => {
                let ms: u64 = ms.parse().map_err(|_| RoboError::Command(format!("wait takes milliseconds, not {ms}")))?;
                thread::sleep(Duration::from_millis(ms));
                self.status()
            }
            ["restart"] => {
                self.start()?;
                self.status()
            }
            ["quit"] => {
                let code = self.quit()?;
                let faults = self.faults();
                Ok(serde_json::json!({ "exit": code, "faults": faults }))
            }
            ["pad", "stick", which, x, y] => {
                let (cx, cy) = match *which {
                    "left" | "l" => (ABS_X, ABS_Y),
                    "right" | "r" => (ABS_Z, ABS_RZ),
                    _ => return Err(RoboError::Command(format!("a stick is left or right, not {which}"))),
                };
                let x: f32 = x.parse().map_err(|_| RoboError::Command(format!("a throw is -1 to 1, not {x}")))?;
                let y: f32 = y.parse().map_err(|_| RoboError::Command(format!("a throw is -1 to 1, not {y}")))?;
                let moved = self.pad()?.axes(&[(cx, stick_value(x)), (cy, stick_value(-y))])?;
                Ok(serde_json::json!({ "moved": moved }))
            }
            ["pad", "trigger", which, pull] => {
                let code = match *which {
                    "left" | "l" => ABS_BRAKE,
                    "right" | "r" => ABS_GAS,
                    _ => return Err(RoboError::Command(format!("a trigger is left or right, not {which}"))),
                };
                let pull: f32 = pull.parse().map_err(|_| RoboError::Command(format!("a pull is 0 to 1, not {pull}")))?;
                let moved = self.pad()?.axes(&[(code, trigger_value(pull))])?;
                Ok(serde_json::json!({ "moved": moved }))
            }
            ["pad", "hat", x, y] => {
                let x: i32 = x.parse().map_err(|_| RoboError::Command("a hat is -1, 0, or 1".to_owned()))?;
                let y: i32 = y.parse().map_err(|_| RoboError::Command("a hat is -1, 0, or 1".to_owned()))?;
                let moved = self.pad()?.axes(&[(ABS_HAT0X, x.clamp(-1, 1)), (ABS_HAT0Y, y.clamp(-1, 1))])?;
                Ok(serde_json::json!({ "moved": moved }))
            }
            ["pad", "button", name, state] => {
                let code = button(name).ok_or_else(|| RoboError::Command(format!("no button {name}")))?;
                let down = matches!(*state, "1" | "down" | "press");
                self.pad()?.button(code, down)?;
                Ok(serde_json::json!({ "button": code, "down": down }))
            }
            ["pad", "tap", name] | ["pad", "tap", name, _] => {
                let hold: u64 = w.get(3).and_then(|s| s.parse().ok()).unwrap_or(100);
                let code = button(name).ok_or_else(|| RoboError::Command(format!("no button {name}")))?;
                self.pad()?.button(code, true)?;
                thread::sleep(Duration::from_millis(hold));
                self.pad()?.button(code, false)?;
                Ok(serde_json::json!({ "button": code, "held_ms": hold }))
            }
            ["pad", "rest"] => {
                let moved = self.pad()?.rest()?;
                Ok(serde_json::json!({ "moved": moved }))
            }
            ["pad", "raw", rest @ ..] => {
                if rest.is_empty() || rest.len() % 3 != 0 {
                    return Err(RoboError::Command("pad raw takes triples: <type> <code> <value>...".to_owned()));
                }
                let mut events = Vec::new();
                for triple in rest.chunks(3) {
                    let kind: u16 = triple[0].parse().map_err(|_| RoboError::Command(format!("an event type, not {}", triple[0])))?;
                    let code: u16 = triple[1].parse().map_err(|_| RoboError::Command(format!("an event code, not {}", triple[1])))?;
                    let value: i32 = triple[2].parse().map_err(|_| RoboError::Command(format!("an event value, not {}", triple[2])))?;
                    events.push((kind, code, value));
                }
                self.pad()?.raw(&events)?;
                Ok(serde_json::json!({ "events": events.len() }))
            }
            ["key", name] | ["key", name, _] => {
                let hold: u64 = w.get(2).and_then(|s| s.parse().ok()).unwrap_or(100);
                self.machine()?.monitor(&format!("sendkey {name} {hold}"))?;
                Ok(serde_json::json!({ "key": name, "held_ms": hold }))
            }
            ["api", "send", hex_text] => {
                let bytes = unhex(hex_text)?;
                let sent = self.machine()?.api_send(&bytes)?;
                Ok(serde_json::json!({ "sent": sent }))
            }
            ["api", "recv"] => {
                let fresh = self.machine()?.api_recv()?;
                let bytes = self.held(fresh);
                Ok(serde_json::json!({ "bytes": bytes.len(), "hex": hex(&bytes) }))
            }
            ["api", "records", size] => {
                let size: usize = size.parse().map_err(|_| RoboError::Command("a record size in bytes".to_owned()))?;
                let fresh = self.machine()?.api_recv()?;
                let bytes = self.held(fresh);
                Ok(self.records(bytes, size)?)
            }
            ["serial"] => {
                let lines = self.machine()?.serial()?;
                let faults = self.faults();
                Ok(serde_json::json!({ "lines": lines, "faults": faults }))
            }
            ["debug"] => {
                let lines = self.machine()?.debug()?;
                Ok(serde_json::json!({ "lines": lines }))
            }
            ["faults"] => {
                self.machine()?.poll()?;
                let faults = self.faults();
                Ok(serde_json::json!({ "faults": faults }))
            }
            ["screen", file] | ["screen", file, _] | ["screen", file, _, _] => {
                let divisor: u32 = w.get(2).and_then(|s| s.parse().ok()).unwrap_or(4);
                let quality: u8 = w.get(3).and_then(|s| s.parse().ok()).unwrap_or(40);
                let format = Path::new(file).extension().and_then(|e| e.to_str()).and_then(Format::parse).unwrap_or(Format::Jpeg);
                let ppm = self.machine()?.screendump()?;
                let shot = capture(&ppm, divisor, quality, format)?;
                fs::write(file, &shot.bytes).map_err(RoboError::io(file.to_string()))?;
                Ok(serde_json::json!({ "file": file, "width": shot.width, "height": shot.height, "bytes": shot.bytes.len() }))
            }
            ["sound", from, to] | ["sound", from, to, _] => {
                let stride: usize = w.get(3).and_then(|s| s.parse().ok()).unwrap_or(97);
                let from: f32 = from.parse().map_err(|_| RoboError::Command("seconds".to_owned()))?;
                let to: f32 = to.parse().map_err(|_| RoboError::Command("seconds".to_owned()))?;
                let wav = self.plan.sound.clone().ok_or_else(|| RoboError::Command("the machine records no sound".to_owned()))?;
                sound_level(&wav, from, to, stride)
            }
            ["frame"] | ["frame", _] | ["frame", _, _] | ["frame", _, _, _] => {
                let look = Look {
                    divisor: w.get(1).and_then(|s| s.parse().ok()).unwrap_or(4),
                    quality: w.get(2).and_then(|s| s.parse().ok()).unwrap_or(40),
                    record_size: w.get(3).and_then(|s| s.parse().ok()),
                    ..Look::default()
                };
                Ok(self.frame(&look)?.value)
            }
            _ => Err(RoboError::Command(format!("unknown command: {}", words.join(" ")))),
        }
    }

    /// The frame: the machine's state and what it said since the last one.
    pub(crate) fn frame(&mut self, look: &Look) -> RoboResult<Frame> {
        let elf = self.elf.clone();
        let prefix = self.prefix.clone();
        let wav = self.plan.sound.clone();
        let out = self.plan.out.clone();
        let since = self.frame_at;
        self.frames += 1;
        let number = self.frames;
        let record_size = look.record_size;
        let machine = self.machine()?;
        let alive = machine.alive();
        let now = machine.elapsed();
        let serial = machine.serial()?;
        let debug = machine.debug()?;
        let api_bytes = if machine.has_api() { Some(machine.api_recv()?) } else { None };
        let fault_lines = machine.faults.clone();
        let exit = machine.exit_code();
        let shot = if alive && look.screen {
            let ppm = machine.screendump()?;
            Some(capture(&ppm, look.divisor, look.quality, look.format)?)
        } else {
            None
        };
        let faults: Vec<serde_json::Value> = fault_lines
            .iter()
            .map(|f| serde_json::json!({ "line": f, "routine": Machine::resolve(f, elf.as_deref(), &prefix) }))
            .collect();
        let api = match api_bytes {
            Some(fresh) => {
                let bytes = self.held(fresh);
                match record_size {
                    Some(size) => self.records(bytes, size)?,
                    None => {
                        let shown = bytes.len().min(HEX_SHOWN);
                        serde_json::json!({ "bytes": bytes.len(), "hex": hex(&bytes[..shown]), "shown": shown })
                    }
                }
            }
            None => serde_json::Value::Null,
        };
        let sound = wav.and_then(|wav| sound_level(&wav, since, now, 97).ok()).unwrap_or(serde_json::Value::Null);
        let screen = match &shot {
            Some(shot) => {
                let file = out.join(format!("frame_{number}.{}", shot.format.extension()));
                fs::write(&file, &shot.bytes).map_err(RoboError::io(file.display().to_string()))?;
                serde_json::json!({ "file": file.display().to_string(), "width": shot.width, "height": shot.height, "format": shot.format.mime() })
            }
            None => serde_json::Value::Null,
        };
        self.frame_at = now;
        let value = serde_json::json!({
            "frame": number,
            "alive": alive,
            "exit": exit,
            "elapsed": now,
            "since": since,
            "faults": faults,
            "serial": serial,
            "debug": debug,
            "api": api,
            "sound": sound,
            "screen": screen,
        });
        Ok(Frame { value, shot })
    }

    fn pad(&mut self) -> RoboResult<&mut Pad> {
        self.machine()?.pad.as_mut().ok_or_else(|| RoboError::Command("the machine has no pad".to_owned()))
    }

    /// The faults so far, each resolved to its routine when an ELF is known.
    fn faults(&self) -> Vec<serde_json::Value> {
        let Some(machine) = &self.machine else { return Vec::new() };
        machine
            .faults
            .iter()
            .map(|f| serde_json::json!({ "line": f, "routine": Machine::resolve(f, self.elf.as_deref(), &self.prefix) }))
            .collect()
    }

    /// The bytes kept from the last read, then the new ones.
    pub(crate) fn held(&mut self, fresh: Vec<u8>) -> Vec<u8> {
        let mut bytes = std::mem::take(&mut self.api_partial);
        bytes.extend(fresh);
        bytes
    }

    /// The bytes cut into records, a trailing part kept for the next read.
    pub(crate) fn records(&mut self, bytes: Vec<u8>, size: usize) -> RoboResult<serde_json::Value> {
        if size == 0 {
            self.api_partial = bytes;
            return Err(RoboError::Command("a record size above zero".to_owned()));
        }
        let whole = bytes.len() - bytes.len() % size;
        let records: Vec<String> = bytes[..whole].chunks_exact(size).map(hex).collect();
        let first = self.api_record;
        self.api_record += records.len();
        self.api_partial = bytes[whole..].to_vec();
        Ok(serde_json::json!({ "bytes": whole, "first": first, "records": records, "remainder": self.api_partial.len() }))
    }

    /// Whether QEMU runs, the seconds since the start, and the faults so far.
    fn status(&mut self) -> RoboResult<serde_json::Value> {
        let alive = self.alive();
        if let Some(machine) = &mut self.machine {
            machine.poll()?;
        }
        let exit = self.machine.as_ref().and_then(|m| m.exit_code());
        let faults = self.faults();
        Ok(serde_json::json!({
            "alive": alive,
            "exit": exit,
            "elapsed": self.elapsed(),
            "faults": faults,
        }))
    }
}

/// A command's words, double quotes grouping.
pub(crate) fn split(line: &str) -> Vec<String> {
    let mut words = Vec::new();
    let mut word = String::new();
    let mut quoted = false;
    for c in line.chars() {
        match c {
            '"' => quoted = !quoted,
            c if c.is_whitespace() && !quoted => {
                if !word.is_empty() {
                    words.push(std::mem::take(&mut word));
                }
            }
            c => word.push(c),
        }
    }
    if !word.is_empty() {
        words.push(word);
    }
    words
}

/// The driver behind its lock, a poisoned lock taken anyway.
pub(crate) fn lock(driver: &Mutex<Driver>) -> MutexGuard<'_, Driver> {
    driver.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}
