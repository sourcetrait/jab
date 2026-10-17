use crate::*;

/// The side of a cell the differing pixels are gathered in before boxing.
pub(crate) const CELL: usize = 16;

/// A region of differing pixels: its box, the pixel past its last, its count.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Region {
    pub(crate) x0: usize,
    pub(crate) y0: usize,
    pub(crate) x1: usize,
    pub(crate) y1: usize,
    pub(crate) pixels: u64,
    pub(crate) largest: u8,
}

impl Region {
    /// A region holding nothing yet.
    fn empty() -> Region {
        Region { x0: usize::MAX, y0: usize::MAX, x1: 0, y1: 0, pixels: 0, largest: 0 }
    }

    /// The region grown by another's box, count, and largest difference.
    fn take(&mut self, other: &Region) {
        self.x0 = self.x0.min(other.x0);
        self.y0 = self.y0.min(other.y0);
        self.x1 = self.x1.max(other.x1);
        self.y1 = self.y1.max(other.y1);
        self.pixels += other.pixels;
        self.largest = self.largest.max(other.largest);
    }
}

/// The largest of a pixel pair's three channel differences.
fn channel_difference(p: [u8; 3], q: [u8; 3]) -> u8 {
    (0..3).map(|c| p[c].abs_diff(q[c])).max().unwrap_or(0)
}

/// Two captures' differing pixels, the stamp's cells skipped, by region.
pub(crate) fn differ(a: &Image, b: &Image) -> Result<Vec<Region>, String> {
    if (a.width, a.height) != (b.width, b.height) {
        return Err(format!("the captures are {} by {} and {} by {}", a.width, a.height, b.width, b.height));
    }
    let (columns, rows) = (a.width.div_ceil(CELL), a.height.div_ceil(CELL));
    let mut cells = vec![Region::empty(); columns * rows];
    for y in 0..a.height {
        for x in 0..a.width {
            if in_stamp(x, y) {
                continue;
            }
            let (p, q) = (a.rgb(x, y), b.rgb(x, y));
            if p == q {
                continue;
            }
            let pixel = Region { x0: x, y0: y, x1: x + 1, y1: y + 1, pixels: 1, largest: channel_difference(p, q) };
            cells[(y / CELL) * columns + x / CELL].take(&pixel);
        }
    }
    let mut seen = vec![false; columns * rows];
    let mut regions = Vec::new();
    for start in 0..cells.len() {
        if cells[start].pixels == 0 || seen[start] {
            continue;
        }
        let mut region = Region::empty();
        let mut stack = vec![start];
        seen[start] = true;
        while let Some(cell) = stack.pop() {
            region.take(&cells[cell]);
            let (cx, cy) = ((cell % columns) as isize, (cell / columns) as isize);
            for (dx, dy) in [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)] {
                let (nx, ny) = (cx + dx, cy + dy);
                if nx < 0 || ny < 0 || nx >= columns as isize || ny >= rows as isize {
                    continue;
                }
                let next = ny as usize * columns + nx as usize;
                if cells[next].pixels > 0 && !seen[next] {
                    seen[next] = true;
                    stack.push(next);
                }
            }
        }
        regions.push(region);
    }
    Ok(regions)
}
