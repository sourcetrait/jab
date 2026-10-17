use crate::*;
use crate::connect::{connect_within, waiting};

#[test]
fn a_pipes_name_becomes_its_win32_path() {
    assert_eq!(pipe_path("jab-000000000000002a-api"), r"\\.\pipe\jab-000000000000002a-api");
}

#[test]
fn a_missing_or_busy_pipe_is_waited_for_and_nothing_else_is() {
    assert!(waiting(&io::Error::from(io::ErrorKind::NotFound)), "no pipe yet");
    assert!(waiting(&io::Error::from_raw_os_error(231)), "ERROR_PIPE_BUSY");
    assert!(!waiting(&io::Error::from(io::ErrorKind::PermissionDenied)), "refused");
    assert!(!waiting(&io::Error::from(io::ErrorKind::BrokenPipe)), "a pipe gone");
}

#[test]
fn a_client_connects_once_the_pipe_takes_it() {
    let mut tries = 0;
    let connected = connect_within("p", Duration::from_secs(5), Duration::from_millis(1), |pipe| {
        tries += 1;
        assert_eq!(pipe, r"\\.\pipe\p", "the pipe's Win32 path tried");
        match tries {
            1 | 2 => Err(io::Error::from(io::ErrorKind::NotFound)),
            3 | 4 => Err(io::Error::from_raw_os_error(231)),
            _ => Ok(tries),
        }
    });
    assert_eq!(connected.expect("connected"), 5, "tried until the pipe took it");
}

#[test]
fn a_client_gives_up_on_a_pipe_at_its_bound() {
    let started = Instant::now();
    let given_up = connect_within("p", Duration::from_millis(120), Duration::from_millis(10), |_| {
        Err::<(), _>(io::Error::from(io::ErrorKind::NotFound))
    });
    let error = given_up.expect_err("no pipe ever came");
    assert!(started.elapsed() >= Duration::from_millis(120), "tried for the bound: {:?}", started.elapsed());
    assert!(matches!(error, PipeError::Connect { within: Some(_), .. }), "a connection given up at the bound: {error}");
    assert!(error.to_string().contains(r"\\.\pipe\p: no connection within 0.12 s"), "{error}");
}

#[test]
fn a_refusal_that_is_no_wait_ends_the_tries_at_once() {
    let mut tries = 0;
    let refused = connect_within("p", Duration::from_secs(5), Duration::from_millis(1), |_| {
        tries += 1;
        Err::<(), _>(io::Error::from(io::ErrorKind::PermissionDenied))
    });
    assert!(matches!(refused, Err(PipeError::Connect { within: None, .. })), "refused as it came: {refused:?}");
    assert_eq!(tries, 1, "one try");
}
