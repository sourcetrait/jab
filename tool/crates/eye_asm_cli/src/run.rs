use crate::*;

const USAGE: &str = "eye-asm <src_dir> [file or directory within it]";

/// Prints the .eye of a source, or of every source under a directory, the
/// whole source directory when none is named.
pub fn run() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let (src_dir, rel) = match args.as_slice() {
        [src_dir] => (src_dir.as_str(), "."),
        [src_dir, rel] => (src_dir.as_str(), rel.as_str()),
        _ => {
            eprintln!("eye-asm: {}", lib::EyeError::Usage(USAGE.to_owned()));
            return ExitCode::from(2);
        }
    };
    let listing = match lib::listing(Path::new(src_dir), Path::new(rel)) {
        Ok(listing) => listing,
        Err(error) => {
            eprintln!("eye-asm: {error}");
            return ExitCode::from(1);
        }
    };
    for missing in &listing.missing {
        eprintln!("eye-asm: no .eye for {}", missing.display());
    }
    match io::stdout().lock().write_all(listing.text.as_bytes()) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) if error.kind() == io::ErrorKind::BrokenPipe => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("eye-asm: {error}");
            ExitCode::from(1)
        }
    }
}
