use crate::*;

/// The threshold's bounds in metres, inside the planned floor.
pub(crate) const PLAN_DEPTHS: (f64, f64) = (4.0, 20.0);
/// The share of the surface's blocks the threshold must put past it.
pub(crate) const PLAN_SHARES: (f64, f64) = (0.2, 0.5);
/// The share the selection aims at.
pub(crate) const PLAN_AIM: f64 = 1.0 / 3.0;
/// The grid the threshold's depth is chosen on, half a metre.
pub(crate) const PLAN_STEP: f64 = 0.5;
/// The witnesses the plan lists, the strongest first.
pub(crate) const PLAN_WITNESSES: usize = 8;

/// A clamped block's levels: held as drawn, unbranched, and free of the hold.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Planned {
    pub(crate) span: u16,
    pub(crate) row: u32,
    pub(crate) x0: u32,
    pub(crate) depth: f64,
    pub(crate) secant: f64,
    pub(crate) held: (f64, u8, Option<u8>),
    pub(crate) unbranched: (f64, u8, Option<u8>),
    pub(crate) free: (f64, u8, Option<u8>),
}

/// The footprint's level and band, as a triple.
fn rated(footprint: f64, levels: u8) -> (f64, u8, Option<u8>) {
    (footprint, level_of(footprint, levels), band_of(footprint, levels))
}

/// A footprint's distance in octaves from the nearest level boundary of its chain.
fn margin(footprint: f64, levels: u8) -> f64 {
    (1..levels).map(|m| (footprint.log2() - m as f64).abs()).fold(f64::INFINITY, f64::min)
}

impl Planned {
    /// The block's least margin over its three footprints, its robustness as a witness.
    fn margin(&self, levels: u8) -> f64 {
        margin(self.held.0, levels).min(margin(self.unbranched.0, levels)).min(margin(self.free.0, levels))
    }
}

/// The candidate's down term without its clamp branch, in doubles.
fn unbranched_down(m: &Mapping, camera: &Camera, x: f64, y: f64, floor: f64) -> f64 {
    let (u, v) = held_texel(m, camera, x, y, floor);
    let dw = dot(m.normal, camera.down) / (HZ * dot(m.normal, summed(m.point, scaled(camera.eye, -1.0))));
    let step = |gradient: [f64; 3], at: f64, coordinate: f64| {
        let d_over = (dot(gradient, camera.eye) + at) * dw + dot(gradient, camera.down) / HZ;
        ((d_over - coordinate * dw) / floor).abs()
    };
    step(m.u, m.u0, u).max(step(m.v, m.v0, v))
}

/// The grid depth whose share past it lies nearest the aim, and the share.
fn chosen_depth(depths: &[f64]) -> Option<(f64, f64)> {
    let n = depths.len() as f64;
    let steps = ((PLAN_DEPTHS.1 - PLAN_DEPTHS.0) / PLAN_STEP).round() as usize;
    (0..=steps)
        .map(|k| PLAN_DEPTHS.0 + k as f64 * PLAN_STEP)
        .map(|d| (d, depths.iter().filter(|&&depth| depth > d).count() as f64 / n))
        .filter(|&(_, share)| share >= PLAN_SHARES.0 && share <= PLAN_SHARES.1)
        .min_by(|a, b| (a.1 - PLAN_AIM).abs().total_cmp(&(b.1 - PLAN_AIM).abs()).then(a.0.total_cmp(&b.0)))
}

/// The nearest-rank quantile of sorted values.
fn quantile(sorted: &[f64], q: f64) -> f64 {
    let rank = ((sorted.len() as f64 * q).ceil() as usize).clamp(1, sorted.len());
    sorted[rank - 1]
}

/// The clamp's plan over a capture's blocks of one surface.
pub(crate) fn clamp_plan(map: &Map, textures: &Textures, lumels: &Lumels, camera: &Camera, owner: &Image, capture: &Capture, surface: u32) -> Result<Nuon, String> {
    let captures = std::slice::from_ref(capture);
    let surfaces = span_surfaces(owner, captures)?;
    let Owned::Mapped(m) = owned(map, textures, lumels, &BTreeMap::new(), camera, surface) else {
        return Err(format!("surface {surface} has no texture mapping"));
    };
    let found = blocks(&capture.image)?;
    let mut last: BTreeMap<u16, u32> = BTreeMap::new();
    for block in &found {
        let x0 = last.entry(block.span).or_insert(block.x0);
        *x0 = (*x0).max(block.x0);
    }
    let mine: Vec<&Block> = found.iter().filter(|b| surfaces.get(&b.span) == Some(&surface)).collect();
    let mut depths: Vec<f64> = mine.iter().map(|b| 1.0 / inverse_depth(&m, camera, b.x0 as f64 + 0.5, b.row as f64 + 0.5)).filter(|d| d.is_finite() && *d > 0.0).collect();
    if depths.is_empty() {
        return Err(format!("the capture shows no block of surface {surface}"));
    }
    depths.sort_by(f64::total_cmp);
    let (depth, share) = chosen_depth(&depths).ok_or_else(|| {
        format!("no depth from {} to {} m puts {} to {} of surface {surface}'s {} blocks past it", PLAN_DEPTHS.0, PLAN_DEPTHS.1, PLAN_SHARES.0, PLAN_SHARES.1, depths.len())
    })?;
    let iz_min = ((1u64 << DEPTH_BITS) as f64 / depth).round() as i64;
    let floor = depth_floor(iz_min);
    let mut planned = Vec::new();
    for block in &mine {
        let (x, y) = (block.x0 as f64 + 0.5, block.row as f64 + 0.5);
        if inverse_depth(&m, camera, x, y) >= floor {
            continue;
        }
        let length = if last.get(&block.span).is_some_and(|&x0| block.x0 < x0) { BLOCK } else { (block.end - block.x0) as f64 };
        let (Footprint::Value(held), Footprint::Value(free)) = (footprint(&m, camera, x, y, floor), footprint(&m, camera, x, y, 0.0)) else {
            continue;
        };
        let secant = block_secant(&m, camera, x, y, length, floor);
        let free_secant = block_secant(&m, camera, x, y, length, 0.0);
        planned.push(Planned {
            span: block.span,
            row: block.row,
            x0: block.x0,
            depth: 1.0 / inverse_depth(&m, camera, x, y),
            secant,
            held: rated(secant.max(held.down), m.levels),
            unbranched: rated(secant.max(unbranched_down(&m, camera, x, y, floor)), m.levels),
            free: rated(free_secant.max(free.down), m.levels),
        });
    }
    planned.sort_by(|a, b| a.depth.total_cmp(&b.depth));
    let mut witnesses: Vec<&Planned> = planned.iter().filter(|p| p.held.2.is_none() && p.unbranched.2.is_none() && p.free.2.is_none() && p.unbranched.1 != p.held.1).collect();
    witnesses.sort_by(|a, b| b.margin(m.levels).total_cmp(&a.margin(m.levels)).then(a.depth.total_cmp(&b.depth)));
    let named = planned.get(planned.len() / 2).ok_or_else(|| format!("no block of surface {surface} lies past {depth} m"))?;
    let (x, y) = (named.x0 as f64 + 0.5, named.row as f64 + 0.5);
    let (u_here, v_here) = held_texel(&m, camera, x, y, floor);
    let (u_below, v_below) = held_texel(&m, camera, x, y + 1.0, floor);
    let analytic = match footprint(&m, camera, x, y, floor) {
        Footprint::Value(d) => d.down,
        Footprint::Degenerate => f64::NAN,
    };
    let rating = |r: &(f64, u8, Option<u8>)| record(vec![("footprint", Nuon::Float(r.0)), ("level", Nuon::Int(r.1 as i64)), ("band", r.2.map(|b| Nuon::Int(b as i64)).unwrap_or(Nuon::Null))]);
    let block_nuon = |p: &Planned| {
        record(vec![
            ("span", Nuon::Int(p.span as i64)),
            ("row", Nuon::Int(p.row as i64)),
            ("x0", Nuon::Int(p.x0 as i64)),
            ("depth", Nuon::Float(p.depth)),
            ("margin", Nuon::Float(p.margin(m.levels))),
            ("secant", Nuon::Float(p.secant)),
            ("held", rating(&p.held)),
            ("unbranched", rating(&p.unbranched)),
            ("free", rating(&p.free)),
        ])
    };
    Ok(record(vec![
        ("surface", Nuon::Int(surface as i64)),
        ("blocks", count(depths.len() as u64)),
        ("depths", record(vec![("least", Nuon::Float(depths[0])), ("quarter", Nuon::Float(quantile(&depths, 0.25))), ("median", Nuon::Float(quantile(&depths, 0.5))), ("three_quarters", Nuon::Float(quantile(&depths, 0.75))), ("greatest", Nuon::Float(depths[depths.len() - 1]))])),
        ("depth", Nuon::Float(depth)),
        ("iz_min", Nuon::Int(iz_min)),
        ("share", Nuon::Float(share)),
        ("clamped", count(planned.len() as u64)),
        ("witnesses", count(witnesses.len() as u64)),
        ("strongest", Nuon::List(witnesses.iter().take(PLAN_WITNESSES).map(|p| block_nuon(p)).collect())),
        (
            "derivative",
            record(vec![
                ("block", block_nuon(named)),
                ("analytic", Nuon::Float(analytic)),
                ("difference", Nuon::Float((u_below - u_here).abs().max((v_below - v_here).abs()))),
            ]),
        ),
    ]))
}
