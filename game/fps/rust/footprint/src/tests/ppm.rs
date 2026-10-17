use crate::*;

#[test]
fn a_p6_image_parses_past_a_comment() {
    let mut bytes = b"P6\n# a capture\n2 1\n255\n".to_vec();
    bytes.extend_from_slice(&[1, 2, 3, 4, 5, 6]);
    let image = parse_ppm(&bytes).unwrap();
    assert_eq!((image.width, image.height), (2, 1));
    assert_eq!(image.rgb(1, 0), [4, 5, 6]);
    assert_eq!(image.word(0, 0), 0x0001_0203);
}

#[test]
fn another_magic_is_refused() {
    assert!(parse_ppm(b"P5\n1 1\n255\n\x00").unwrap_err().contains("not a P6"));
}

#[test]
fn a_short_image_is_refused() {
    assert!(parse_ppm(b"P6\n2 2\n255\n\x00\x00\x00").unwrap_err().contains("needs 12"));
}

#[test]
fn a_wide_maxval_is_refused() {
    assert!(parse_ppm(b"P6\n1 1\n65535\n\x00\x00\x00\x00\x00\x00").unwrap_err().contains("maxval"));
}

#[test]
fn the_stamp_cells_are_the_top_left_64_by_4() {
    assert!(in_stamp(0, 0));
    assert!(in_stamp(63, 3));
    assert!(!in_stamp(64, 0));
    assert!(!in_stamp(0, 4));
}
