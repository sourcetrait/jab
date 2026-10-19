use crate::*;

/// How far a centered stamp may lie from the first pair's, in ticks.
pub(crate) const LIMIT: i128 = 1 << 40;

/// The bound every part of a drift range's ends stays under.
pub(crate) const PART_LIMIT: i64 = 1 << 31;

/// The ticks a logged microsecond spans, its far end admitted.
pub(crate) const QUANTUM: i128 = 10;

/// The wide range the free reading solves over, a half to two.
pub(crate) const FREE: [(i64, i64); 2] = [(1, 2), (2, 1)];

const CENTER: &str = "the centered stamps";
const DRIFT: &str = "the drift range";
const SWEEP: &str = "a range's candidates";
const MARGIN: &str = "a margin";
const ZERO: &str = "a margin's zero";
const OFFSET: &str = "the offset's envelope";
const PLACE: &str = "an upload's place";
const BIND: &str = "the binding pairs";

/// A present's paired upload: the host's logged microsecond and the call's ticks.
#[derive(Clone, Copy, Debug)]
pub(crate) struct Pair {
    pub(crate) h_us: i64,
    pub(crate) l: i64,
    pub(crate) u: i64,
}

/// The pairs in ticks from the first pair's, each value held to the limit.
pub(crate) struct Centered {
    pub(crate) host: i128,
    pub(crate) guest: i128,
    pub(crate) lo: Vec<i128>,
    pub(crate) hi: Vec<i128>,
    pub(crate) l: Vec<i128>,
    pub(crate) u: Vec<i128>,
}

/// One pairing's bracket over a declared drift range.
pub(crate) struct Bracket {
    pub(crate) host: i128,
    pub(crate) guest: i128,
    pub(crate) range: [Ratio; 2],
    pub(crate) best: Best,
    pub(crate) region: Option<Region>,
    pub(crate) free: Option<[Ratio; 2]>,
    pub(crate) ceiling_binding: Vec<usize>,
    pub(crate) floor_binding: Vec<usize>,
    pub(crate) places: Vec<[Ratio; 2]>,
}

/// The margin's best drift, the margin there, and the offset's bounds there.
pub(crate) struct Best {
    pub(crate) b: Ratio,
    pub(crate) margin: Ratio,
    pub(crate) floor: Ratio,
    pub(crate) ceiling: Ratio,
}

/// The feasible drifts, and the offset's envelope over all of them.
pub(crate) struct Region {
    pub(crate) b: [Ratio; 2],
    pub(crate) offset: [Ratio; 2],
}

/// A range's candidate drifts, both envelopes there times each denominator.
struct Sweep {
    cands: Vec<Ratio>,
    ceiling: Vec<i128>,
    floor: Vec<i128>,
}

/// The pairs centered on the first, refused past the limit.
pub(crate) fn center_pairs(pairs: &[Pair], quantum: i128) -> PairResult<Centered> {
    let first = pairs
        .first()
        .ok_or_else(|| PairError::Model("no pairs to bracket".to_owned()))?;
    let host = mul(i128::from(first.h_us), 10, CENTER)?;
    let guest = i128::from(first.l);
    let mut centered = Centered {
        host,
        guest,
        lo: Vec::with_capacity(pairs.len()),
        hi: Vec::with_capacity(pairs.len()),
        l: Vec::with_capacity(pairs.len()),
        u: Vec::with_capacity(pairs.len()),
    };
    for (index, pair) in pairs.iter().enumerate() {
        if pair.l > pair.u {
            return Err(PairError::Unresolvable {
                step: "a call's bounds",
                detail: format!(
                    "pair {index}'s call starts at tick {} past its end at {}",
                    pair.l, pair.u
                ),
            });
        }
        let lo = sub(mul(i128::from(pair.h_us), 10, CENTER)?, host, CENTER)?;
        let hi = add(lo, quantum, CENTER)?;
        let l = sub(i128::from(pair.l), guest, CENTER)?;
        let u = sub(i128::from(pair.u), guest, CENTER)?;
        for (clock, value) in [("host", lo), ("host", hi), ("guest", l), ("guest", u)] {
            if !(-LIMIT..=LIMIT).contains(&value) {
                return Err(PairError::Unresolvable {
                    step: CENTER,
                    detail: format!(
                        "pair {index}'s {clock} stamp lies {value} ticks from the first pair's, past 2^40"
                    ),
                });
            }
        }
        centered.lo.push(lo);
        centered.hi.push(hi);
        centered.l.push(l);
        centered.u.push(u);
    }
    Ok(centered)
}

/// A drift range's ends as rationals, every part held under its bound.
pub(crate) fn drift_range(ends: [(i64, i64); 2]) -> PairResult<[Ratio; 2]> {
    let mut range = [Ratio::whole(1); 2];
    for (slot, name) in ["low", "high"].into_iter().enumerate() {
        let (num, den) = ends[slot];
        if !(1..PART_LIMIT).contains(&num) || !(1..PART_LIMIT).contains(&den) {
            return Err(PairError::Unresolvable {
                step: DRIFT,
                detail: format!("its {name} end {num}/{den} has a part outside 1 to 2^31 - 1"),
            });
        }
        range[slot] = Ratio::new(i128::from(num), i128::from(den), DRIFT)?;
    }
    if range[0].order(range[1], DRIFT)? == Ordering::Greater {
        return Err(PairError::Model(format!(
            "an empty drift range, its low end {} past its high end {}",
            range[0].text(),
            range[1].text()
        )));
    }
    Ok(range)
}

/// A pairing's bracket over the declared drift range.
pub(crate) fn bracket(pairs: &[Pair], drift: [(i64, i64); 2]) -> PairResult<Bracket> {
    bracket_with(pairs, drift, QUANTUM)
}

/// The bracket, with the ticks a logged microsecond spans given.
pub(crate) fn bracket_with(
    pairs: &[Pair],
    drift: [(i64, i64); 2],
    quantum: i128,
) -> PairResult<Bracket> {
    let range = drift_range(drift)?;
    let centered = center_pairs(pairs, quantum)?;
    let count = centered.lo.len();
    let ceiling = Envelope::min(
        &(0..count)
            .map(|i| Line {
                c: centered.hi[i],
                x: centered.l[i],
            })
            .collect::<Vec<Line>>(),
    )?;
    let floor = Envelope::max(
        &(0..count)
            .map(|i| Line {
                c: centered.lo[i],
                x: centered.u[i],
            })
            .collect::<Vec<Line>>(),
    )?;
    let sweep = sweep_range(&ceiling, &floor, range)?;
    let top = best_index(&sweep)?;
    let b = sweep.cands[top];
    let best = Best {
        b,
        margin: margin_at(&sweep, top)?,
        floor: Ratio::new(sweep.floor[top], b.den, MARGIN)?,
        ceiling: Ratio::new(sweep.ceiling[top], b.den, MARGIN)?,
    };
    let (ceiling_binding, floor_binding) =
        binding_of(&centered, b, sweep.ceiling[top], sweep.floor[top])?;
    let (region, places) = match feasible_span(&ceiling, &floor, &sweep, top)? {
        Some(span) => {
            let mut points = vec![span[0]];
            points.extend(inside(&sweep.cands, span)?);
            if span[1].order(span[0], SWEEP)? == Ordering::Greater {
                points.push(span[1]);
            }
            (
                Some(region_of(&ceiling, &floor, span, &points)?),
                places_of(&centered, &ceiling, &floor, &points)?,
            )
        }
        None => (None, Vec::new()),
    };
    let wide = sweep_range(&ceiling, &floor, drift_range(FREE)?)?;
    let free = feasible_span(&ceiling, &floor, &wide, best_index(&wide)?)?;
    Ok(Bracket {
        host: centered.host,
        guest: centered.guest,
        range,
        best,
        region,
        free,
        ceiling_binding,
        floor_binding,
        places,
    })
}

/// A range's ends and every break of either envelope inside it, in order.
fn sweep_range(ceiling: &Envelope, floor: &Envelope, range: [Ratio; 2]) -> PairResult<Sweep> {
    let mut cands = vec![range[0]];
    cands.extend(merged(
        &inside(ceiling.breaks(), range)?,
        &inside(floor.breaks(), range)?,
    )?);
    if range[1].order(range[0], SWEEP)? == Ordering::Greater {
        cands.push(range[1]);
    }
    let ceiling_at = cands
        .iter()
        .map(|b| ceiling.at(*b))
        .collect::<PairResult<Vec<i128>>>()?;
    let floor_at = cands
        .iter()
        .map(|b| floor.at(*b))
        .collect::<PairResult<Vec<i128>>>()?;
    Ok(Sweep {
        cands,
        ceiling: ceiling_at,
        floor: floor_at,
    })
}

/// The values strictly inside a range, in their order.
fn inside(values: &[Ratio], range: [Ratio; 2]) -> PairResult<Vec<Ratio>> {
    let mut kept = Vec::new();
    for value in values {
        if value.order(range[0], SWEEP)? == Ordering::Greater
            && value.order(range[1], SWEEP)? == Ordering::Less
        {
            kept.push(*value);
        }
    }
    Ok(kept)
}

/// Two increasing lists as one, a value both hold kept once.
fn merged(a: &[Ratio], b: &[Ratio]) -> PairResult<Vec<Ratio>> {
    let mut out: Vec<Ratio> = Vec::with_capacity(a.len() + b.len());
    let (mut i, mut j) = (0, 0);
    while i < a.len() || j < b.len() {
        let from_a = j == b.len() || (i < a.len() && a[i].order(b[j], SWEEP)? != Ordering::Greater);
        let next = if from_a { a[i] } else { b[j] };
        if from_a {
            i += 1;
        } else {
            j += 1;
        }
        let repeated = match out.last() {
            Some(last) => last.order(next, SWEEP)? == Ordering::Equal,
            None => false,
        };
        if !repeated {
            out.push(next);
        }
    }
    Ok(out)
}

/// The margin at a candidate: the offset's ceiling less its floor.
fn margin_at(sweep: &Sweep, k: usize) -> PairResult<Ratio> {
    Ratio::new(
        sub(sweep.ceiling[k], sweep.floor[k], MARGIN)?,
        sweep.cands[k].den,
        MARGIN,
    )
}

/// The first candidate where the margin is greatest.
fn best_index(sweep: &Sweep) -> PairResult<usize> {
    let mut best = 0;
    for k in 1..sweep.cands.len() {
        if margin_at(sweep, k)?.order(margin_at(sweep, best)?, MARGIN)? == Ordering::Greater {
            best = k;
        }
    }
    Ok(best)
}

/// The drifts around the best where the margin is not negative; none if it is.
fn feasible_span(
    ceiling: &Envelope,
    floor: &Envelope,
    sweep: &Sweep,
    top: usize,
) -> PairResult<Option<[Ratio; 2]>> {
    if margin_at(sweep, top)?.num < 0 {
        return Ok(None);
    }
    let last = sweep.cands.len() - 1;
    let mut left = top;
    while left > 0 && margin_at(sweep, left - 1)?.num >= 0 {
        left -= 1;
    }
    let mut right = top;
    while right < last && margin_at(sweep, right + 1)?.num >= 0 {
        right += 1;
    }
    let low = if left == 0 {
        sweep.cands[0]
    } else {
        zero_after(ceiling, floor, sweep.cands[left - 1])?
    };
    let high = if right == last {
        sweep.cands[last]
    } else {
        zero_after(ceiling, floor, sweep.cands[right])?
    };
    Ok(Some([low, high]))
}

/// Where the margin, linear from a candidate to the next, reaches zero.
fn zero_after(ceiling: &Envelope, floor: &Envelope, after: Ratio) -> PairResult<Ratio> {
    let upper = ceiling.after(after)?;
    let lower = floor.after(after)?;
    let slope = sub(upper.x, lower.x, ZERO)?;
    if slope == 0 {
        return Err(PairError::Internal(
            "a margin changing sign where it is flat".to_owned(),
        ));
    }
    Ratio::new(sub(upper.c, lower.c, ZERO)?, slope, ZERO)
}

/// The feasible span with the offset's least floor and greatest ceiling over it.
fn region_of(
    ceiling: &Envelope,
    floor: &Envelope,
    span: [Ratio; 2],
    points: &[Ratio],
) -> PairResult<Region> {
    let mut low = Ratio::new(floor.at(points[0])?, points[0].den, OFFSET)?;
    let mut high = Ratio::new(ceiling.at(points[0])?, points[0].den, OFFSET)?;
    for b in &points[1..] {
        let down = Ratio::new(floor.at(*b)?, b.den, OFFSET)?;
        if down.order(low, OFFSET)? == Ordering::Less {
            low = down;
        }
        let up = Ratio::new(ceiling.at(*b)?, b.den, OFFSET)?;
        if up.order(high, OFFSET)? == Ordering::Greater {
            high = up;
        }
    }
    Ok(Region {
        b: span,
        offset: [low, high],
    })
}

/// Each upload's earliest and latest place in its call over the feasible set.
fn places_of(
    centered: &Centered,
    ceiling: &Envelope,
    floor: &Envelope,
    points: &[Ratio],
) -> PairResult<Vec<[Ratio; 2]>> {
    let ceiling_at = points
        .iter()
        .map(|b| ceiling.at(*b))
        .collect::<PairResult<Vec<i128>>>()?;
    let floor_at = points
        .iter()
        .map(|b| floor.at(*b))
        .collect::<PairResult<Vec<i128>>>()?;
    let mut places = Vec::with_capacity(centered.lo.len());
    for (i, (&start, &end)) in centered.l.iter().zip(&centered.u).enumerate() {
        let earliest = |k: usize| -> PairResult<Ratio> {
            Ratio::new(
                sub(
                    mul(centered.lo[i], points[k].den, PLACE)?,
                    ceiling_at[k],
                    PLACE,
                )?,
                points[k].num,
                PLACE,
            )
        };
        let latest = |k: usize| -> PairResult<Ratio> {
            Ratio::new(
                sub(
                    mul(centered.hi[i], points[k].den, PLACE)?,
                    floor_at[k],
                    PLACE,
                )?,
                points[k].num,
                PLACE,
            )
        };
        let first = earliest(extreme(points.len(), &earliest, Ordering::Less)?)?;
        let last = latest(extreme(points.len(), &latest, Ordering::Greater)?)?;
        let first = if first.order(Ratio::whole(start), PLACE)? == Ordering::Less {
            Ratio::whole(start)
        } else {
            first
        };
        let last = if last.order(Ratio::whole(end), PLACE)? == Ordering::Greater {
            Ratio::whole(end)
        } else {
            last
        };
        if first.order(last, PLACE)? == Ordering::Greater {
            return Err(PairError::Internal(format!(
                "pair {i}'s upload has no place in its call in a feasible bracket"
            )));
        }
        places.push([first.less(start, PLACE)?, last.less(start, PLACE)?]);
    }
    Ok(places)
}

/// Where a sequence that falls then rises is least, or rises then falls is greatest.
fn extreme(
    len: usize,
    value: &dyn Fn(usize) -> PairResult<Ratio>,
    want: Ordering,
) -> PairResult<usize> {
    let (mut low, mut high) = (0, len - 1);
    while low < high {
        let mid = (low + high) / 2;
        if value(mid + 1)?.order(value(mid)?, PLACE)? == want {
            low = mid + 1;
        } else {
            high = mid;
        }
    }
    Ok(low)
}

/// The pairs whose lines hold the offset's ceiling and floor at b.
fn binding_of(
    centered: &Centered,
    b: Ratio,
    ceiling_at: i128,
    floor_at: i128,
) -> PairResult<(Vec<usize>, Vec<usize>)> {
    let (mut ceiling, mut floor) = (Vec::new(), Vec::new());
    for i in 0..centered.lo.len() {
        let upper = sub(
            mul(centered.hi[i], b.den, BIND)?,
            mul(b.num, centered.l[i], BIND)?,
            BIND,
        )?;
        if upper == ceiling_at {
            ceiling.push(i);
        }
        let lower = sub(
            mul(centered.lo[i], b.den, BIND)?,
            mul(b.num, centered.u[i], BIND)?,
            BIND,
        )?;
        if lower == floor_at {
            floor.push(i);
        }
    }
    Ok((ceiling, floor))
}
