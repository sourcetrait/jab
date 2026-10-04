use crate::*;

/// A machine the SDK prepared, as `jab.nu plan` prints it.
#[derive(Debug, Clone)]
pub(crate) struct Plan {
    pub(crate) qemu_binary: String,
    pub(crate) qemu: Vec<String>,
    pub(crate) env: HashMap<String, String>,
    pub(crate) out: PathBuf,
    pub(crate) serial_log: PathBuf,
    pub(crate) pidfile: PathBuf,
    pub(crate) monitor: PathBuf,
    pub(crate) debug_log: Option<PathBuf>,
    pub(crate) api_in: Option<PathBuf>,
    pub(crate) api_out: Option<PathBuf>,
    pub(crate) pad_fifo: Option<PathBuf>,
    pub(crate) pad_pipe_in: Option<PathBuf>,
    pub(crate) pad_port: bool,
    pub(crate) pad_header: Vec<u8>,
    pub(crate) sound: Option<PathBuf>,
    pub(crate) target: Option<PathBuf>,
}

impl Plan {
    /// The plan read from its JSON file; an empty path field is absent.
    pub(crate) fn load(path: &Path) -> RoboResult<Plan> {
        let text = fs::read_to_string(path).map_err(RoboError::io(path.display().to_string()))?;
        let value: serde_json::Value = serde_json::from_str(&text).map_err(|error| RoboError::Plan(error.to_string()))?;
        let field = |name: &str| -> RoboResult<&serde_json::Value> {
            value.get(name).ok_or_else(|| RoboError::Plan(format!("no field {name}")))
        };
        let text_field = |name: &str| -> RoboResult<String> {
            field(name)?.as_str().map(str::to_owned).ok_or_else(|| RoboError::Plan(format!("{name} is not a string")))
        };
        let path_field = |name: &str| -> RoboResult<Option<PathBuf>> {
            let text = text_field(name)?;
            Ok(if text.is_empty() { None } else { Some(PathBuf::from(text)) })
        };
        let qemu = field("qemu")?
            .as_array()
            .ok_or_else(|| RoboError::Plan("qemu is not a list".to_owned()))?
            .iter()
            .map(|v| v.as_str().map(str::to_owned).ok_or_else(|| RoboError::Plan("a qemu argument is not a string".to_owned())))
            .collect::<RoboResult<Vec<String>>>()?;
        let env = field("env")?
            .as_object()
            .ok_or_else(|| RoboError::Plan("env is not a record".to_owned()))?
            .iter()
            .map(|(k, v)| v.as_str().map(|s| (k.clone(), s.to_owned())).ok_or_else(|| RoboError::Plan(format!("env {k} is not a string"))))
            .collect::<RoboResult<HashMap<String, String>>>()?;
        let pad_header = unhex(&text_field("pad_header")?)?;
        Ok(Plan {
            qemu_binary: text_field("qemu_binary")?,
            qemu,
            env,
            out: PathBuf::from(text_field("out")?),
            serial_log: PathBuf::from(text_field("serial_log")?),
            pidfile: PathBuf::from(text_field("pidfile")?),
            monitor: PathBuf::from(text_field("monitor")?),
            debug_log: path_field("debug_log")?,
            api_in: path_field("api_in")?,
            api_out: path_field("api_out")?,
            pad_fifo: path_field("pad_fifo")?,
            pad_pipe_in: path_field("pad_pipe_in")?,
            pad_port: field("pad_port")?.as_bool().unwrap_or(false),
            pad_header,
            sound: path_field("sound")?,
            target: value.get("target").and_then(|v| v.as_str()).filter(|t| !t.is_empty()).map(PathBuf::from),
        })
    }

    /// The target a run retires what it clears away into (retire): the one
    /// the plan names, the workspace's or else the program's, wherever its
    /// files lie, else for a plan that names none the one its files lie in.
    pub(crate) fn target(&self) -> RoboResult<PathBuf> {
        if let Some(target) = &self.target {
            return Ok(target.clone());
        }
        target_of(&self.out).ok_or_else(|| RoboError::Plan(format!("the plan names no target and {} lies in none, so a run has nowhere to retire what it clears away", self.out.display())))
    }
}

/// Bytes from a hex string, either case, whitespace ignored.
pub(crate) fn unhex(text: &str) -> RoboResult<Vec<u8>> {
    let digits: Vec<u8> = text.bytes().filter(|b| !b.is_ascii_whitespace()).collect();
    if !digits.len().is_multiple_of(2) {
        return Err(RoboError::Command(format!("odd hex: {text}")));
    }
    digits
        .chunks(2)
        .map(|pair| {
            let s = std::str::from_utf8(pair).map_err(|_| RoboError::Command(format!("bad hex: {text}")))?;
            u8::from_str_radix(s, 16).map_err(|_| RoboError::Command(format!("bad hex: {text}")))
        })
        .collect()
}

/// A hex string of bytes, lower case.
pub(crate) fn hex(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        out.push_str(&format!("{b:02x}"));
    }
    out
}
