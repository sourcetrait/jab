use (path self ../../../../../../nu/mod/target)
use (path self ../../../../../../nu/mod/walk)
use (path self ..)
use (path self ../plan)
use (path self ..) [classes entry_size header_size kinds magic sizes]

# A surface's solid flag bit
const surface_solid = 1

# A surface's masked flag bit
const surface_masked = 2

# A surface's sky flag bit
const surface_sky = 4

# An entity's flag bit for facing the camera
const entity_camera = 1

# An entity's flag bit for flat facing
const entity_flat = 2

# An entity's two-sided flag bit
const entity_two_sided = 4

# An entity's solid flag bit
const entity_solid = 8

# The vertex snap: points rounded to 1/1024, shared to a thousandth
const snap = 1024.0

# The game's content, the compile's default, from the module's own file
const content_dir = path self ../../../../content

# A source compiled to its tree under `out`: map, assets, NUON, plan views
export def main [source: path, out: path, --content: path = ""] {
    let content = (if $content == "" { $content_dir } else { $content | path expand })
    let src = (open $source)
    let m = (build $src)
    let summary = (lay-out $src $m $content ($out | path expand))
    print $"map: ($src.name) at ($out | path expand | path join $src.name): ($summary)"
}

# A map record encoded as the file's bytes
export def write [m: record]: nothing -> binary {
    let names = (($m.materials | get name) ++ ($m.ambients | get name) | uniq)
    mut table = 0x[]
    mut offsets = {}
    for n in $names {
        $offsets = ($offsets | insert $n ($table | bytes length))
        $table = ([$table, ($n | into binary), 0x[00]] | bytes collect)
    }
    let offsets = $offsets
    let materials = (joined ($m.materials | each {|r| [(u32b ($offsets | get $r.name)), (u32b $r.flags)] | bytes collect }))
    let vertices = (joined ($m.vertices | each {|v| [(f32b $v.x), (f32b $v.y)] | bytes collect }))
    let sectors = (joined ($m.sectors | each {|s| [
        (f32b $s.floor.a), (f32b $s.floor.b), (f32b $s.floor.c), (f32b $s.ceiling.a), (f32b $s.ceiling.b), (f32b $s.ceiling.c),
        (surface-bytes $s.floor_surface), (surface-bytes $s.ceiling_surface),
        (u32b $s.first_loop), (u32b $s.loop_count),
        (f32b $s.bounds.min_x), (f32b $s.bounds.min_y), (f32b $s.bounds.max_x), (f32b $s.bounds.max_y),
        (i32b $s.tag), (i32b $s.ambient), (u32b $s.first_light), (u32b $s.light_count),
    ] | bytes collect }))
    let loops = (joined ($m.loops | each {|l| [(u32b $l.first_wall), (u32b $l.wall_count)] | bytes collect }))
    let walls = (joined ($m.walls | each {|w| [
        (u32b $w.a), (u32b $w.b), (u32b $w.sector), (surface-bytes $w.surface), (f32b $w.anchor),
        (u32b $w.first_portal), (u32b $w.portal_count), (i32b $w.tag),
    ] | bytes collect }))
    let portals = (joined ($m.portals | each {|p| [(u32b $p.sector), (u32b $p.wall)] | bytes collect }))
    let entities = (joined ($m.entities | each {|e| [
        (u32b $e.class), (f32b $e.x), (f32b $e.y), (f32b $e.z), (f32b $e.yaw), (f32b $e.pitch), (f32b $e.width), (f32b $e.height),
        (i32b $e.material), (f32b $e.r), (f32b $e.g), (f32b $e.b), (f32b $e.radius), (f32b $e.spread),
        (u32b $e.flags), (i32b $e.tag), (i32b $e.target), (i32b $e.sector),
    ] | bytes collect }))
    let ambients = (joined ($m.ambients | each {|a| u32b ($offsets | get $a.name) }))
    let sector_lights = (joined ($m.sector_lights | each {|l| u32b $l }))
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
    mut offset = ($header_size + ($sections | length) * $entry_size)
    mut directory = []
    mut bodies = []
    for s in $sections {
        $directory = ($directory | append ([(u32b $s.kind), (u32b $offset), (u32b $s.size), (u32b $s.count)] | bytes collect))
        let body = (padded $s.bytes)
        $bodies = ($bodies | append $body)
        $offset = ($offset + ($body | bytes length))
    }
    [(u32b $magic), (u32b ($sections | length)), (joined $directory), (joined $bodies)] | bytes collect
}

# Bytes padded with zeros to a multiple of four
def padded [bytes: binary]: nothing -> binary {
    let pad = ((4 - (($bytes | bytes length) mod 4)) mod 4)
    if $pad == 0 { $bytes } else { [$bytes, (1..$pad | each {|_| 0x[00] } | bytes collect)] | bytes collect }
}

# Byte chunks joined as one, an empty list as no bytes
def joined [chunks: list<binary>]: nothing -> binary {
    if ($chunks | is-empty) { 0x[] } else { $chunks | bytes collect }
}

# A surface encoded as its bytes: material, scales, offsets, flags
def surface-bytes [s: record]: nothing -> binary {
    [(i32b $s.material), (f32b $s.u_scale), (f32b $s.v_scale), (f32b $s.u_offset), (f32b $s.v_offset), (u32b $s.flags)] | bytes collect
}

# A map source as the map record: vertices, windings, planes, portals, lights
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
                    "string" => (if $w.anchor_spec == "top" { map plane-z $ceiling $w.a.x $w.a.y } else if $w.anchor_spec == "bottom" { map plane-z $floor $w.a.x $w.a.y } else { error make { msg: $"sector ($sec.name): an anchor is top, bottom, or a height, not ($w.anchor_spec)" } }),
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
            (map plane-z ($sectors_built | get ($walls_built | get $p | get sector) | get ceiling) $mx $my) > (map plane-z ($sectors_built | get ($walls_built | get $q | get sector) | get ceiling) $mx $my)
        })
        let first_portal = ($portals | length)
        for o in $sorted {
            $portals = ($portals | append { sector: ($walls_built | get $o | get sector), wall: $o })
        }
        $walls_out = ($walls_out | append ($wall | update first_portal $first_portal | update portal_count ($sorted | length)))
    }
    let walls = $walls_out
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
        let full = (map sector-holding $model_geometry $at.0 $at.1 $at.2)
        let sector = (if $full >= 0 or $class == 0 { $full } else { map sector-holding $model_geometry $at.0 $at.1 $at.2 --plan })
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

# A source point as floats
def point [p: list<any>]: nothing -> record<x: float, y: float> {
    { x: ($p | get 0 | into float), y: ($p | get 1 | into float) }
}

# A plane from a height at a point and a slope
def plane-of [spec: record, p0: record]: nothing -> record<a: float, b: float, c: float> {
    let a = ($spec.slope | get 0 | into float)
    let b = ($spec.slope | get 1 | into float)
    let h = ($spec.height | into float)
    { a: $a, b: $b, c: ($h - $a * $p0.x - $b * $p0.y) }
}

# A surface from a source's material spec, material index, and flags
def surface-of [spec: record, material: int, flags: int]: nothing -> record<material: int, u_scale: float, v_scale: float, u_offset: float, v_offset: float, flags: int> {
    { material: $material, u_scale: ($spec.scale | get 0 | into float), v_scale: ($spec.scale | get 1 | into float), u_offset: ($spec.offset | get 0 | into float), v_offset: ($spec.offset | get 1 | into float), flags: $flags }
}

# A name's index in a name list, appended when new
def material-index [names: list<string>, name: string]: nothing -> record<materials: list<string>, index: int> {
    let found = ($names | enumerate | where item == $name | get -o 0.index)
    if $found == null { { materials: ($names | append $name), index: ($names | length) } } else { { materials: $names, index: $found } }
}

# A point's vertex index, shared to a thousandth, appended when new
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

# Twice a polygon's signed area, positive counter-clockwise with y up
def signed-area [points: list<record>]: nothing -> float {
    let n = ($points | length)
    0..<$n | each {|i|
        let a = ($points | get $i)
        let b = ($points | get (($i + 1) mod $n))
        $a.x * $b.y - $b.x * $a.y
    } | math sum
}

# Whether two sectors' height ranges overlap at a point
def ranges-overlap [s: record, t: record, x: float, y: float]: nothing -> bool {
    let floor = ([(map plane-z $s.floor $x $y), (map plane-z $t.floor $x $y)] | math max)
    let ceiling = ([(map plane-z $s.ceiling $x $y), (map plane-z $t.ceiling $x $y)] | math min)
    $floor <= $ceiling
}

# The tree written: map, title, assets, NUON, plan views; the summary line
def lay-out [src: record, m: record, content: string, out: string]: nothing -> string {
    let dest = ($out | path join $src.name)
    if ($dest | path exists) {
        if not ((($dest | path join "map" "name") | path exists) or (ls -a $dest | is-empty)) { error make { msg: $"($dest) is not a tree the compiler wrote; not retiring it" } }
        target retire $dest
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
        let path = (map tile-path $t.item.name)
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
    let sounds = (walk paths ($content | path join "sound" "*.pcm"))
    if not ($sounds | is-empty) { mkdir ($dest | path join "sound") }
    for p in $sounds {
        cp $p ($dest | path join "sound" ($p | path basename))
    }
    let sprite_root = ($content | path join "sprite")
    let sprites = (walk paths ($sprite_root | path join "**" "*.png"))
    for p in $sprites {
        let file = ($dest | path join "sprite" ($p | path relative-to $sprite_root))
        mkdir ($file | path dirname)
        cp $p $file
    }
    let s = (map summary $m)
    let info = ($s | merge { name: $src.name, bytes: ($bytes | bytes length), sounds: ($sounds | length), sprite_files: ($sprites | length), unresolved: ($unresolved | length), missing: $unresolved })
    $tiles | to nuon | save -f ($dest | path join "tile.nuon")
    $info | to nuon | save -f ($dest | path join "map.nuon")
    mkdir ($dest | path join "plan")
    for storey in ($src.sectors | get storey | uniq) {
        plan plan-svg $src $m $storey | save --raw -f ($dest | path join "plan" $"($storey).svg")
    }
    $"($s.sectors) sectors, ($s.walls) walls, ($s.vertices) vertices, ($s.portals) portals, ($s.materials) materials and ($s.ambients) ambients \(($unresolved | length) unresolved\), ($sounds | length) sounds, ($sprites | length) sprite images, ($s.entities) entities \(($s.lights) lights, ($s.sprites) sprites\), ($bytes | bytes length) bytes"
}

# An unsigned 32-bit value as four little-endian bytes
def u32b [v: int]: nothing -> binary { $v | into binary --endian little | bytes at 0..<4 }

# A signed 32-bit value as four little-endian bytes
def i32b [v: int]: nothing -> binary { $v | into binary --endian little | bytes at 0..<4 }

# A float as a single's four little-endian bytes
def f32b [v: float]: nothing -> binary { map float-bytes $v }
