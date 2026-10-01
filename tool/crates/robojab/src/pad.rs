use crate::*;

/// The reference pad's axis codes, evdev's.
pub(crate) const ABS_X: u16 = 0;
pub(crate) const ABS_Y: u16 = 1;
pub(crate) const ABS_Z: u16 = 2;
pub(crate) const ABS_RZ: u16 = 5;
pub(crate) const ABS_GAS: u16 = 9;
pub(crate) const ABS_BRAKE: u16 = 10;
pub(crate) const ABS_HAT0X: u16 = 16;
pub(crate) const ABS_HAT0Y: u16 = 17;
const EV_SYN: u16 = 0;
const EV_KEY: u16 = 1;
const EV_ABS: u16 = 3;

/// A button's code by its name, as the pad bridge maps gilrs's, or a
/// code given outright in BTN_GAMEPAD's range.
pub(crate) fn button(name: &str) -> Option<u16> {
    let code = match name {
        "south" | "a" => 304,
        "east" | "b" => 305,
        "c" => 306,
        "north" | "x" => 307,
        "west" | "y" => 308,
        "z" => 309,
        "tl" | "l1" => 310,
        "tr" | "r1" => 311,
        "tl2" | "l2" => 312,
        "tr2" | "r2" => 313,
        "select" => 314,
        "start" => 315,
        "mode" => 316,
        "thumbl" | "l3" => 317,
        "thumbr" | "r3" => 318,
        _ => return name.parse::<u16>().ok().filter(|c| (304..=335).contains(c)),
    };
    Some(code)
}

/// A centred stick axis, -1 to 1, on the reference pad's 0 to 255.
pub(crate) fn stick_value(throw: f32) -> i32 {
    (127.0 + throw.clamp(-1.0, 1.0) * 128.0).round().clamp(0.0, 255.0) as i32
}

/// A one-sided trigger, 0 to 1, on 0 to 255.
pub(crate) fn trigger_value(pull: f32) -> i32 {
    (pull.clamp(0.0, 1.0) * 255.0).round() as i32
}

/// The pad the harness plays: the fifo QEMU reads as a device through the
/// evdev shim, 24-byte input_event records with a SYN closing each report,
/// or the pad port, eight-byte frames after its header; the axes' last
/// values, so a report carries only what moved.
pub(crate) struct Pad {
    sink: fs::File,
    port: bool,
    axes: HashMap<u16, i32>,
}

impl Pad {
    /// The fifo or the port opened read-write, so the open never waits
    /// on a reader; the port's header sent first.
    pub(crate) fn open(plan: &Plan) -> RoboResult<Option<Pad>> {
        let (path, port) = match (&plan.pad_fifo, &plan.pad_pipe_in) {
            (Some(fifo), _) if !plan.pad_port => (fifo.clone(), false),
            (_, Some(pipe)) => (pipe.clone(), true),
            _ => return Ok(None),
        };
        let mut sink = fs::OpenOptions::new().read(true).write(true).open(&path).map_err(RoboError::io(path.display().to_string()))?;
        if port {
            sink.write_all(&plan.pad_header).map_err(RoboError::io("the pad port's header"))?;
        }
        let mut axes = HashMap::new();
        for code in [ABS_X, ABS_Y, ABS_Z, ABS_RZ] {
            axes.insert(code, 127);
        }
        for code in [ABS_GAS, ABS_BRAKE, ABS_HAT0X, ABS_HAT0Y] {
            axes.insert(code, 0);
        }
        Ok(Some(Pad { sink, port, axes }))
    }

    /// Axes set to values as one report; the ones that moved.
    pub(crate) fn axes(&mut self, wanted: &[(u16, i32)]) -> RoboResult<Vec<(u16, i32)>> {
        let mut moved = Vec::new();
        for (code, value) in wanted {
            if self.axes.get(code) != Some(value) {
                self.axes.insert(*code, *value);
                moved.push((*code, *value));
            }
        }
        if moved.is_empty() {
            return Ok(moved);
        }
        let events: Vec<(u16, u16, i32)> = moved.iter().map(|(code, value)| (EV_ABS, *code, *value)).collect();
        self.report(&events)?;
        Ok(moved)
    }

    /// A button pressed or released, as one report.
    pub(crate) fn button(&mut self, code: u16, down: bool) -> RoboResult<()> {
        self.report(&[(EV_KEY, code, if down { 1 } else { 0 })])
    }

    /// Events given outright, type, code, and value each, as one report:
    /// what a real device sends beyond the reference pad's own set.
    pub(crate) fn raw(&mut self, events: &[(u16, u16, i32)]) -> RoboResult<()> {
        for (kind, code, value) in events {
            if *kind == EV_ABS {
                self.axes.insert(*code, *value);
            }
        }
        self.report(events)
    }

    /// Every axis at rest and nothing pressed, as the device would
    /// report after the hand lets go; the axes that moved.
    pub(crate) fn rest(&mut self) -> RoboResult<Vec<(u16, i32)>> {
        self.axes(&[
            (ABS_X, 127),
            (ABS_Y, 127),
            (ABS_Z, 127),
            (ABS_RZ, 127),
            (ABS_GAS, 0),
            (ABS_BRAKE, 0),
            (ABS_HAT0X, 0),
            (ABS_HAT0Y, 0),
        ])
    }

    /// The events written as the device or the port takes them.
    fn report(&mut self, events: &[(u16, u16, i32)]) -> RoboResult<()> {
        let mut bytes = Vec::with_capacity((events.len() + 1) * 24);
        for (kind, code, value) in events {
            self.frame(&mut bytes, *kind, *code, *value);
        }
        if !self.port {
            self.frame(&mut bytes, EV_SYN, 0, 0);
        }
        self.sink.write_all(&bytes).map_err(RoboError::io("the pad"))?;
        self.sink.flush().map_err(RoboError::io("the pad"))
    }

    /// One event: the port's eight bytes, or evdev's input_event with the
    /// clock in two 64-bit fields before them.
    fn frame(&self, out: &mut Vec<u8>, kind: u16, code: u16, value: i32) {
        if !self.port {
            let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default();
            out.extend_from_slice(&(now.as_secs() as i64).to_le_bytes());
            out.extend_from_slice(&(now.subsec_micros() as i64).to_le_bytes());
        }
        out.extend_from_slice(&kind.to_le_bytes());
        out.extend_from_slice(&code.to_le_bytes());
        out.extend_from_slice(&value.to_le_bytes());
    }
}
