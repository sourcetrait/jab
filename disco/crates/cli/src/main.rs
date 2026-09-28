//! Prints what lowkickdisco discovers, one NUON record, and nothing else;
//! with `--debug`, the same record with a `debug` item beside the
//! gamepad and the audio output, every gamepad gilrs lists and every
//! audio host and output cpal lists, for a report.

fn main() {
    let debug = std::env::args().skip(1).any(|argument| argument == "--debug");
    println!("{}", if debug { lowkickdisco::debug() } else { lowkickdisco::discover() });
}
