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

fn runtime() -> tokio::runtime::Runtime {
    tokio::runtime::Builder::new_current_thread().enable_all().build().expect("a runtime")
}

/// A wait on the runtime, its tasks driven through it, as the supervisor's loop waits.
fn idle(runtime: &tokio::runtime::Runtime, ms: u64) {
    runtime.block_on(async { tokio::time::sleep(Duration::from_millis(ms)).await });
}

#[test]
fn carries_go_in_whole_and_in_order_their_bytes_counted() {
    let dir = scratch("carries");
    let outward = dir.join("monitor.out");
    let (one, two) = (Carry::new(Arc::from(&b"sendkey a 100\n"[..])), Carry::new(Arc::from(&b"quit\n"[..])));
    runtime().block_on(async {
        let (relayed, mut qemu) = tokio::io::duplex(4);
        let (queue, carries) = tokio::sync::mpsc::unbounded_channel();
        queue.send(one.clone()).unwrap();
        queue.send(two.clone()).unwrap();
        let serving = tokio::spawn(async move {
            let mut got = vec![0u8; 19];
            qemu.read_exact(&mut got).await.expect("the carried bytes");
            qemu.write_all(b"bye").await.expect("the answer");
            got
        });
        relay_carrying(relayed, carries, None, &outward, Duration::from_millis(5), Duration::from_millis(200))
            .await
            .expect("a clean end once QEMU closed the pipe");
        assert_eq!(serving.await.unwrap(), b"sendkey a 100\nquit\n", "each whole, in the order queued");
    });
    for carry in [&one, &two] {
        assert!(matches!(carry.result(), Some((_, Ok(())))), "written whole");
    }
    assert_eq!((one.accepted(), two.accepted()), (14, 5));
    assert_eq!(fs::read(&outward).unwrap(), b"bye");
}

#[test]
fn a_carry_into_a_pipe_that_closed_fails_with_its_bytes_counted() {
    let dir = scratch("carryclosed");
    let outward = dir.join("api.out");
    let big = Carry::new(Arc::from(vec![1u8; 4096]));
    runtime().block_on(async {
        let (relayed, mut qemu) = tokio::io::duplex(64);
        let (queue, carries) = tokio::sync::mpsc::unbounded_channel();
        queue.send(big.clone()).unwrap();
        let serving = tokio::spawn(async move {
            let mut piece = vec![0u8; 100];
            qemu.read_exact(&mut piece).await.expect("a piece");
        });
        let ended = relay_carrying(relayed, carries, None, &outward, Duration::from_millis(5), Duration::from_millis(100)).await;
        serving.await.unwrap();
        assert!(ended.is_ok(), "the pipe's close is a clean end: {ended:?}");
    });
    match big.result() {
        Some((_, Err(_))) => {}
        other => panic!("the carry failed: {other:?}"),
    }
    assert!(big.accepted() >= 100 && big.accepted() < 4096, "{}", big.accepted());
}

#[cfg(unix)]
fn socket_connector(path: PathBuf) -> impl FnMut() -> io::Result<tokio::net::UnixStream> + Send + 'static {
    move || {
        let stream = std::os::unix::net::UnixStream::connect(&path)?;
        stream.set_nonblocking(true)?;
        tokio::net::UnixStream::from_std(stream)
    }
}

#[cfg(unix)]
#[test]
fn a_link_connects_once_its_pipe_appears_and_ends_clean_with_it() {
    let dir = scratch("linkconnect");
    let socket = dir.join("api.sock");
    let outward = dir.join("api.out");
    let runtime = runtime();
    let link = Link::start(&runtime, "api", "api.sock", socket_connector(socket.clone()), None, outward.clone(), Instant::now() + Duration::from_secs(5));
    idle(&runtime, 150);
    assert!(link.seen().0.is_none(), "no connection before the pipe exists");
    let listener = std::os::unix::net::UnixListener::bind(&socket).unwrap();
    let served = std::thread::spawn(move || {
        let (mut stream, _) = listener.accept().unwrap();
        stream.write_all(b"guest").unwrap();
        let mut asked = [0u8; 3];
        stream.read_exact(&mut asked).unwrap();
        asked
    });
    let carried = {
        while link.seen().0.is_none() {
            idle(&runtime, 10);
        }
        link.carry(Arc::from(&b"ask"[..]))
    };
    let deadline = Instant::now() + Duration::from_secs(5);
    while link.seen().1.is_none() && Instant::now() < deadline {
        idle(&runtime, 10);
    }
    assert_eq!(&served.join().unwrap(), b"ask");
    assert!(matches!(carried.result(), Some((_, Ok(())))));
    assert!(matches!(link.seen().1, Some((_, Ending::Clean))), "{:?}", link.seen().1);
    assert_eq!(fs::read(&outward).unwrap(), b"guest");
}

#[cfg(unix)]
#[test]
fn a_link_whose_pipe_never_comes_fails_at_its_deadline() {
    let dir = scratch("linknever");
    let runtime = runtime();
    let started = Instant::now();
    let link = Link::start(&runtime, "monitor", "never", socket_connector(dir.join("never")), None, dir.join("monitor.out"), started + Duration::from_millis(300));
    while link.seen().1.is_none() {
        idle(&runtime, 10);
    }
    match link.seen().1 {
        Some((at, Ending::Failed(why))) => {
            assert!(why.starts_with("no connection within its allowance"), "{why}");
            assert!(at.duration_since(started) >= Duration::from_millis(300));
        }
        other => panic!("failed at the deadline: {other:?}"),
    }
}

#[cfg(unix)]
#[test]
fn a_link_refused_outright_fails_at_once() {
    let dir = scratch("linkrefused");
    let refused = dir.join("plain");
    fs::write(&refused, b"").unwrap();
    let runtime = runtime();
    let started = Instant::now();
    let link = Link::start(&runtime, "api", "plain", socket_connector(refused), None, dir.join("api.out"), started + Duration::from_secs(5));
    while link.seen().1.is_none() {
        idle(&runtime, 5);
    }
    assert!(matches!(link.seen().1, Some((_, Ending::Failed(_)))));
    assert!(started.elapsed() < Duration::from_secs(1), "{:?}", started.elapsed());
}

#[test]
fn a_stopped_link_records_its_stop() {
    let dir = scratch("linkstop");
    let runtime = runtime();
    let link = Link::start(
        &runtime,
        "api",
        "nowhere",
        || Err::<tokio::io::DuplexStream, _>(io::Error::from(io::ErrorKind::NotFound)),
        None,
        dir.join("api.out"),
        Instant::now() + Duration::from_secs(30),
    );
    idle(&runtime, 60);
    link.stop();
    assert!(matches!(link.seen(), (None, Some((_, Ending::Stopped)))));
}
