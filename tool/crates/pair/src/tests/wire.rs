use crate::*;

#[test]
fn a_request_answers_each_case_by_name_with_its_status() {
    let text = r#"{"drift": {"lo": [19999, 20000], "hi": [20001, 20000]}, "cases": [
        {"name": "binding", "pairs": [{"h_us": 0, "l": 0, "u": 0}, {"h_us": 201, "l": 2000, "u": 2000}]},
        {"name": "backwards", "pairs": [{"h_us": 0, "l": 5, "u": 4}]}
    ]}"#;
    let answer: serde_json::Value = serde_json::from_str(&respond(text).unwrap()).unwrap();
    assert_eq!(answer["cases"][0]["name"], "binding");
    assert_eq!(answer["cases"][0]["status"], "feasible");
    assert_eq!(answer["cases"][0]["best"]["margin"], "1/10");
    assert_eq!(answer["cases"][0]["places"].as_array().unwrap().len(), 2);
    assert_eq!(answer["cases"][1]["status"], "unresolved");
    assert!(
        answer["cases"][1]["reason"]
            .as_str()
            .unwrap()
            .contains("a call's bounds")
    );
}

#[test]
fn a_request_with_a_field_it_does_not_know_is_refused() {
    let text = r#"{"drift": {"lo": [1, 1], "hi": [1, 1]}, "cases": [], "extra": 1}"#;
    assert!(matches!(respond(text), Err(PairError::Request(_))));
}
