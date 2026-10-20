//! A supervised launch's control files, named by its token, each written whole.

use crate::*;

/// The schedule the SDK writes before the supervisor starts.
pub(crate) const SCHEDULE: &str = "schedule";

/// The supervisor's readiness, the ownership record the caller keeps.
pub(crate) const READINESS: &str = "readiness";

/// The caller's go, written only once it holds the readiness.
pub(crate) const AUTHORIZATION: &str = "authorization";

/// The caller's request to stop the launch, before or after its go.
pub(crate) const CANCEL: &str = "cancel";

/// The supervisor's one decision on the startup: go, cancelled, or expired.
pub(crate) const OUTCOME: &str = "outcome";

/// The supervisor's last word, every action, reading, and the run's end.
pub(crate) const RECEIPT: &str = "receipt";

/// Whether a token is a launch's: sixteen lowercase hex digits, not all zero.
pub(crate) fn token_ok(token: &str) -> bool {
    token.len() == 16 && token.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b)) && token.bytes().any(|b| b != b'0')
}

/// A control file's path: `launch-<token>.<kind>.json` in the run's directory.
pub(crate) fn control_path(dir: &Path, token: &str, kind: &str) -> PathBuf {
    dir.join(format!("launch-{token}.{kind}.json"))
}

/// Bytes written whole: a temporary name beside the file, synced, renamed over it.
pub(crate) fn write_whole(path: &Path, bytes: &[u8]) -> PipeResult<()> {
    let name = path.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
    let temporary = path.with_file_name(format!(".{name}.{}.tmp", std::process::id()));
    {
        let mut file = File::create(&temporary).map_err(PipeError::io(temporary.display().to_string()))?;
        file.write_all(bytes).map_err(PipeError::io(temporary.display().to_string()))?;
        file.sync_all().map_err(PipeError::io(temporary.display().to_string()))?;
    }
    std::fs::rename(&temporary, path).map_err(PipeError::io(path.display().to_string()))?;
    if let Some(dir) = path.parent()
        && let Ok(handle) = File::open(dir)
    {
        let _ = handle.sync_all();
    }
    Ok(())
}

/// A value written whole as JSON.
pub(crate) fn write_json<T: serde::Serialize>(path: &Path, value: &T) -> PipeResult<()> {
    let bytes = serde_json::to_vec_pretty(value).map_err(|e| PipeError::Io { what: path.display().to_string(), source: io::Error::other(e) })?;
    write_whole(path, &bytes)
}

/// A control file's value once it is there, None while it is not.
pub(crate) fn read_json<T: serde::de::DeserializeOwned>(path: &Path) -> PipeResult<Option<T>> {
    match std::fs::read(path) {
        Ok(bytes) => serde_json::from_slice(&bytes)
            .map(Some)
            .map_err(|e| PipeError::Io { what: path.display().to_string(), source: io::Error::other(e) }),
        Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(None),
        Err(source) => Err(PipeError::Io { what: path.display().to_string(), source }),
    }
}

/// The realtime clock as UTC text, for dates and provenance alone.
pub(crate) fn utc_now() -> String {
    let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default();
    let seconds = now.as_secs();
    let (year, month, day) = civil_of(seconds / 86_400);
    let of_day = seconds % 86_400;
    format!(
        "{year:04}-{month:02}-{day:02}T{:02}:{:02}:{:02}.{:06}Z",
        of_day / 3600,
        of_day % 3600 / 60,
        of_day % 60,
        now.subsec_micros()
    )
}

/// The civil date of a day counted from 1970-01-01, the proleptic Gregorian.
fn civil_of(days: u64) -> (i64, u32, u32) {
    let z = days as i64 + 719_468;
    let era = z.div_euclid(146_097);
    let of_era = z.rem_euclid(146_097);
    let year_of_era = (of_era - of_era / 1460 + of_era / 36_524 - of_era / 146_096) / 365;
    let day_of_year = of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100);
    let month_index = (5 * day_of_year + 2) / 153;
    let day = (day_of_year - (153 * month_index + 2) / 5 + 1) as u32;
    let month = if month_index < 10 { month_index + 3 } else { month_index - 9 } as u32;
    let year = year_of_era + era * 400 + if month <= 2 { 1 } else { 0 };
    (year, month, day)
}
