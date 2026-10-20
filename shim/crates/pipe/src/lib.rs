#![cfg_attr(not(windows), allow(dead_code, unused_imports))]

pub(crate) use std::{
    env,
    error::Error,
    fmt,
    fs::{self, File, OpenOptions, TryLockError},
    io::{self, Read, Write},
    mem::{self, MaybeUninit},
    path::{Path, PathBuf},
    process::{self, Command, ExitCode, Stdio},
    ptr,
    sync::{
        Arc, Mutex,
        atomic::{AtomicU64, Ordering},
    },
    thread,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};

#[cfg(unix)]
pub(crate) use std::os::unix::{
    fs::OpenOptionsExt,
    io::{AsRawFd, FromRawFd, RawFd},
    net::UnixStream,
    process::{CommandExt, ExitStatusExt},
};

#[cfg(windows)]
pub(crate) use std::os::windows::{
    io::AsRawHandle,
    process::{ChildExt, CommandExt},
};

pub(crate) use tokio::io::{AsyncReadExt, AsyncWriteExt};

pub(crate) mod r {
    pub(crate) mod mpsc {
        pub(crate) use tokio::sync::mpsc::{UnboundedReceiver, UnboundedSender, unbounded_channel};
    }

    #[cfg(target_os = "macos")]
    pub(crate) mod mach {
        pub(crate) use mach2::mach_time::mach_timebase_info;
    }

    #[cfg(windows)]
    pub(crate) mod np {
        pub(crate) use tokio::net::windows::named_pipe::{ClientOptions, NamedPipeClient};
    }

    #[cfg(windows)]
    pub(crate) mod win {
        pub(crate) use windows_sys::Win32::Foundation::{CloseHandle, FILETIME, HANDLE, STILL_ACTIVE};
        pub(crate) use windows_sys::Win32::System::Console::SetConsoleCtrlHandler;
        pub(crate) use windows_sys::Win32::System::JobObjects::{
            AssignProcessToJobObject, CreateJobObjectW, JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE, JOBOBJECT_BASIC_ACCOUNTING_INFORMATION,
            JOBOBJECT_EXTENDED_LIMIT_INFORMATION, JobObjectBasicAccountingInformation, JobObjectExtendedLimitInformation,
            QueryInformationJobObject, SetInformationJobObject, TerminateJobObject,
        };
        pub(crate) use windows_sys::Win32::System::Threading::{
            CREATE_SUSPENDED, GetExitCodeProcess, GetProcessTimes, OpenProcess, PROCESS_QUERY_LIMITED_INFORMATION, ResumeThread,
        };
        pub(crate) use windows_sys::core::BOOL;
    }
}

mod child;
mod connect;
mod control;
mod error;
#[cfg(unix)]
mod gate;
#[cfg(unix)]
mod group;
mod helper;
mod link;
mod lock;
mod payload;
mod receipt;
mod relay;
mod run;
mod schedule;
mod supervise;
mod table;

pub(crate) use child::*;
pub(crate) use connect::*;
pub(crate) use control::*;
#[cfg(unix)]
pub(crate) use gate::*;
#[cfg(unix)]
pub(crate) use group::*;
pub(crate) use helper::*;
pub(crate) use link::*;
pub(crate) use lock::*;
pub(crate) use payload::*;
pub(crate) use receipt::*;
pub(crate) use relay::*;
pub(crate) use schedule::*;
pub(crate) use supervise::*;
pub(crate) use table::*;

pub use connect::{connect, pipe_path};
pub use error::{PipeError, PipeResult};
pub use run::run;

#[cfg(test)]
mod tests {
    mod connect;
    mod link;
    mod lock;
    mod relay;
}
