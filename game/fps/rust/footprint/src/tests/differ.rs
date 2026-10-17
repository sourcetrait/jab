use crate::*;

/// A black capture of that size with the given pixels set to a colour.
fn capture(width: usize, height: usize, set: &[(usize, usize, [u8; 3])]) -> Image {
    let mut pixels = vec![0; width * height * 3];
    for &(x, y, rgb) in set {
        let at = (y * width + x) * 3;
        pixels[at..at + 3].copy_from_slice(&rgb);
    }
    Image { width, height, pixels }
}

#[test]
fn identical_captures_differ_nowhere() {
    let a = capture(64, 32, &[(5, 9, [1, 2, 3])]);
    assert_eq!(differ(&a, &a.clone()).unwrap(), vec![]);
}

#[test]
fn a_difference_is_boxed_with_its_count_and_largest_channel() {
    let a = capture(64, 32, &[]);
    let b = capture(64, 32, &[(20, 10, [0, 7, 0]), (22, 12, [3, 0, 200])]);
    let regions = differ(&a, &b).unwrap();
    assert_eq!(regions, vec![Region { x0: 20, y0: 10, x1: 23, y1: 13, pixels: 2, largest: 200 }]);
}

#[test]
fn cells_apart_are_regions_apart_and_neighbours_join() {
    let a = capture(96, 48, &[]);
    // cells (0, 1) and (1, 2) touch at a corner; cell (5, 0) stands alone
    let b = capture(96, 48, &[(3, 20, [9, 9, 9]), (17, 33, [9, 9, 9]), (90, 1, [9, 9, 9])]);
    let regions = differ(&a, &b).unwrap();
    assert_eq!(regions.len(), 2);
    // in the order of their first cell, row by row
    assert_eq!((regions[0].x0, regions[0].y0, regions[0].pixels), (90, 1, 1));
    assert_eq!((regions[1].x0, regions[1].y0, regions[1].x1, regions[1].y1, regions[1].pixels), (3, 20, 18, 34, 2));
}

#[test]
fn the_stamps_cells_are_skipped() {
    let a = capture(96, 8, &[]);
    let b = capture(96, 8, &[(0, 0, [255, 255, 255]), (63, 3, [255, 255, 255]), (64, 0, [1, 0, 0])]);
    let regions = differ(&a, &b).unwrap();
    assert_eq!(regions, vec![Region { x0: 64, y0: 0, x1: 65, y1: 1, pixels: 1, largest: 1 }]);
}

#[test]
fn captures_of_two_sizes_are_refused() {
    assert!(differ(&capture(2, 2, &[]), &capture(2, 3, &[])).unwrap_err().contains("2 by 2 and 2 by 3"));
}
