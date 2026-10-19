use crate::*;

#[test]
fn the_checked_helpers_refuse_at_i128s_edge_naming_their_step() {
    let cases = [
        (mul(i128::MAX, 2, "a product"), "a product"),
        (add(i128::MAX, 1, "a sum"), "a sum"),
        (sub(i128::MIN, 1, "a difference"), "a difference"),
    ];
    for (result, step) in cases {
        match result {
            Err(PairError::Unresolvable { step: named, .. }) => assert_eq!(named, step),
            other => panic!("{other:?} for {step}"),
        }
    }
    assert_eq!(mul(i128::MAX, 1, "a product").unwrap(), i128::MAX);
    assert_eq!(sub(i128::MIN + 1, 1, "a difference").unwrap(), i128::MIN);
}

#[test]
fn rationals_carry_their_sign_up_and_order_by_cross_multiplication() {
    let half = Ratio::new(-1, -2, "a test").unwrap();
    assert_eq!((half.num, half.den), (1, 2));
    let third = Ratio::new(1, 3, "a test").unwrap();
    assert_eq!(third.order(half, "a test").unwrap(), Ordering::Less);
    assert_eq!(
        Ratio::new(2, 4, "a test")
            .unwrap()
            .order(half, "a test")
            .unwrap(),
        Ordering::Equal
    );
    assert_eq!(Ratio::new(6, -4, "a test").unwrap().text(), "-3/2");
    assert_eq!(
        Ratio::new(7, 2, "a test")
            .unwrap()
            .less(3, "a test")
            .unwrap()
            .text(),
        "1/2"
    );
    assert!(matches!(
        Ratio::new(1, 0, "a test"),
        Err(PairError::Internal(_))
    ));
}
