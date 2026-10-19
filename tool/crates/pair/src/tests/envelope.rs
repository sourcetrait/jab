use crate::*;

fn ratio(num: i128, den: i128) -> Ratio {
    Ratio::new(num, den, "a test").unwrap()
}

fn breaks(envelope: &Envelope) -> Vec<String> {
    envelope.breaks().iter().map(|b| b.text()).collect()
}

#[test]
fn the_least_of_three_lines_keeps_the_middle_one_where_it_binds() {
    let lines = [
        Line { c: 0, x: 0 },
        Line { c: 4, x: 1 },
        Line { c: 10, x: 2 },
    ];
    let envelope = Envelope::min(&lines).unwrap();
    assert_eq!(breaks(&envelope), ["4/1", "6/1"]);
    assert_eq!(envelope.at(ratio(5, 1)).unwrap(), -1);
    assert_eq!(envelope.at(ratio(7, 1)).unwrap(), -4);
    assert_eq!(envelope.at(ratio(4, 1)).unwrap(), 0);
    assert_eq!(envelope.at(ratio(9, 2)).unwrap(), -1);
    assert_eq!(envelope.after(ratio(4, 1)).unwrap(), Line { c: 4, x: 1 });
}

#[test]
fn a_line_no_drift_needs_is_dropped() {
    let lines = [
        Line { c: 0, x: 0 },
        Line { c: 6, x: 1 },
        Line { c: 10, x: 2 },
    ];
    assert_eq!(breaks(&Envelope::min(&lines).unwrap()), ["5/1"]);
}

#[test]
fn parallel_lines_keep_the_binding_one() {
    let lines = [Line { c: 9, x: 3 }, Line { c: 5, x: 3 }];
    assert_eq!(Envelope::min(&lines).unwrap().at(ratio(1, 1)).unwrap(), 2);
    assert_eq!(Envelope::max(&lines).unwrap().at(ratio(1, 1)).unwrap(), 6);
}

#[test]
fn the_greatest_of_lines_mirrors_the_least() {
    let lines = [
        Line { c: 0, x: 0 },
        Line { c: 4, x: 1 },
        Line { c: 10, x: 2 },
    ];
    let envelope = Envelope::max(&lines).unwrap();
    assert_eq!(breaks(&envelope), ["5/1"]);
    assert_eq!(envelope.at(ratio(1, 1)).unwrap(), 8);
    assert_eq!(envelope.at(ratio(6, 1)).unwrap(), 0);
    assert_eq!(envelope.at(ratio(1, 2)).unwrap(), 18);
    assert_eq!(envelope.after(ratio(4, 1)).unwrap(), Line { c: 10, x: 2 });
    assert_eq!(envelope.after(ratio(5, 1)).unwrap(), Line { c: 0, x: 0 });
}
