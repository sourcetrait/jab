use crate::*;

/// The least 1/z the span keeps, IZ_MIN in 6.26 as a fraction of a metre.
pub(crate) const IZ_MIN: f64 = 4096.0 / 67_108_864.0;
/// A footprint within this factor of a level boundary is threshold-sensitive.
pub(crate) const BAND: f64 = 1.044_273_782_427_413_8;
/// The pixels of a full block, BLOCK in render.inc.
pub(crate) const BLOCK: f64 = 16.0;

/// A pixel's texel derivatives: the largest along the row and down it.
#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct Derivatives {
    pub(crate) along: f64,
    pub(crate) down: f64,
}

impl Derivatives {
    /// The footprint, the largest of the four.
    pub(crate) fn footprint(&self) -> f64 {
        self.along.max(self.down)
    }
}

/// A block's reference: its derivatives in level-0 texels a pixel, or why none.
#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) enum Footprint {
    Value(Derivatives),
    Clamped,
    Degenerate,
}

/// The exact derivatives at a screen point, each of u and v along x and y.
pub(crate) fn footprint(m: &Mapping, camera: &Camera, x: f64, y: f64) -> Footprint {
    let dir = camera.ray(x, y);
    let reach = dot(m.normal, summed(m.point, scaled(camera.eye, -1.0)));
    let facing = dot(m.normal, dir);
    let depth = HZ * reach / facing;
    if !depth.is_finite() || depth <= 0.0 {
        return Footprint::Degenerate;
    }
    if 1.0 / depth < IZ_MIN {
        return Footprint::Clamped;
    }
    let derivative = |gradient: [f64; 3], axis: [f64; 3]| (reach * (dot(gradient, axis) * facing - dot(gradient, dir) * dot(m.normal, axis)) / (facing * facing)).abs();
    let along = derivative(m.u, camera.right).max(derivative(m.v, camera.right));
    let down = derivative(m.u, camera.down).max(derivative(m.v, camera.down));
    if along.is_finite() && down.is_finite() { Footprint::Value(Derivatives { along, down }) } else { Footprint::Degenerate }
}

/// The texel coordinate's change a pixel over a block's pixels, as the block steps.
pub(crate) fn block_secant(m: &Mapping, camera: &Camera, x: f64, y: f64, length: f64) -> f64 {
    let texel = |x: f64| {
        let dir = camera.ray(x, y);
        let hit = summed(camera.eye, scaled(dir, dot(m.normal, summed(m.point, scaled(camera.eye, -1.0))) / dot(m.normal, dir)));
        (dot(m.u, hit), dot(m.v, hit))
    };
    let (u0, v0) = texel(x);
    let (u1, v1) = texel(x + length);
    ((u1 - u0) / length).abs().max(((v1 - v0) / length).abs())
}

/// The level the engine's rule gives a footprint: m below 2^(m + 1), capped.
pub(crate) fn level_of(footprint: f64, levels: u8) -> u8 {
    let last = levels.saturating_sub(1);
    if footprint < 2.0 {
        return 0;
    }
    (footprint.log2().floor() as u8).min(last)
}

/// The level boundary a footprint lies within the band of.
pub(crate) fn band_of(footprint: f64, levels: u8) -> Option<u8> {
    (1..levels).find(|&m| {
        let boundary = (1u64 << m) as f64;
        footprint >= boundary / BAND && footprint <= boundary * BAND
    })
}

/// A block's level held to its reference.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Verdict {
    Agree,
    Sharper,
    Coarser,
}

/// The verdict on a level: the reference's, or in a band either level beside it.
pub(crate) fn judge(level: u8, reference: u8, band: Option<u8>) -> Verdict {
    let (least, most) = match band {
        Some(m) => (m - 1, m),
        None => (reference, reference),
    };
    if level < least {
        Verdict::Sharper
    } else if level > most {
        Verdict::Coarser
    } else {
        Verdict::Agree
    }
}

/// One capture's blocks against the reference, counted.
#[derive(Clone, Debug, Default, PartialEq)]
pub(crate) struct Tally {
    pub(crate) blocks: u64,
    pub(crate) judged: u64,
    pub(crate) sky: u64,
    pub(crate) actors: u64,
    pub(crate) unknown: u64,
    pub(crate) unread: u64,
    pub(crate) clamped: u64,
    pub(crate) degenerate: u64,
    pub(crate) sensitive: u64,
    pub(crate) agree: u64,
    pub(crate) sharper: u64,
    pub(crate) coarser: u64,
    pub(crate) secant_agree: u64,
    pub(crate) secant_sharper: u64,
    pub(crate) secant_coarser: u64,
    pub(crate) levels: [u64; 10],
}

/// A judged block: its place, surface, references, and each capture's level.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Row {
    pub(crate) span: u16,
    pub(crate) row: u32,
    pub(crate) x0: u32,
    pub(crate) surface: u32,
    pub(crate) footprint: f64,
    pub(crate) along: f64,
    pub(crate) down: f64,
    pub(crate) secant: f64,
    pub(crate) reference: u8,
    pub(crate) band: Option<u8>,
    pub(crate) secant_reference: u8,
    pub(crate) secant_band: Option<u8>,
    pub(crate) levels: Vec<Option<u8>>,
}

/// A block's pixels as the engine steps them, short for its span's last alone.
fn block_length(block: &Block, last: &BTreeMap<u16, u32>) -> f64 {
    if last.get(&block.span).is_some_and(|&x0| block.x0 < x0) { BLOCK } else { (block.end - block.x0) as f64 }
}

/// Each span's surface, the OWNER capture's wherever the span shows.
pub(crate) fn span_surfaces(owner: &Image, first: &Image) -> Result<BTreeMap<u16, u32>, String> {
    if (owner.width, owner.height) != (first.width, first.height) {
        return Err(format!("the OWNER capture is {} by {} where the LEVELS capture is {} by {}", owner.width, owner.height, first.width, first.height));
    }
    let mut surfaces: BTreeMap<u16, u32> = BTreeMap::new();
    for y in 0..first.height {
        for x in 0..first.width {
            if in_stamp(x, y) {
                continue;
            }
            let Some(code) = code_of(first.rgb(x, y)) else {
                continue;
            };
            let surface = owner.word(x, y);
            if surface == OWNER_NONE {
                return Err(format!("pixel ({x}, {y}) shows span {} in the LEVELS capture and no surface in the OWNER one", code.span));
            }
            let held = *surfaces.entry(code.span).or_insert(surface);
            if held != surface {
                return Err(format!("span {} shows surfaces {held} and {surface}", code.span));
            }
        }
    }
    Ok(surfaces)
}

/// Every capture's blocks held to the reference, each block judged once.
pub(crate) fn compare(map: &Map, sizes: &[Result<(u32, u32), String>], camera: &Camera, owner: &Image, captures: &[Image]) -> Result<(Vec<Tally>, Vec<Row>), String> {
    let first = captures.first().ok_or("no LEVELS capture to compare")?;
    let surfaces = span_surfaces(owner, first)?;
    let mut tallies = vec![Tally::default(); captures.len()];
    let mut rows: BTreeMap<(u16, u32), Row> = BTreeMap::new();
    let mut owners: BTreeMap<u32, Owned> = BTreeMap::new();
    for (k, capture) in captures.iter().enumerate() {
        let tally = &mut tallies[k];
        let found = blocks(capture)?;
        let mut last: BTreeMap<u16, u32> = BTreeMap::new();
        for block in &found {
            let x0 = last.entry(block.span).or_insert(block.x0);
            *x0 = (*x0).max(block.x0);
        }
        for block in found {
            tally.blocks += 1;
            let Some(&surface) = surfaces.get(&block.span) else {
                tally.unknown += 1;
                continue;
            };
            let named = owners.entry(surface).or_insert_with(|| owned(map, sizes, camera, surface));
            let mapping = match named {
                Owned::Mapped(mapping) => *mapping,
                Owned::Sky => {
                    tally.sky += 1;
                    continue;
                }
                Owned::Actor => {
                    tally.actors += 1;
                    continue;
                }
                Owned::Unsized(_) => {
                    tally.unread += 1;
                    continue;
                }
                Owned::Unknown => {
                    tally.unknown += 1;
                    continue;
                }
            };
            let (x, y) = (block.x0 as f64 + 0.5, block.row as f64 + 0.5);
            let derivatives = match footprint(&mapping, camera, x, y) {
                Footprint::Value(derivatives) => derivatives,
                Footprint::Clamped => {
                    tally.clamped += 1;
                    continue;
                }
                Footprint::Degenerate => {
                    tally.degenerate += 1;
                    continue;
                }
            };
            let value = derivatives.footprint();
            let reference = level_of(value, mapping.levels);
            let band = band_of(value, mapping.levels);
            tally.judged += 1;
            if band.is_some() {
                tally.sensitive += 1;
            }
            match judge(block.level, reference, band) {
                Verdict::Agree => tally.agree += 1,
                Verdict::Sharper => tally.sharper += 1,
                Verdict::Coarser => tally.coarser += 1,
            }
            let secant = block_secant(&mapping, camera, x, y, block_length(&block, &last));
            let stepped = secant.max(derivatives.down);
            let secant_reference = level_of(stepped, mapping.levels);
            let secant_band = band_of(stepped, mapping.levels);
            match judge(block.level, secant_reference, secant_band) {
                Verdict::Agree => tally.secant_agree += 1,
                Verdict::Sharper => tally.secant_sharper += 1,
                Verdict::Coarser => tally.secant_coarser += 1,
            }
            tally.levels[block.level as usize] += 1;
            let row = rows.entry((block.span, block.x0)).or_insert_with(|| Row {
                span: block.span,
                row: block.row,
                x0: block.x0,
                surface,
                footprint: value,
                along: derivatives.along,
                down: derivatives.down,
                secant,
                reference,
                band,
                secant_reference,
                secant_band,
                levels: vec![None; captures.len()],
            });
            row.levels[k] = Some(block.level);
        }
    }
    Ok((tallies, rows.into_values().collect()))
}
