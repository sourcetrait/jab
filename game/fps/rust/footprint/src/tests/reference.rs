use crate::*;

fn head_on_wall(levels: u8) -> Mapping {
    Mapping { normal: [0.0, -1.0, 0.0], point: [0.0, 0.0, 0.0], u: [128.0, 0.0, 0.0], v: [0.0, 0.0, -128.0], levels }
}

fn value(fp: Footprint) -> f64 {
    match fp {
        Footprint::Value(derivatives) => derivatives.footprint(),
        other => panic!("no footprint: {other:?}"),
    }
}

fn texel(m: &Mapping, camera: &Camera, x: f64, y: f64) -> (f64, f64) {
    let dir = camera.ray(x, y);
    let t = dot(m.normal, summed(m.point, scaled(camera.eye, -1.0))) / dot(m.normal, dir);
    let hit = summed(camera.eye, scaled(dir, t));
    (dot(m.u, hit), dot(m.v, hit))
}

#[test]
fn a_wall_seen_head_on_reads_its_texels_a_pixel() {
    let camera = Camera::from_angles([0.0, -4.8, 1.6], 90.0, 0.0, 0.0);
    assert!((value(footprint(&head_on_wall(9), &camera, HX + 0.5, HY + 0.5)) - 0.64).abs() < 1e-9);
}

#[test]
fn the_analytic_derivatives_match_the_differences() {
    let m = Mapping { normal: [0.3, -1.0, 0.2], point: [0.0, 2.0, 0.0], u: [90.0, 10.0, 0.0], v: [5.0, 0.0, -70.0], levels: 9 };
    let camera = Camera::from_angles([0.5, -3.0, 1.6], 80.0, -10.0, 7.0);
    let (x, y) = (700.5, 300.5);
    let h = 1e-3;
    let (ul, vl) = texel(&m, &camera, x - h, y);
    let (ur, vr) = texel(&m, &camera, x + h, y);
    let (ua, va) = texel(&m, &camera, x, y - h);
    let (ub, vb) = texel(&m, &camera, x, y + h);
    let numeric = [(ur - ul) / (2.0 * h), (vr - vl) / (2.0 * h), (ub - ua) / (2.0 * h), (vb - va) / (2.0 * h)].iter().fold(0.0_f64, |a, d| a.max(d.abs()));
    let analytic = value(footprint(&m, &camera, x, y));
    assert!((analytic - numeric).abs() < 1e-6 * numeric.max(1.0), "{analytic} against {numeric}");
}

#[test]
fn a_head_on_wall_steps_alike_both_ways_and_a_block_steps_its_derivative() {
    let camera = Camera::from_angles([0.0, -4.8, 1.6], 90.0, 0.0, 0.0);
    let m = head_on_wall(9);
    let Footprint::Value(d) = footprint(&m, &camera, HX + 0.5, HY + 0.5) else { panic!("a footprint") };
    assert!((d.along - 0.64).abs() < 1e-9 && (d.down - 0.64).abs() < 1e-9, "{d:?}");
    assert!((block_secant(&m, &camera, HX + 0.5, HY + 0.5, BLOCK) - 0.64).abs() < 1e-9);
    assert!((block_secant(&m, &camera, HX + 0.5, HY + 0.5, 3.0) - 0.64).abs() < 1e-9);
}

#[test]
fn a_surface_through_the_eye_is_degenerate() {
    let camera = Camera::from_angles([0.0, 0.0, 1.6], 90.0, 0.0, 0.0);
    let m = head_on_wall(9);
    assert_eq!(footprint(&m, &camera, HX, HY), Footprint::Degenerate);
}

#[test]
fn a_surface_past_the_clamp_is_clamped() {
    let camera = Camera::from_angles([0.0, -20000.0, 1.6], 90.0, 0.0, 0.0);
    assert_eq!(footprint(&head_on_wall(9), &camera, HX + 0.5, HY + 0.5), Footprint::Clamped);
}

#[test]
fn levels_follow_the_halvings_and_the_cap() {
    assert_eq!(level_of(1.99, 9), 0);
    assert_eq!(level_of(2.0, 9), 1);
    assert_eq!(level_of(3.99, 9), 1);
    assert_eq!(level_of(4.0, 9), 2);
    assert_eq!(level_of(1.0e6, 9), 8);
    assert_eq!(level_of(100.0, 1), 0);
}

#[test]
fn bands_lie_about_each_boundary_under_the_cap() {
    assert_eq!(band_of(2.0, 9), Some(1));
    assert_eq!(band_of(2.0 * 1.04, 9), Some(1));
    assert_eq!(band_of(2.0 / 1.04, 9), Some(1));
    assert_eq!(band_of(2.0 * 1.05, 9), None);
    assert_eq!(band_of(256.0, 9), Some(8));
    assert_eq!(band_of(512.0, 9), None);
    assert_eq!(band_of(2.0, 1), None);
}

#[test]
fn a_band_passes_either_level_beside_it() {
    assert_eq!(judge(1, 2, Some(2)), Verdict::Agree);
    assert_eq!(judge(2, 1, Some(2)), Verdict::Agree);
    assert_eq!(judge(0, 1, Some(2)), Verdict::Sharper);
    assert_eq!(judge(3, 2, Some(2)), Verdict::Coarser);
    assert_eq!(judge(2, 2, None), Verdict::Agree);
    assert_eq!(judge(1, 2, None), Verdict::Sharper);
    assert_eq!(judge(3, 2, None), Verdict::Coarser);
}

fn image(width: usize, height: usize, fill: [u8; 3]) -> Image {
    let mut pixels = Vec::with_capacity(width * height * 3);
    for _ in 0..width * height {
        pixels.extend_from_slice(&fill);
    }
    Image { width, height, pixels }
}

fn set(image: &mut Image, x: usize, y: usize, rgb: [u8; 3]) {
    let at = (y * image.width + x) * 3;
    image.pixels[at..at + 3].copy_from_slice(&rgb);
}

#[test]
fn a_span_takes_the_surface_the_owner_capture_shows() {
    let mut owner = image(80, 8, [0xff, 0x00, 0xff]);
    let mut levels = image(80, 8, [0xff, 0x00, 0xff]);
    for x in 64..72 {
        set(&mut owner, x, 5, [0x00, 0x08, 0x02]);
        set(&mut levels, x, 5, [((x - 64) as u8) & 0xf, 0x00, 0x07]);
    }
    assert_eq!(span_surfaces(&owner, &levels).unwrap(), BTreeMap::from([(7u16, 0x0802u32)]));
    set(&mut owner, 70, 5, [0x00, 0x08, 0x03]);
    assert!(span_surfaces(&owner, &levels).unwrap_err().contains("surfaces 2050 and 2051"));
    set(&mut owner, 70, 5, [0xff, 0x00, 0xff]);
    assert!(span_surfaces(&owner, &levels).unwrap_err().contains("no surface"));
}

#[test]
fn each_capture_is_judged_against_one_reference() {
    let map = Map {
        materials: vec!["texture/concrete".to_string()],
        vertices: vec![[-100.0, 0.0], [100.0, 0.0]],
        sectors: vec![],
        walls: vec![Wall { a: 0, b: 1, surface: Surface { material: 0, u_scale: 0.5, v_scale: 0.5, u_offset: 0.0, v_offset: 0.0, flags: 1 }, anchor: 3.0 }],
        entities: vec![],
    };
    let sizes = vec![Ok((256, 256))];
    let camera = Camera::from_angles([0.0, -48.0, 1.6], 90.0, 0.0, 0.0);
    let surface = LUMAP_PLANES;
    let mut owner = image(1920, 1080, [0xff, 0x00, 0xff]);
    let mut today = image(1920, 1080, [0xff, 0x00, 0xff]);
    let mut candidate = image(1920, 1080, [0xff, 0x00, 0xff]);
    for x in 960..976 {
        set(&mut owner, x, 540, [(surface >> 16) as u8, (surface >> 8) as u8, surface as u8]);
        set(&mut today, x, 540, [2 << 4 | (x - 960) as u8, 0x00, 0x05]);
        set(&mut candidate, x, 540, [1 << 4 | (x - 960) as u8, 0x00, 0x05]);
    }
    let (tallies, rows) = compare(&map, &sizes, &camera, &owner, &[today, candidate]).unwrap();
    assert_eq!(rows.len(), 1);
    assert!((rows[0].footprint - 6.4).abs() < 1e-6, "{}", rows[0].footprint);
    assert_eq!((rows[0].reference, rows[0].band, rows[0].levels.clone()), (2, None, vec![Some(2), Some(1)]));
    assert_eq!((tallies[0].judged, tallies[0].agree, tallies[0].sharper), (1, 1, 0));
    assert_eq!((tallies[1].judged, tallies[1].agree, tallies[1].sharper), (1, 0, 1));
    assert_eq!((tallies[0].secant_agree, tallies[1].secant_sharper), (1, 1));
    assert!((rows[0].secant - 6.4).abs() < 1e-6, "{}", rows[0].secant);
}
