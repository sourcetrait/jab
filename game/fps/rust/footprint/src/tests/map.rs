use crate::*;

fn words(values: &[u32]) -> Vec<u8> {
    values.iter().flat_map(|v| v.to_le_bytes()).collect()
}

fn singles(values: &[f32]) -> Vec<u8> {
    values.iter().flat_map(|v| v.to_le_bytes()).collect()
}

fn surface_bytes(material: i32, scales: [f32; 4], flags: u32) -> Vec<u8> {
    let mut bytes = words(&[material as u32]);
    bytes.extend(singles(&scales));
    bytes.extend(words(&[flags]));
    bytes
}

fn map_bytes() -> Vec<u8> {
    let mut names = b"texture/concrete\0sprite/sign\0".to_vec();
    while !names.len().is_multiple_of(4) {
        names.push(0);
    }
    let materials = words(&[0, 0, 17, 0]);
    let vertices = singles(&[0.0, 0.0, 4.0, 0.0]);
    let mut sector = singles(&[0.0, 0.0, 0.0, 0.0, 0.0, 3.0]);
    sector.extend(surface_bytes(0, [0.5, 0.5, 0.0, 0.0], 0));
    sector.extend(surface_bytes(0, [0.25, 0.25, 0.0, 0.0], 4));
    sector.extend(words(&[0, 1]));
    sector.extend(singles(&[0.0, 0.0, 4.0, 4.0]));
    sector.extend(words(&[0, u32::MAX, 0, 0]));
    let mut wall = words(&[0, 1, 0]);
    wall.extend(surface_bytes(0, [0.5, 0.5, 0.0, 0.0], 1));
    wall.extend(singles(&[3.0]));
    wall.extend(words(&[0, 0, 0]));
    let mut entity = words(&[2]);
    entity.extend(singles(&[1.0, 2.0, 0.5, 90.0, 0.0, 2.0, 1.0]));
    entity.extend(words(&[1]));
    entity.extend(singles(&[1.0, 1.0, 1.0, 0.0, 0.0]));
    entity.extend(words(&[5, 0, u32::MAX, 0]));
    let sections: Vec<(u32, u32, Vec<u8>, u32)> = vec![
        (1, 1, names.clone(), names.len() as u32),
        (2, 8, materials, 2),
        (3, 8, vertices, 2),
        (4, 112, sector, 1),
        (6, 52, wall, 1),
        (8, 72, entity, 1),
    ];
    let mut bytes = words(&[MAP_MAGIC, sections.len() as u32]);
    let mut offset = 8 + 16 * sections.len() as u32;
    for (kind, size, data, count) in &sections {
        bytes.extend(words(&[*kind, offset, *size, *count]));
        offset += data.len() as u32;
    }
    for (_, _, data, _) in &sections {
        bytes.extend(data);
    }
    bytes
}

#[test]
fn a_map_reads_its_sections() {
    let map = parse_map(&map_bytes()).unwrap();
    assert_eq!(map.materials, vec!["texture/concrete".to_string(), "sprite/sign".to_string()]);
    assert_eq!(map.vertices, vec![[0.0, 0.0], [4.0, 0.0]]);
    assert_eq!(map.sectors[0].ceiling.c, 3.0);
    assert_eq!(map.sectors[0].ceiling_surface.flags, SURFACE_SKY);
    assert_eq!(map.walls[0].anchor, 3.0);
    assert_eq!(map.walls[0].surface.u_scale, 0.5);
    assert_eq!(map.entities[0].class, CLASS_SPRITE);
    assert_eq!(map.entities[0].position, [1.0, 2.0, 0.5]);
    assert_eq!(map.entities[0].yaw, 90.0);
    assert_eq!((map.entities[0].width, map.entities[0].height), (2.0, 1.0));
    assert_eq!(map.entities[0].material, 1);
    assert_eq!(map.entities[0].flags, 5);
}

#[test]
fn another_magic_is_refused() {
    let mut bytes = map_bytes();
    bytes[0] = b'X';
    assert!(parse_map(&bytes).unwrap_err().contains("magic"));
}

#[test]
fn a_record_of_another_size_is_refused() {
    let mut bytes = map_bytes();
    let entry = 8 + 16 * 3;
    bytes[entry + 8] = 100;
    assert!(parse_map(&bytes).unwrap_err().contains("kind 4's records are 100 bytes"));
}

#[test]
fn a_section_past_the_end_is_refused() {
    let mut bytes = map_bytes();
    bytes.truncate(bytes.len() - 10);
    assert!(parse_map(&bytes).unwrap_err().contains("runs past"));
}

#[test]
fn a_kind_twice_is_refused() {
    let mut bytes = map_bytes();
    let entry = 8 + 16 * 2;
    bytes[entry] = 2;
    assert!(parse_map(&bytes).unwrap_err().contains("twice"));
}
