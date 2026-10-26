use crate::*;

/// A footprint within this factor of a level boundary is threshold-sensitive.
pub(crate) const BAND: f64 = 1.044_273_782_427_413_8;
/// The pixels of a full block, BLOCK in render.inc.
pub(crate) const BLOCK: f64 = 16.0;
/// The bits of 1/z's fraction, DEPTH_BITS in render.inc: 6.26.
pub(crate) const DEPTH_BITS: u32 = 26;

/// The least 1/z an image keeps, in a metre's fractions, from its IZ_MIN.
pub(crate) fn depth_floor(iz_min: i64) -> f64 {
    iz_min as f64 / (1u64 << DEPTH_BITS) as f64
}

/// A pixel's texel derivatives along the row and down it, and the hold.
#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct Derivatives {
    pub(crate) along: f64,
    pub(crate) down: f64,
    pub(crate) clamped: bool,
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
    Degenerate,
}

/// The camera's distance to a mapping's plane along its normal, n.(q - eye).
fn reach(m: &Mapping, camera: &Camera) -> f64 {
    dot(m.normal, summed(m.point, scaled(camera.eye, -1.0)))
}

/// 1/z at a screen point, affine over the screen: n.dir / (hz n.(q - eye)).
pub(crate) fn inverse_depth(m: &Mapping, camera: &Camera, x: f64, y: f64) -> f64 {
    dot(m.normal, camera.ray(x, y)) / (HZ * reach(m, camera))
}

/// A coordinate over z at a screen point, affine over the screen.
fn over_z(m: &Mapping, camera: &Camera, gradient: [f64; 3], at: f64, x: f64, y: f64) -> f64 {
    (dot(gradient, camera.eye) + at) * inverse_depth(m, camera, x, y) + dot(gradient, camera.ray(x, y)) / HZ
}

/// A coordinate over z's change along a screen axis.
fn over_z_step(m: &Mapping, camera: &Camera, gradient: [f64; 3], at: f64, axis: [f64; 3]) -> f64 {
    (dot(gradient, camera.eye) + at) * dot(m.normal, axis) / (HZ * reach(m, camera)) + dot(gradient, axis) / HZ
}

/// The exact derivatives at a screen point on the mapping drawn there.
pub(crate) fn footprint(m: &Mapping, camera: &Camera, x: f64, y: f64, floor: f64) -> Footprint {
    let dir = camera.ray(x, y);
    let reach = reach(m, camera);
    let facing = dot(m.normal, dir);
    let depth = HZ * reach / facing;
    if !depth.is_finite() || depth <= 0.0 {
        return Footprint::Degenerate;
    }
    let (along, down, clamped) = if 1.0 / depth < floor {
        let held = |axis: [f64; 3]| (over_z_step(m, camera, m.u, m.u0, axis).abs() / floor).max(over_z_step(m, camera, m.v, m.v0, axis).abs() / floor);
        (held(camera.right), held(camera.down), true)
    } else {
        let derivative = |gradient: [f64; 3], axis: [f64; 3]| (reach * (dot(gradient, axis) * facing - dot(gradient, dir) * dot(m.normal, axis)) / (facing * facing)).abs();
        (derivative(m.u, camera.right).max(derivative(m.v, camera.right)), derivative(m.u, camera.down).max(derivative(m.v, camera.down)), false)
    };
    if along.is_finite() && down.is_finite() { Footprint::Value(Derivatives { along, down, clamped }) } else { Footprint::Degenerate }
}

/// The texel the drawn mapping gives a screen point, 1/z held at the floor.
pub(crate) fn held_texel(m: &Mapping, camera: &Camera, x: f64, y: f64, floor: f64) -> (f64, f64) {
    let held = inverse_depth(m, camera, x, y).max(floor);
    (over_z(m, camera, m.u, m.u0, x, y) / held, over_z(m, camera, m.v, m.v0, x, y) / held)
}

/// The texel coordinate's change a pixel over a block, as the block steps.
pub(crate) fn block_secant(m: &Mapping, camera: &Camera, x: f64, y: f64, length: f64, floor: f64) -> f64 {
    let clamped = inverse_depth(m, camera, x, y) < floor || inverse_depth(m, camera, x + length, y) < floor;
    let texel = |x: f64| {
        if clamped {
            held_texel(m, camera, x, y, floor)
        } else {
            let dir = camera.ray(x, y);
            let hit = summed(camera.eye, scaled(dir, reach(m, camera) / dot(m.normal, dir)));
            (dot(m.u, hit), dot(m.v, hit))
        }
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

/// A union block's class: judged, excluded by design, or unresolved.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub(crate) enum Class {
    Judged,
    Sky,
    Unknown,
    Unread,
    Actor,
    Degenerate,
    NoEnd,
    Unpaired,
}

impl Class {
    /// The class as a reading names it.
    pub(crate) fn name(&self) -> &'static str {
        match self {
            Class::Judged => "judged",
            Class::Sky => "sky",
            Class::Unknown => "unknown",
            Class::Unread => "unread",
            Class::Actor => "actor",
            Class::Degenerate => "degenerate",
            Class::NoEnd => "no_end",
            Class::Unpaired => "unpaired",
        }
    }

    /// Whether the class leaves its block unresolved, never excluded by design.
    pub(crate) fn unresolved(&self) -> bool {
        !matches!(self, Class::Judged | Class::Sky)
    }
}

/// The captures' union of blocks by class, and the judged blocks' own counts.
#[derive(Clone, Debug, Default, PartialEq)]
pub(crate) struct Population {
    pub(crate) blocks: u64,
    pub(crate) classes: BTreeMap<Class, u64>,
    pub(crate) sensitive: u64,
    pub(crate) clamped: u64,
    pub(crate) actors: u64,
}

impl Population {
    /// The blocks a class holds.
    pub(crate) fn count(&self, class: Class) -> u64 {
        self.classes.get(&class).copied().unwrap_or(0)
    }

    /// The blocks left unresolved, every reason together.
    pub(crate) fn unresolved(&self) -> u64 {
        self.classes.iter().filter(|(class, _)| class.unresolved()).map(|(_, n)| n).sum()
    }
}

/// One capture's levels on the judged blocks against both references, counted.
#[derive(Clone, Debug, Default, PartialEq)]
pub(crate) struct Tally {
    pub(crate) blocks: u64,
    pub(crate) judged: u64,
    pub(crate) agree: u64,
    pub(crate) sharper: u64,
    pub(crate) coarser: u64,
    pub(crate) secant_agree: u64,
    pub(crate) secant_sharper: u64,
    pub(crate) secant_coarser: u64,
    pub(crate) levels: [u64; 10],
}

/// A union block: its place, class, references, and each capture's level.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Row {
    pub(crate) span: u16,
    pub(crate) row: u32,
    pub(crate) x0: u32,
    pub(crate) class: Class,
    pub(crate) surface: Option<u32>,
    pub(crate) depth: Option<f64>,
    pub(crate) clamped: bool,
    pub(crate) footprint: f64,
    pub(crate) along: f64,
    pub(crate) down: f64,
    pub(crate) secant: f64,
    pub(crate) length: f64,
    pub(crate) reference: u8,
    pub(crate) band: Option<u8>,
    pub(crate) secant_reference: u8,
    pub(crate) secant_band: Option<u8>,
    pub(crate) levels: Vec<Option<u8>>,
}

/// A LEVELS capture to compare, its span table where its export carries one.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Capture {
    pub(crate) image: Image,
    pub(crate) spans: Option<Vec<SpanEnd>>,
}

/// What a view's blocks are judged against.
pub(crate) struct Scene<'a> {
    pub(crate) map: &'a Map,
    pub(crate) textures: &'a Textures,
    pub(crate) lumels: &'a Lumels,
    pub(crate) actors: &'a BTreeMap<u32, Entity>,
    pub(crate) camera: &'a Camera,
    pub(crate) floor: f64,
}

/// A union block as the first capture holding it shows it, and its levels.
struct United {
    block: Block,
    levels: Vec<Option<u8>>,
}

/// Each span's surface, the OWNER capture's wherever the span shows in any capture.
pub(crate) fn span_surfaces(owner: &Image, captures: &[Capture]) -> Result<BTreeMap<u16, u32>, String> {
    let mut surfaces: BTreeMap<u16, u32> = BTreeMap::new();
    for capture in captures {
        let image = &capture.image;
        if (owner.width, owner.height) != (image.width, image.height) {
            return Err(format!("the OWNER capture is {} by {} where a LEVELS capture is {} by {}", owner.width, owner.height, image.width, image.height));
        }
        for y in 0..image.height {
            for x in 0..image.width {
                if in_stamp(x, y) {
                    continue;
                }
                let Some(code) = code_of(image.rgb(x, y)) else {
                    continue;
                };
                let surface = owner.word(x, y);
                if surface == OWNER_NONE {
                    return Err(format!("pixel ({x}, {y}) shows span {} in a LEVELS capture and no surface in the OWNER one", code.span));
                }
                let held = *surfaces.entry(code.span).or_insert(surface);
                if held != surface {
                    return Err(format!("span {} shows surfaces {held} and {surface}", code.span));
                }
            }
        }
    }
    Ok(surfaces)
}

/// A capture's pixels held to its span table, each inside its span.
pub(crate) fn check_table(image: &Image, spans: &[SpanEnd]) -> Result<(), String> {
    for y in 0..image.height {
        for x in 0..image.width {
            if in_stamp(x, y) {
                continue;
            }
            let Some(code) = code_of(image.rgb(x, y)) else {
                continue;
            };
            let Some(end) = spans.get(code.span as usize) else {
                return Err(format!("pixel ({x}, {y}) names span {}, past the table's {}", code.span, spans.len()));
            };
            if end.row as usize != y || (x as u32) < end.x0 as u32 || (x as u32) >= end.x1 as u32 {
                return Err(format!("pixel ({x}, {y}) names span {}, which the table has on row {} from {} to {}", code.span, end.row, end.x0, end.x1));
            }
        }
    }
    Ok(())
}

/// A block's pixels as the engine steps them.
fn block_length(block: &Block, spans: Option<&[SpanEnd]>, last: &BTreeMap<u16, u32>) -> Option<f64> {
    match spans {
        Some(table) => table.get(block.span as usize).map(|end| (end.x1 as u32).saturating_sub(block.x0).min(BLOCK as u32) as f64),
        None => Some(if last.get(&block.span).is_some_and(|&x0| block.x0 < x0) { BLOCK } else { (block.end - block.x0) as f64 }),
    }
}

/// Every capture's blocks united and classed, the judged held to both.
pub(crate) fn compare(scene: &Scene, owner: &Image, captures: &[Capture]) -> Result<(Population, Vec<Tally>, Vec<Row>), String> {
    let first = captures.first().ok_or("no LEVELS capture to compare")?;
    if captures.iter().any(|c| c.spans != first.spans) {
        return Err("the captures' span tables differ, where FOOTPRINT changes no span".to_string());
    }
    for capture in captures {
        if let Some(spans) = &capture.spans {
            check_table(&capture.image, spans)?;
        }
    }
    let surfaces = span_surfaces(owner, captures)?;
    let found = captures.iter().map(|c| blocks(&c.image)).collect::<Result<Vec<_>, _>>()?;
    let mut last: BTreeMap<u16, u32> = BTreeMap::new();
    for block in &found[0] {
        let x0 = last.entry(block.span).or_insert(block.x0);
        *x0 = (*x0).max(block.x0);
    }
    let mut union: BTreeMap<(u16, u32), United> = BTreeMap::new();
    for (k, blocks) in found.iter().enumerate() {
        for block in blocks {
            let entry = union.entry((block.span, block.x0)).or_insert_with(|| United { block: block.clone(), levels: vec![None; captures.len()] });
            entry.levels[k] = Some(block.level);
        }
    }
    let mut population = Population { blocks: union.len() as u64, ..Population::default() };
    let mut tallies: Vec<Tally> = found.iter().map(|blocks| Tally { blocks: blocks.len() as u64, ..Tally::default() }).collect();
    let mut owners: BTreeMap<u32, Owned> = BTreeMap::new();
    let mut rows = Vec::with_capacity(union.len());
    for United { block, levels } in union.into_values() {
        let mut row = Row {
            span: block.span,
            row: block.row,
            x0: block.x0,
            class: Class::Judged,
            surface: surfaces.get(&block.span).copied(),
            depth: None,
            clamped: false,
            footprint: 0.0,
            along: 0.0,
            down: 0.0,
            secant: 0.0,
            length: 0.0,
            reference: 0,
            band: None,
            secant_reference: 0,
            secant_band: None,
            levels,
        };
        row.class = classify(scene, &mut owners, &block, &mut row, first.spans.as_deref(), &last);
        *population.classes.entry(row.class).or_insert(0) += 1;
        if row.class == Class::Judged {
            if row.band.is_some() {
                population.sensitive += 1;
            }
            if row.clamped {
                population.clamped += 1;
            }
            if row.surface.is_some_and(|s| s >= SURFACE_ACTORS) {
                population.actors += 1;
            }
            for (k, tally) in tallies.iter_mut().enumerate() {
                let level = row.levels[k].expect("a judged block is paired in every capture");
                tally.judged += 1;
                match judge(level, row.reference, row.band) {
                    Verdict::Agree => tally.agree += 1,
                    Verdict::Sharper => tally.sharper += 1,
                    Verdict::Coarser => tally.coarser += 1,
                }
                match judge(level, row.secant_reference, row.secant_band) {
                    Verdict::Agree => tally.secant_agree += 1,
                    Verdict::Sharper => tally.secant_sharper += 1,
                    Verdict::Coarser => tally.secant_coarser += 1,
                }
                tally.levels[level as usize] += 1;
            }
        }
        rows.push(row);
    }
    Ok((population, tallies, rows))
}

/// A union block's class, its row's references filled where it is judged.
fn classify(scene: &Scene, owners: &mut BTreeMap<u32, Owned>, block: &Block, row: &mut Row, spans: Option<&[SpanEnd]>, last: &BTreeMap<u16, u32>) -> Class {
    let (camera, floor) = (scene.camera, scene.floor);
    let Some(surface) = row.surface else {
        return Class::Unknown;
    };
    let mapping = match owners.entry(surface).or_insert_with(|| owned(scene.map, scene.textures, scene.lumels, scene.actors, camera, surface)) {
        Owned::Mapped(mapping) => *mapping,
        Owned::Sky => return Class::Sky,
        Owned::Actor => return Class::Actor,
        Owned::Unsized(_) => return Class::Unread,
        Owned::Unknown => return Class::Unknown,
    };
    let (x, y) = (block.x0 as f64 + 0.5, block.row as f64 + 0.5);
    let Footprint::Value(derivatives) = footprint(&mapping, camera, x, y, floor) else {
        return Class::Degenerate;
    };
    row.depth = Some(1.0 / inverse_depth(&mapping, camera, x, y));
    row.clamped = derivatives.clamped;
    let Some(length) = block_length(block, spans, last) else {
        return Class::NoEnd;
    };
    row.length = length;
    row.footprint = derivatives.footprint();
    row.along = derivatives.along;
    row.down = derivatives.down;
    row.reference = level_of(row.footprint, mapping.levels);
    row.band = band_of(row.footprint, mapping.levels);
    row.secant = block_secant(&mapping, camera, x, y, length, floor);
    let stepped = row.secant.max(derivatives.down);
    row.secant_reference = level_of(stepped, mapping.levels);
    row.secant_band = band_of(stepped, mapping.levels);
    if row.levels.iter().any(Option::is_none) {
        return Class::Unpaired;
    }
    Class::Judged
}
