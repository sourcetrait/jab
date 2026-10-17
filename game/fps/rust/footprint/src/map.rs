use crate::*;

/// A Jab FPS map's magic, `JAB` and a zero, as its first word reads.
pub(crate) const MAP_MAGIC: u32 = 0x0042_414a;
/// A surface flag: the surface shows the sky.
pub(crate) const SURFACE_SKY: u32 = 4;
/// An entity class: a sprite.
pub(crate) const CLASS_SPRITE: u32 = 2;
/// An entity flag: the sprite faces the camera.
pub(crate) const ENTITY_CAMERA: u32 = 1;
/// An entity flag: the sprite lies flat on the floor.
pub(crate) const ENTITY_FLAT: u32 = 2;

/// A surface as the map writes it: material, scales and offsets, flags.
#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct Surface {
    pub(crate) material: i32,
    pub(crate) u_scale: f64,
    pub(crate) v_scale: f64,
    pub(crate) u_offset: f64,
    pub(crate) v_offset: f64,
    pub(crate) flags: u32,
}

/// A plane z = a x + b y + c.
#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct Plane {
    pub(crate) a: f64,
    pub(crate) b: f64,
    pub(crate) c: f64,
}

/// A sector's floor and ceiling, each a plane with its surface.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Sector {
    pub(crate) floor: Plane,
    pub(crate) ceiling: Plane,
    pub(crate) floor_surface: Surface,
    pub(crate) ceiling_surface: Surface,
}

/// A wall: its two vertices, its surface, and the height its v counts down from.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Wall {
    pub(crate) a: usize,
    pub(crate) b: usize,
    pub(crate) surface: Surface,
    pub(crate) anchor: f64,
}

/// An entity's fields a sprite reads; angles in degrees, sizes in metres.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Entity {
    pub(crate) class: u32,
    pub(crate) position: [f64; 3],
    pub(crate) yaw: f64,
    pub(crate) width: f64,
    pub(crate) height: f64,
    pub(crate) material: i32,
    pub(crate) flags: u32,
}

/// The sections of a map the reference reads.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Map {
    pub(crate) materials: Vec<String>,
    pub(crate) vertices: Vec<[f64; 2]>,
    pub(crate) sectors: Vec<Sector>,
    pub(crate) walls: Vec<Wall>,
    pub(crate) entities: Vec<Entity>,
}

/// A map read from its file.
pub(crate) fn read_map(path: &Path) -> FootprintResult<Map> {
    let bytes = fs::read(path).map_err(FootprintError::io(path))?;
    parse_map(&bytes).map_err(|message| FootprintError::refused(path, message))
}

/// The little-endian word at a byte, or why there is none.
fn word(bytes: &[u8], at: usize) -> Result<u32, String> {
    bytes.get(at..at + 4).map(|w| u32::from_le_bytes([w[0], w[1], w[2], w[3]])).ok_or_else(|| format!("the map ends before its word at {at}"))
}

/// The single at a byte, widened.
fn single(bytes: &[u8], at: usize) -> Result<f64, String> {
    Ok(f32::from_bits(word(bytes, at)?) as f64)
}

/// A surface's 24 bytes at a byte.
fn surface(bytes: &[u8], at: usize) -> Result<Surface, String> {
    Ok(Surface {
        material: word(bytes, at)? as i32,
        u_scale: single(bytes, at + 4)?,
        v_scale: single(bytes, at + 8)?,
        u_offset: single(bytes, at + 12)?,
        v_offset: single(bytes, at + 16)?,
        flags: word(bytes, at + 20)?,
    })
}

/// A plane's three singles at a byte.
fn plane(bytes: &[u8], at: usize) -> Result<Plane, String> {
    Ok(Plane { a: single(bytes, at)?, b: single(bytes, at + 4)?, c: single(bytes, at + 8)? })
}

/// A map from its bytes: the header, the directory, and the sections read.
pub(crate) fn parse_map(bytes: &[u8]) -> Result<Map, String> {
    if word(bytes, 0)? != MAP_MAGIC {
        return Err("not a Jab FPS map: its magic is not JAB and a zero".to_string());
    }
    let count = word(bytes, 4)? as usize;
    let mut sections: BTreeMap<u32, (usize, usize)> = BTreeMap::new();
    for entry in 0..count {
        let at = 8 + entry * 16;
        let kind = word(bytes, at)?;
        let offset = word(bytes, at + 4)? as usize;
        let size = word(bytes, at + 8)? as usize;
        let records = word(bytes, at + 12)? as usize;
        let expected = match kind {
            1 => 1,
            2 | 3 | 5 | 7 => 8,
            4 => 112,
            6 => 52,
            8 => 72,
            9 | 10 => 4,
            _ => return Err(format!("a section of kind {kind}, which the format does not have")),
        };
        if size != expected {
            return Err(format!("kind {kind}'s records are {size} bytes where the format's are {expected}"));
        }
        if offset + size * records > bytes.len() {
            return Err(format!("kind {kind}'s section runs past the map's {} bytes", bytes.len()));
        }
        if sections.insert(kind, (offset, records)).is_some() {
            return Err(format!("kind {kind} appears twice in the directory"));
        }
    }
    let section = |kind: u32| sections.get(&kind).copied().ok_or_else(|| format!("no section of kind {kind}"));
    let (names_at, names_len) = section(1)?;
    let name = |offset: usize| -> Result<String, String> {
        let start = names_at + offset;
        let table = bytes.get(start..names_at + names_len).ok_or_else(|| format!("a name at {offset}, past the names"))?;
        let end = table.iter().position(|&b| b == 0).ok_or_else(|| format!("the name at {offset} has no terminator"))?;
        Ok(String::from_utf8_lossy(&table[..end]).into_owned())
    };
    let (at, n) = section(2)?;
    let materials = (0..n).map(|i| name(word(bytes, at + i * 8)? as usize)).collect::<Result<Vec<_>, _>>()?;
    let (at, n) = section(3)?;
    let vertices = (0..n).map(|i| Ok([single(bytes, at + i * 8)?, single(bytes, at + i * 8 + 4)?])).collect::<Result<Vec<_>, String>>()?;
    let (at, n) = section(4)?;
    let sectors = (0..n)
        .map(|i| {
            let r = at + i * 112;
            Ok(Sector { floor: plane(bytes, r)?, ceiling: plane(bytes, r + 12)?, floor_surface: surface(bytes, r + 24)?, ceiling_surface: surface(bytes, r + 48)? })
        })
        .collect::<Result<Vec<_>, String>>()?;
    let (at, n) = section(6)?;
    let walls = (0..n)
        .map(|i| {
            let r = at + i * 52;
            let wall = Wall { a: word(bytes, r)? as usize, b: word(bytes, r + 4)? as usize, surface: surface(bytes, r + 12)?, anchor: single(bytes, r + 36)? };
            if wall.a >= vertices.len() || wall.b >= vertices.len() {
                return Err(format!("wall {i}'s vertices lie past the {} the map holds", vertices.len()));
            }
            Ok(wall)
        })
        .collect::<Result<Vec<_>, String>>()?;
    let (at, n) = section(8)?;
    let entities = (0..n)
        .map(|i| {
            let r = at + i * 72;
            Ok(Entity {
                class: word(bytes, r)?,
                position: [single(bytes, r + 4)?, single(bytes, r + 8)?, single(bytes, r + 12)?],
                yaw: single(bytes, r + 16)?,
                width: single(bytes, r + 24)?,
                height: single(bytes, r + 28)?,
                material: word(bytes, r + 32)? as i32,
                flags: word(bytes, r + 56)?,
            })
        })
        .collect::<Result<Vec<_>, String>>()?;
    Ok(Map { materials, vertices, sectors, walls, entities })
}
