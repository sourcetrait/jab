use ../../../../../nu/mod/target
use ../../map.nu
use ../../png.nu
use ../../../test/tiles.nu [builder-texel]
use std/assert

# The halves sprite's material, the test's own texture
export const SPRITE_MATERIAL = "sprite/test"

# The halves sprite's feet and size, in metres
const SPRITE = { at: [1.5, 4.0, 0.6], size: [2.0, 2.0] }

# The straddling quad's material, the uniform alpha case over the pass
export const STRADDLE_MATERIAL = "sprite/test/opaque"

# The straddling quad's feet and size, along y through the door sector
const STRADDLE = { at: [3.3, 8.5, 0.6], size: [1.8, 1.0] }

# The alpha cases: the test's own textures, materials of the sprite tree
export const ALPHA_CASES = [
    { name: "sprite/test", w: 64, h: 64, kind: "halves", alpha: 255 },
    { name: "sprite/test/opaque", w: 64, h: 64, kind: "uniform", alpha: 200 },
    { name: "sprite/test/faint", w: 64, h: 64, kind: "uniform", alpha: 100 },
    { name: "sprite/test/checker", w: 64, h: 64, kind: "checker", alpha: 255 },
    { name: "sprite/test/small", w: 8, h: 8, kind: "block", alpha: 255 },
    { name: "sprite/test/edge", w: 4, h: 4, kind: "edge", alpha: 128 },
]

# The most levels a mip chain holds, render.inc's MIP_LEVELS
const MIP_LEVELS = 10

# The fixture copies' map name: Render One with a wall of the test's own
export const FIXTURE_MAP = "render_1_alpha"

# The alpha fixture texture: name, size, patch, and repeats a metre
export const ALPHA_FIXTURE = { name: "texture/alphafix", w: 256, h: 256, patch: 64, scale: 2.0 }

# The solid backdrop texture: its name, size, and colour
export const FIXTURE_BACKDROP = { name: "texture/alphaback", size: 16, colour: 0x[30 30 30] }

# The alpha fixture's patch kinds, each a 2 by 2 of colours and alphas
export const FIXTURE_KINDS = {
    A: { colours: [0x[ff 00 00], 0x[ff 00 00], 0x[ff 00 00], 0x[ff 00 00]], alphas: [255, 255, 255, 255] },
    B: { colours: [0x[00 ff 00], 0x[00 ff 00], 0x[00 ff 00], 0x[00 ff 00]], alphas: [127, 127, 127, 127] },
    C: { colours: [0x[00 00 ff], 0x[00 00 ff], 0x[00 00 ff], 0x[00 00 ff]], alphas: [128, 128, 128, 128] },
    D: { colours: [0x[ff ff 00], 0x[ff ff 00], 0x[00 00 00], 0x[00 00 00]], alphas: [255, 255, 0, 0] },
    E: { colours: [0x[00 00 00], 0x[00 00 00], 0x[00 00 00], 0x[00 00 00]], alphas: [0, 0, 0, 0] },
    F: { colours: [0x[00 ff ff], 0x[00 ff ff], 0x[00 00 00], 0x[00 00 00]], alphas: [255, 145, 0, 0] },
    G: { colours: [0x[ff 00 00], 0x[00 00 ff], 0x[00 00 ff], 0x[00 00 00]], alphas: [255, 128, 128, 0] },
}

# The kinds over the alpha fixture's 4 by 4 patches
export const FIXTURE_GRID = [[A, B, A, D], [C, A, E, D], [A, F, A, G], [D, E, C, F]]

# The alpha fixture's head-on poses: distance in metres, level read
export const FIXTURE_POSES = [
    { name: "near", distance: 2.0, level: 0 },
    { name: "mid", distance: 5.5, level: 1 },
    { name: "far", distance: 10.0, level: 2 },
]

# The texel-centre fixture's white texture: its name, size, and scale
export const CENTRE_FIXTURE = { name: "texture/centrefix", size: 16, scale: 2.0 }

# The builder fixture's texture: its name, size, and scale
export const BUILDER_FIXTURE = { name: "texture/builderfix", size: 64, scale: 0.25 }

# The handoff fixture's white texture: its name, size, and scale
export const HANDOFF_FIXTURE = { name: "texture/handofffix", size: 64, scale: 0.5 }

# The edge of the north room's loop the handoff texture goes on
const HANDOFF_EDGE = 6

# The growth map's name, a map of the test's own
export const GROW_MAP = "rectgrow"

# The far room's sector name, reached through the grown rectangle
export const GROW_FAR = "D"

# The eye's height over the feet, in metres
export const EYE_HEIGHT = 1.6

# A map source copied without entities of the given classes, compiled
export def variant [source: record, name: string, dropped: list<string>, out: path, game: path]: nothing -> string {
    target retire $out
    mkdir $out
    let copy = ($source | update name $name | update entities ($source.entities | where {|e| $e.class not-in $dropped }))
    let src = ($out | path join $"($name).nuon")
    $copy | to nuon | save --raw -f $src
    let compiled = (^nu ($game | path join "nu" "map.nu") compile $src $out --content ($game | path join "content") | complete)
    if $compiled.exit_code != 0 { error make { msg: $"compiling ($name): ($compiled.stderr)" } }
    $out | path join $name
}

# A tree's romfs image with the program's volume name; its path
export def romfs [tree: path, image: path]: nothing -> string {
    let made = (^genromfs -d $tree -f $image -V "fps" | complete)
    if $made.exit_code != 0 { error make { msg: $"genromfs on ($tree): ($made.stderr)" } }
    $image
}

# A map copy without lights or android, the alpha cases laid in as sprites
export def sprite-tree [source: record, name: string, out: path, game: path, --halves]: nothing -> string {
    let cases = ($ALPHA_CASES | where {|c| $halves or $c.name != $SPRITE_MATERIAL })
    let sprites = ($cases | enumerate | each {|e|
        let placed = (if $e.item.name == $SPRITE_MATERIAL {
            { at: $SPRITE.at, size: $SPRITE.size, facing: "camera" }
        } else if $e.item.name == $STRADDLE_MATERIAL {
            { at: $STRADDLE.at, size: $STRADDLE.size, facing: "fixed" }
        } else {
            { at: [(1.0 + $e.index), 1.0, 3.5], size: [0.5, 0.5], facing: "fixed" }
        })
        { name: $"alpha_($e.index)", class: "sprite", at: $placed.at, yaw: 0.0, pitch: 0.0, size: $placed.size, material: ($e.item.name | str substring 7..), colour: [1.0, 1.0, 1.0], radius: 0.0, spread: 0.0, facing: $placed.facing, two_sided: true, solid: false, tag: 0, target: "" }
    })
    let tree = (variant ($source | update entities ($source.entities | append $sprites)) $name [light android] $out $game)
    for c in $cases {
        let file = ($tree | path join (map tile-path $c.name | str substring 1..))
        mkdir ($file | path dirname)
        let pixels = (0..<$c.h | each {|y| 0..<$c.w | each {|x| (case-texel $c $x $y).bytes } | bytes collect } | bytes collect)
        png write-rgba $file $c.w $c.h $pixels
    }
    $tree
}

# An alpha case's texel: its RGBA bytes and its alpha
export def case-texel [c: record, x: int, y: int]: nothing -> record<bytes: binary, alpha: int> {
    let clear = { bytes: 0x[00 00 00 00], alpha: 0 }
    let red = { bytes: 0x[ff 00 00 ff], alpha: 255 }
    let white = { bytes: 0x[ff ff ff ff], alpha: 255 }
    let tinted = {|alpha: int| { bytes: ([0x[40 80 c0], ($alpha | into binary | bytes at 0..<1)] | bytes collect), alpha: $alpha } }
    match $c.kind {
        "halves" => (if $x < ($c.w // 2) { $clear } else { $red }),
        "uniform" => (do $tinted $c.alpha),
        "checker" => (if (($x + $y) mod 2) == 0 { $red } else { $clear }),
        "block" => (if $x < 2 and $y < 2 { $white } else { $clear }),
        "edge" => (if ($x mod 2) == 1 and ($y mod 2) == 1 { do $tinted ($c.alpha - 1) } else { do $tinted $c.alpha }),
        _ => (error make { msg: $"no alpha case of kind ($c.kind)" }),
    }
}

# The levels of a texture's mip chain as the engine builds it
export def chain-levels [w: int, h: int]: nothing -> int {
    mut levels = 1
    mut pw = $w
    mut ph = $h
    while $levels < $MIP_LEVELS and $pw >= 2 and $ph >= 2 {
        $pw = $pw // 2
        $ph = $ph // 2
        $levels += 1
    }
    $levels
}

# A row of the alpha fixture: its RGBA pixels and its alphas
export def fixture-row [y: int]: nothing -> record<bytes: binary, alphas: list<int>> {
    let kinds = ($FIXTURE_GRID | get ($y // $ALPHA_FIXTURE.patch))
    let parity = (($y mod 2) * 2)
    let half = ($ALPHA_FIXTURE.patch // 2)
    let cells = ($kinds | each {|kind|
        let k = ($FIXTURE_KINDS | get $kind)
        let even = ($k.alphas | get $parity)
        let odd = ($k.alphas | get ($parity + 1))
        let pair = ([($k.colours | get $parity), ($even | into binary | bytes at 0..<1), ($k.colours | get ($parity + 1)), ($odd | into binary | bytes at 0..<1)] | bytes collect)
        { bytes: (0..<$half | each {|i| $pair } | bytes collect), alphas: (0..<$half | each {|i| [$even, $odd] } | flatten) }
    })
    { bytes: ($cells | get bytes | bytes collect), alphas: ($cells | get alphas | flatten) }
}

# Render One's copy with a test material on the grate wall, alcove backdrop
def fixture-tree [source: record, game: path, out: path, material: string, scale: float]: nothing -> string {
    let north = ($source.sectors | enumerate | where {|s| $s.item.name == "north" } | get 0.index)
    let sector = ($source.sectors | get $north)
    let grate = ($sector.walls | enumerate | where {|w| $w.item.material == "grate" } | get 0.index)
    let stem = ($material | path basename)
    let walls = ($sector.walls | update $grate {|w| $w | update material $stem | update scale [$scale, $scale] | update offset [0.0, 0.0] })
    let alcove = ($source.sectors | enumerate | where {|s| $s.item.name == "alcove" } | get 0.index)
    let back = ($FIXTURE_BACKDROP.name | path basename)
    let solid = ($source.sectors | get $alcove | update floor.material $back | update ceiling.material $back | update wall.material $back)
    let fixed = ($source | update sectors ($source.sectors | update $north ($sector | update walls $walls) | update $alcove $solid))
    let tree = (variant $fixed $FIXTURE_MAP [android] $out $game)
    let backdrop = ($tree | path join (map tile-path $FIXTURE_BACKDROP.name | str substring 1..))
    mkdir ($backdrop | path dirname)
    let texel = ([$FIXTURE_BACKDROP.colour, 0x[ff]] | bytes collect)
    png write-rgba $backdrop $FIXTURE_BACKDROP.size $FIXTURE_BACKDROP.size (0..<($FIXTURE_BACKDROP.size * $FIXTURE_BACKDROP.size) | each {|i| $texel } | bytes collect)
    $tree
}

# The alpha fixture's tree, its texture on the grate wall at a scale
export def alpha-tree [source: record, game: path, out: path, --scale: float]: nothing -> string {
    let tree = (fixture-tree $source $game $out $ALPHA_FIXTURE.name ($scale | default $ALPHA_FIXTURE.scale))
    let file = ($tree | path join (map tile-path $ALPHA_FIXTURE.name | str substring 1..))
    mkdir ($file | path dirname)
    let pixels = (0..<$ALPHA_FIXTURE.h | each {|y| (fixture-row $y).bytes } | bytes collect)
    png write-rgba $file $ALPHA_FIXTURE.w $ALPHA_FIXTURE.h $pixels
    $tree
}

# The texel-centre fixture's tree, a white texture on the grate wall
export def centre-tree [source: record, game: path, out: path]: nothing -> string {
    let tree = (fixture-tree $source $game $out $CENTRE_FIXTURE.name $CENTRE_FIXTURE.scale)
    let file = ($tree | path join (map tile-path $CENTRE_FIXTURE.name | str substring 1..))
    mkdir ($file | path dirname)
    png write-rgba $file $CENTRE_FIXTURE.size $CENTRE_FIXTURE.size (0..<($CENTRE_FIXTURE.size * $CENTRE_FIXTURE.size) | each {|i| 0x[ff ff ff ff] } | bytes collect)
    $tree
}

# The growth map's source: eight rectangular rooms, a spawn in C, unlit
export def grow-source []: nothing -> record {
    let room = {|name: string, loop: list<list<float>>, floor: float, ceiling: float, material: string|
        {
            name: $name, storey: "lower", tag: 0, ambient: "",
            floor: { height: $floor, slope: [0.0, 0.0], material: $material, scale: [0.5, 0.5], offset: [0.0, 0.0], sky: false },
            ceiling: { height: $ceiling, slope: [0.0, 0.0], material: $material, scale: [0.5, 0.5], offset: [0.0, 0.0], sky: false },
            wall: { material: $material, scale: [0.5, 0.5], offset: [0.0, 0.0], anchor: "top", solid: false, masked: false, sky: false, tag: 0 },
            loops: [$loop], walls: [],
        }
    }
    let back = ($FIXTURE_BACKDROP.name | path basename)
    {
        name: $GROW_MAP,
        sectors: [
            (do $room "C" [[0.0, 0.0], [4.0, 0.0], [4.0, 1.0], [4.0, 3.0], [4.0, 4.0], [2.5, 4.0], [1.5, 4.0], [0.0, 4.0]] 0.0 3.0 "panel"),
            (do $room "W" [[1.5, 4.0], [2.5, 4.0], [2.5, 4.5], [1.5, 4.5]] 1.2 2.2 "panel"),
            (do $room "E" [[4.0, 1.0], [4.5, 1.0], [4.5, 3.0], [4.0, 3.0]] 0.0 2.5 "panel"),
            (do $room "T" [[4.5, 0.0], [8.5, 0.0], [8.5, 4.0], [8.0, 4.0], [4.75, 4.0], [4.5, 4.0], [4.5, 3.0], [4.5, 1.0]] 0.0 3.0 "panel"),
            (do $room "G" [[4.75, 4.0], [8.0, 4.0], [8.0, 4.5], [4.75, 4.5]] 0.0 2.5 "panel"),
            (do $room "S" [[0.0, 4.5], [1.5, 4.5], [2.5, 4.5], [4.75, 4.5], [8.0, 4.5], [8.0, 8.5], [7.5, 8.5], [5.5, 8.5], [0.0, 8.5]] 0.0 3.0 "panel"),
            (do $room "H" [[5.5, 8.5], [7.5, 8.5], [7.5, 9.0], [5.5, 9.0]] 0.0 2.5 "panel"),
            (do $room $GROW_FAR [[5.0, 9.0], [5.5, 9.0], [7.5, 9.0], [9.0, 9.0], [9.0, 13.0], [5.0, 13.0]] 0.0 3.0 $back),
        ],
        entities: [
            { name: "spawn", class: "spawn", at: [2.0, 2.0, 0.0], yaw: 0.0, pitch: 0.0, size: [0.0, 0.0], material: "", colour: [0.0, 0.0, 0.0], radius: 0.0, spread: 0.0, facing: "fixed", two_sided: false, solid: false, tag: 0, target: "" },
        ],
    }
}

# The growth map compiled with its backdrop texture laid in; its path
export def grow-tree [game: path, out: path]: nothing -> string {
    let tree = (variant (grow-source) $GROW_MAP [] $out $game)
    let backdrop = ($tree | path join (map tile-path $FIXTURE_BACKDROP.name | str substring 1..))
    mkdir ($backdrop | path dirname)
    let texel = ([$FIXTURE_BACKDROP.colour, 0x[ff]] | bytes collect)
    png write-rgba $backdrop $FIXTURE_BACKDROP.size $FIXTURE_BACKDROP.size (0..<($FIXTURE_BACKDROP.size * $FIXTURE_BACKDROP.size) | each {|i| $texel } | bytes collect)
    $tree
}

# The builder fixture's tree, its texture on the grate wall
export def builder-tree [source: record, game: path, out: path]: nothing -> string {
    let tree = (fixture-tree $source $game $out $BUILDER_FIXTURE.name $BUILDER_FIXTURE.scale)
    let file = ($tree | path join (map tile-path $BUILDER_FIXTURE.name | str substring 1..))
    mkdir ($file | path dirname)
    let size = $BUILDER_FIXTURE.size
    let pixels = (0..<$size | each {|y| 0..<$size | each {|x| builder-texel $x $y | each {|v| $v | into binary | bytes at 0..<1 } | bytes collect } | bytes collect } | bytes collect)
    png write-rgba $file $size $size $pixels
    $tree
}

# The handoff fixture's tree, a white texture on the north room's long wall
export def handoff-tree [source: record, game: path, out: path]: nothing -> string {
    let north = ($source.sectors | enumerate | where {|s| $s.item.name == "north" } | get 0.index)
    let sector = ($source.sectors | get $north)
    let scale = $HANDOFF_FIXTURE.scale
    let long = ($sector.wall | select anchor solid masked sky tag | merge { loop: 0, edge: $HANDOFF_EDGE, material: ($HANDOFF_FIXTURE.name | path basename), scale: [$scale, $scale], offset: [0.0, 0.0] })
    let fixed = ($source | update sectors ($source.sectors | update $north ($sector | update walls ($sector.walls | append $long))))
    let tree = (variant $fixed $FIXTURE_MAP [android] $out $game)
    let file = ($tree | path join (map tile-path $HANDOFF_FIXTURE.name | str substring 1..))
    mkdir ($file | path dirname)
    let size = $HANDOFF_FIXTURE.size
    png write-rgba $file $size $size (0..<($size * $size) | each {|i| 0x[ff ff ff ff] } | bytes collect)
    $tree
}

# A wall's lumel map as lumap_frame lays it: k, origin, columns, rows
export def wall-lumap [m: record, wall: record, w: int, h: int]: nothing -> record<k: int, u0: int, v0: int, w: int, h: int> {
    let s = $wall.surface
    let a = ($m.vertices | get $wall.a)
    let b = ($m.vertices | get $wall.b)
    let len = ((($b.x - $a.x) ** 2 + ($b.y - $a.y) ** 2) | math sqrt)
    let sector = ($m.sectors | get $wall.sector)
    let top = ([(map plane-z $sector.ceiling $a.x $a.y), (map plane-z $sector.ceiling $b.x $b.y)] | math max)
    let bottom = ([(map plane-z $sector.floor $a.x $a.y), (map plane-z $sector.floor $b.x $b.y)] | math min)
    let us = [($s.u_offset * $w), ((($s.u_scale * $len) + $s.u_offset) * $w)]
    let vs = [(((($wall.anchor - $top) * $s.v_scale) + $s.v_offset) * $h), (((($wall.anchor - $bottom) * $s.v_scale) + $s.v_offset) * $h)]
    let half = ((($w * $s.u_scale) | math abs) * 0.5)
    let k = ([([((($half | math log 2) + 0.5) | math floor | into int), 0] | math max), 15] | math min)
    let u0 = (((($us | math min | math floor | into int) - 1) // $w) * $w)
    let v0 = (((($vs | math min | math floor | into int) - 1) // $h) * $h)
    {
        k: $k, u0: $u0, v0: $v0,
        w: (((($us | math max | math ceil | into int) - $u0) bit-shr $k) + 2),
        h: (((($vs | math max | math ceil | into int) - $v0) bit-shr $k) + 2),
    }
}

# A compiled tree's plan views: an SVG a storey, at the storey's bounds
export def plan-views [tree: path, source: record, read: record]: nothing -> nothing {
    for storey in ($source.sectors | get storey | uniq) {
        let svg = ($tree | path join "plan" $"($storey).svg")
        assert ($svg | path exists) $"a plan view of the ($storey) storey"
        let members = ($source.sectors | enumerate | where {|s| $s.item.storey == $storey } | each {|s| $read.sectors | get $s.index | get bounds })
        let width = ((($members | get max_x | math max) - ($members | get min_x | math min) + 2.0) * 24)
        let height = ((($members | get max_y | math max) - ($members | get min_y | math min) + 2.0) * 24)
        let head = (open --raw $svg | decode | lines | get 0 | parse --regex 'width="(?P<w>[0-9.]+)" height="(?P<h>[0-9.]+)"' | get 0)
        assert (((($head.w | into float) - $width) | math abs) < 0.001 and ((($head.h | into float) - $height) | math abs) < 0.001) $"the ($storey) plan view at the storey's bounds: ($head) against ($width) by ($height)"
    }
}

# A tree holding a map of the given bytes under the given name; its path
export def broken [tree: path, name: string, bytes: binary]: nothing -> string {
    target retire $tree
    mkdir ($tree | path join "map")
    $name | save --raw -f ($tree | path join "map" "name")
    $bytes | save --raw -f ($tree | path join "map" $"($name).jabfps.map")
    $tree
}

# A point's plan distance from the nearest wall of a sector's loops
export def wall-clearance [m: record, sector: int, x: float, y: float]: nothing -> float {
    let sec = ($m.sectors | get $sector)
    $sec.first_loop..<($sec.first_loop + $sec.loop_count) | each {|li|
        let lp = ($m.loops | get $li)
        $lp.first_wall..<($lp.first_wall + $lp.wall_count) | each {|wi|
            let w = ($m.walls | get $wi)
            let a = ($m.vertices | get $w.a)
            let b = ($m.vertices | get $w.b)
            let dx = ($b.x - $a.x)
            let dy = ($b.y - $a.y)
            let along = (((($x - $a.x) * $dx) + (($y - $a.y) * $dy)) / (($dx * $dx) + ($dy * $dy)))
            let t = ([0.0 ([1.0 $along] | math min)] | math max)
            ((($x - ($a.x + $t * $dx)) ** 2) + (($y - ($a.y + $t * $dy)) ** 2)) | math sqrt
        }
    } | flatten | math min
}

# A sector's index in a map source, by its name
export def sector-index [source: record, name: string]: nothing -> int {
    $source.sectors | enumerate | where {|s| $s.item.name == $name } | get 0.index
}

# A material's index in a read map, by its name
export def material-index [read: record, name: string]: nothing -> int {
    $read.materials | enumerate | where {|m| $m.item.name == $name } | get 0.index
}

# An ambient's index in a read map, by its name
export def ambient-index [read: record, name: string]: nothing -> int {
    $read.ambients | enumerate | where {|a| $a.item.name == $"ambient/($name)" } | get 0.index
}
