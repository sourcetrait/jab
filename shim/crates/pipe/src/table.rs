//! The process table: a process's start, its state, its group, its CPU, its threads.

use crate::*;

pub(crate) use crate::receipt::Thread;
pub(crate) use os::*;

/// A process as the table shows it: running, exited and awaiting its reap, or gone.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum State {
    Live,
    Zombie,
    Gone,
}

/// Whether the process a record names still runs: its pid live, started when it says.
pub(crate) fn is_running(pid: i64, start: Option<u64>) -> bool {
    start.is_some() && state(pid) == State::Live && os::start(pid) == start
}

/// The members of a group still running, an exited member awaiting its reap not counted.
pub(crate) fn running_members(group: i64) -> io::Result<Vec<i64>> {
    Ok(members(group)?.into_iter().filter(|(_, s)| *s == State::Live).map(|(pid, _)| pid).collect())
}

#[cfg(target_os = "linux")]
mod os {
    use super::*;

    /// A `stat` file's fields from the state on, past the name in its parentheses.
    fn fields(path: &str) -> Option<Vec<String>> {
        let text = std::fs::read_to_string(path).ok()?;
        let (_, rest) = text.rsplit_once(") ")?;
        Some(rest.split_whitespace().map(str::to_owned).collect())
    }

    fn stat(pid: i64) -> Option<Vec<String>> {
        fields(&format!("/proc/{pid}/stat"))
    }

    /// Clock ticks a second, the unit of `stat`'s times.
    fn ticks() -> f64 {
        let hz = unsafe { libc::sysconf(libc::_SC_CLK_TCK) };
        if hz > 0 { hz as f64 } else { 100.0 }
    }

    /// A `stat`'s user and system time in seconds.
    fn seconds(fields: &[String]) -> Option<f64> {
        let user: u64 = fields.get(11)?.parse().ok()?;
        let system: u64 = fields.get(12)?.parse().ok()?;
        Some((user + system) as f64 / ticks())
    }

    /// A process's start, in clock ticks since the boot.
    pub(crate) fn start(pid: i64) -> Option<u64> {
        stat(pid)?.get(19)?.parse().ok()
    }

    pub(crate) fn state(pid: i64) -> State {
        match stat(pid) {
            None => State::Gone,
            Some(fields) if fields.first().is_some_and(|s| s == "Z") => State::Zombie,
            Some(_) => State::Live,
        }
    }

    pub(crate) fn group_of(pid: i64) -> Option<i64> {
        stat(pid)?.get(2)?.parse().ok()
    }

    /// Every process of a group with its state, read from the whole table.
    pub(crate) fn members(group: i64) -> io::Result<Vec<(i64, State)>> {
        let mut found = Vec::new();
        for entry in std::fs::read_dir("/proc")? {
            let Some(pid) = entry?.file_name().to_str().and_then(|n| n.parse::<i64>().ok()) else {
                continue;
            };
            let Some(fields) = stat(pid) else {
                continue;
            };
            if fields.get(2).and_then(|g| g.parse::<i64>().ok()) == Some(group) {
                found.push((pid, if fields[0] == "Z" { State::Zombie } else { State::Live }));
            }
        }
        Ok(found)
    }

    pub(crate) fn cpu_seconds(pid: i64) -> Option<f64> {
        seconds(&stat(pid)?)
    }

    /// Every thread of a process, by its id, with its name and CPU seconds.
    pub(crate) fn threads(pid: i64) -> Option<Vec<Thread>> {
        let mut ids: Vec<i64> = std::fs::read_dir(format!("/proc/{pid}/task"))
            .ok()?
            .filter_map(|e| e.ok()?.file_name().to_str()?.parse().ok())
            .collect();
        ids.sort_unstable();
        let threads = ids
            .into_iter()
            .filter_map(|id| {
                let cpu = seconds(&fields(&format!("/proc/{pid}/task/{id}/stat"))?)?;
                let name = std::fs::read_to_string(format!("/proc/{pid}/task/{id}/comm"))
                    .map(|n| n.trim().to_owned())
                    .unwrap_or_default();
                Some(Thread { id: id.to_string(), name, cpu })
            })
            .collect();
        Some(threads)
    }
}

#[cfg(target_os = "macos")]
mod os {
    use super::*;

    /// A process's BSD record from the kernel, a zombie's among them.
    fn info(pid: i64) -> Option<libc::proc_bsdinfo> {
        let mut info = std::mem::MaybeUninit::<libc::proc_bsdinfo>::zeroed();
        let size = std::mem::size_of::<libc::proc_bsdinfo>() as libc::c_int;
        let got = unsafe { libc::proc_pidinfo(pid as libc::c_int, libc::PROC_PIDTBSDINFO, 0, info.as_mut_ptr().cast(), size) };
        (got == size).then(|| unsafe { info.assume_init() })
    }

    /// A process's start, in microseconds since the epoch.
    pub(crate) fn start(pid: i64) -> Option<u64> {
        let info = info(pid)?;
        Some(info.pbi_start_tvsec * 1_000_000 + info.pbi_start_tvusec)
    }

    pub(crate) fn state(pid: i64) -> State {
        match info(pid) {
            None => State::Gone,
            Some(info) if info.pbi_status == libc::SZOMB => State::Zombie,
            Some(_) => State::Live,
        }
    }

    pub(crate) fn group_of(pid: i64) -> Option<i64> {
        Some(info(pid)?.pbi_pgid as i64)
    }

    /// Every process of a group with its state, as the kernel lists the group.
    pub(crate) fn members(group: i64) -> io::Result<Vec<(i64, State)>> {
        let mut capacity = 256usize;
        loop {
            let mut pids = vec![0 as libc::c_int; capacity];
            let bytes = (capacity * std::mem::size_of::<libc::c_int>()) as libc::c_int;
            let count = unsafe { libc::proc_listpgrppids(group as libc::pid_t, pids.as_mut_ptr().cast(), bytes) };
            if count < 0 {
                return Err(io::Error::last_os_error());
            }
            let count = count as usize;
            if count < capacity {
                return Ok(pids[..count]
                    .iter()
                    .filter(|&&pid| pid > 0)
                    .map(|&pid| (pid as i64, state(pid as i64)))
                    .filter(|(_, s)| *s != State::Gone)
                    .collect());
            }
            capacity *= 4;
        }
    }

    /// A process's user and system time, its task's Mach ticks over the timebase.
    pub(crate) fn cpu_seconds(pid: i64) -> Option<f64> {
        let mut task = std::mem::MaybeUninit::<libc::proc_taskinfo>::zeroed();
        let size = std::mem::size_of::<libc::proc_taskinfo>() as libc::c_int;
        let got = unsafe { libc::proc_pidinfo(pid as libc::c_int, libc::PROC_PIDTASKINFO, 0, task.as_mut_ptr().cast(), size) };
        if got != size {
            return None;
        }
        let task = unsafe { task.assume_init() };
        let mut base = mach2::mach_time::mach_timebase_info { numer: 0, denom: 0 };
        if unsafe { mach2::mach_time::mach_timebase_info(&mut base) } != 0 || base.denom == 0 {
            return None;
        }
        let ticks = (task.pti_total_user + task.pti_total_system) as f64;
        Some(ticks * base.numer as f64 / base.denom as f64 / 1e9)
    }

    /// Every thread of a process as `ps -M` reads it, by its row, the first the main.
    pub(crate) fn threads(pid: i64) -> Option<Vec<Thread>> {
        let out = std::process::Command::new("ps").args(["-M", "-p", &pid.to_string()]).output().ok()?;
        let text = String::from_utf8_lossy(&out.stdout);
        let threads = text
            .lines()
            .skip(1)
            .enumerate()
            .filter_map(|(row, line)| {
                let words: Vec<&str> = line.split_whitespace().collect();
                let at = words.windows(2).position(|w| clock(w[0]).is_some() && clock(w[1]).is_some())?;
                let cpu = clock(words[at])? + clock(words[at + 1])?;
                let name = if row == 0 { "main".to_owned() } else { format!("thread {row}") };
                Some(Thread { id: row.to_string(), name, cpu })
            })
            .collect();
        Some(threads)
    }

    /// `ps`'s clock text, M:SS.hh or H:MM:SS.hh, as seconds.
    fn clock(text: &str) -> Option<f64> {
        let (whole, fraction) = text.split_once('.')?;
        let digits = |s: &str| !s.is_empty() && s.bytes().all(|b| b.is_ascii_digit());
        let parts: Vec<&str> = whole.split(':').collect();
        if !digits(fraction) || !(2..=3).contains(&parts.len()) || !parts.iter().all(|p| digits(p)) {
            return None;
        }
        let whole = parts.iter().try_fold(0.0, |seconds, p| Some(seconds * 60.0 + p.parse::<f64>().ok()?))?;
        Some(whole + format!("0.{fraction}").parse::<f64>().ok()?)
    }
}

#[cfg(windows)]
mod os {
    use super::*;
    use windows_sys::Win32::Foundation::{CloseHandle, FILETIME, STILL_ACTIVE};
    use windows_sys::Win32::System::Threading::{GetExitCodeProcess, GetProcessTimes, OpenProcess, PROCESS_QUERY_LIMITED_INFORMATION};

    /// A FILETIME's 100 ns units as one number.
    fn units(time: FILETIME) -> u64 {
        ((time.dwHighDateTime as u64) << 32) | time.dwLowDateTime as u64
    }

    /// A process's creation, its CPU in 100 ns units, and whether it still runs, from a handle on it.
    fn times(pid: i64) -> Option<(u64, u64, bool)> {
        let handle = unsafe { OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid as u32) };
        if handle.is_null() {
            return None;
        }
        let zero = FILETIME { dwLowDateTime: 0, dwHighDateTime: 0 };
        let (mut created, mut exited, mut kernel, mut user) = (zero, zero, zero, zero);
        let mut code = 0u32;
        let read = unsafe { GetProcessTimes(handle, &mut created, &mut exited, &mut kernel, &mut user) } != 0
            && unsafe { GetExitCodeProcess(handle, &mut code) } != 0;
        unsafe { CloseHandle(handle) };
        read.then(|| (units(created), units(kernel) + units(user), code == STILL_ACTIVE as u32))
    }

    /// A process's creation, in 100 ns units since 1601.
    pub(crate) fn start(pid: i64) -> Option<u64> {
        times(pid).map(|(created, _, _)| created)
    }

    pub(crate) fn state(pid: i64) -> State {
        match times(pid) {
            Some((_, _, true)) => State::Live,
            _ => State::Gone,
        }
    }

    pub(crate) fn group_of(_pid: i64) -> Option<i64> {
        None
    }

    pub(crate) fn members(_group: i64) -> io::Result<Vec<(i64, State)>> {
        Ok(Vec::new())
    }

    /// A process's kernel and user time.
    pub(crate) fn cpu_seconds(pid: i64) -> Option<f64> {
        times(pid).map(|(_, cpu, _)| cpu as f64 / 1e7)
    }

    pub(crate) fn threads(_pid: i64) -> Option<Vec<Thread>> {
        None
    }
}

#[cfg(not(any(target_os = "linux", target_os = "macos", windows)))]
mod os {
    use super::*;

    pub(crate) fn start(_pid: i64) -> Option<u64> {
        None
    }

    pub(crate) fn state(_pid: i64) -> State {
        State::Gone
    }

    pub(crate) fn group_of(_pid: i64) -> Option<i64> {
        None
    }

    pub(crate) fn members(_group: i64) -> io::Result<Vec<(i64, State)>> {
        Err(io::Error::new(io::ErrorKind::Unsupported, "no process table reader for this host"))
    }

    pub(crate) fn cpu_seconds(_pid: i64) -> Option<f64> {
        None
    }

    pub(crate) fn threads(_pid: i64) -> Option<Vec<Thread>> {
        None
    }
}
