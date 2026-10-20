//! The supervised child: owned from its spawn, inert until its go, ended and reaped by its owner.

use crate::*;
use crate::schedule::{Mode, Schedule};

/// A termination's signal: the asking one, then the one that cannot be refused.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Signal {
    Term,
    Kill,
}

/// How the child ended: its exit status, or the signal that ended it.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub(crate) struct Ended {
    pub status: Option<i32>,
    pub signal: Option<i32>,
}

/// A file a launch's child writes, made fresh: one already there is never written over.
fn fresh(path: &str) -> PipeResult<File> {
    OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(path)
        .map_err(PipeError::io(format!("{path}, the child's output, made fresh")))
}

#[cfg(unix)]
pub(crate) use unix::Child;

#[cfg(windows)]
pub(crate) use windows::Child;

#[cfg(unix)]
mod unix {
    use super::*;
    use crate::gate;
    use crate::table::{self, State};
    use std::os::unix::io::{AsRawFd, RawFd};
    use std::os::unix::process::{CommandExt, ExitStatusExt};

    /// The terminal's attributes as the launch found them, put back however it ends.
    struct Terminal(libc::termios);

    impl Terminal {
        fn save() -> Option<Terminal> {
            if unsafe { libc::isatty(libc::STDIN_FILENO) } != 1 {
                return None;
            }
            let mut saved = std::mem::MaybeUninit::<libc::termios>::uninit();
            (unsafe { libc::tcgetattr(libc::STDIN_FILENO, saved.as_mut_ptr()) } == 0).then(|| Terminal(unsafe { saved.assume_init() }))
        }

        fn restore(&self) {
            unsafe { libc::tcsetattr(libc::STDIN_FILENO, libc::TCSANOW, &self.0) };
        }
    }

    /// The gate's process, its group when bounded, its control pipe until the word, the terminal kept.
    pub(crate) struct Child {
        process: std::process::Child,
        pid: i64,
        group: Option<i64>,
        own_group: bool,
        start: Option<u64>,
        control: Option<io::PipeWriter>,
        terminal: Option<Terminal>,
    }

    impl Child {
        /// The gate spawned inert over the schedule's command: bounded in a group of its own.
        pub(crate) fn spawn(schedule: &Schedule) -> PipeResult<Child> {
            let exe = env::current_exe().map_err(PipeError::io("the supervisor's own binary"))?;
            let (reader, writer) = io::pipe().map_err(PipeError::io("the gate's control pipe"))?;
            let fd = reader.as_raw_fd();
            let mut command = std::process::Command::new(exe);
            command.arg("gate").arg(gate::CONTROL_FD.to_string()).arg("--").args(&schedule.command);
            command.envs(schedule.env.iter().map(|v| (&v.name, &v.value)));
            let bounded = schedule.mode == Mode::Bounded;
            let terminal = if bounded { None } else { Terminal::save() };
            if bounded {
                command.process_group(0);
                command.stdin(std::process::Stdio::null());
                command.stdout(fresh(&schedule.stdout)?);
                command.stderr(fresh(&schedule.stderr)?);
            }
            unsafe { command.pre_exec(move || place(fd)) };
            let process = command.spawn().map_err(PipeError::io(format!("the gate for {}", schedule.command[0])))?;
            drop(reader);
            let pid = process.id() as i64;
            let group = if bounded { Some(pid) } else { table::group_of(pid) };
            let start = table::start(pid);
            Ok(Child { process, pid, group, own_group: bounded, start, control: Some(writer), terminal })
        }

        pub(crate) fn pid(&self) -> i64 {
            self.pid
        }

        pub(crate) fn group(&self) -> Option<i64> {
            self.group
        }

        pub(crate) fn start(&self) -> Option<u64> {
            self.start
        }

        /// The go written to the gate, which execs the command in its own place.
        pub(crate) fn release(&mut self) -> PipeResult<()> {
            let mut control = self.control.take().ok_or_else(|| PipeError::Host("the gate was released or abandoned already".to_owned()))?;
            control.write_all(&[gate::GO]).map_err(PipeError::io("the gate's control pipe"))
        }

        /// The gate abandoned: its pipe closed with no go, so it exits having run nothing.
        pub(crate) fn abandon(&mut self) {
            self.control = None;
        }

        /// Whether the child has exited, unreaped, its pid and group still its own.
        pub(crate) fn exited(&self) -> bool {
            table::state(self.pid) != State::Live
        }

        /// The processes still running that the child owns: its group's, else itself.
        pub(crate) fn running(&self) -> io::Result<Vec<i64>> {
            match self.group {
                Some(group) if self.own_group => table::running_members(group),
                _ => Ok(if self.exited() { Vec::new() } else { vec![self.pid] }),
            }
        }

        /// A signal to the group, or to the child alone when the group is the caller's.
        pub(crate) fn signal(&self, signal: Signal) {
            let number = match signal {
                Signal::Term => libc::SIGTERM,
                Signal::Kill => libc::SIGKILL,
            };
            let target = match self.group {
                Some(group) if self.own_group => -(group as libc::pid_t),
                _ => self.pid as libc::pid_t,
            };
            unsafe { libc::kill(target, number) };
        }

        /// The child reaped, once nothing it owns runs; the terminal put back.
        pub(crate) fn reap(&mut self) -> PipeResult<Ended> {
            let status = self.process.wait().map_err(PipeError::io("the child's reap"));
            self.restore();
            let status = status?;
            Ok(Ended { status: status.code(), signal: status.signal() })
        }

        /// The terminal's attributes as the launch found them.
        pub(crate) fn restore(&self) {
            if let Some(terminal) = &self.terminal {
                terminal.restore();
            }
        }
    }

    /// The control pipe's reading end put at the gate's descriptor, kept across the exec.
    fn place(fd: RawFd) -> io::Result<()> {
        let placed = if fd == gate::CONTROL_FD {
            unsafe { libc::fcntl(fd, libc::F_SETFD, 0) }
        } else {
            unsafe { libc::dup2(fd, gate::CONTROL_FD) }
        };
        if placed < 0 { Err(io::Error::last_os_error()) } else { Ok(()) }
    }

    /// The interrupt and quit keys left to the terminal's foreground: the supervisor waits.
    pub(crate) fn ignore_interrupts() {
        unsafe {
            libc::signal(libc::SIGINT, libc::SIG_IGN);
            libc::signal(libc::SIGQUIT, libc::SIG_IGN);
        }
    }
}

#[cfg(windows)]
mod windows {
    use super::*;
    use std::os::windows::io::AsRawHandle;
    use std::os::windows::process::{ChildExt, CommandExt};
    use windows_sys::Win32::Foundation::{CloseHandle, HANDLE};
    use windows_sys::Win32::System::JobObjects::{
        AssignProcessToJobObject, CreateJobObjectW, JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE, JOBOBJECT_BASIC_ACCOUNTING_INFORMATION,
        JOBOBJECT_EXTENDED_LIMIT_INFORMATION, JobObjectBasicAccountingInformation, JobObjectExtendedLimitInformation,
        QueryInformationJobObject, SetInformationJobObject, TerminateJobObject,
    };
    use windows_sys::Win32::System::Threading::{CREATE_SUSPENDED, ResumeThread};

    /// The child created suspended in a Job Object that kills on its last handle's close.
    pub(crate) struct Child {
        process: std::process::Child,
        pid: i64,
        start: Option<u64>,
        job: HANDLE,
        released: bool,
    }

    impl Child {
        /// The schedule's command created suspended, then assigned to its job before it runs.
        pub(crate) fn spawn(schedule: &Schedule) -> PipeResult<Child> {
            let mut command = std::process::Command::new(&schedule.command[0]);
            command.args(&schedule.command[1..]).envs(schedule.env.iter().map(|v| (&v.name, &v.value))).creation_flags(CREATE_SUSPENDED);
            if schedule.mode == Mode::Bounded {
                command.stdin(std::process::Stdio::null());
                command.stdout(fresh(&schedule.stdout)?);
                command.stderr(fresh(&schedule.stderr)?);
            }
            let mut process = command.spawn().map_err(PipeError::io(format!("the child {}", schedule.command[0])))?;
            let job = unsafe { CreateJobObjectW(std::ptr::null(), std::ptr::null()) };
            let owned = !job.is_null() && {
                let mut limit: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = unsafe { std::mem::zeroed() };
                limit.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
                let size = std::mem::size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() as u32;
                (unsafe { SetInformationJobObject(job, JobObjectExtendedLimitInformation, (&limit as *const JOBOBJECT_EXTENDED_LIMIT_INFORMATION).cast(), size) }) != 0
                    && (unsafe { AssignProcessToJobObject(job, process.as_raw_handle() as HANDLE) }) != 0
            };
            if !owned {
                let error = io::Error::last_os_error();
                let _ = process.kill();
                let _ = process.wait();
                if !job.is_null() {
                    unsafe { CloseHandle(job) };
                }
                return Err(PipeError::Io { what: "the child's Job Object".to_owned(), source: error });
            }
            let pid = process.id() as i64;
            Ok(Child { process, pid, start: table::start(pid), job, released: false })
        }

        pub(crate) fn pid(&self) -> i64 {
            self.pid
        }

        pub(crate) fn group(&self) -> Option<i64> {
            None
        }

        pub(crate) fn start(&self) -> Option<u64> {
            self.start
        }

        /// The suspended child's main thread resumed.
        pub(crate) fn release(&mut self) -> PipeResult<()> {
            let thread = self.process.main_thread_handle().as_raw_handle() as HANDLE;
            if unsafe { ResumeThread(thread) } == u32::MAX {
                return Err(PipeError::Io { what: "the child's resume".to_owned(), source: io::Error::last_os_error() });
            }
            self.released = true;
            Ok(())
        }

        /// The suspended child's job terminated, having run nothing.
        pub(crate) fn abandon(&mut self) {
            unsafe { TerminateJobObject(self.job, 1) };
        }

        pub(crate) fn exited(&mut self) -> bool {
            !matches!(self.process.try_wait(), Ok(None))
        }

        /// The job's processes still running, by its count; no pid is named.
        pub(crate) fn running(&mut self) -> io::Result<Vec<i64>> {
            let mut account: JOBOBJECT_BASIC_ACCOUNTING_INFORMATION = unsafe { std::mem::zeroed() };
            let size = std::mem::size_of::<JOBOBJECT_BASIC_ACCOUNTING_INFORMATION>() as u32;
            let read = unsafe { QueryInformationJobObject(self.job, JobObjectBasicAccountingInformation, (&mut account as *mut JOBOBJECT_BASIC_ACCOUNTING_INFORMATION).cast(), size, std::ptr::null_mut()) };
            if read == 0 {
                return Err(io::Error::last_os_error());
            }
            Ok(vec![0; account.ActiveProcesses as usize])
        }

        /// The job terminated whole, Windows having no asking signal.
        pub(crate) fn signal(&self, _signal: Signal) {
            unsafe { TerminateJobObject(self.job, 1) };
        }

        pub(crate) fn reap(&mut self) -> PipeResult<Ended> {
            let status = self.process.wait().map_err(PipeError::io("the child's reap"))?;
            Ok(Ended { status: status.code(), signal: None })
        }

        pub(crate) fn restore(&self) {}
    }

    impl Drop for Child {
        fn drop(&mut self) {
            unsafe { CloseHandle(self.job) };
        }
    }

    /// Ctrl-C left to the console's processes: the supervisor's handler takes it and waits.
    pub(crate) fn ignore_interrupts() {
        use windows_sys::Win32::System::Console::SetConsoleCtrlHandler;
        unsafe extern "system" fn taken(_event: u32) -> windows_sys::core::BOOL {
            1
        }
        unsafe { SetConsoleCtrlHandler(Some(taken), 1) };
    }

    use crate::table;
}

#[cfg(unix)]
pub(crate) use unix::ignore_interrupts;

#[cfg(windows)]
pub(crate) use windows::ignore_interrupts;
