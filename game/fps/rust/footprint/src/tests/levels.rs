use crate::*;

fn sentinel_image(width: usize, height: usize) -> Image {
    let mut pixels = Vec::with_capacity(width * height * 3);
    for _ in 0..width * height {
        pixels.extend_from_slice(&[0xff, 0x00, 0xff]);
    }
    Image { width, height, pixels }
}

fn lay(image: &mut Image, row: usize, x0: usize, count: usize, level: u8, span: u16) {
    for i in 0..count {
        let at = (row * image.width + x0 + i) * 3;
        image.pixels[at] = level << 4 | (i as u8 & 0xf);
        image.pixels[at + 1] = (span >> 8) as u8;
        image.pixels[at + 2] = span as u8;
    }
}

#[test]
fn the_sentinel_carries_no_code() {
    assert_eq!(code_of([0xff, 0x00, 0xff]), None);
    assert_eq!(code_of([0x2b, 0x01, 0x2c]), Some(Code { level: 2, offset: 11, span: 300 }));
}

#[test]
fn spans_read_as_their_blocks() {
    let mut image = sentinel_image(128, 8);
    lay(&mut image, 5, 70, 16, 2, 300);
    lay(&mut image, 5, 86, 16, 2, 300);
    lay(&mut image, 5, 102, 4, 3, 300);
    let found = blocks(&image).unwrap();
    assert_eq!(found, vec![
        Block { span: 300, row: 5, x0: 70, level: 2, pixels: 16, end: 86 },
        Block { span: 300, row: 5, x0: 86, level: 2, pixels: 16, end: 102 },
        Block { span: 300, row: 5, x0: 102, level: 3, pixels: 4, end: 106 },
    ]);
}

#[test]
fn a_covered_start_is_found_from_the_offsets() {
    let mut image = sentinel_image(128, 8);
    lay(&mut image, 6, 70, 16, 5, 40);
    lay(&mut image, 6, 70, 4, 6, 41);
    let found = blocks(&image).unwrap();
    assert_eq!(found, vec![
        Block { span: 40, row: 6, x0: 70, level: 5, pixels: 12, end: 86 },
        Block { span: 41, row: 6, x0: 70, level: 6, pixels: 4, end: 74 },
    ]);
}

#[test]
fn the_stamp_cells_are_skipped() {
    let mut image = sentinel_image(128, 8);
    lay(&mut image, 2, 10, 16, 1, 9);
    lay(&mut image, 1, 56, 16, 4, 10);
    assert_eq!(blocks(&image).unwrap(), vec![Block { span: 10, row: 1, x0: 56, level: 4, pixels: 8, end: 72 }]);
}

#[test]
fn a_level_past_nine_is_refused() {
    let mut image = sentinel_image(128, 8);
    lay(&mut image, 5, 70, 16, 12, 1);
    assert!(blocks(&image).unwrap_err().contains("level 12"));
}

#[test]
fn a_block_of_two_levels_is_refused() {
    let mut image = sentinel_image(128, 8);
    lay(&mut image, 5, 70, 16, 2, 1);
    let at = (5 * 128 + 75) * 3;
    image.pixels[at] = 3 << 4 | 5;
    assert!(blocks(&image).unwrap_err().contains("levels 2 and 3"));
}

#[test]
fn a_span_on_two_rows_is_refused() {
    let mut image = sentinel_image(128, 8);
    lay(&mut image, 5, 70, 4, 2, 1);
    lay(&mut image, 6, 70, 4, 2, 1);
    assert!(blocks(&image).unwrap_err().contains("rows 5 and 6"));
}

#[test]
fn a_start_before_the_row_is_refused() {
    let mut image = sentinel_image(128, 8);
    let at = (5 * 128 + 2) * 3;
    image.pixels[at] = 7;
    image.pixels[at + 1] = 0;
    image.pixels[at + 2] = 1;
    assert!(blocks(&image).unwrap_err().contains("before its row"));
}
