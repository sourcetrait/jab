use crate::*;

/// Fifty parts per million either way, the model's declared range.
const DRIFT: [(i64, i64); 2] = [(19_999, 20_000), (20_001, 20_000)];

/// The host's clock at the guest's tick zero, in ticks.
const ORIGIN: i128 = 17_600_000_000_000_000;

/// The saved capture's drift, 3.2 parts per million.
const CAPTURED: (i128, i128) = (10_000_032, 10_000_000);

fn ratio(num: i128, den: i128) -> Ratio {
    Ratio::new(num, den, "a test").unwrap()
}

/// Each upload at guest tick t logged as the host microsecond holding a + b t.
fn logged(a: i128, b: (i128, i128), calls: &[(i64, i64, i64)]) -> Vec<Pair> {
    calls
        .iter()
        .map(|&(l, u, t)| {
            let host = a * b.1 + i128::from(t) * b.0;
            Pair {
                h_us: host.div_euclid(b.1 * 10) as i64,
                l,
                u,
            }
        })
        .collect()
}

/// The saved capture's shape: the load's two presents, then frames a period
/// apart, each call about 1.5 ms with its upload 0.3 ms in, a 14 ms stall.
fn capture(frames: usize, stall: Option<usize>) -> Vec<(i64, i64, i64)> {
    let mut calls = vec![
        (1_000_000, 1_010_000, 1_003_000),
        (15_000_000, 15_012_000, 15_004_000),
    ];
    for k in 0..frames {
        let start = 16_000_000 + k as i64 * 166_667;
        let length = if stall == Some(k) {
            140_440
        } else {
            14_360 + (k as i64 % 7) * 400
        };
        calls.push((start, start + length, start + 3_000));
    }
    calls
}

/// Calls of 100 ticks a period apart, each upload at the middle.
fn narrow(frames: usize) -> Vec<(i64, i64, i64)> {
    (0..frames as i64)
        .map(|k| {
            let start = 16_000_000 + k * 166_667;
            (start, start + 100, start + 50)
        })
        .collect()
}

fn feasible(pairs: &[Pair], drift: [(i64, i64); 2]) -> bool {
    bracket(pairs, drift).unwrap().region.is_some()
}

#[test]
fn astras_counterexample_is_admitted_and_the_old_end_refuses_it() {
    let pairs = [
        Pair {
            h_us: 0,
            l: 0,
            u: 0,
        },
        Pair {
            h_us: 201,
            l: 2000,
            u: 2000,
        },
    ];
    let solved = bracket(&pairs, DRIFT).unwrap();
    assert_eq!(solved.best.b.text(), "20001/20000");
    assert_eq!(solved.best.margin.text(), "1/10");
    assert_eq!(solved.region.expect("feasible").b[1].text(), "20001/20000");
    assert!(bracket_with(&pairs, DRIFT, 9).unwrap().region.is_none());
}

#[test]
fn an_instant_a_tenth_of_a_tick_below_the_next_microsecond_is_admitted() {
    let fixed = [(20_001, 20_000), (20_001, 20_000)];
    let pairs = [
        Pair {
            h_us: 0,
            l: 0,
            u: 0,
        },
        Pair {
            h_us: 0,
            l: 0,
            u: 0,
        },
        Pair {
            h_us: 201,
            l: 2000,
            u: 2000,
        },
    ];
    let region = bracket(&pairs, fixed).unwrap().region.expect("feasible");
    assert_eq!(region.offset[0].text(), "99/10");
    assert_eq!(region.offset[1].text(), "10/1");
    assert!(bracket_with(&pairs, fixed, 9).unwrap().region.is_none());
}

#[test]
fn an_upload_a_quantum_past_its_calls_end_is_refused_and_one_inside_held() {
    let fixed = [(1, 1), (1, 1)];
    let pin = [
        Pair {
            h_us: 0,
            l: 0,
            u: 0,
        },
        Pair {
            h_us: 1,
            l: 5,
            u: 5,
        },
    ];
    let with = |h_us: i64| {
        [
            pin[0],
            pin[1],
            Pair {
                h_us,
                l: 100,
                u: 200,
            },
        ]
    };
    assert!(feasible(&with(21), fixed));
    assert!(!feasible(&with(22), fixed));
    assert!(feasible(&with(10), fixed));
    assert!(!feasible(&with(9), fixed));
}

#[test]
fn logged_pairs_bound_the_drift_at_each_end_of_its_range() {
    let calls = narrow(800);
    let high = bracket(&logged(ORIGIN, (20_001, 20_000), &calls), DRIFT)
        .unwrap()
        .region
        .expect("feasible");
    assert_eq!(high.b[1].text(), "20001/20000");
    assert_eq!(
        high.b[0].order(ratio(20_001, 20_000), "a test").unwrap(),
        Ordering::Less
    );
    let low = bracket(&logged(ORIGIN, (19_999, 20_000), &calls), DRIFT)
        .unwrap()
        .region
        .expect("feasible");
    assert_eq!(low.b[0].text(), "19999/20000");
    assert_eq!(
        low.b[1].order(ratio(19_999, 20_000), "a test").unwrap(),
        Ordering::Greater
    );
}

#[test]
fn drift_past_the_bound_is_refused_and_found_over_the_wide_range() {
    let solved = bracket(&logged(ORIGIN, (1_000_060, 1_000_000), &narrow(800)), DRIFT).unwrap();
    assert!(solved.region.is_none());
    let free = solved.free.expect("feasible over the wide range");
    assert!(free[0].ppm() < 60.0 && free[1].ppm() > 60.0, "{free:?}");
}

#[test]
fn the_saved_captures_shape_is_feasible_with_its_stall_placed_early() {
    let solved = bracket(&logged(ORIGIN, CAPTURED, &capture(813, Some(158))), DRIFT).unwrap();
    let region = solved.region.expect("feasible");
    let truth = ratio(CAPTURED.0, CAPTURED.1);
    assert_ne!(
        region.b[0].order(truth, "a test").unwrap(),
        Ordering::Greater
    );
    assert_ne!(region.b[1].order(truth, "a test").unwrap(), Ordering::Less);
    assert_eq!(solved.places.len(), 815);
    let stall = solved.places[160];
    assert!(
        stall[0].approx() <= 3_000.0 && stall[1].approx() >= 3_000.0,
        "{stall:?}"
    );
    assert!(stall[1].approx() < 20_000.0, "{stall:?}");
}

#[test]
fn a_synthetic_stream_of_8192_pairs_is_solved_exactly() {
    let solved = bracket(&logged(ORIGIN, CAPTURED, &capture(8_190, None)), DRIFT).unwrap();
    assert!(solved.region.is_some());
    assert_eq!(solved.places.len(), 8_192);
}

#[test]
fn an_upload_in_the_await_between_two_attempts_is_refused_and_named() {
    let mut calls = capture(300, None);
    calls[100].2 = calls[100].0 - 50_000;
    let solved = bracket(&logged(ORIGIN, CAPTURED, &calls), DRIFT).unwrap();
    assert!(solved.region.is_none());
    assert_eq!(solved.ceiling_binding, [100]);
}

#[test]
fn a_slip_mid_window_is_refused() {
    let mut pairs = logged(ORIGIN, CAPTURED, &narrow(400));
    let next: Vec<i64> = pairs.iter().map(|pair| pair.h_us).collect();
    for (k, pair) in pairs.iter_mut().enumerate().take(399).skip(200) {
        pair.h_us = next[k + 1];
    }
    pairs.truncate(399);
    assert!(!feasible(&pairs, DRIFT));
}

#[test]
fn a_stream_shifted_by_one_is_refused_across_the_loads_gap_and_open_without_it() {
    let shifted = |calls: &[(i64, i64, i64)]| -> Vec<Pair> {
        let pairs = logged(ORIGIN, CAPTURED, calls);
        (0..pairs.len() - 1)
            .map(|k| Pair {
                h_us: pairs[k + 1].h_us,
                ..pairs[k]
            })
            .collect()
    };
    assert!(!feasible(&shifted(&capture(300, None)), DRIFT));
    assert!(feasible(&shifted(&capture(300, None)[2..]), DRIFT));
}

#[test]
fn a_pause_inside_a_run_is_infeasible_at_every_drift() {
    let mut pairs = logged(ORIGIN, CAPTURED, &narrow(400));
    for pair in &mut pairs[200..] {
        pair.h_us += 500_000;
    }
    let solved = bracket(&pairs, DRIFT).unwrap();
    assert!(solved.region.is_none());
    assert!(solved.free.is_none());
}

#[test]
fn an_empty_drift_range_and_no_pairs_are_model_errors() {
    let pairs = [Pair {
        h_us: 0,
        l: 0,
        u: 0,
    }];
    assert!(matches!(
        bracket(&pairs, [(20_001, 20_000), (19_999, 20_000)]),
        Err(PairError::Model(_))
    ));
    assert!(matches!(bracket(&[], DRIFT), Err(PairError::Model(_))));
}

#[test]
fn the_largest_admitted_values_pass_and_one_past_them_refuses_by_name() {
    let reach: i64 = 1 << 40;
    let h_reach: i64 = (reach - 10) / 10;
    let edge = [
        (2_147_483_646, 2_147_483_647),
        (2_147_483_647, 2_147_483_646),
    ];
    let pairs = [
        Pair {
            h_us: 0,
            l: 0,
            u: 0,
        },
        Pair {
            h_us: h_reach,
            l: h_reach * 10,
            u: h_reach * 10,
        },
        Pair {
            h_us: -h_reach,
            l: -h_reach * 10,
            u: -h_reach * 10,
        },
        Pair {
            h_us: 1,
            l: 10,
            u: reach,
        },
        Pair {
            h_us: -1,
            l: -reach,
            u: -10,
        },
    ];
    assert!(bracket(&pairs, edge).unwrap().region.is_some());
    let refused = |pairs: &[Pair], drift| match bracket(pairs, drift) {
        Err(PairError::Unresolvable { step, .. }) => step,
        other => panic!("{:?}", other.map(|solved| solved.best.b.text())),
    };
    assert_eq!(
        refused(
            &[
                pairs[0],
                Pair {
                    h_us: h_reach + 1,
                    ..pairs[1]
                }
            ],
            DRIFT
        ),
        "the centered stamps"
    );
    assert_eq!(
        refused(
            &[
                pairs[0],
                Pair {
                    u: reach + 1,
                    ..pairs[3]
                }
            ],
            DRIFT
        ),
        "the centered stamps"
    );
    assert_eq!(
        refused(&pairs, [(2_147_483_648, 2_147_483_647), edge[1]]),
        "the drift range"
    );
    assert_eq!(
        refused(
            &[Pair {
                h_us: 0,
                l: 5,
                u: 4
            }],
            DRIFT
        ),
        "a call's bounds"
    );
}
