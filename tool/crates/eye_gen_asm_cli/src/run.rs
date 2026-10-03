use crate::*;

const USAGE: &str = "eye-gen-asm [--done] <src_dir> [file or directory within it]";

/// Writes the stubs, or with --done replaces each .eye with its stub, for the
/// whole source directory when no path is named; quiet unless something stops
/// it.
pub fn run() -> ExitCode {
    let mut args: Vec<String> = std::env::args().skip(1).collect();
    let finish = match args.iter().position(|arg| arg == "--done") {
        Some(at) => {
            args.remove(at);
            true
        }
        None => false,
    };
    let (src_dir, rel) = match args.as_slice() {
        [src_dir] => (src_dir.as_str(), "."),
        [src_dir, rel] => (src_dir.as_str(), rel.as_str()),
        _ => return usage(),
    };
    if src_dir.starts_with("--") || rel.starts_with("--") {
        return usage();
    }
    let (src_dir, rel) = (Path::new(src_dir), Path::new(rel));
    let outcome = if finish { lib::done(src_dir, rel) } else { lib::generate(src_dir, rel) };
    match outcome {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("eye-gen-asm: {error}");
            ExitCode::from(1)
        }
    }
}

fn usage() -> ExitCode {
    eprintln!("eye-gen-asm: {}", lib::EyeError::Usage(USAGE.to_owned()));
    ExitCode::from(2)
}
