use crate::*;

fn close(a: [f64; 3], b: [f64; 3]) -> bool {
    (0..3).all(|i| (a[i] - b[i]).abs() < 1e-12)
}

fn surface(material: i32, u_scale: f64, v_scale: f64, flags: u32) -> Surface {
    Surface { material, u_scale, v_scale, u_offset: 0.0, v_offset: 0.0, flags }
}

fn plain_map() -> Map {
    let flat = Plane { a: 0.0, b: 0.0, c: 0.0 };
    let roof = Plane { a: 0.0, b: 0.0, c: 3.0 };
    Map {
        materials: vec!["texture/concrete".to_string(), "sprite/sign".to_string()],
        vertices: vec![[0.0, 0.0], [4.0, 0.0]],
        sectors: vec![Sector { floor: flat, ceiling: roof, floor_surface: surface(0, 0.5, 0.25, 0), ceiling_surface: surface(0, 0.5, 0.5, SURFACE_SKY) }],
        walls: vec![Wall { a: 0, b: 1, surface: surface(0, 0.5, 0.25, 1), anchor: 3.0 }],
        entities: vec![Entity { class: CLASS_SPRITE, position: [1.0, 5.0, 0.0], yaw: 90.0, width: 2.0, height: 1.0, material: 1, flags: ENTITY_CAMERA }],
    }
}

fn sizes() -> Vec<Result<(u32, u32), String>> {
    vec![Ok((256, 256)), Ok((64, 32))]
}

#[test]
fn the_basis_follows_the_yaw() {
    let camera = Camera::from_angles([0.0, 0.0, 0.0], 90.0, 0.0, 0.0);
    assert!(close(camera.forward, [0.0, 1.0, 0.0]));
    assert!(close(camera.right, [1.0, 0.0, 0.0]));
    assert!(close(camera.down, [0.0, 0.0, -1.0]));
}

#[test]
fn a_positive_roll_tilts_up_toward_the_right() {
    let camera = Camera::from_angles([0.0, 0.0, 0.0], 90.0, 0.0, 90.0);
    assert!(close(scaled(camera.down, -1.0), [1.0, 0.0, 0.0]));
    assert!(close(camera.right, [0.0, 0.0, -1.0]));
}

#[test]
fn the_ray_through_the_centre_is_forward() {
    let camera = Camera::from_angles([0.0, 0.0, 0.0], 0.0, 0.0, 0.0);
    assert!(close(camera.ray(HX, HY), [HZ, 0.0, 0.0]));
}

#[test]
fn chains_halve_while_both_sides_are_two() {
    assert_eq!(chain_levels(256, 256), 9);
    assert_eq!(chain_levels(256, 1024), 9);
    assert_eq!(chain_levels(1024, 512), 10);
    assert_eq!(chain_levels(16, 16), 5);
    assert_eq!(chain_levels(1, 1), 1);
}

#[test]
fn a_png_header_gives_its_size() {
    let mut bytes = b"\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR".to_vec();
    bytes.extend_from_slice(&256u32.to_be_bytes());
    bytes.extend_from_slice(&1024u32.to_be_bytes());
    assert_eq!(png_size_of(&bytes), Some((256, 1024)));
    assert_eq!(png_size_of(b"GIF89a"), None);
}

#[test]
fn a_floor_maps_u_along_x_and_v_along_y() {
    let camera = Camera::from_angles([0.0, 0.0, 1.6], 0.0, 0.0, 0.0);
    let Owned::Mapped(m) = owned(&plain_map(), &sizes(), &camera, 0) else { panic!("the floor is mapped") };
    assert!(close(m.u, [128.0, 0.0, 0.0]));
    assert!(close(m.v, [0.0, 64.0, 0.0]));
    assert_eq!(m.levels, 9);
}

#[test]
fn a_sky_ceiling_is_named_sky() {
    let camera = Camera::from_angles([0.0, 0.0, 1.6], 0.0, 0.0, 0.0);
    assert_eq!(owned(&plain_map(), &sizes(), &camera, 1), Owned::Sky);
}

#[test]
fn a_wall_maps_u_along_its_run_and_v_down() {
    let camera = Camera::from_angles([0.0, 0.0, 1.6], 0.0, 0.0, 0.0);
    let Owned::Mapped(m) = owned(&plain_map(), &sizes(), &camera, LUMAP_PLANES) else { panic!("the wall is mapped") };
    assert!(close(m.u, [128.0, 0.0, 0.0]));
    assert!(close(m.v, [0.0, 0.0, -64.0]));
    assert!(close(m.normal, [0.0, 4.0, 0.0]));
}

#[test]
fn a_facing_sprite_turns_to_the_camera_and_is_pulled() {
    let camera = Camera::from_angles([1.0, 0.0, 0.5], 90.0, 0.0, 0.0);
    let Owned::Mapped(m) = owned(&plain_map(), &sizes(), &camera, SURFACE_SPRITES) else { panic!("the sprite is mapped") };
    let r = 0.99;
    assert!(close(m.point, [1.0, 0.0 + 5.0 * r, 0.5]));
    assert!(close(m.u, [64.0 / (2.0 * r), 0.0, 0.0]));
    assert!(close(m.v, [0.0, 0.0, -32.0 / (2.0 * 0.5 * r)]));
    assert_eq!(m.levels, 6);
}

#[test]
fn past_the_sprites_lie_the_actors() {
    let camera = Camera::from_angles([0.0, 0.0, 1.6], 0.0, 0.0, 0.0);
    assert_eq!(owned(&plain_map(), &sizes(), &camera, SURFACE_ACTORS + 3), Owned::Actor);
    assert_eq!(owned(&plain_map(), &sizes(), &camera, LUMAP_PLANES + 1), Owned::Unknown);
}

#[test]
fn an_unread_texture_leaves_its_surface_unread() {
    let camera = Camera::from_angles([0.0, 0.0, 1.6], 0.0, 0.0, 0.0);
    let unread = vec![Err("no file".to_string()), Ok((64, 32))];
    assert_eq!(owned(&plain_map(), &unread, &camera, 0), Owned::Unsized("no file".to_string()));
}
