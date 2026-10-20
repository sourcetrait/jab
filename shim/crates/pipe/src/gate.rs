//! The gate: a supervised launch's child before its go, inert until the word.

use crate::*;

/// The descriptor the gate reads its word on.
pub(crate) const CONTROL_FD: RawFd = 3;

/// The supervisor's word that releases the gate.
pub(crate) const GO: u8 = b'g';

/// A gate's exit when its pipe closed with no go, having run nothing.
pub(crate) const ABANDONED: u8 = 125;

/// A gate's exit when its command could not be run.
pub(crate) const UNRUN: u8 = 127;

/// `jabpipe gate <fd> -- <command...>`: the go read, then the command exec'd.
pub(crate) fn gate(args: Vec<String>) -> ExitCode {
    let (fd, command) = match gated(args) {
        Ok(parsed) => parsed,
        Err(error) => {
            eprintln!("jabpipe gate: {error}");
            return ExitCode::from(error.exit_code());
        }
    };
    if !released(fd) {
        return ExitCode::from(ABANDONED);
    }
    defaults();
    let error = Command::new(&command[0]).args(&command[1..]).exec();
    eprintln!("jabpipe gate: {}: {error}", command[0]);
    ExitCode::from(UNRUN)
}

/// The descriptor and the command the arguments name.
fn gated(args: Vec<String>) -> PipeResult<(RawFd, Vec<String>)> {
    let usage = || PipeError::Usage("jabpipe gate <fd> -- <command...>".to_owned());
    let mut args = args.into_iter();
    let fd = args.next().and_then(|fd| fd.parse::<RawFd>().ok()).ok_or_else(usage)?;
    if args.next().as_deref() != Some("--") {
        return Err(usage());
    }
    let command: Vec<String> = args.collect();
    if command.is_empty() || fd < 0 {
        return Err(usage());
    }
    Ok((fd, command))
}

/// Whether the supervisor's word was the go; its pipe closed is no go.
fn released(fd: RawFd) -> bool {
    let mut control = unsafe { File::from_raw_fd(fd) };
    let mut word = [0u8; 1];
    loop {
        match control.read(&mut word) {
            Ok(1) => return word[0] == GO,
            Ok(_) => return false,
            Err(error) if error.kind() == io::ErrorKind::Interrupted => {}
            Err(_) => return false,
        }
    }
}

/// Every signal disposition back to its default, the signal mask cleared.
fn defaults() {
    for signal in [libc::SIGINT, libc::SIGQUIT, libc::SIGPIPE, libc::SIGTERM, libc::SIGHUP, libc::SIGTSTP, libc::SIGTTIN, libc::SIGTTOU] {
        unsafe { libc::signal(signal, libc::SIG_DFL) };
    }
    unsafe {
        let mut none = MaybeUninit::<libc::sigset_t>::uninit();
        libc::sigemptyset(none.as_mut_ptr());
        libc::sigprocmask(libc::SIG_SETMASK, none.as_ptr(), ptr::null_mut());
    }
}
