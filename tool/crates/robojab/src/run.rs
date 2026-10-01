use crate::*;

const USAGE: &str = "robojab serve --plan <plan.json> --sock <path> [--elf <program.elf>] [--prefix <toolchain prefix>] [--seconds <bound>]\n\
robojab mcp --plan <plan.json> [--elf <program.elf>] [--prefix <toolchain prefix>] [--seconds <bound>]\n\
robojab send --sock <path> <command...>";

/// The harness: `serve` runs a planned machine and answers commands on a
/// socket, `mcp` serves the same machine to an MCP client over stdio, and
/// `send` puts one command to a serving socket and prints the reply.
pub fn run() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match dispatch(&args) {
        Ok(code) => code,
        Err(error) => {
            eprintln!("robojab: {error}");
            ExitCode::from(2)
        }
    }
}

fn dispatch(args: &[String]) -> RoboResult<ExitCode> {
    let Some(verb) = args.first() else { return Err(RoboError::Usage(USAGE.to_owned())) };
    match verb.as_str() {
        "serve" => {
            let (driver, options) = driver(&args[1..])?;
            let sock = options.get("sock").ok_or_else(|| RoboError::Usage(USAGE.to_owned()))?;
            let code = serve_socket(driver, Path::new(sock))?;
            Ok(if code == 0 { ExitCode::SUCCESS } else { ExitCode::from(1) })
        }
        "mcp" => {
            let (driver, _) = driver(&args[1..])?;
            serve_mcp(driver)?;
            Ok(ExitCode::SUCCESS)
        }
        "send" => {
            if args.get(1).map(String::as_str) != Some("--sock") {
                return Err(RoboError::Usage(USAGE.to_owned()));
            }
            let sock = args.get(2).ok_or_else(|| RoboError::Usage(USAGE.to_owned()))?;
            let rest = &args[3..];
            if rest.is_empty() {
                return Err(RoboError::Usage(USAGE.to_owned()));
            }
            let reply = send(Path::new(sock), rest)?;
            println!("{reply}");
            let ok = serde_json::from_str::<serde_json::Value>(&reply).ok().and_then(|v| v.get("ok").and_then(|o| o.as_bool())).unwrap_or(false);
            Ok(if ok { ExitCode::SUCCESS } else { ExitCode::from(1) })
        }
        _ => Err(RoboError::Usage(USAGE.to_owned())),
    }
}

/// A driver from the serving options: the plan, the ELF and toolchain
/// prefix for resolving faults, and the bound, 600 s unless given.
fn driver(args: &[String]) -> RoboResult<(Driver, HashMap<String, String>)> {
    let options = options(args)?;
    let plan = options.get("plan").ok_or_else(|| RoboError::Usage(USAGE.to_owned()))?;
    let elf = options.get("elf").map(PathBuf::from);
    let prefix = options.get("prefix").cloned().unwrap_or_default();
    let seconds: u64 = match options.get("seconds") {
        Some(text) => text.parse().map_err(|_| RoboError::Usage(USAGE.to_owned()))?,
        None => 600,
    };
    let plan = Plan::load(Path::new(plan))?;
    Ok((Driver::new(plan, elf, prefix, seconds), options))
}

/// `--name value` pairs.
fn options(args: &[String]) -> RoboResult<HashMap<String, String>> {
    let mut out = HashMap::new();
    let mut i = 0;
    while i < args.len() {
        let name = args[i].strip_prefix("--").ok_or_else(|| RoboError::Usage(USAGE.to_owned()))?;
        let value = args.get(i + 1).ok_or_else(|| RoboError::Usage(USAGE.to_owned()))?;
        out.insert(name.to_owned(), value.clone());
        i += 2;
    }
    Ok(out)
}
