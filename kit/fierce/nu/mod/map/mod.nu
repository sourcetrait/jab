# The map file's magic word: JAB and a zero, little-endian
export const magic = 0x0042414a

# The map file's header in bytes: the magic and the section count
export const header_size = 8

# A section directory entry's bytes: kind, offset, record size, count
export const entry_size = 16

# The map's section kinds by name, as the directory numbers them
export const kinds = { names: 1, materials: 2, vertices: 3, sectors: 4, loops: 5, walls: 6, portals: 7, entities: 8, ambients: 9, sector_lights: 10 }

# Each section's record size in bytes, the names table aside
export const sizes = { materials: 8, vertices: 8, sectors: 112, loops: 8, walls: 52, portals: 8, entities: 72, ambients: 4, sector_lights: 4 }

# A surface's bytes: material, scales, offsets, and flags
const surface_size = 24

# The entity classes, in the order the map numbers them
export const classes = [spawn light sprite waypoint android magazine]

# A map's counts and its spawn printed as one NUON record
export def show [map: path]: nothing -> nothing {
    let m = (read $map)
    summary $m | to nuon | print
}

# The romfs path a material's name maps to: a leading slash and .png
export def tile-path [name: string]: nothing -> string {
    "/" + $name + ".png"
}

# A map file read whole, held to the format: ranges, portals, entities
export def read [path: path]: [
    nothing -> record<
        materials: table<name: string, flags: int>,
        vertices: table<x: float, y: float>,
        sectors: table<floor: record<a: float, b: float, c: float>, ceiling: record<a: float, b: float, c: float>, floor_surface: record<material: int, u_scale: float, v_scale: float, u_offset: float, v_offset: float, flags: int>, ceiling_surface: record<material: int, u_scale: float, v_scale: float, u_offset: float, v_offset: float, flags: int>, first_loop: int, loop_count: int, bounds: record<min_x: float, min_y: float, max_x: float, max_y: float>, tag: int, ambient: int, first_light: int, light_count: int>,
        loops: table<first_wall: int, wall_count: int>,
        walls: table<a: int, b: int, sector: int, surface: record<material: int, u_scale: float, v_scale: float, u_offset: float, v_offset: float, flags: int>, anchor: float, first_portal: int, portal_count: int, tag: int>,
        portals: table<sector: int, wall: int>,
        entities: table<class: int, x: float, y: float, z: float, yaw: float, pitch: float, width: float, height: float, material: int, r: float, g: float, b: float, radius: float, spread: float, flags: int, tag: int, target: int, sector: int>,
        ambients: table<name: string>,
        sector_lights: list<int>
    >
] {
    let b = (open --raw $path | into binary)
    let len = ($b | bytes length)
    if $len < $header_size { error make { msg: $"($path): ($len) bytes, too short for a Jab FPS map's header" } }
    if (u32 $b 0) != $magic { error make { msg: $"($path): not a Jab FPS map" } }
    let count = (u32 $b 4)
    if ($header_size + $count * $entry_size) > $len { error make { msg: $"($path): the section directory runs past ($len) bytes" } }
    let entries = (0..<$count | each {|i|
        let o = ($header_size + $i * $entry_size)
        { kind: (u32 $b $o), offset: (u32 $b ($o + 4)), size: (u32 $b ($o + 8)), count: (u32 $b ($o + 12)) }
    })
    for e in $entries {
        if ($e.offset + $e.size * $e.count) > $len { error make { msg: $"($path): section kind ($e.kind) runs past ($len) bytes" } }
        if ($e.offset mod 4) != 0 { error make { msg: $"($path): section kind ($e.kind) starts off a word boundary" } }
        let name = ($kinds | transpose name kind | where kind == $e.kind | get -o 0.name)
        if $name == null { error make { msg: $"($path): section kind ($e.kind) is not one the format has" } }
        if $name != "names" and $e.size != ($sizes | get $name) { error make { msg: $"($path): ($name) records of ($e.size) bytes, the format's ($sizes | get $name)" } }
    }
    let kinds_seen = ($entries | get kind)
    if ($kinds_seen | uniq | length) != ($kinds_seen | length) { error make { msg: $"($path): a section kind appears twice" } }
    let sec = {|name: string|
        let e = ($entries | where kind == ($kinds | get $name))
        if ($e | is-empty) { error make { msg: $"($path): no ($name) section" } }
        $e | get 0
    }
    let names = (do $sec names)
    let name_at = {|off: int|
        if $off >= $names.count { error make { msg: $"($path): a name at ($off) lies past the names table" } }
        let start = ($names.offset + $off)
        let nul = ($b | bytes at $start..<($names.offset + $names.count) | bytes index-of 0x[00])
        if $nul < 0 { error make { msg: $"($path): a name at ($off) has no end" } }
        $b | bytes at $start..<($start + $nul) | decode
    }
    let materials = (records (do $sec materials) {|o| { name: (do $name_at (u32 $b $o)), flags: (u32 $b ($o + 4)) } })
    let vertices = (records (do $sec vertices) {|o| { x: (f32 $b $o), y: (f32 $b ($o + 4)) } })
    let sectors = (records (do $sec sectors) {|o| {
        floor: { a: (f32 $b $o), b: (f32 $b ($o + 4)), c: (f32 $b ($o + 8)) },
        ceiling: { a: (f32 $b ($o + 12)), b: (f32 $b ($o + 16)), c: (f32 $b ($o + 20)) },
        floor_surface: (surface-at $b ($o + 24)), ceiling_surface: (surface-at $b ($o + 48)),
        first_loop: (u32 $b ($o + 72)), loop_count: (u32 $b ($o + 76)),
        bounds: { min_x: (f32 $b ($o + 80)), min_y: (f32 $b ($o + 84)), max_x: (f32 $b ($o + 88)), max_y: (f32 $b ($o + 92)) },
        tag: (i32 $b ($o + 96)), ambient: (i32 $b ($o + 100)), first_light: (u32 $b ($o + 104)), light_count: (u32 $b ($o + 108)),
    } })
    let loops = (records (do $sec loops) {|o| { first_wall: (u32 $b $o), wall_count: (u32 $b ($o + 4)) } })
    let walls = (records (do $sec walls) {|o| {
        a: (u32 $b $o), b: (u32 $b ($o + 4)), sector: (u32 $b ($o + 8)), surface: (surface-at $b ($o + 12)),
        anchor: (f32 $b ($o + 36)), first_portal: (u32 $b ($o + 40)), portal_count: (u32 $b ($o + 44)), tag: (i32 $b ($o + 48)),
    } })
    let portals = (records (do $sec portals) {|o| { sector: (u32 $b $o), wall: (u32 $b ($o + 4)) } })
    let entities = (records (do $sec entities) {|o| {
        class: (u32 $b $o), x: (f32 $b ($o + 4)), y: (f32 $b ($o + 8)), z: (f32 $b ($o + 12)), yaw: (f32 $b ($o + 16)), pitch: (f32 $b ($o + 20)),
        width: (f32 $b ($o + 24)), height: (f32 $b ($o + 28)), material: (i32 $b ($o + 32)),
        r: (f32 $b ($o + 36)), g: (f32 $b ($o + 40)), b: (f32 $b ($o + 44)), radius: (f32 $b ($o + 48)), spread: (f32 $b ($o + 52)),
        flags: (u32 $b ($o + 56)), tag: (i32 $b ($o + 60)), target: (i32 $b ($o + 64)), sector: (i32 $b ($o + 68)),
    } })
    let ambients = (records (do $sec ambients) {|o| { name: (do $name_at (u32 $b $o)) } })
    let sector_lights = (records (do $sec sector_lights) {|o| u32 $b $o })
    let m = { materials: $materials, vertices: $vertices, sectors: $sectors, loops: $loops, walls: $walls, portals: $portals, entities: $entities, ambients: $ambients, sector_lights: $sector_lights }
    check $m $path
    $m
}

# A section's records, a closure applied to each record's offset
def records [e: record, f: closure]: nothing -> list<any> {
    0..<$e.count | each {|i| do $f ($e.offset + $i * $e.size) }
}

# A surface read at an offset: material, scales, offsets, flags
def surface-at [b: binary, o: int]: nothing -> record<material: int, u_scale: float, v_scale: float, u_offset: float, v_offset: float, flags: int> {
    { material: (i32 $b $o), u_scale: (f32 $b ($o + 4)), v_scale: (f32 $b ($o + 8)), u_offset: (f32 $b ($o + 12)), v_offset: (f32 $b ($o + 16)), flags: (u32 $b ($o + 20)) }
}

# The format's rules held over a map record, as the loader holds them
def check [m: record, path: string]: nothing -> nothing {
    let ns = ($m.sectors | length)
    let nw = ($m.walls | length)
    let nv = ($m.vertices | length)
    let np = ($m.portals | length)
    let nl = ($m.loops | length)
    let ne = ($m.entities | length)
    let nm = ($m.materials | length)
    let na = ($m.ambients | length)
    let nsl = ($m.sector_lights | length)
    for s in ($m.sectors | enumerate) {
        let sec = $s.item
        if $sec.loop_count < 1 or ($sec.first_loop + $sec.loop_count) > $nl { error make { msg: $"($path): sector ($s.index)'s loops are out of range" } }
        if ($sec.first_light + $sec.light_count) > $nsl { error make { msg: $"($path): sector ($s.index)'s lights are out of range" } }
        if $sec.ambient >= $na { error make { msg: $"($path): sector ($s.index)'s ambient is out of range" } }
        if $sec.floor_surface.material >= $nm or $sec.ceiling_surface.material >= $nm { error make { msg: $"($path): sector ($s.index)'s materials are out of range" } }
        for li in $sec.first_loop..<($sec.first_loop + $sec.loop_count) {
            let lp = ($m.loops | get $li)
            if $lp.wall_count < 3 or ($lp.first_wall + $lp.wall_count) > $nw { error make { msg: $"($path): loop ($li) has ($lp.wall_count) walls or runs out of range" } }
            for wi in $lp.first_wall..<($lp.first_wall + $lp.wall_count) {
                let w = ($m.walls | get $wi)
                if $w.sector != $s.index { error make { msg: $"($path): wall ($wi) belongs to sector ($w.sector), not ($s.index)" } }
                let next = ($m.walls | get (if ($wi + 1) < ($lp.first_wall + $lp.wall_count) { $wi + 1 } else { $lp.first_wall }))
                if $w.b != $next.a { error make { msg: $"($path): wall ($wi) does not lead to the next around its loop" } }
            }
        }
    }
    for w in ($m.walls | enumerate) {
        let wall = $w.item
        if $wall.a >= $nv or $wall.b >= $nv or $wall.a == $wall.b { error make { msg: $"($path): wall ($w.index)'s vertices are out of range or the same" } }
        if $wall.sector >= $ns { error make { msg: $"($path): wall ($w.index)'s sector is out of range" } }
        if ($wall.first_portal + $wall.portal_count) > $np { error make { msg: $"($path): wall ($w.index)'s portals are out of range" } }
        if $wall.surface.material >= $nm { error make { msg: $"($path): wall ($w.index)'s material is out of range" } }
        for pi in $wall.first_portal..<($wall.first_portal + $wall.portal_count) {
            let p = ($m.portals | get $pi)
            if $p.sector >= $ns or $p.wall >= $nw { error make { msg: $"($path): portal ($pi) is out of range" } }
            let across = ($m.walls | get $p.wall)
            if $across.sector != $p.sector or $across.sector == $wall.sector or $across.a != $wall.b or $across.b != $wall.a {
                error make { msg: $"($path): portal ($pi) of wall ($w.index) is not exact" }
            }
        }
    }
    for e in ($m.entities | enumerate) {
        let ent = $e.item
        if $ent.class >= ($classes | length) { error make { msg: $"($path): entity ($e.index)'s class ($ent.class) is not one the format has" } }
        if $ent.material >= $nm or $ent.target >= $ne or $ent.sector >= $ns or $ent.sector < 0 { error make { msg: $"($path): entity ($e.index)'s references are out of range" } }
        if not (holds-plan $m $ent.sector $ent.x $ent.y) { error make { msg: $"($path): entity ($e.index) at ($ent.x), ($ent.y) is not in sector ($ent.sector)" } }
    }
    for li in $m.sector_lights {
        if $li >= $ne or (($m.entities | get $li | get class) != 1) { error make { msg: $"($path): a sector's light ($li) is not a light" } }
    }
}

# Whether a sector holds a plan point, by the even-odd rule over its loops
export def holds-plan [m: record, s: int, x: float, y: float]: nothing -> bool {
    let sec = ($m.sectors | get $s)
    mut crossings = 0
    for li in $sec.first_loop..<($sec.first_loop + $sec.loop_count) {
        let lp = ($m.loops | get $li)
        for wi in $lp.first_wall..<($lp.first_wall + $lp.wall_count) {
            let w = ($m.walls | get $wi)
            let a = ($m.vertices | get $w.a)
            let b = ($m.vertices | get $w.b)
            if (($a.y > $y) != ($b.y > $y)) {
                let xi = ($a.x + ($y - $a.y) * ($b.x - $a.x) / ($b.y - $a.y))
                if $xi > $x { $crossings = ($crossings + 1) }
            }
        }
    }
    ($crossings mod 2) == 1
}

# A plane's height at a point
export def plane-z [p: record, x: float, y: float]: nothing -> float {
    $p.a * $x + $p.b * $y + $p.c
}

# The sector holding a point by loops, and planes unless `--plan`; -1 for none
export def sector-holding [m: record, x: float, y: float, z: float, --plan]: nothing -> int {
    let found = ($m.sectors | enumerate | where {|s|
        (holds-plan $m $s.index $x $y) and ($plan or (($z >= ((plane-z $s.item.floor $x $y) - 0.001)) and ($z <= ((plane-z $s.item.ceiling $x $y) + 0.001))))
    } | get -o 0.index)
    if $found == null { -1 } else { $found }
}

# A map's counts and its spawn
export def summary [m: record]: nothing -> record<sectors: int, walls: int, vertices: int, portals: int, materials: int, entities: int, lights: int, sprites: int, ambients: int, spawn: record<at: list<float>, yaw: float, pitch: float>> {
    let spawn = ($m.entities | where class == 0 | get -o 0)
    {
        sectors: ($m.sectors | length), walls: ($m.walls | length), vertices: ($m.vertices | length), portals: ($m.portals | length),
        materials: ($m.materials | length), entities: ($m.entities | length),
        lights: ($m.entities | where class == 1 | length), sprites: ($m.entities | where class == 2 | length),
        ambients: ($m.ambients | length),
        spawn: (if $spawn == null { { at: [0.0, 0.0, 0.0], yaw: 0.0, pitch: 0.0 } } else { { at: [$spawn.x, $spawn.y, $spawn.z], yaw: $spawn.yaw, pitch: $spawn.pitch } }),
    }
}

# A little-endian unsigned 32-bit word at a byte offset
def u32 [b: binary, off: int]: nothing -> int { $b | bytes at $off..<($off + 4) | into int --endian little }

# A little-endian signed 32-bit word at a byte offset
def i32 [b: binary, off: int]: nothing -> int { $b | bytes at $off..<($off + 4) | into int --endian little --signed }

# A single read at an offset of any bytes, the program's records among them
export def float-at [b: binary, off: int]: nothing -> float {
    f32 $b $off
}

# A host float as a single's four little-endian bytes, rounded to nearest
export def float-bytes [v: float]: nothing -> binary {
    let bits = ($v | into binary | into int --endian little --signed)
    let sign = (if $bits < 0 { 1 } else { 0 })
    let exp = (($bits bit-shr 52) bit-and 0x7FF)
    let mant = ($bits bit-and 0xFFFFFFFFFFFFF)
    if $exp == 0 { return (if $sign == 1 { 0x[00 00 00 80] } else { 0x[00 00 00 00] }) }
    let e32 = ($exp - 1023 + 127)
    if $e32 <= 0 { return 0x[00 00 00 00] }
    if $e32 >= 255 { error make { msg: $"($v) does not fit a single" } }
    mut m = (($mant + (1 bit-shl 28)) bit-shr 29)
    mut e = $e32
    if $m >= 8388608 { $m = 0; $e = ($e + 1) }
    let out = (($sign bit-shl 31) bit-or ($e bit-shl 23) bit-or $m)
    $out | into binary --endian little | bytes at 0..<4
}

# An IEEE 754 single at an offset, exact in the host's double
def f32 [b: binary, off: int]: nothing -> float {
    let u = (u32 $b $off)
    let sign = (if ($u bit-shr 31) == 1 { -1.0 } else { 1.0 })
    let exp = (($u bit-shr 23) bit-and 0xff)
    let man = ($u bit-and 0x7fffff)
    if $exp == 0 {
        $sign * ($man / 8388608.0) * (2.0 ** -126)
    } else if $exp == 255 {
        if $man == 0 { $sign * inf } else { nan }
    } else {
        $sign * (1.0 + ($man / 8388608.0)) * (2.0 ** ($exp - 127))
    }
}
