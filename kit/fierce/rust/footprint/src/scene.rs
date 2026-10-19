use crate::*;

/// The projection's half width and half height, and its focal length, in pixels.
pub(crate) const HX: f64 = 960.0;
pub(crate) const HY: f64 = 540.0;
pub(crate) const HZ: f64 = 960.0;
/// The OWNER index space: planes, then walls, then map sprites, then actors.
pub(crate) const LUMAP_PLANES: u32 = 2 * 1024;
pub(crate) const SURFACE_SPRITES: u32 = LUMAP_PLANES + 8192;
pub(crate) const SURFACE_ACTORS: u32 = SURFACE_SPRITES + 1024;
/// The OWNER capture's prepaint, magenta, where no surface drew.
pub(crate) const OWNER_NONE: u32 = 0x00ff_00ff;
/// A texture's chain holds this many levels at most, MIP_LEVELS in render.inc.
pub(crate) const MIP_LEVELS: u8 = 10;
/// The fraction of the way to the eye a sprite's quad is pulled, k_pull_d.
pub(crate) const SPRITE_PULL: f64 = 0.99;
/// A camera's right whose level length is under this leaves a sprite its yaw.
pub(crate) const SPRITE_TINY: f64 = 0.000_000_001;

/// The dot product of two vectors.
pub(crate) fn dot(a: [f64; 3], b: [f64; 3]) -> f64 {
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}

/// A vector scaled.
pub(crate) fn scaled(a: [f64; 3], s: f64) -> [f64; 3] {
    [a[0] * s, a[1] * s, a[2] * s]
}

/// The sum of two vectors.
pub(crate) fn summed(a: [f64; 3], b: [f64; 3]) -> [f64; 3] {
    [a[0] + b[0], a[1] + b[1], a[2] + b[2]]
}

/// The camera as camera_basis derives it: the eye, right, down, and forward.
#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct Camera {
    pub(crate) eye: [f64; 3],
    pub(crate) right: [f64; 3],
    pub(crate) down: [f64; 3],
    pub(crate) forward: [f64; 3],
}

impl Camera {
    /// The camera at an eye, its yaw, pitch, and roll in degrees.
    pub(crate) fn from_angles(eye: [f64; 3], yaw: f64, pitch: f64, roll: f64) -> Camera {
        let (sy, cy) = yaw.to_radians().sin_cos();
        let (sp, cp) = pitch.to_radians().sin_cos();
        let (sr, cr) = roll.to_radians().sin_cos();
        let forward = [cp * cy, cp * sy, sp];
        let level = [sy, -cy, 0.0];
        let up0 = [-cy * sp, -sy * sp, cp];
        let right = summed(scaled(level, cr), scaled(up0, -sr));
        let up = summed(scaled(up0, cr), scaled(level, sr));
        Camera { eye, right, down: scaled(up, -1.0), forward }
    }

    /// The ray through a screen point: right (x - hx) + down (y - hy) + forward hz.
    pub(crate) fn ray(&self, x: f64, y: f64) -> [f64; 3] {
        summed(summed(scaled(self.right, x - HX), scaled(self.down, y - HY)), scaled(self.forward, HZ))
    }
}

/// A surface's plane, and its texel coordinates' gradients and intercepts.
#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct Mapping {
    pub(crate) normal: [f64; 3],
    pub(crate) point: [f64; 3],
    pub(crate) u: [f64; 3],
    pub(crate) v: [f64; 3],
    pub(crate) u0: f64,
    pub(crate) v0: f64,
    pub(crate) levels: u8,
}

/// What an OWNER index names for the reference.
#[derive(Clone, Debug, PartialEq)]
pub(crate) enum Owned {
    Mapped(Mapping),
    Sky,
    Actor,
    Unsized(String),
    Unknown,
}

/// The engine's own images after the map's materials: sets, then singles.
pub(crate) const FRAME_SETS: [&str; 8] = ["stand", "walk1", "walk2", "walk3", "walk4", "aim", "fire", "struck"];
pub(crate) const FRAME_SINGLES: [&str; 5] = ["android/fallen", "android/spark1", "android/spark2", "android/spark3", "gun/magazine"];

/// An engine image's stem under `sprite/`, by its index after the materials.
pub(crate) fn frame_stem(frame: usize) -> Option<String> {
    let rotations = FRAME_SETS.len() * 8;
    if frame < rotations {
        Some(format!("android/{}_{}", FRAME_SETS[frame / 8], frame % 8))
    } else {
        FRAME_SINGLES.get(frame - rotations).map(|stem| stem.to_string())
    }
}

/// The levels a texture's chain holds: halved while both sides are two or more.
pub(crate) fn chain_levels(width: u32, height: u32) -> u8 {
    let (mut w, mut h, mut levels) = (width, height, 1);
    while levels < MIP_LEVELS && w >= 2 && h >= 2 {
        w /= 2;
        h /= 2;
        levels += 1;
    }
    levels
}

/// A PNG's width and height from its bytes, read from its IHDR.
pub(crate) fn png_size_of(bytes: &[u8]) -> Option<(u32, u32)> {
    if bytes.len() < 24 || &bytes[..8] != b"\x89PNG\r\n\x1a\n" || &bytes[12..16] != b"IHDR" {
        return None;
    }
    let be = |at: usize| u32::from_be_bytes([bytes[at], bytes[at + 1], bytes[at + 2], bytes[at + 3]]);
    Some((be(16), be(20)))
}

/// A PNG's width and height, read from its file's IHDR.
pub(crate) fn png_size(path: &Path) -> Result<(u32, u32), String> {
    let bytes = fs::read(path).map_err(|error| format!("{}: {error}", path.display()))?;
    png_size_of(&bytes).ok_or_else(|| format!("{}: not a PNG opening with its IHDR", path.display()))
}

/// Each texture's size: the map's materials', then the engine's images'.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Textures {
    pub(crate) materials: Vec<Result<(u32, u32), String>>,
    pub(crate) frames: Vec<Result<(u32, u32), String>>,
}

impl Textures {
    /// A material's texture size, the engine's images following the map's materials.
    fn of(&self, material: i32) -> Option<&Result<(u32, u32), String>> {
        let index = usize::try_from(material).ok()?;
        self.materials.get(index).or_else(|| self.frames.get(index - self.materials.len()))
    }

    /// The materials and images unread, each with its reason.
    pub(crate) fn unread(&self, map: &Map) -> Vec<(String, String)> {
        let materials = map.materials.iter().zip(&self.materials).filter_map(|(name, size)| size.as_ref().err().map(|why| (name.clone(), why.clone())));
        let frames = self.frames.iter().enumerate().filter_map(|(k, size)| size.as_ref().err().map(|why| (format!("sprite/{}", frame_stem(k).unwrap_or_default()), why.clone())));
        materials.chain(frames).collect()
    }
}

/// Each texture's size, read from its PNG in the tree.
pub(crate) fn textures(map: &Map, tree: &Path) -> Textures {
    Textures {
        materials: map.materials.iter().map(|name| png_size(&tree.join(format!("{name}.png")))).collect(),
        frames: (0usize..).map_while(frame_stem).map(|stem| png_size(&tree.join("sprite").join(format!("{stem}.png")))).collect(),
    }
}

/// The mapping a surface's texture takes, or why it has none.
fn textured(textures: &Textures, material: i32) -> Result<(f64, f64, u8), Owned> {
    match textures.of(material).ok_or(Owned::Unknown)? {
        Ok((w, h)) => Ok((*w as f64, *h as f64, chain_levels(*w, *h))),
        Err(why) => Err(Owned::Unsized(why.clone())),
    }
}

/// The mapping of the surface an OWNER index names, an actor's as it was drawn.
pub(crate) fn owned(map: &Map, textures: &Textures, actors: &BTreeMap<u32, Entity>, camera: &Camera, index: u32) -> Owned {
    let mapped = if index < LUMAP_PLANES {
        plane_mapping(map, textures, index)
    } else if index < SURFACE_SPRITES {
        wall_mapping(map, textures, index - LUMAP_PLANES)
    } else if index < SURFACE_ACTORS {
        sprite_mapping(map, textures, camera, index - SURFACE_SPRITES)
    } else {
        actors.get(&(index - SURFACE_ACTORS)).ok_or(Owned::Actor).and_then(|entity| quad_mapping(entity, textures, camera))
    };
    match mapped {
        Ok(mapping) => Owned::Mapped(mapping),
        Err(owned) => owned,
    }
}

/// A floor or ceiling: the normal (-a, -b, 1), u along x and v along y.
fn plane_mapping(map: &Map, textures: &Textures, index: u32) -> Result<Mapping, Owned> {
    let sector = map.sectors.get((index / 2) as usize).ok_or(Owned::Unknown)?;
    let (plane, surface) = if index.is_multiple_of(2) { (sector.floor, sector.floor_surface) } else { (sector.ceiling, sector.ceiling_surface) };
    if surface.flags & SURFACE_SKY != 0 {
        return Err(Owned::Sky);
    }
    let (w, h, levels) = textured(textures, surface.material)?;
    Ok(Mapping {
        normal: [-plane.a, -plane.b, 1.0],
        point: [0.0, 0.0, plane.c],
        u: [w * surface.u_scale, 0.0, 0.0],
        v: [0.0, h * surface.v_scale, 0.0],
        u0: w * surface.u_offset,
        v0: h * surface.v_offset,
        levels,
    })
}

/// A wall: its normal across its run, u along it from a, v down from its anchor.
fn wall_mapping(map: &Map, textures: &Textures, index: u32) -> Result<Mapping, Owned> {
    let wall = map.walls.get(index as usize).ok_or(Owned::Unknown)?;
    if wall.surface.flags & SURFACE_SKY != 0 {
        return Err(Owned::Sky);
    }
    let (w, h, levels) = textured(textures, wall.surface.material)?;
    let a = map.vertices[wall.a];
    let b = map.vertices[wall.b];
    let run = [b[0] - a[0], b[1] - a[1]];
    let length = (run[0] * run[0] + run[1] * run[1]).sqrt();
    if length.is_nan() || length <= 0.0 {
        return Err(Owned::Unknown);
    }
    let along = [run[0] / length, run[1] / length];
    let s = &wall.surface;
    Ok(Mapping {
        normal: [a[1] - b[1], b[0] - a[0], 0.0],
        point: [a[0], a[1], 0.0],
        u: [w * s.u_scale * along[0], w * s.u_scale * along[1], 0.0],
        v: [0.0, 0.0, -h * s.v_scale],
        u0: w * (s.u_offset - s.u_scale * (a[0] * along[0] + a[1] * along[1])),
        v0: h * (s.v_offset + s.v_scale * wall.anchor),
        levels,
    })
}

/// A map sprite's quad as sprite_draw lays it, pulled toward the eye.
fn sprite_mapping(map: &Map, textures: &Textures, camera: &Camera, index: u32) -> Result<Mapping, Owned> {
    let entity = map.entities.get(index as usize).ok_or(Owned::Unknown)?;
    if entity.class != CLASS_SPRITE {
        return Err(Owned::Unknown);
    }
    quad_mapping(entity, textures, camera)
}

/// A sprite's quad as sprite_draw lays it from its entity, pulled to the eye.
fn quad_mapping(entity: &Entity, textures: &Textures, camera: &Camera) -> Result<Mapping, Owned> {
    let (w, h, levels) = textured(textures, entity.material)?;
    let (sy, cy) = entity.yaw.to_radians().sin_cos();
    let (half_w, half_h) = (entity.width / 2.0, entity.height / 2.0);
    let mut centre = entity.position;
    let (r, d) = if entity.flags & ENTITY_FLAT != 0 {
        ([cy * half_w, sy * half_w, 0.0], [sy * half_h, -cy * half_h, 0.0])
    } else {
        centre[2] += half_h;
        let level = (camera.right[0] * camera.right[0] + camera.right[1] * camera.right[1]).sqrt();
        let r = if entity.flags & ENTITY_CAMERA != 0 && level >= SPRITE_TINY {
            [camera.right[0] * half_w / level, camera.right[1] * half_w / level, 0.0]
        } else {
            [-sy * half_w, cy * half_w, 0.0]
        };
        (r, [0.0, 0.0, -half_h])
    };
    let normal = [d[1] * r[2] - d[2] * r[1], d[2] * r[0] - d[0] * r[2], d[0] * r[1] - d[1] * r[0]];
    let point = summed(camera.eye, scaled(summed(centre, scaled(camera.eye, -1.0)), SPRITE_PULL));
    let (r, d) = (scaled(r, SPRITE_PULL), scaled(d, SPRITE_PULL));
    let (u, v) = (scaled(r, w / (2.0 * dot(r, r))), scaled(d, h / (2.0 * dot(d, d))));
    Ok(Mapping { normal, point, u, v, u0: w * 0.5 - dot(u, point), v0: h * 0.5 - dot(v, point), levels })
}
