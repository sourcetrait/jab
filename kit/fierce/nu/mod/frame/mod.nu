use std/assert

# The load report line's form: the map, its load time, its counts by kind
export const LOAD = "fps: {name} loaded in {ms} ms: {sectors} sectors, {walls} walls, {vertices} vertices, {portals} portals, {entities} entities, {lights} lights, {lumel_maps} lumel maps, {sprites} sprites, {materials} materials, {textures} textures, {missing} missing"

# The frame report line's form: its time, counts, phases, and workers' bands
export const FRAME = "fps: frame in {us} us: {sectors} sectors, {walls} walls, {pieces} pieces, {planes} planes, {openings} openings, {sprites} sprites, {uncovered} uncovered; clear, planes, walls, portals, sprites, raster us {clear}, {plane_us}, {wall_us}, {portal_us}, {sprite_us}, {raster_us}; spans {spans}, pixels {pixels}, lit spans {lit_spans}, lit pixels {lit_pixels}, light us {light_us}, rejected {rejected}, samples {samples}, tiles built {tiles_built}, tiled {tiled}, resets {resets}, slots {slots}, commands {commands}, flushes {flushes}, workers {workers}, grain {grain}, rounds {rounds}, bands {bands1} {bands2} {bands3} {bands4} {bands5} {bands6} {bands7}, dispatch us {dispatch}, barrier us {barrier}, slowest us {slowest}, busy us {busy}, cancelled {cancelled}"

# The pixels a frame may leave unreached where two surfaces' edges round apart
export const CRACKS = 32

# An API record's size in bytes
export const RECORD = 64

# A console answer's record kind, render.inc's REPORT_CONSOLE
const CONSOLE_KIND = 11

# The engine's mips line form: chains, levels, texels, and time
const MIPS_LINE = "fps: mips {chains} chains, {levels} levels, {texels} texels in {ms} ms"

# The raster workers started on the specification's three harts
export const WORKERS_STARTED = 2

# The raster's worker slots, a secondary each: the ABI's harts less hart 0
export const GFX_SLOTS = 7

# The line saying the engine's images all loaded
export const FRAMES_LINE = "fps: frames 69 loaded, 0 missing"

# The line saying the engine's sounds all loaded
export const SOUNDS_LINE = "fps: sounds 16 loaded, 0 missing"

# The bands a frame line counts across every slot's hart
export def band-sum [frame: record]: nothing -> int {
    1..$GFX_SLOTS | each {|s| $frame | get $"bands($s)" } | math sum
}

# A run's mips line: chains, levels, texels, and time, held plausible
export def mips-built [lines: list<string>]: nothing -> record<chains: int, levels: int, texels: int, ms: int> {
    let line = ($lines | where {|l| $l starts-with "fps: mips " })
    assert equal ($line | length) 1 $"one mips line: ($line)"
    let got = ($line | get 0 | parse $MIPS_LINE | get 0 | update cells {|v| $v | into int })
    assert ($got.chains >= 1) $"chains built: ($line | get 0)"
    assert ($got.levels >= $got.chains) $"a level a chain at least: ($line | get 0)"
    assert ($got.texels > 0) $"texels built: ($line | get 0)"
    $got
}

# The frames that read a console command, as state counts before each
export def answered [api: binary, command: int]: nothing -> list<int> {
    mut states = 0
    mut frames = []
    for r in ($api | chunks $RECORD | where {|c| ($c | bytes length) == $RECORD }) {
        let kind = ($r | bytes at 0..<4 | into int --endian little)
        if $kind == 1 { $states += 1 }
        if $kind == $CONSOLE_KIND and ($r | bytes at 4..<8 | into int --endian little) == $command { $frames = ($frames | append $states) }
    }
    $frames
}
