use crate::*;

/// A record of the program's API, 64 bytes.
pub(crate) const RECORD: usize = 64;
/// An export's record kinds: span entries, a snapshot's end, an actor drawn.
pub(crate) const KIND_SPANS: u32 = 23;
pub(crate) const KIND_SNAPSHOT_END: u32 = 24;
pub(crate) const KIND_ACTOR: u32 = 25;
/// The span entries a record holds, and an entry's bytes: x0, x1, the row.
pub(crate) const SPANS_A_RECORD: usize = 8;
pub(crate) const SPAN_ENTRY: usize = 6;

/// A span's row and ends as the program's table holds them.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct SpanEnd {
    pub(crate) x0: u16,
    pub(crate) x1: u16,
    pub(crate) row: u16,
}

/// A presented frame's snapshot: its span table and the actors it drew.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Snapshot {
    pub(crate) frame: u32,
    pub(crate) sequence: u32,
    pub(crate) spans: Vec<SpanEnd>,
    pub(crate) actors: BTreeMap<u32, Entity>,
}

/// CRC-32 by the reflected polynomial 0xEDB88320, the program's crc32.
pub(crate) fn crc32(bytes: &[u8]) -> u32 {
    let mut crc = 0xffff_ffffu32;
    for &byte in bytes {
        crc ^= byte as u32;
        for _ in 0..8 {
            let mask = (crc & 1).wrapping_neg();
            crc = (crc >> 1) ^ (0xedb8_8320 & mask);
        }
    }
    !crc
}

/// The little-endian word at a byte of a record.
fn word_at(record: &[u8], at: usize) -> u32 {
    u32::from_le_bytes([record[at], record[at + 1], record[at + 2], record[at + 3]])
}

/// The little-endian half word at a byte of a record.
fn half_at(record: &[u8], at: usize) -> u16 {
    u16::from_le_bytes([record[at], record[at + 1]])
}

/// The single at a byte of a record, widened.
fn single_at(record: &[u8], at: usize) -> f64 {
    f32::from_bits(word_at(record, at)) as f64
}

/// An actor record's scratch entity, the sprite sprite_draw drew it as.
fn actor_of(record: &[u8]) -> Entity {
    Entity {
        class: CLASS_SPRITE,
        position: [single_at(record, 12), single_at(record, 16), single_at(record, 20)],
        yaw: single_at(record, 24),
        width: single_at(record, 28),
        height: single_at(record, 32),
        material: word_at(record, 36) as i32,
        flags: word_at(record, 40),
    }
}

/// Every snapshot an export wrote, each held whole by its count and CRC.
pub(crate) fn snapshots(api: &[u8]) -> Result<Vec<Snapshot>, String> {
    let mut done = Vec::new();
    let mut packed: Vec<u8> = Vec::new();
    let mut actors: BTreeMap<u32, Entity> = BTreeMap::new();
    let mut open: Option<u32> = None;
    for record in api.as_chunks::<RECORD>().0 {
        let kind = word_at(record, 0);
        if kind != KIND_SPANS && kind != KIND_SNAPSHOT_END && kind != KIND_ACTOR {
            continue;
        }
        let frame = word_at(record, 4);
        if let Some(held) = open.filter(|&held| held != frame) {
            return Err(format!("frame {frame}'s snapshot records begin before frame {held}'s end"));
        }
        open = Some(frame);
        if kind == KIND_SPANS {
            let first = word_at(record, 8) as usize;
            if first * SPAN_ENTRY != packed.len() {
                return Err(format!("frame {frame}'s span records jump to entry {first} after {}", packed.len() / SPAN_ENTRY));
            }
            packed.extend_from_slice(&record[12..12 + SPANS_A_RECORD * SPAN_ENTRY]);
        } else if kind == KIND_ACTOR {
            let index = word_at(record, 8);
            if actors.insert(index, actor_of(record)).is_some() {
                return Err(format!("frame {frame}'s snapshot names actor {index} twice"));
            }
        } else {
            let count = word_at(record, 12) as usize;
            let received = packed.len() / SPAN_ENTRY;
            if received != count.div_ceil(SPANS_A_RECORD) * SPANS_A_RECORD {
                return Err(format!("frame {frame}'s snapshot ends after {received} span entries where its count, {count}, needs {}", count.div_ceil(SPANS_A_RECORD) * SPANS_A_RECORD));
            }
            let table = &packed[..count * SPAN_ENTRY];
            let crc = crc32(table);
            if crc != word_at(record, 16) {
                return Err(format!("frame {frame}'s span table has CRC-32 {crc:08x} where its end records {:08x}", word_at(record, 16)));
            }
            let actor_count = word_at(record, 20) as usize;
            if actors.len() != actor_count {
                return Err(format!("frame {frame}'s snapshot holds {} actors where its end records {actor_count}", actors.len()));
            }
            let spans = table.as_chunks::<SPAN_ENTRY>().0.iter().map(|entry| SpanEnd { x0: half_at(entry, 0), x1: half_at(entry, 2), row: half_at(entry, 4) }).collect();
            done.push(Snapshot { frame, sequence: word_at(record, 8), spans, actors: std::mem::take(&mut actors) });
            packed.clear();
            open = None;
        }
    }
    if let Some(frame) = open {
        return Err(format!("frame {frame}'s snapshot has no end record"));
    }
    Ok(done)
}

/// One frame's snapshot, a table it carries held whole: one packet, ends on screen.
pub(crate) fn snapshot_of(snapshots: &[Snapshot], frame: u32, height: usize, tabled: bool) -> Result<Snapshot, String> {
    let held: Vec<u32> = snapshots.iter().map(|s| s.frame).collect();
    let mut found = snapshots.iter().filter(|s| s.frame == frame);
    let snapshot = found.next().ok_or_else(|| format!("the export holds no snapshot of frame {frame}, only of {held:?}"))?;
    if found.next().is_some() {
        return Err(format!("the export holds frame {frame}'s snapshot twice"));
    }
    if tabled && snapshot.sequence != 0 {
        return Err(format!("frame {frame}'s table is its packet {}'s, where a LEVELS frame is drawn from one packet", snapshot.sequence));
    }
    if let Some((index, end)) = snapshot.spans.iter().enumerate().find(|(_, end)| end.x0 > end.x1 || end.row as usize >= height) {
        return Err(format!("frame {frame}'s span {index} runs from {} to {} on row {}, outside a screen of {height} rows", end.x0, end.x1, end.row));
    }
    Ok(snapshot.clone())
}
