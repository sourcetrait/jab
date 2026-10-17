use crate::*;

#[test]
fn an_ordinary_case_takes_its_value() {
    assert_eq!(row_derivative(10 << 16, 1 << 20, 1 << 16, 2 << 16), Some(110_592));
}

#[test]
fn both_products_past_64_bits_are_taken_when_their_shifts_fit() {
    assert_eq!(row_derivative(3 << 40, 5 << 30, 1 << 50, 1 << 20), Some(49 << 48));
}

#[test]
fn a_product_past_64_bits_once_shifted_saturates() {
    assert_eq!(row_derivative(1 << 60, 1 << 40, 0, 1 << 16), None);
}

#[test]
fn the_second_product_past_64_bits_once_shifted_saturates() {
    assert_eq!(row_derivative(0, 0, 1 << 62, 1 << 20), None);
}

#[test]
fn an_overflowing_subtraction_saturates() {
    assert_eq!(row_derivative(1 << 26, 1 << 26, i64::MIN, 1 << 16), None);
}

#[test]
fn the_most_negative_value_saturates() {
    assert_eq!(row_derivative(0, 0, -(1 << 47), 1 << 32), None);
}

#[test]
fn a_negative_derivative_reads_as_its_absolute() {
    assert_eq!(row_derivative(1 << 20, 1 << 26, 0, 1 << 16), Some(1 << 20));
}

#[test]
fn the_clamped_mapping_drops_the_izb_term() {
    assert_eq!(row_derivative(1 << 40, 0, 5 << 16, 1 << 30), Some(5 << 30));
}

#[test]
fn a_negative_product_floors_as_an_arithmetic_shift() {
    assert_eq!(row_derivative(-3, 1 << 25, 0, 1 << 16), Some(2));
}

#[test]
fn the_answer_names_a_saturation() {
    assert_eq!(derivative_nuon(0, 0, 1 << 62, 1 << 20).to_string(), "{saturated: true, value: null}");
    assert_eq!(derivative_nuon(1 << 20, 1 << 26, 0, 1 << 16).to_string(), "{saturated: false, value: 1048576}");
}
