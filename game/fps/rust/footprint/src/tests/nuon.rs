use crate::*;

#[test]
fn floats_keep_a_fraction_and_drop_what_is_not_finite() {
    assert_eq!(Nuon::Float(1.0).to_string(), "1.0");
    assert_eq!(Nuon::Float(0.64).to_string(), "0.64");
    assert_eq!(Nuon::Float(1e-7).to_string(), "1e-7");
    assert_eq!(Nuon::Float(f64::NAN).to_string(), "null");
    assert_eq!(Nuon::Float(f64::INFINITY).to_string(), "null");
}

#[test]
fn strings_are_quoted_and_escaped() {
    assert_eq!(Nuon::Str("a \"b\"\\\n".to_string()).to_string(), "\"a \\\"b\\\"\\\\\\n\"");
}

#[test]
fn records_quote_the_keys_that_need_it() {
    let r = record(vec![("span", Nuon::Int(3)), ("a key", Nuon::Bool(true)), ("2x", Nuon::Null)]);
    assert_eq!(r.to_string(), "{span: 3, \"a key\": true, \"2x\": null}");
}

#[test]
fn lists_hold_their_items() {
    assert_eq!(Nuon::List(vec![count(1), Nuon::List(vec![]), Nuon::Str("x".to_string())]).to_string(), "[1, [], \"x\"]");
}
