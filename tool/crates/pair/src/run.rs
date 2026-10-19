use crate::*;

const USAGE: &str = "jabpair < request.json";

/// Answers the bracket request on stdin with every case's bracket as JSON.
pub fn run() -> ExitCode {
    if std::env::args().len() > 1 {
        eprintln!(
            "jabpair: {}",
            PairError::Request(format!("it takes no arguments: {USAGE}"))
        );
        return ExitCode::from(2);
    }
    let mut text = String::new();
    if let Err(error) = io::stdin().read_to_string(&mut text) {
        eprintln!("jabpair: {}", PairError::Io(error));
        return ExitCode::from(1);
    }
    let json = match respond(&text) {
        Ok(json) => json,
        Err(error) => {
            eprintln!("jabpair: {error}");
            return ExitCode::from(1);
        }
    };
    match io::stdout().lock().write_all(json.as_bytes()) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("jabpair: {}", PairError::Io(error));
            ExitCode::from(1)
        }
    }
}
