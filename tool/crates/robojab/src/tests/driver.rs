use crate::*;

fn plan() -> Plan {
    Plan {
        qemu_binary: String::new(),
        qemu: Vec::new(),
        env: HashMap::new(),
        out: PathBuf::new(),
        serial_log: PathBuf::new(),
        pidfile: PathBuf::new(),
        monitor: PathBuf::new(),
        debug_log: None,
        api_in: None,
        api_out: None,
        pad_fifo: None,
        pad_pipe_in: None,
        pad_port: false,
        pad_header: Vec::new(),
        sound: None,
    }
}

fn record(byte: u8, size: usize) -> Vec<u8> {
    vec![byte; size]
}

#[test]
fn a_record_split_across_reads_comes_back_whole() {
    let mut driver = Driver::new(plan(), None, String::new(), 1);
    let mut first = record(1, 64);
    first.extend(record(2, 64));
    first.extend(record(3, 10));
    let read = driver.held(first);
    let value = driver.records(read, 64).expect("records");
    assert_eq!(value["records"].as_array().map(Vec::len), Some(2));
    assert_eq!(value["first"], 0);
    assert_eq!(value["remainder"], 10);

    let mut second = record(3, 54);
    second.extend(record(4, 64));
    let read = driver.held(second);
    let value = driver.records(read, 64).expect("records");
    let records = value["records"].as_array().expect("a list");
    assert_eq!(records.len(), 2);
    assert_eq!(value["first"], 2);
    assert_eq!(records[0], hex(&record(3, 64)));
    assert_eq!(records[1], hex(&record(4, 64)));
    assert_eq!(value["remainder"], 0);
}

#[test]
fn a_hex_read_takes_what_a_record_read_kept() {
    let mut driver = Driver::new(plan(), None, String::new(), 1);
    let read = driver.held(record(5, 70));
    driver.records(read, 64).expect("records");
    let bytes = driver.held(record(6, 2));
    assert_eq!(bytes, [record(5, 6), record(6, 2)].concat());
}
