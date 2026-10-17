use crate::*;
use std::{fs, path::PathBuf};

/// A fresh directory under the shim workspace's own target for one test.
fn scratch(name: &str) -> PathBuf {
    let nanos = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
    let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .join("..")
        .join("target")
        .join("test")
        .join(format!("{name}-{}-{nanos}", std::process::id()));
    fs::create_dir_all(&dir).expect("the scratch directory");
    fs::canonicalize(dir).expect("the scratch directory's own path")
}

/// A runtime of the relay's own kind for one test.
fn runtime() -> tokio::runtime::Runtime {
    tokio::runtime::Builder::new_current_thread().enable_all().build().expect("a runtime")
}

/// `bytes` appended to the file at `path`, as a launch's writer appends.
fn append(path: &Path, bytes: &[u8]) {
    OpenOptions::new().append(true).open(path).and_then(|mut file| file.write_all(bytes)).expect("an append");
}

#[cfg(unix)]
#[test]
fn bytes_appended_to_the_in_file_reach_the_pipe_in_order() {
    let dir = scratch("forward");
    let inward = dir.join("api.in");
    fs::write(&inward, b"zero ").expect("the in-file");
    let got = runtime().block_on(async {
        let (mut to, mut from) = tokio::net::unix::pipe::pipe().expect("a fifo");
        let mut input = File::open(&inward).expect("the in-file");
        let appending = {
            let inward = inward.clone();
            tokio::spawn(async move {
                tokio::time::sleep(Duration::from_millis(30)).await;
                append(&inward, b"one ");
                tokio::time::sleep(Duration::from_millis(30)).await;
                append(&inward, b"two");
            })
        };
        let mut got = vec![0u8; 12];
        tokio::select! {
            read = from.read_exact(&mut got) => { read.expect("the pipe's bytes"); }
            end = forward(&mut input, &mut to, &inward, Duration::from_millis(5)) => panic!("the forwarding ended: {end}"),
        }
        appending.await.expect("the appends");
        got
    });
    assert_eq!(got, b"zero one two", "the file's bytes, those there first and each append after, in order");
}

#[cfg(unix)]
#[test]
fn what_the_pipe_gives_lands_in_the_out_file_until_the_pipe_closes() {
    let dir = scratch("drain");
    let outward = dir.join("api.out");
    fs::write(&outward, b"").expect("the out-file");
    let drained = runtime().block_on(async {
        let (mut to, mut from) = tokio::net::unix::pipe::pipe().expect("a fifo");
        to.write_all(b"guest bytes").await.expect("the guest's bytes");
        drop(to);
        let mut output = OpenOptions::new().append(true).open(&outward).expect("the out-file");
        drain(&mut from, &mut output, &outward).await.expect("drained to the pipe's close")
    });
    assert_eq!(drained, 11, "every byte counted");
    assert_eq!(fs::read(&outward).expect("the out-file"), b"guest bytes");
}

#[test]
fn a_relay_carries_both_ways_and_ends_when_qemu_closes_the_pipe() {
    let dir = scratch("duplex");
    let inward = dir.join("monitor.in");
    let outward = dir.join("monitor.out");
    fs::write(&inward, b"").expect("the in-file");
    fs::write(&outward, b"").expect("the out-file");
    runtime().block_on(async {
        let (relayed, mut qemu) = tokio::io::duplex(2048);
        let serving = tokio::spawn(async move {
            let mut asked = [0u8; 4];
            qemu.read_exact(&mut asked).await.expect("the relayed bytes");
            qemu.write_all(&asked.to_ascii_uppercase()).await.expect("the answer");
        });
        append(&inward, b"quit");
        relay_duplex(relayed, &inward, &outward).await.expect("a clean end once QEMU closed the pipe");
        serving.await.expect("the stand-in for QEMU");
    });
    assert_eq!(fs::read(&outward).expect("the out-file"), b"QUIT", "the pipe's answer in the out-file");
}

#[cfg(unix)]
#[test]
fn a_relay_keeps_what_the_pipe_gives_once_a_write_is_refused() {
    let dir = scratch("refused");
    let inward = dir.join("api.in");
    let outward = dir.join("api.out");
    fs::write(&inward, b"asked").expect("the in-file");
    fs::write(&outward, b"").expect("the out-file");
    runtime().block_on(async {
        let (to, gone) = tokio::net::unix::pipe::pipe().expect("the pipe in");
        drop(gone);
        let (mut giving, from) = tokio::net::unix::pipe::pipe().expect("the pipe out");
        let late = tokio::spawn(async move {
            tokio::time::sleep(Duration::from_millis(50)).await;
            giving.write_all(b"late").await.expect("the pipe's last bytes");
        });
        relay(from, to, &inward, &outward, Duration::from_millis(5), Duration::from_millis(500))
            .await
            .expect("a clean end once the pipe closed");
        late.await.expect("the last bytes");
    });
    assert_eq!(fs::read(&outward).expect("the out-file"), b"late", "what the pipe gave after it refused a write");
}

#[cfg(unix)]
#[test]
fn a_relay_whose_pipe_refuses_writes_and_stays_open_fails_at_its_grace() {
    let dir = scratch("grace");
    let inward = dir.join("api.in");
    let outward = dir.join("api.out");
    fs::write(&inward, b"asked").expect("the in-file");
    fs::write(&outward, b"").expect("the out-file");
    runtime().block_on(async {
        let (to, gone) = tokio::net::unix::pipe::pipe().expect("the pipe in");
        drop(gone);
        let (giving, from) = tokio::net::unix::pipe::pipe().expect("the pipe out");
        let started = Instant::now();
        let ended = relay(from, to, &inward, &outward, Duration::from_millis(5), Duration::from_millis(60)).await;
        assert!(matches!(ended, Err(PipeError::Pipe(_))), "the refused write ends it: {ended:?}");
        assert!(started.elapsed() >= Duration::from_millis(60), "after its grace: {:?}", started.elapsed());
        drop(giving);
    });
}

#[test]
fn a_relay_with_no_in_file_fails_naming_it() {
    let dir = scratch("absent");
    let inward = dir.join("none.in");
    let outward = dir.join("none.out");
    runtime().block_on(async {
        let (relayed, _qemu) = tokio::io::duplex(64);
        match relay_duplex(relayed, &inward, &outward).await {
            Err(PipeError::Io { what, .. }) => assert_eq!(what, inward.display().to_string()),
            other => panic!("refused naming the in-file: {other:?}"),
        }
    });
}
