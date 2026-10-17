use crate::*;

/// The level a pixel no span drew carries: the magenta prepaint's red nibble.
pub(crate) const SENTINEL: u8 = 15;
/// The deepest level a code carries, the chain's MIP_LEVELS less one.
pub(crate) const LEVEL_MAX: u8 = 9;

/// A LEVELS pixel: its block's level, its offset in the block, its span.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Code {
    pub(crate) level: u8,
    pub(crate) offset: u8,
    pub(crate) span: u16,
}

/// A pixel's code, None for the sentinel's.
pub(crate) fn code_of(rgb: [u8; 3]) -> Option<Code> {
    let level = rgb[0] >> 4;
    if level == SENTINEL {
        return None;
    }
    Some(Code { level, offset: rgb[0] & 0xf, span: (rgb[1] as u16) << 8 | rgb[2] as u16 })
}

/// A block as a LEVELS capture shows it: span, row, start, level, pixels seen.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct Block {
    pub(crate) span: u16,
    pub(crate) row: u32,
    pub(crate) x0: u32,
    pub(crate) level: u8,
    pub(crate) pixels: u32,
    pub(crate) end: u32,
}

/// Every block a capture shows, ordered by span and start.
pub(crate) fn blocks(image: &Image) -> Result<Vec<Block>, String> {
    let mut found: BTreeMap<(u16, u32), Block> = BTreeMap::new();
    let mut rows: BTreeMap<u16, u32> = BTreeMap::new();
    for y in 0..image.height {
        for x in 0..image.width {
            if in_stamp(x, y) {
                continue;
            }
            let Some(code) = code_of(image.rgb(x, y)) else {
                continue;
            };
            if code.level > LEVEL_MAX {
                return Err(format!("pixel ({x}, {y}) carries level {}, past {LEVEL_MAX} and short of the sentinel", code.level));
            }
            let Some(x0) = (x as u32).checked_sub(code.offset as u32) else {
                return Err(format!("pixel ({x}, {y}) lies {} into a block that would start before its row", code.offset));
            };
            let row = *rows.entry(code.span).or_insert(y as u32);
            if row != y as u32 {
                return Err(format!("span {} lies on rows {row} and {y}", code.span));
            }
            let block = found.entry((code.span, x0)).or_insert(Block { span: code.span, row, x0, level: code.level, pixels: 0, end: x0 });
            if block.level != code.level {
                return Err(format!("span {}'s block at {x0} on row {y} carries levels {} and {}", code.span, block.level, code.level));
            }
            block.pixels += 1;
            block.end = block.end.max(x as u32 + 1);
        }
    }
    Ok(found.into_values().collect())
}
