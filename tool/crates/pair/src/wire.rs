use crate::*;

/// The binding pairs an answer lists at most, each side.
const BINDING_SHOWN: usize = 16;

/// A request: the declared drift range and the pairings to bracket.
#[derive(serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct Request {
    pub(crate) drift: DriftWire,
    pub(crate) cases: Vec<CaseWire>,
}

/// The declared drift range's ends, each a numerator and a denominator.
#[derive(serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct DriftWire {
    pub(crate) lo: [i64; 2],
    pub(crate) hi: [i64; 2],
}

/// One pairing to bracket, by name.
#[derive(serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct CaseWire {
    pub(crate) name: String,
    pub(crate) pairs: Vec<PairWire>,
}

/// A pair as a request gives it.
#[derive(serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct PairWire {
    pub(crate) h_us: i64,
    pub(crate) l: i64,
    pub(crate) u: i64,
}

/// The answer to a request, a case each.
#[derive(serde::Serialize)]
pub(crate) struct Response {
    pub(crate) cases: Vec<Answer>,
}

/// One case's bracket, or why it is unresolved.
#[derive(serde::Serialize)]
pub(crate) struct Answer {
    pub(crate) name: String,
    pub(crate) status: &'static str,
    pub(crate) reason: Option<String>,
    pub(crate) pairs: usize,
    pub(crate) drift: Option<[String; 2]>,
    pub(crate) center: Option<CenterWire>,
    pub(crate) best: Option<BestWire>,
    pub(crate) feasible: Option<RegionWire>,
    pub(crate) free: Option<SpanWire>,
    pub(crate) binding: Option<BindingWire>,
    pub(crate) places: Vec<PlaceWire>,
}

/// The ticks every value is centered on.
#[derive(serde::Serialize)]
pub(crate) struct CenterWire {
    pub(crate) host_tick: String,
    pub(crate) guest_tick: String,
}

/// The margin's best drift and the offset there.
#[derive(serde::Serialize)]
pub(crate) struct BestWire {
    pub(crate) b: String,
    pub(crate) b_ppm: f64,
    pub(crate) margin: String,
    pub(crate) margin_ticks: f64,
    pub(crate) offset_lo_ticks: f64,
    pub(crate) offset_hi_ticks: f64,
}

/// The feasible drifts and the offset's envelope over them.
#[derive(serde::Serialize)]
pub(crate) struct RegionWire {
    pub(crate) b_lo: String,
    pub(crate) b_hi: String,
    pub(crate) b_lo_ppm: f64,
    pub(crate) b_hi_ppm: f64,
    pub(crate) offset_lo_ticks: f64,
    pub(crate) offset_hi_ticks: f64,
}

/// The feasible drifts over the wide range, if any.
#[derive(serde::Serialize)]
pub(crate) struct SpanWire {
    pub(crate) feasible: bool,
    pub(crate) b_lo_ppm: Option<f64>,
    pub(crate) b_hi_ppm: Option<f64>,
}

/// The pairs holding the offset's ceiling and floor at the best drift.
#[derive(serde::Serialize)]
pub(crate) struct BindingWire {
    pub(crate) ceiling: Vec<usize>,
    pub(crate) ceiling_count: usize,
    pub(crate) floor: Vec<usize>,
    pub(crate) floor_count: usize,
}

/// An upload's earliest and latest place, ticks from its call's start.
#[derive(serde::Serialize)]
pub(crate) struct PlaceWire {
    pub(crate) first_ticks: f64,
    pub(crate) last_ticks: f64,
}

/// The text answering a request, every case bracketed.
pub(crate) fn respond(text: &str) -> PairResult<String> {
    let request: Request =
        serde_json::from_str(text).map_err(|error| PairError::Request(error.to_string()))?;
    let drift = [
        (request.drift.lo[0], request.drift.lo[1]),
        (request.drift.hi[0], request.drift.hi[1]),
    ];
    let cases = request
        .cases
        .iter()
        .map(|case| answer_case(case, drift))
        .collect::<PairResult<Vec<Answer>>>()?;
    serde_json::to_string(&Response { cases })
        .map_err(|error| PairError::Request(error.to_string()))
}

/// One case's answer; a broken invariant fails the whole request.
fn answer_case(case: &CaseWire, drift: [(i64, i64); 2]) -> PairResult<Answer> {
    let pairs: Vec<Pair> = case
        .pairs
        .iter()
        .map(|pair| Pair {
            h_us: pair.h_us,
            l: pair.l,
            u: pair.u,
        })
        .collect();
    let mut out = Answer {
        name: case.name.clone(),
        status: "unresolved",
        reason: None,
        pairs: pairs.len(),
        drift: None,
        center: None,
        best: None,
        feasible: None,
        free: None,
        binding: None,
        places: Vec::new(),
    };
    let solved = match bracket(&pairs, drift) {
        Ok(solved) => solved,
        Err(error @ (PairError::Unresolvable { .. } | PairError::Model(_))) => {
            out.reason = Some(error.to_string());
            return Ok(out);
        }
        Err(error) => return Err(error),
    };
    out.status = if solved.region.is_some() {
        "feasible"
    } else {
        "infeasible"
    };
    out.drift = Some([solved.range[0].text(), solved.range[1].text()]);
    out.center = Some(CenterWire {
        host_tick: solved.host.to_string(),
        guest_tick: solved.guest.to_string(),
    });
    out.best = Some(BestWire {
        b: solved.best.b.text(),
        b_ppm: solved.best.b.ppm(),
        margin: solved.best.margin.text(),
        margin_ticks: solved.best.margin.approx(),
        offset_lo_ticks: solved.best.floor.approx(),
        offset_hi_ticks: solved.best.ceiling.approx(),
    });
    out.feasible = solved.region.as_ref().map(|region| RegionWire {
        b_lo: region.b[0].text(),
        b_hi: region.b[1].text(),
        b_lo_ppm: region.b[0].ppm(),
        b_hi_ppm: region.b[1].ppm(),
        offset_lo_ticks: region.offset[0].approx(),
        offset_hi_ticks: region.offset[1].approx(),
    });
    out.free = Some(SpanWire {
        feasible: solved.free.is_some(),
        b_lo_ppm: solved.free.map(|span| span[0].ppm()),
        b_hi_ppm: solved.free.map(|span| span[1].ppm()),
    });
    out.binding = Some(BindingWire {
        ceiling: solved
            .ceiling_binding
            .iter()
            .take(BINDING_SHOWN)
            .copied()
            .collect(),
        ceiling_count: solved.ceiling_binding.len(),
        floor: solved
            .floor_binding
            .iter()
            .take(BINDING_SHOWN)
            .copied()
            .collect(),
        floor_count: solved.floor_binding.len(),
    });
    out.places = solved
        .places
        .iter()
        .map(|place| PlaceWire {
            first_ticks: place[0].approx(),
            last_ticks: place[1].approx(),
        })
        .collect();
    Ok(out)
}
