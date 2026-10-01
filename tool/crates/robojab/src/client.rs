use crate::*;

/// One command sent to a serving harness; its JSON reply line.
pub(crate) fn send(sock: &Path, words: &[String]) -> RoboResult<String> {
    let mut stream = UnixStream::connect(sock).map_err(RoboError::io(sock.display().to_string()))?;
    let line: Vec<String> = words.iter().map(|w| if w.contains(' ') { format!("\"{w}\"") } else { w.clone() }).collect();
    stream.write_all(format!("{}\n", line.join(" ")).as_bytes()).map_err(RoboError::io("the socket"))?;
    let mut reader = BufReader::new(stream);
    let mut reply = String::new();
    reader.read_line(&mut reply).map_err(RoboError::io("the socket"))?;
    Ok(reply.trim_end().to_owned())
}
