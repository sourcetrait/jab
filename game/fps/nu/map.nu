# The Jab FPS map on the host. `read` parses <name>.jabfps.map into a
# record, every section a table with its names resolved, and holds the
# file to the format's rules, stopping where it breaks one; `write`
# encodes such a record; `build` turns a map source into that record,
# the vertices shared, the windings fixed, the portals, bounds, and
# light lists computed; `float-at` and `float-bytes` read and write the
# singles the file and the program's records carry. Run as a script it
# is the compiler: `nu map.nu compile <source> <out> [--content <dir>]`
# writes the tree the engine reads under <out>/<name>/ with a plan view
# an SVG a storey. src/map.inc spells the same layout.
use ../../../sdk/nu/jab.nu

const magic = 0x0042414a            # JAB and a zero, little-endian
const header_size = 8
const entry_size = 16
const kinds = { names: 1, materials: 2, vertices: 3, sectors: 4, loops: 5, walls: 6, portals: 7, entities: 8, ambients: 9, sector_lights: 10 }
const sizes = { materials: 8, vertices: 8, sectors: 112, loops: 8, walls: 52, portals: 8, entities: 72, ambients: 4, sector_lights: 4 }
const surface_size = 24
const classes = [spawn light sprite waypoint android magazine]
const surface_solid = 1
const surface_masked = 2
const surface_sky = 4
const entity_camera = 1
const entity_flat = 2
const entity_two_sided = 4
const entity_solid = 8
const snap = 1024.0
const plan_scale = 24
const plan_margin = 1.0
const here = (path self | path dirname)
# The plan view's labels are drawn in the kernel's console font, the
# glyph table the kernel assembles, so the renderer needs no font
const font_path = ($here | path join ".." ".." ".." "kernel" "src" "font.S")
const glyph_width = 12
const glyph_height = 24

def main [] {
    print "map.nu compile <source> <out> [--content <dir>] | show <map>"
}

# The source compiled into the tree under <out>/<name>/: the map, the
# name file and the title's when the source gives a title, every
# material and ambient the map names copied from the content, map.nuon
# and tile.nuon, and a plan view an SVG a storey.
def "main compile" [source: path, out: path, --content: path = ""] {
    let content = (if $content == "" { $here | path dirname | path join "content" } else { $content | path expand })
    let src = (open $source)
    let m = (build $src)
    let summary = (lay-out $src $m $content ($out | path expand))
    print $"map: ($src.name) at ($out | path expand | path join $src.name): ($summary)"
}

# The map's counts and its spawn, as one NUON record.
def "main show" [map: path] {
    let m = (read $map)
    summary $m | to nuon | print
}

# The romfs path a material's name maps to: a leading slash and .png.
export def tile-path [name: string]: nothing -> string {
    "/" + $name + ".png"
}

# The whole map, held to the format: the directory within the file,
# every section once at its record size, every index in range, every
# portal exact, every entity in its sector by the loops and the planes.
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

# The record count of a section applied to a closure of each record's
# offset.
def records [e: record, f: closure]: nothing -> list<any> {
    0..<$e.count | each {|i| do $f ($e.offset + $i * $e.size) }
}

# A surface at an offset.
def surface-at [b: binary, o: int]: nothing -> record<material: int, u_scale: float, v_scale: float, u_offset: float, v_offset: float, flags: int> {
    { material: (i32 $b $o), u_scale: (f32 $b ($o + 4)), v_scale: (f32 $b ($o + 8)), u_offset: (f32 $b ($o + 12)), v_offset: (f32 $b ($o + 16)), flags: (u32 $b ($o + 20)) }
}

# The format's rules over a record, as the loader holds them.
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

# Whether the sector holds the point in the plan, by the even-odd rule
# over its loops.
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

# A plane's height at a point.
export def plane-z [p: record, x: float, y: float]: nothing -> float {
    $p.a * $x + $p.b * $y + $p.c
}

# The sector holding a point: in the plan by the loops, and, unless
# `--plan` alone, with z between the floor and the ceiling there; -1
# for none.
export def sector-holding [m: record, x: float, y: float, z: float, --plan]: nothing -> int {
    let found = ($m.sectors | enumerate | where {|s|
        (holds-plan $m $s.index $x $y) and ($plan or (($z >= ((plane-z $s.item.floor $x $y) - 0.001)) and ($z <= ((plane-z $s.item.ceiling $x $y) + 0.001))))
    } | get -o 0.index)
    if $found == null { -1 } else { $found }
}

# The map's counts and its spawn.
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

# The record encoded as the file's bytes.
export def write [m: record]: nothing -> binary {
    let names = (($m.materials | get name) ++ ($m.ambients | get name) | uniq)
    mut table = 0x[]
    mut offsets = {}
    for n in $names {
        $offsets = ($offsets | insert $n ($table | bytes length))
        $table = ([$table, ($n | into binary), 0x[00]] | bytes collect)
    }
    let offsets = $offsets
    let materials = (collect ($m.materials | each {|r| [(u32b ($offsets | get $r.name)), (u32b $r.flags)] | bytes collect }))
    let vertices = (collect ($m.vertices | each {|v| [(f32b $v.x), (f32b $v.y)] | bytes collect }))
    let sectors = (collect ($m.sectors | each {|s| [
        (f32b $s.floor.a), (f32b $s.floor.b), (f32b $s.floor.c), (f32b $s.ceiling.a), (f32b $s.ceiling.b), (f32b $s.ceiling.c),
        (surface-bytes $s.floor_surface), (surface-bytes $s.ceiling_surface),
        (u32b $s.first_loop), (u32b $s.loop_count),
        (f32b $s.bounds.min_x), (f32b $s.bounds.min_y), (f32b $s.bounds.max_x), (f32b $s.bounds.max_y),
        (i32b $s.tag), (i32b $s.ambient), (u32b $s.first_light), (u32b $s.light_count),
    ] | bytes collect }))
    let loops = (collect ($m.loops | each {|l| [(u32b $l.first_wall), (u32b $l.wall_count)] | bytes collect }))
    let walls = (collect ($m.walls | each {|w| [
        (u32b $w.a), (u32b $w.b), (u32b $w.sector), (surface-bytes $w.surface), (f32b $w.anchor),
        (u32b $w.first_portal), (u32b $w.portal_count), (i32b $w.tag),
    ] | bytes collect }))
    let portals = (collect ($m.portals | each {|p| [(u32b $p.sector), (u32b $p.wall)] | bytes collect }))
    let entities = (collect ($m.entities | each {|e| [
        (u32b $e.class), (f32b $e.x), (f32b $e.y), (f32b $e.z), (f32b $e.yaw), (f32b $e.pitch), (f32b $e.width), (f32b $e.height),
        (i32b $e.material), (f32b $e.r), (f32b $e.g), (f32b $e.b), (f32b $e.radius), (f32b $e.spread),
        (u32b $e.flags), (i32b $e.tag), (i32b $e.target), (i32b $e.sector),
    ] | bytes collect }))
    let ambients = (collect ($m.ambients | each {|a| u32b ($offsets | get $a.name) }))
    let sector_lights = (collect ($m.sector_lights | each {|l| u32b $l }))
    let sections = [
        { kind: $kinds.names, bytes: $table, size: 1, count: ($table | bytes length) },
        { kind: $kinds.materials, bytes: $materials, size: $sizes.materials, count: ($m.materials | length) },
        { kind: $kinds.vertices, bytes: $vertices, size: $sizes.vertices, count: ($m.vertices | length) },
        { kind: $kinds.sectors, bytes: $sectors, size: $sizes.sectors, count: ($m.sectors | length) },
        { kind: $kinds.loops, bytes: $loops, size: $sizes.loops, count: ($m.loops | length) },
        { kind: $kinds.walls, bytes: $walls, size: $sizes.walls, count: ($m.walls | length) },
        { kind: $kinds.portals, bytes: $portals, size: $sizes.portals, count: ($m.portals | length) },
        { kind: $kinds.entities, bytes: $entities, size: $sizes.entities, count: ($m.entities | length) },
        { kind: $kinds.ambients, bytes: $ambients, size: $sizes.ambients, count: ($m.ambients | length) },
        { kind: $kinds.sector_lights, bytes: $sector_lights, size: $sizes.sector_lights, count: ($m.sector_lights | length) },
    ]
    # every section on a word boundary, the names table padded with
    # zeros past its count, so the program reads every record in place
    mut offset = ($header_size + ($sections | length) * $entry_size)
    mut directory = []
    mut bodies = []
    for s in $sections {
        $directory = ($directory | append ([(u32b $s.kind), (u32b $offset), (u32b $s.size), (u32b $s.count)] | bytes collect))
        let body = (padded $s.bytes)
        $bodies = ($bodies | append $body)
        $offset = ($offset + ($body | bytes length))
    }
    [(u32b $magic), (u32b ($sections | length)), (collect $directory), (collect $bodies)] | bytes collect
}

# The bytes padded with zeros to a multiple of four.
def padded [bytes: binary]: nothing -> binary {
    let pad = ((4 - (($bytes | bytes length) mod 4)) mod 4)
    if $pad == 0 { $bytes } else { [$bytes, (1..$pad | each {|_| 0x[00] } | bytes collect)] | bytes collect }
}

# A list of byte chunks as one, an empty list as no bytes.
def collect [chunks: list<binary>]: nothing -> binary {
    if ($chunks | is-empty) { 0x[] } else { $chunks | bytes collect }
}

def surface-bytes [s: record]: nothing -> binary {
    [(i32b $s.material), (f32b $s.u_scale), (f32b $s.v_scale), (f32b $s.u_offset), (f32b $s.v_offset), (u32b $s.flags)] | bytes collect
}

# A map source as the map record: the vertices shared to a thousandth,
# each loop's winding fixed, the planes from heights and slopes, the
# walls with their overrides and anchors, the portals by the edge rule,
# the bounds, the entities with their sectors, and each sector's light
# list. Stops on what the source gets wrong.
export def build [src: record]: nothing -> record {
    mut vertices = []
    mut vkeys = {}
    mut materials = []
    mut ambients = []
    mut sectors = []
    mut loops = []
    mut walls = []
    let sector_names = ($src.sectors | get name)
    for s in ($src.sectors | enumerate) {
        let sec = $s.item
        if ($sec.loops | is-empty) { error make { msg: $"sector ($sec.name) has no loops" } }
        let outer = ($sec.loops | get 0 | each {|p| point $p })
        if ($outer | length) < 3 { error make { msg: $"sector ($sec.name)'s outer loop has under three points" } }
        let p0 = ($outer | get 0)
        let floor = (plane-of $sec.floor $p0)
        let ceiling = (plane-of $sec.ceiling $p0)
        let floor_m = (material-index $materials $"texture/($sec.floor.material)")
        $materials = $floor_m.materials
        let ceiling_m = (material-index $materials $"texture/($sec.ceiling.material)")
        $materials = $ceiling_m.materials
        let floor_surface = (surface-of $sec.floor $floor_m.index (if $sec.floor.sky { $surface_sky } else { 0 }))
        let ceiling_surface = (surface-of $sec.ceiling $ceiling_m.index (if $sec.ceiling.sky { $surface_sky } else { 0 }))
        let first_loop = ($loops | length)
        mut min_x = $p0.x
        mut min_y = $p0.y
        mut max_x = $p0.x
        mut max_y = $p0.y
        for l in ($sec.loops | enumerate) {
            let points = ($l.item | each {|p| point $p })
            let n = ($points | length)
            if $n < 3 { error make { msg: $"sector ($sec.name)'s loop ($l.index) has under three points" } }
            if (($points | each {|p| $"($p.x),($p.y)" } | uniq | length) != $n) { error make { msg: $"sector ($sec.name)'s loop ($l.index) repeats a point" } }
            for p in $points {
                if $p.x < $min_x { $min_x = $p.x }
                if $p.y < $min_y { $min_y = $p.y }
                if $p.x > $max_x { $max_x = $p.x }
                if $p.y > $max_y { $max_y = $p.y }
            }
            # the walls in the author's order, each with its surface
            mut loop_walls = []
            for i in 0..<$n {
                let a = ($points | get $i)
                let b = ($points | get (($i + 1) mod $n))
                let over = ($sec.walls | where loop == $l.index and edge == $i)
                let spec = (if ($over | is-empty) { $sec.wall } else { $over | get 0 })
                let m = (material-index $materials $"texture/($spec.material)")
                $materials = $m.materials
                let flags = ((if $spec.solid { $surface_solid } else { 0 }) + (if $spec.masked { $surface_masked } else { 0 }) + (if $spec.sky { $surface_sky } else { 0 }))
                $loop_walls = ($loop_walls | append { a: $a, b: $b, surface: (surface-of $spec $m.index $flags), anchor_spec: $spec.anchor, tag: $spec.tag })
            }
            # the winding: the outer loop counter-clockwise, a hole clockwise
            let area = (signed-area $points)
            if $area == 0.0 { error make { msg: $"sector ($sec.name)'s loop ($l.index) has no area" } }
            if ($l.index == 0 and $area < 0.0) or ($l.index > 0 and $area > 0.0) {
                $loop_walls = ($loop_walls | reverse | each {|w| $w | update a $w.b | update b $w.a })
            }
            let first_wall = ($walls | length)
            for w in $loop_walls {
                let va = (vertex-index $vertices $vkeys $w.a)
                $vertices = $va.vertices
                $vkeys = $va.keys
                let vb = (vertex-index $vertices $vkeys $w.b)
                $vertices = $vb.vertices
                $vkeys = $vb.keys
                let anchor = (match ($w.anchor_spec | describe) {
                    "string" => (if $w.anchor_spec == "top" { plane-z $ceiling $w.a.x $w.a.y } else if $w.anchor_spec == "bottom" { plane-z $floor $w.a.x $w.a.y } else { error make { msg: $"sector ($sec.name): an anchor is top, bottom, or a height, not ($w.anchor_spec)" } }),
                    _ => ($w.anchor_spec | into float),
                })
                $walls = ($walls | append { a: $va.index, b: $vb.index, sector: $s.index, surface: $w.surface, anchor: $anchor, first_portal: 0, portal_count: 0, tag: $w.tag })
            }
            $loops = ($loops | append { first_wall: $first_wall, wall_count: $n })
        }
        let ambient = (if ($sec.ambient | is-empty) { -1 } else {
            let a = (material-index $ambients $"ambient/($sec.ambient)")
            $ambients = $a.materials
            $a.index
        })
        $sectors = ($sectors | append {
            floor: $floor, ceiling: $ceiling, floor_surface: $floor_surface, ceiling_surface: $ceiling_surface,
            first_loop: $first_loop, loop_count: ($sec.loops | length),
            bounds: { min_x: $min_x, min_y: $min_y, max_x: $max_x, max_y: $max_y },
            tag: $sec.tag, ambient: $ambient, first_light: 0, light_count: 0,
        })
    }
    # the portals: for every wall, the walls of other sectors running its
    # edge the other way whose height ranges overlap at either end,
    # sorted from the top down
    let vertices = $vertices
    let walls_built = $walls
    mut by_edge = {}
    for w in ($walls_built | enumerate) {
        let key = $"($w.item.a):($w.item.b)"
        let had = ($by_edge | get -o $key | default [])
        $by_edge = ($by_edge | upsert $key ($had | append $w.index))
    }
    let by_edge = $by_edge
    let sectors_built = $sectors
    mut portals = []
    mut walls_out = []
    for w in ($walls_built | enumerate) {
        let wall = $w.item
        let across = ($by_edge | get -o $"($wall.b):($wall.a)" | default [] | where {|o| ($walls_built | get $o | get sector) != $wall.sector })
        let pa = ($vertices | get $wall.a)
        let pb = ($vertices | get $wall.b)
        let mine = ($sectors_built | get $wall.sector)
        let touching = ($across | where {|o|
            let theirs = ($sectors_built | get ($walls_built | get $o | get sector))
            (ranges-overlap $mine $theirs $pa.x $pa.y) or (ranges-overlap $mine $theirs $pb.x $pb.y)
        })
        let mx = (($pa.x + $pb.x) / 2.0)
        let my = (($pa.y + $pb.y) / 2.0)
        let sorted = ($touching | sort-by --custom {|p, q|
            (plane-z ($sectors_built | get ($walls_built | get $p | get sector) | get ceiling) $mx $my) > (plane-z ($sectors_built | get ($walls_built | get $q | get sector) | get ceiling) $mx $my)
        })
        let first_portal = ($portals | length)
        for o in $sorted {
            $portals = ($portals | append { sector: ($walls_built | get $o | get sector), wall: $o })
        }
        $walls_out = ($walls_out | append ($wall | update first_portal $first_portal | update portal_count ($sorted | length)))
    }
    let walls = $walls_out
    # the entities, their sectors, and the sectors' light lists
    let model_geometry = { vertices: $vertices, sectors: $sectors_built, loops: $loops, walls: $walls }
    let entity_names = ($src.entities | get name)
    mut entities = []
    for e in ($src.entities | enumerate) {
        let ent = $e.item
        let class = ($classes | enumerate | where item == $ent.class | get -o 0.index)
        if $class == null { error make { msg: $"entity ($ent.name)'s class ($ent.class) is not one of ($classes | str join ', ')" } }
        let at = ($ent.at | each {|c| $c | into float })
        let material = (if ($ent.material | is-empty) { -1 } else {
            let m = (material-index $materials $"sprite/($ent.material)")
            $materials = $m.materials
            $m.index
        })
        let target = (if ($ent.target | is-empty) { -1 } else {
            let t = ($entity_names | enumerate | where item == $ent.target | get -o 0.index)
            if $t == null { error make { msg: $"entity ($ent.name) targets ($ent.target), which is no entity" } }
            $t
        })
        # the sector holding the entity by the loops and the planes; any
        # class but the spawn may sit above or below its sector's planes,
        # a light in a ceiling or a sprite sunk in a floor, and takes the
        # sector by the loops alone
        let full = (sector-holding $model_geometry $at.0 $at.1 $at.2)
        let sector = (if $full >= 0 or $class == 0 { $full } else { sector-holding $model_geometry $at.0 $at.1 $at.2 --plan })
        if $sector < 0 { error make { msg: $"entity ($ent.name) at ($at) is in no sector" } }
        let flags = ((match $ent.facing { "camera" => $entity_camera, "flat" => $entity_flat, "fixed" => 0, _ => (error make { msg: $"entity ($ent.name)'s facing ($ent.facing) is camera, fixed, or flat" }) }) + (if $ent.two_sided { $entity_two_sided } else { 0 }) + (if $ent.solid { $entity_solid } else { 0 }))
        let colour = ($ent.colour | each {|c| $c | into float })
        let size = ($ent.size | each {|c| $c | into float })
        $entities = ($entities | append {
            class: $class, x: $at.0, y: $at.1, z: $at.2, yaw: ($ent.yaw | into float), pitch: ($ent.pitch | into float),
            width: $size.0, height: $size.1, material: $material, r: $colour.0, g: $colour.1, b: $colour.2,
            radius: ($ent.radius | into float), spread: ($ent.spread | into float), flags: $flags, tag: $ent.tag, target: $target, sector: $sector,
        })
    }
    let entities = $entities
    if ($entities | where class == 0 | length) != 1 { error make { msg: $"the map has ($entities | where class == 0 | length) spawns; one is required" } }
    let lights = ($entities | enumerate | where {|e| $e.item.class == 1 })
    mut sector_lights = []
    mut sectors_out = []
    for s in $sectors_built {
        let reach = ($lights | where {|l|
            let e = $l.item
            let dx = ([($s.bounds.min_x - $e.x), 0.0, ($e.x - $s.bounds.max_x)] | math max)
            let dy = ([($s.bounds.min_y - $e.y), 0.0, ($e.y - $s.bounds.max_y)] | math max)
            ($dx * $dx + $dy * $dy) <= ($e.radius * $e.radius)
        } | get index)
        $sectors_out = ($sectors_out | append ($s | update first_light ($sector_lights | length) | update light_count ($reach | length)))
        $sector_lights = ($sector_lights ++ $reach)
    }
    {
        materials: ($materials | each {|n| { name: $n, flags: 0 } }),
        vertices: $vertices, sectors: $sectors_out, loops: $loops, walls: $walls, portals: $portals,
        entities: $entities, ambients: ($ambients | each {|n| { name: $n } }), sector_lights: $sector_lights,
    }
}

# A source point as floats.
def point [p: list<any>]: nothing -> record<x: float, y: float> {
    { x: ($p | get 0 | into float), y: ($p | get 1 | into float) }
}

# A plane from a height at the point and a slope.
def plane-of [spec: record, p0: record]: nothing -> record<a: float, b: float, c: float> {
    let a = ($spec.slope | get 0 | into float)
    let b = ($spec.slope | get 1 | into float)
    let h = ($spec.height | into float)
    { a: $a, b: $b, c: ($h - $a * $p0.x - $b * $p0.y) }
}

# A surface from a source's material spec.
def surface-of [spec: record, material: int, flags: int]: nothing -> record<material: int, u_scale: float, v_scale: float, u_offset: float, v_offset: float, flags: int> {
    { material: $material, u_scale: ($spec.scale | get 0 | into float), v_scale: ($spec.scale | get 1 | into float), u_offset: ($spec.offset | get 0 | into float), v_offset: ($spec.offset | get 1 | into float), flags: $flags }
}

# A name's index in a name list, appended when new.
def material-index [names: list<string>, name: string]: nothing -> record<materials: list<string>, index: int> {
    let found = ($names | enumerate | where item == $name | get -o 0.index)
    if $found == null { { materials: ($names | append $name), index: ($names | length) } } else { { materials: $names, index: $found } }
}

# A point's vertex index, shared to a thousandth, appended when new.
def vertex-index [vertices: list<record>, keys: record, p: record]: nothing -> record<vertices: list<record>, keys: record, index: int> {
    let x = ((($p.x * $snap) | math round) / $snap)
    let y = ((($p.y * $snap) | math round) / $snap)
    let key = $"($x):($y)"
    let found = ($keys | get -o $key)
    if $found == null {
        { vertices: ($vertices | append { x: $x, y: $y }), keys: ($keys | insert $key ($vertices | length)), index: ($vertices | length) }
    } else {
        { vertices: $vertices, keys: $keys, index: $found }
    }
}

# Twice a polygon's signed area, positive counter-clockwise with y up.
def signed-area [points: list<record>]: nothing -> float {
    let n = ($points | length)
    0..<$n | each {|i|
        let a = ($points | get $i)
        let b = ($points | get (($i + 1) mod $n))
        $a.x * $b.y - $b.x * $a.y
    } | math sum
}

# Whether two sectors' height ranges overlap at a point: the higher
# floor at or below the lower ceiling.
def ranges-overlap [s: record, t: record, x: float, y: float]: nothing -> bool {
    let floor = ([(plane-z $s.floor $x $y), (plane-z $t.floor $x $y)] | math max)
    let ceiling = ([(plane-z $s.ceiling $x $y), (plane-z $t.ceiling $x $y)] | math min)
    $floor <= $ceiling
}

# The tree written: the map, the name file and the title's when the
# source gives a title, the materials and ambients the map names and
# every sound copied from the content, map.nuon, tile.nuon, and the plan
# views; the summary line.
def lay-out [src: record, m: record, content: string, out: string]: nothing -> string {
    let dest = ($out | path join $src.name)
    if ($dest | path exists) {
        if not ((($dest | path join "map" "name") | path exists) or (ls -a $dest | is-empty)) { error make { msg: $"($dest) is not a tree the compiler wrote; not retiring it" } }
        jab retire $dest
    }
    mkdir ($dest | path join "map")
    let bytes = (write $m)
    $bytes | save --raw -f ($dest | path join "map" $"($src.name).jabfps.map")
    $src.name | save --raw -f ($dest | path join "map" "name")
    let title = ($src.title? | default "")
    if $title != "" { $title | save --raw -f ($dest | path join "map" "title") }
    mut unresolved = []
    mut tiles = []
    for t in ($m.materials | enumerate) {
        let source = ($content | path join $"($t.item.name).png")
        let path = (tile-path $t.item.name)
        if ($source | path exists) {
            let file = ($dest | path join ($path | str substring 1..))
            mkdir ($file | path dirname)
            cp $source $file
            $tiles = ($tiles | append { index: $t.index, name: $t.item.name, path: $path, source: $source })
        } else {
            $unresolved = ($unresolved | append $t.item.name)
            $tiles = ($tiles | append { index: $t.index, name: $t.item.name, path: $path, source: "" })
        }
    }
    for a in $m.ambients {
        let source = ($content | path join $"($a.name).mid")
        if ($source | path exists) {
            let file = ($dest | path join $"($a.name).mid")
            mkdir ($file | path dirname)
            cp $source $file
        } else {
            $unresolved = ($unresolved | append $a.name)
        }
    }
    # every sound the content holds, since the game's tables name them
    # rather than the map, and every sprite image likewise, the
    # androids' frames and the gun's among them
    let sounds = (glob ($content | path join "sound" "*.pcm"))
    if not ($sounds | is-empty) { mkdir ($dest | path join "sound") }
    for p in $sounds {
        cp $p ($dest | path join "sound" ($p | path basename))
    }
    let sprite_root = ($content | path join "sprite")
    let sprites = (glob ($sprite_root | path join "**" "*.png"))
    for p in $sprites {
        let file = ($dest | path join "sprite" ($p | path relative-to $sprite_root))
        mkdir ($file | path dirname)
        cp $p $file
    }
    let s = (summary $m)
    let info = ($s | merge { name: $src.name, bytes: ($bytes | bytes length), sounds: ($sounds | length), sprite_files: ($sprites | length), unresolved: ($unresolved | length), missing: $unresolved })
    $tiles | to nuon | save -f ($dest | path join "tile.nuon")
    $info | to nuon | save -f ($dest | path join "map.nuon")
    mkdir ($dest | path join "plan")
    for storey in ($src.sectors | get storey | uniq) {
        plan-svg $src $m $storey | save --raw -f ($dest | path join "plan" $"($storey).svg")
    }
    $"($s.sectors) sectors, ($s.walls) walls, ($s.vertices) vertices, ($s.portals) portals, ($s.materials) materials and ($s.ambients) ambients \(($unresolved | length) unresolved\), ($sounds | length) sounds, ($sprites | length) sprite images, ($s.entities) entities \(($s.lights) lights, ($s.sprites) sprites\), ($bytes | bytes length) bytes"
}

# The kernel's console font from its assembled glyph table: a record
# from each printable character to its rows, 24 of them, each the
# glyph's 12 columns in the high bits of a 16-bit value.
def font-glyphs []: nothing -> record {
    let text = (open --raw $font_path | decode)
    mut glyphs = {}
    mut code = -1
    mut rows = []
    for l in ($text | lines) {
        let t = ($l | str trim)
        if ($t | str starts-with "# ") and ($t =~ '^# \d+ ') {
            if $code >= 0 { $glyphs = ($glyphs | insert ($code | into string) $rows) }
            $code = ($t | parse --regex '^# (?P<code>\d+) ' | get 0.code | into int)
            $rows = []
        } else if ($t | str starts-with ".2byte ") {
            $rows = ($rows ++ ($t | str substring 7.. | split row "," | each {|v| $v | str trim | str substring 2.. | into int --radix 16 }))
        }
    }
    if $code >= 0 { $glyphs = ($glyphs | insert ($code | into string) $rows) }
    $glyphs
}

# A label as SVG rects of the font's pixels, one a run of set columns
# a row, centred on a point, a pixel a font pixel; a character the
# font lacks draws as a space.
def label-svg [glyphs: record, text: string, cx: float, cy: float, colour: string]: nothing -> string {
    let chars = ($text | split chars)
    let x0 = ($cx - (($chars | length) * $glyph_width) / 2.0)
    let y0 = ($cy - $glyph_height / 2.0)
    mut out = []
    for c in ($chars | enumerate) {
        let code = ($c.item | into binary | bytes at 0..<1 | into int)
        let rows = ($glyphs | get -o ($code | into string) | default [])
        let gx = ($x0 + $c.index * $glyph_width)
        for r in ($rows | enumerate) {
            mut col = 0
            while $col < $glyph_width {
                let bit = (15 - $col)
                if (($r.item bit-shr $bit) bit-and 1) == 1 {
                    mut run = 1
                    while ($col + $run) < $glyph_width and (($r.item bit-shr ($bit - $run)) bit-and 1) == 1 { $run = ($run + 1) }
                    $out = ($out | append $"<rect x=\"($gx + $col)\" y=\"($y0 + $r.index)\" width=\"($run)\" height=\"1\" fill=\"($colour)\"/>")
                    $col = ($col + $run)
                } else {
                    $col = ($col + 1)
                }
            }
        }
    }
    $out | str join ""
}

# The plan view of a storey: every sector of it filled by a colour
# keyed to its floor height with its name at its centre in the
# kernel's font, walls as lines (grey with a portal, black solid, red
# tagged), entities as marks.
export def plan-svg [src: record, m: record, storey: string]: nothing -> string {
    let members = ($src.sectors | enumerate | where {|s| $s.item.storey == $storey } | get index)
    let secs = ($members | each {|i| $m.sectors | get $i })
    let min_x = (($secs | get bounds.min_x | math min) - $plan_margin)
    let min_y = (($secs | get bounds.min_y | math min) - $plan_margin)
    let max_x = (($secs | get bounds.max_x | math max) + $plan_margin)
    let max_y = (($secs | get bounds.max_y | math max) + $plan_margin)
    let w = (($max_x - $min_x) * $plan_scale)
    let h = (($max_y - $min_y) * $plan_scale)
    let px = {|x: float| ($x - $min_x) * $plan_scale }
    let py = {|y: float| ($max_y - $y) * $plan_scale }
    let heights = ($members | each {|i| let s = ($m.sectors | get $i); plane-z $s.floor (($s.bounds.min_x + $s.bounds.max_x) / 2.0) (($s.bounds.min_y + $s.bounds.max_y) / 2.0) })
    let lo = ($heights | math min)
    let hi = ($heights | math max)
    let glyphs = (font-glyphs)
    mut out = [$"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"($w)\" height=\"($h)\" viewBox=\"0 0 ($w) ($h)\">", $"<rect width=\"($w)\" height=\"($h)\" fill=\"white\"/>"]
    for k in ($members | enumerate) {
        let i = $k.item
        let s = ($m.sectors | get $i)
        let t = (if $hi > $lo { (($heights | get $k.index) - $lo) / ($hi - $lo) } else { 0.5 })
        let hue = ((240.0 - 240.0 * $t) | math round)
        mut d = ""
        for li in $s.first_loop..<($s.first_loop + $s.loop_count) {
            let lp = ($m.loops | get $li)
            for wi in $lp.first_wall..<($lp.first_wall + $lp.wall_count) {
                let wall = ($m.walls | get $wi)
                let a = ($m.vertices | get $wall.a)
                $d = ($d + (if $wi == $lp.first_wall { "M" } else { "L" }) + $"(do $px $a.x) (do $py $a.y) ")
            }
            $d = ($d + "Z ")
        }
        $out = ($out | append $"<path d=\"($d)\" fill=\"hsl\(($hue), 60%, 75%\)\" fill-rule=\"evenodd\" stroke=\"none\"/>")
    }
    for k in $members {
        let s = ($m.sectors | get $k)
        for li in $s.first_loop..<($s.first_loop + $s.loop_count) {
            let lp = ($m.loops | get $li)
            for wi in $lp.first_wall..<($lp.first_wall + $lp.wall_count) {
                let wall = ($m.walls | get $wi)
                let a = ($m.vertices | get $wall.a)
                let b = ($m.vertices | get $wall.b)
                let colour = (if $wall.tag != 0 { "red" } else if $wall.portal_count > 0 { "#999" } else { "black" })
                let width = (if $wall.portal_count > 0 { 1 } else { 2 })
                $out = ($out | append $"<line x1=\"(do $px $a.x)\" y1=\"(do $py $a.y)\" x2=\"(do $px $b.x)\" y2=\"(do $py $b.y)\" stroke=\"($colour)\" stroke-width=\"($width)\"/>")
            }
        }
        let name = ($src.sectors | get $k | get name)
        let cx = (do $px (($s.bounds.min_x + $s.bounds.max_x) / 2.0))
        let cy = (do $py (($s.bounds.min_y + $s.bounds.max_y) / 2.0))
        $out = ($out | append (label-svg $glyphs $name $cx $cy "#333"))
    }
    for e in ($m.entities | enumerate) {
        let ent = $e.item
        if not ($ent.sector in $members) { continue }
        let cx = (do $px $ent.x)
        let cy = (do $py $ent.y)
        let r = ($plan_scale * 0.15)
        match $ent.class {
            0 => {
                let yaw = ($ent.yaw * 3.14159265358979 / 180.0)
                let ex = ($cx + ($yaw | math cos) * $plan_scale)
                let ey = ($cy - ($yaw | math sin) * $plan_scale)
                $out = ($out | append $"<circle cx=\"($cx)\" cy=\"($cy)\" r=\"($r)\" fill=\"green\"/><line x1=\"($cx)\" y1=\"($cy)\" x2=\"($ex)\" y2=\"($ey)\" stroke=\"green\" stroke-width=\"2\"/>")
            }
            1 => {
                $out = ($out | append $"<circle cx=\"($cx)\" cy=\"($cy)\" r=\"($ent.radius * $plan_scale)\" fill=\"none\" stroke=\"gold\" stroke-width=\"1\"/><circle cx=\"($cx)\" cy=\"($cy)\" r=\"($r)\" fill=\"gold\"/>")
            }
            3 => {
                $out = ($out | append $"<circle cx=\"($cx)\" cy=\"($cy)\" r=\"($r)\" fill=\"blue\"/>")
                if $ent.target >= 0 {
                    let t = ($m.entities | get $ent.target)
                    $out = ($out | append $"<line x1=\"($cx)\" y1=\"($cy)\" x2=\"(do $px $t.x)\" y2=\"(do $py $t.y)\" stroke=\"blue\" stroke-width=\"1\" stroke-dasharray=\"4 2\"/>")
                }
            }
            _ => {
                $out = ($out | append $"<circle cx=\"($cx)\" cy=\"($cy)\" r=\"($r)\" fill=\"purple\"/>")
            }
        }
    }
    $out = ($out | append "</svg>")
    $out | str join (char nl)
}

def u32 [b: binary, off: int]: nothing -> int { $b | bytes at $off..<($off + 4) | into int --endian little }
def i32 [b: binary, off: int]: nothing -> int { $b | bytes at $off..<($off + 4) | into int --endian little --signed }
def u32b [v: int]: nothing -> binary { $v | into binary --endian little | bytes at 0..<4 }
def i32b [v: int]: nothing -> binary { $v | into binary --endian little | bytes at 0..<4 }
def f32b [v: float]: nothing -> binary { float-bytes $v }

# A single read at an offset of any bytes, for a reader of the
# program's own records, which carry the same singles.
export def float-at [b: binary, off: int]: nothing -> float {
    f32 $b $off
}

# A single's four bytes, little-endian, of a host float: the double's
# bits taken apart and put back with the narrower exponent and
# mantissa, rounded to nearest, anything under the single's range
# flushed to zero; a value past its range is an error.
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

# An IEEE 754 single from its bits: the sign, the exponent, and the
# mantissa, exact in the host's double.
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
