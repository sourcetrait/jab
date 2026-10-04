use crate::*;

/// The harness over a Unix socket: one command a line in, one JSON line
/// out, the machine started at once and served until quit or ten seconds
/// past the bound, whether or not QEMU is still running. Whatever sits at
/// the socket's path is retired before the bind, and the socket after,
/// into the plan's target (retire).
pub(crate) fn serve_socket(mut driver: Driver, sock: &Path) -> RoboResult<i32> {
    let root = driver.target()?;
    retire(sock, &root)?;
    let listener = UnixListener::bind(sock).map_err(RoboError::io(sock.display().to_string()))?;
    listener.set_nonblocking(true).map_err(RoboError::io("the socket"))?;
    driver.start()?;
    println!("robojab: up on {} for {} s at most", sock.display(), driver.seconds());
    let code = accept_loop(&mut driver, &listener);
    drop(listener);
    let _ = retire(sock, &root);
    code
}

fn accept_loop(driver: &mut Driver, listener: &UnixListener) -> RoboResult<i32> {
    let grace = driver.seconds() as f32 + 10.0;
    loop {
        if driver.elapsed().is_some_and(|e| e > grace) {
            println!("robojab: the bound ended the run");
            return driver.quit();
        }
        match listener.accept() {
            Ok((stream, _)) => {
                if session(driver, stream)? {
                    return driver.quit();
                }
            }
            Err(error) if error.kind() == io::ErrorKind::WouldBlock => thread::sleep(Duration::from_millis(20)),
            Err(error) => return Err(RoboError::Io { what: "accept".to_owned(), source: error }),
        }
    }
}

/// One connection's lines answered; true once quit was asked.
fn session(driver: &mut Driver, stream: UnixStream) -> RoboResult<bool> {
    stream.set_nonblocking(false).map_err(RoboError::io("the session"))?;
    let mut reader = BufReader::new(stream.try_clone().map_err(RoboError::io("the session"))?);
    let mut writer = stream;
    let mut line = String::new();
    loop {
        line.clear();
        let read = reader.read_line(&mut line).map_err(RoboError::io("the session"))?;
        if read == 0 {
            return Ok(false);
        }
        let words = split(line.trim());
        if words.is_empty() {
            continue;
        }
        let quit = words[0] == "quit";
        let reply = match driver.command(&words) {
            Ok(value) => {
                let mut record = serde_json::Map::new();
                record.insert("ok".to_owned(), serde_json::Value::Bool(true));
                if let serde_json::Value::Object(fields) = value {
                    record.extend(fields);
                } else if !value.is_null() {
                    record.insert("value".to_owned(), value);
                }
                serde_json::Value::Object(record)
            }
            Err(error) => serde_json::json!({ "ok": false, "error": error.to_string() }),
        };
        writer.write_all(format!("{reply}\n").as_bytes()).map_err(RoboError::io("the session"))?;
        if quit {
            return Ok(true);
        }
    }
}
