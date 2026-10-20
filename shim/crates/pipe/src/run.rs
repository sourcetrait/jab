//! The binary's command line: the relay, the supervisor and its gate, the lock, and a group's end.

use crate::*;

/// `jabpipe <name> <in-file> <out-file>`, or a mode: `supervise`, `gate`, `lock`, `group`.
pub fn run() -> ExitCode {
    let args: Vec<String> = env::args().skip(1).collect();
    let rest = || args[1..].to_vec();
    match args.first().map(String::as_str) {
        Some("supervise") => supervise::supervise(rest()),
        #[cfg(unix)]
        Some("gate") => gate::gate(rest()),
        Some("lock") => lock::lock(rest()),
        #[cfg(unix)]
        Some("group") => group::group(rest()),
        _ => match relayed(args) {
            Ok(()) => ExitCode::SUCCESS,
            Err(error) => {
                eprintln!("jabpipe: {error}");
                ExitCode::from(error.exit_code())
            }
        },
    }
}

/// The relay the arguments name.
fn relayed(args: Vec<String>) -> PipeResult<()> {
    let [name, inward, outward] = <[String; 3]>::try_from(args)
        .map_err(|_| PipeError::Usage("jabpipe <name> <in-file> <out-file> | supervise | lock | group".to_owned()))?;
    duplex(&name, Path::new(&inward), Path::new(&outward))
}

/// The pipe `name` connected, then relayed on a runtime of its own.
#[cfg(windows)]
fn duplex(name: &str, inward: &Path, outward: &Path) -> PipeResult<()> {
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .map_err(PipeError::io("the relay's runtime"))?;
    let client = {
        let _entered = runtime.enter();
        connect(name, |pipe| r::np::ClientOptions::new().open(pipe))?
    };
    runtime.block_on(relay_duplex(client, inward, outward))
}

/// Refused: QEMU's pipe chardev on this host opens fifos of its own.
#[cfg(not(windows))]
fn duplex(name: &str, _inward: &Path, _outward: &Path) -> PipeResult<()> {
    Err(PipeError::Host(format!("{name}: the relay is for a Windows named pipe, and QEMU here opens fifos")))
}
