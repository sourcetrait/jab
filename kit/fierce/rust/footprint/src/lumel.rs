use crate::*;

/// The share of a metre whose texels set a lumel's size, k_lumel_d.
const LUMEL_METRE: f64 = 0.5;
/// The square root of two's mantissa, where k rounds up, k_sqrt2_mantissa.
const SQRT2_MANTISSA: u64 = 0x6_a09e_667f_3bcd;
/// The largest k, LUMEL_K_MAX.
const LUMEL_K_MAX: i64 = 15;
/// The lumel arena's bytes, LUMEL_ARENA_BYTES.
const LUMEL_ARENA_BYTES: i128 = 8 * 1024 * 1024;
/// A lumel's bytes, LUMEL_BYTES.
const LUMEL_BYTES: i128 = 8;

/// A surface's lumel map as the bake lays it, or why it has none.
#[derive(Clone, Debug, PartialEq)]
pub(crate) enum Lumel {
    /// Baked, its origin in level-0 texels, which the bind folds into u and v.
    Mapped { u0: i64, v0: i64 },
    /// No map, so the surface draws unlit on its texture's own coordinates.
    Unmapped,
    /// Unknown, past an unread texture in the bake.
    Uncertain(String),
}

/// The planes' and walls' lumel maps by OWNER index, and the bake's counts.
#[derive(Clone, Debug, Default, PartialEq)]
pub(crate) struct Lumels {
    surfaces: BTreeMap<u32, Lumel>,
    pub(crate) maps: u64,
    pub(crate) lumels: u64,
    pub(crate) unmapped: u64,
}

impl Lumels {
    /// A plane's or wall's map by its OWNER index; one the bake skipped has none.
    pub(crate) fn of(&self, index: u32) -> &Lumel {
        self.surfaces.get(&index).unwrap_or(&Lumel::Unmapped)
    }
}

/// A map's origin in texels and its nodes, columns by rows.
#[derive(Clone, Copy, Debug, PartialEq)]
struct Frame {
    u0: i64,
    v0: i64,
    columns: i64,
    rows: i64,
}

/// The mask a texture side wraps by, as material_bind derives it.
fn wrap_mask(side: u32) -> i64 {
    if side == 0 { 0 } else { (1i64 << (u32::BITS - 1 - side.leading_zeros())) - 1 }
}

/// k, a lumel's texels a side as a power of two, from the texels a metre.
fn lumel_shift(texels: f64) -> i64 {
    let bits = (texels * LUMEL_METRE).to_bits();
    let mut k = ((bits >> 52) & 0x7ff) as i64 - 1023;
    if bits & ((1u64 << 52) - 1) >= SQRT2_MANTISSA {
        k += 1;
    }
    k.clamp(0, LUMEL_K_MAX)
}

/// lumap_frame over a surface's least and greatest texels along u and v.
fn frame(texels: f64, u: (f64, f64), v: (f64, f64), size: (u32, u32)) -> Frame {
    let k = lumel_shift(texels);
    let u0 = (u.0.floor() as i64).wrapping_sub(1) & !wrap_mask(size.0);
    let v0 = (v.0.floor() as i64).wrapping_sub(1) & !wrap_mask(size.1);
    let columns = ((u.1.ceil() as i64).wrapping_sub(u0) >> k).wrapping_add(2);
    let rows = ((v.1.ceil() as i64).wrapping_sub(v0) >> k).wrapping_add(2);
    Frame { u0, v0, columns, rows }
}

/// The least and the greatest of two coordinates.
fn ordered(a: f64, b: f64) -> (f64, f64) {
    (a.min(b), a.max(b))
}

/// A plane's height at a point in the plan, as plane_height takes it.
fn height(plane: Plane, p: [f64; 2]) -> f64 {
    p[1].mul_add(plane.b, p[0] * plane.a) + plane.c
}

/// What the bake makes of a surface.
enum Baked {
    Frame(Frame),
    Skipped,
    Missing,
    Unread(String),
}

/// A surface's texture size for the bake, or what it makes of none.
fn bound(s: &Surface, textures: &Textures) -> Result<(u32, u32), Baked> {
    if s.flags & SURFACE_SKY != 0 {
        return Err(Baked::Skipped);
    }
    match textures.of(s.material) {
        None => Err(Baked::Skipped),
        Some(Err(why)) => Err(Baked::Unread(why.clone())),
        Some(Ok(size)) => Ok(*size),
    }
}

/// A floor's or ceiling's frame over its sector's bounds.
fn plane_frame(sector: &Sector, ceiling: bool, textures: &Textures) -> Baked {
    let s = if ceiling { sector.ceiling_surface } else { sector.floor_surface };
    let (w, h) = match bound(&s, textures) {
        Ok(size) => size,
        Err(baked) => return baked,
    };
    if s.u_scale == 0.0 || s.v_scale == 0.0 {
        return Baked::Missing;
    }
    let [min_x, min_y, max_x, max_y] = sector.bounds;
    let (tw, th) = (w as f64, h as f64);
    let u = ordered(s.u_scale.mul_add(min_x, s.u_offset) * tw, s.u_scale.mul_add(max_x, s.u_offset) * tw);
    let v = ordered(s.v_scale.mul_add(min_y, s.v_offset) * th, s.v_scale.mul_add(max_y, s.v_offset) * th);
    Baked::Frame(frame((tw * s.u_scale).abs(), u, v, (w, h)))
}

/// A wall's frame over its length and its sector's heights at its ends.
fn wall_frame(map: &Map, wall: &Wall, textures: &Textures) -> Baked {
    let s = wall.surface;
    let (w, h) = match bound(&s, textures) {
        Ok(size) => size,
        Err(baked) => return baked,
    };
    let sector = &map.sectors[wall.sector];
    let (a, b) = (map.vertices[wall.a], map.vertices[wall.b]);
    let top = height(sector.ceiling, a).max(height(sector.ceiling, b));
    let bottom = height(sector.floor, a).min(height(sector.floor, b));
    let run = [b[0] - a[0], b[1] - a[1]];
    let length = run[1].mul_add(run[1], run[0] * run[0]).sqrt();
    if length == 0.0 || s.u_scale == 0.0 || s.v_scale == 0.0 {
        return Baked::Missing;
    }
    let (tw, th) = (w as f64, h as f64);
    let u = ordered(s.u_offset * tw, s.u_scale.mul_add(length, s.u_offset) * tw);
    let v = ordered(s.v_scale.mul_add(wall.anchor - top, s.v_offset) * th, s.v_scale.mul_add(wall.anchor - bottom, s.v_offset) * th);
    Baked::Frame(frame((tw * s.u_scale).abs(), u, v, (w, h)))
}

/// lumaps_bake's maps, planes then walls, while the arena holds them.
pub(crate) fn lumels(map: &Map, textures: &Textures) -> Lumels {
    let mut found = Lumels::default();
    if !map.entities.iter().any(|e| e.class == CLASS_LIGHT) {
        return found;
    }
    let planes = map.sectors.iter().zip(0u32..).flat_map(|(sector, k)| [(2 * k, plane_frame(sector, false, textures)), (2 * k + 1, plane_frame(sector, true, textures))]);
    let walls = map.walls.iter().zip(0u32..).map(|(wall, k)| (LUMAP_PLANES + k, wall_frame(map, wall, textures)));
    let mut cursor: i128 = 0;
    let mut unread: Option<String> = None;
    for (index, baked) in planes.chain(walls) {
        let lumel = match baked {
            Baked::Skipped => continue,
            Baked::Missing => {
                found.unmapped += 1;
                Lumel::Unmapped
            }
            Baked::Unread(why) => {
                unread.get_or_insert_with(|| why.clone());
                Lumel::Uncertain(why)
            }
            Baked::Frame(f) => match &unread {
                Some(why) => Lumel::Uncertain(format!("the bake past an unread texture: {why}")),
                None => {
                    let lumels = f.columns as i128 * f.rows as i128;
                    if cursor + lumels * LUMEL_BYTES > LUMEL_ARENA_BYTES {
                        found.unmapped += 1;
                        Lumel::Unmapped
                    } else {
                        cursor += lumels * LUMEL_BYTES;
                        found.maps += 1;
                        found.lumels += lumels as u64;
                        Lumel::Mapped { u0: f.u0, v0: f.v0 }
                    }
                }
            },
        };
        found.surfaces.insert(index, lumel);
    }
    found
}
