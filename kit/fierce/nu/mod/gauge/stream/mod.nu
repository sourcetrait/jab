use ../../../map.nu
use ../../console [CONSOLE_P]
use ../../frame [RECORD]

# A state record's kind
const KIND_STATE = 1

# A frame's clock record kind
const KIND_FRAME = 7

# A frame's drawing record kind
const KIND_DRAW = 8

# The end marker's record kind
const KIND_END = 9

# A frame's presentation record kind
const KIND_PRESENT = 10

# A console answer's record kind, as the stream reads it
const KIND_CONSOLE = 11

# A frame's packet record kind
const KIND_PACKET = 12

# A frame's tile pool activity record kind
const KIND_TILE = 13

# The tile pool's configuration record kind
const KIND_CONFIG = 14

# A frame's tile pool storage record kind
const KIND_STORAGE = 15

# A frame's harts masks record kind
const KIND_HARTS = 18

# A debug build's witness of a frame's rounds under the cancel, record kind
const KIND_ROUNDS = 19

# A frame's receipt record kind, from schema 7
const KIND_RECEIPT = 20

# The load's record kind: its two presents and the capture nonce
const KIND_LOAD = 21

# A seed's command byte, R, as console records name it
const CONSOLE_R = 82

# A cadence's command byte, C, as console records name it
const CONSOLE_C = 67

# The workers' and grain's command byte, W, as console records name it
const CONSOLE_W = 87

# The capture nonce's command byte, I, as console records name it
const CONSOLE_I = 73

# The critical path's phases at each schema
const PHASES = {
    "1": [game_us draw_us hud_us mix_us flip_us report_us],
    "2": [game_us draw_us hud_us mix_us pacing_us flip_us report_us],
    "3": [game_us draw_us hud_us mix_us pacing_us flip_us report_us],
    "4": [game_us draw_us hud_us mix_us pacing_us flip_us report_us],
    "5": [game_us draw_us hud_us mix_us pacing_us flip_us report_us],
    "6": [game_us draw_us hud_us mix_us pacing_us flip_us report_us],
    "7": [game_us draw_us hud_us mix_us pacing_us flip_us report_us],
}

# The drawing's parts at each schema
const PARTS = {
    "1": [clear_us portals_us planes_us walls_us sprites_us],
    "2": [clear_us portals_us planes_us walls_us sprites_us],
    "3": [clear_us portals_us planes_us walls_us sprites_us raster_us],
    "4": [clear_us portals_us planes_us walls_us sprites_us raster_us],
    "5": [clear_us portals_us planes_us walls_us sprites_us raster_us tiles_us],
    "6": [clear_us portals_us planes_us walls_us sprites_us raster_us tiles_us],
    "7": [clear_us portals_us planes_us walls_us sprites_us raster_us tiles_us],
}

# The phases' class when they hold their rendering
const WITH_RENDERING = "with rendering"

# The phases' class when they hold preparation alone
const PREPARATION_ALONE = "preparation alone"

# The remainder's class when it holds no rendering
const NO_RENDERING = "holding no rendering"

# The remainder's class when it holds the raster
const HOLDING_RASTER = "holding the raster"

# The class of parts whose meaning is unknown
export const UNKNOWN_PARTS = "unknown"

# The tiles' class below schema 5: built in the plane and wall phases
const BUILT_IN_PHASES = "built inside the plane and wall phases"

# The tiles' class from schema 5: built at the pool's boundary
const BUILT_AT_BOUNDARY = "built at the pool's boundary"

# The schema 2 images whose parts are known, by their .jab SHA-256
const PHASE_IMAGES = {
    "ef8d01fa7e52c0076b6ca735803ae8ddb9c5a80c016e47577c5df4a51ef02234": {
        commit: "f59f7a740873f9dfad4c3bcab8126271fe475fd4", set: "release", flags: "-march=rva23u64",
        sdk: "sdk/src at 9397f24, the workspace at 31e4023", toolchain: "GNU Binutils 2.47.20260726, riscv64-unknown-linux-gnu",
        phases: $PREPARATION_ALONE, remainder: $HOLDING_RASTER,
    },
    "5d723b3f14e3bedeca11f03b95a196eac116d4f5c3aba8906c93b5040fe32ca4": {
        commit: "f59f7a740873f9dfad4c3bcab8126271fe475fd4", set: "debug", flags: "--defsym DEBUG=1 -march=rva23u64",
        sdk: "sdk/src at 9397f24, the workspace at 31e4023", toolchain: "GNU Binutils 2.47.20260726, riscv64-unknown-linux-gnu",
        phases: $PREPARATION_ALONE, remainder: $HOLDING_RASTER,
    },
    "263c84ee5b9a1b1f355d0242b9d775df74f86d2e73b90dc0aba4d0b0e96d2cf8": {
        commit: "f59f7a740873f9dfad4c3bcab8126271fe475fd4", set: "debug,owner", flags: "--defsym DEBUG=1 --defsym OWNER=1 -march=rva23u64",
        sdk: "sdk/src at 9397f24, the workspace at 31e4023", toolchain: "GNU Binutils 2.47.20260726, riscv64-unknown-linux-gnu",
        phases: $PREPARATION_ALONE, remainder: $HOLDING_RASTER,
    },
}

# The clock records' schema the walk and the fixtures are held to
export const CLOCK_SCHEMA = 7

# A record's little-endian 32-bit word at a byte offset
def u32-at [r: binary, at: int]: nothing -> int { $r | bytes at $at..<($at + 4) | into int --endian little }

# A record's little-endian 64-bit word at a byte offset
def u64-at [r: binary, at: int]: nothing -> int { $r | bytes at $at..<($at + 8) | into int --endian little }

# A capture's records read in order by kind through its first end marker
export def main [api: binary]: nothing -> record<states: list<any>, events: list<any>, seeded: bool, late_seed: bool, cadence_set: bool, late_cadence: bool, workers_set: bool, late_workers: bool, frames: list<any>, draws: list<any>, presents: list<any>, packets: list<any>, tiles: list<any>, storages: list<any>, configs: list<any>, harts: list<any>, rounds: list<any>, end: oneof<record<frame: int, schema: int>, nothing>, past: int, receipts: list<any>, loads: list<any>, nonce_set: bool, late_nonce: bool> {
    mut states = []
    mut events = []
    mut frames = []
    mut draws = []
    mut presents = []
    mut packets = []
    mut tiles = []
    mut storages = []
    mut configs = []
    mut harts = []
    mut rounds = []
    mut placed = 0
    mut seeded = false
    mut late_seed = false
    mut cadence_set = false
    mut late_cadence = false
    mut workers_set = false
    mut late_workers = false
    mut receipts = []
    mut loads = []
    mut nonce_set = false
    mut late_nonce = false
    mut end: any = null
    mut past = 0
    for r in ($api | chunks $RECORD | where {|c| ($c | bytes length) == $RECORD }) {
        let kind = (u32-at $r 0)
        if $end != null {
            if $kind == $KIND_STATE { $past += 1 }
        } else if $kind == $KIND_CONSOLE {
            let command = (u32-at $r 4)
            if $command == $CONSOLE_P { $placed += 1 }
            if $command == $CONSOLE_R {
                if ($states | is-empty) { $seeded = true } else { $late_seed = true }
            }
            if $command == $CONSOLE_C {
                if ($states | is-empty) { $cadence_set = true } else { $late_cadence = true }
            }
            if $command == $CONSOLE_W {
                if ($states | is-empty) { $workers_set = true } else { $late_workers = true }
            }
            if $command == $CONSOLE_I {
                if ($states | is-empty) { $nonce_set = true } else { $late_nonce = true }
            }
        } else if $kind == $KIND_STATE {
            $states = ($states | append {
                frame: ($states | length), placed: $placed,
                sector: ($r | bytes at 4..<8 | into int --endian little --signed),
                x: (map float-at $r 8), y: (map float-at $r 12), z: (map float-at $r 16), yaw: (map float-at $r 20),
                pitch: (map float-at $r 24), roll: (map float-at $r 28),
                draw_us: (u32-at $r 32), game_us: (u32-at $r 36),
            })
        } else if $kind >= 2 and $kind <= 6 {
            $events = ($events | append {
                frame: ($states | length), kind: $kind,
                fields: (0..<5 | each {|f| $r | bytes at (40 + $f * 4)..<(44 + $f * 4) | into int --endian little --signed }),
            })
        } else if $kind == $KIND_FRAME {
            $frames = ($frames | append {
                frame: (u32-at $r 4), start_us: (u64-at $r 8), critical_us: (u32-at $r 16), game_us: (u32-at $r 20),
                draw_us: (u32-at $r 24), hud_us: (u32-at $r 28), mix_us: (u32-at $r 32), flip_us: (u32-at $r 36),
                report_us: (u32-at $r 40), await_us: (u32-at $r 44), flip_done_us: (u64-at $r 48),
                flip_status: (u32-at $r 56), schema: (u32-at $r 60),
            })
        } else if $kind == $KIND_DRAW {
            $draws = ($draws | append {
                frame: (u32-at $r 4), clear_us: (u32-at $r 8), portals_us: (u32-at $r 12), planes_us: (u32-at $r 16),
                walls_us: (u32-at $r 20), sprites_us: (u32-at $r 24), tiles_us: (u32-at $r 28), tiles_built: (u32-at $r 32),
                tile_resets: (u32-at $r 36), tiled_pixels: (u32-at $r 40), lit_pixels: (u32-at $r 44),
                tile_bytes: (u32-at $r 48), tile_peak: (u32-at $r 52), spans: (u32-at $r 56), schema: (u32-at $r 60),
            })
        } else if $kind == $KIND_PRESENT {
            $presents = ($presents | append {
                frame: (u32-at $r 4), simulation_us: (u64-at $r 8), next_start_us: (u64-at $r 16), wait_us: (u32-at $r 24),
                pacing_us: (u32-at $r 28), wakes: (u32-at $r 32), wait_presses: (u32-at $r 36), flip_attempts: (u32-at $r 40),
                refusals: (u32-at $r 44), cadence: (u32-at $r 48), schema: (u32-at $r 60),
            })
        } else if $kind == $KIND_PACKET {
            let schema = (u32-at $r 60)
            let workers = (if $schema >= 4 {
                { workers: (u32-at $r 36), grain: (u32-at $r 40), slowest_us: (u32-at $r 44), busy_us: (u32-at $r 48), dispatch_us: (u32-at $r 52), barrier_us: (u32-at $r 56) }
            } else {
                { workers: null, grain: null, slowest_us: null, busy_us: null, dispatch_us: null, barrier_us: null }
            })
            $packets = ($packets | append ({
                frame: (u32-at $r 4), preparation_us: (u32-at $r 8), raster_us: (u32-at $r 12), commands: (u32-at $r 16),
                flushes: (u32-at $r 20), invalidated: (u32-at $r 24), packet_bytes: (u32-at $r 28), snapshot: (u32-at $r 32),
                schema: $schema,
            } | merge $workers))
        } else if $kind == $KIND_TILE {
            $tiles = ($tiles | append {
                frame: (u32-at $r 4), admitted: (u32-at $r 8), dropped: (u32-at $r 12), filtered: (u32-at $r 16),
                batch_source: (u32-at $r 20), batch_admitted: (u32-at $r 24), merged: (u32-at $r 28),
                unprocessed: (u32-at $r 32), evicted: (u32-at $r 36), build_us: (u32-at $r 40), overrun_us: (u32-at $r 44),
                hit_blocks: (u32-at $r 48), straddling_blocks: (u32-at $r 52), missed_blocks: (u32-at $r 56),
                schema: (u32-at $r 60),
            })
        } else if $kind == $KIND_STORAGE {
            $storages = ($storages | append {
                frame: (u32-at $r 4), slots_used: (u32-at $r 8), slots_effective: (u32-at $r 12), building: (u32-at $r 16),
                ring_fill: (u32-at $r 20), requesting: (u32-at $r 24), merge_entries: (u32-at $r 28),
                memory: (u32-at $r 32), memory_peak: (u32-at $r 36), schema: (u32-at $r 60),
            })
        } else if $kind == $KIND_CONFIG {
            $configs = ($configs | append {
                merge_us: (u32-at $r 4), from: (u32-at $r 8), tile_shift: (u32-at $r 12), tile_size: (u32-at $r 16), slots: (u32-at $r 20),
                config_effective: (u32-at $r 24), quota: (u32-at $r 28), allowance_us: (u32-at $r 32),
                config_flags: (u32-at $r 36), guarantee: (u32-at $r 40), ring: (u32-at $r 44), recent: (u32-at $r 48),
                directory_bytes: (u32-at $r 52), tile_memory: (u32-at $r 56), schema: (u32-at $r 60),
                arrival_states: ($states | length), arrival_frames: ($frames | length),
            })
        } else if $kind == $KIND_HARTS {
            $harts = ($harts | append {
                frame: (u32-at $r 4), online: (u32-at $r 8), floor: (u32-at $r 12), grant: (u32-at $r 16),
                claimed: (u32-at $r 20), started: (u32-at $r 24), active: (u32-at $r 28), reported: (u32-at $r 32),
                schema: (u32-at $r 60),
            })
        } else if $kind == $KIND_ROUNDS {
            $rounds = ($rounds | append { frame: (u32-at $r 4), rounds: (u32-at $r 8), cancelled: (u32-at $r 12) })
        } else if $kind == $KIND_RECEIPT {
            $receipts = ($receipts | append {
                frame: (u32-at $r 4), stamp: (u64-at $r 8), tick: (u64-at $r 16), ordinal: (u64-at $r 24),
                first_ordinal: (u64-at $r 32), schema: (u32-at $r 60),
            })
        } else if $kind == $KIND_LOAD {
            $loads = ($loads | append {
                title_stamp: (u64-at $r 8), title_end_us: (u64-at $r 16), clear_stamp: (u64-at $r 24), clear_end_us: (u64-at $r 32),
                title_ordinal: (u32-at $r 40), clear_ordinal: (u32-at $r 44), nonce: (u64-at $r 48), schema: (u32-at $r 60),
                arrival_states: ($states | length),
            })
        } else if $kind == $KIND_END {
            $end = { frame: (u32-at $r 4), schema: (u32-at $r 60) }
        }
    }
    {
        states: $states, events: $events, seeded: $seeded, late_seed: $late_seed, cadence_set: $cadence_set,
        late_cadence: $late_cadence, workers_set: $workers_set, late_workers: $late_workers, frames: $frames,
        draws: $draws, presents: $presents, packets: $packets, tiles: $tiles, storages: $storages, configs: $configs,
        harts: $harts, rounds: $rounds, end: $end, past: $past, receipts: $receipts, loads: $loads,
        nonce_set: $nonce_set, late_nonce: $late_nonce,
    }
}

# The schema of a capture's clock records: the end marker's, else the first's
export def schema-of [s: record]: nothing -> oneof<int, nothing> {
    if $s.end != null { return $s.end.schema }
    let first = ($s.frames | append $s.draws | append $s.presents | append $s.packets | append $s.tiles | append $s.storages | append $s.configs | append $s.harts | append $s.receipts | get -o 0)
    if $first == null { null } else { $first.schema }
}

# The critical path's phases at a schema, schema 1's for one not taken
export def phases-of [schema: oneof<int, nothing>]: nothing -> list<string> {
    $PHASES | get -o ($schema | default 1 | into string) | default ($PHASES | get "1")
}

# The drawing's parts at a schema, schema 1's for one not taken
export def parts-of [schema: oneof<int, nothing>]: nothing -> list<string> {
    $PARTS | get -o ($schema | default 1 | into string) | default ($PARTS | get "1")
}

# What a run's moved parts measure, by schema or listed image, with evidence
export def parts-meaning [schema: any, image: any]: nothing -> record<phases: string, remainder: string, tiles: string, evidence: string> {
    let tiles = (if $schema in [5 6 7] { $BUILT_AT_BOUNDARY } else if $schema in [1 2 3 4] { $BUILT_IN_PHASES } else { $UNKNOWN_PARTS })
    if $schema == 1 { return { phases: $WITH_RENDERING, remainder: $NO_RENDERING, tiles: $tiles, evidence: "schema 1" } }
    if $schema in [3 4 5 6 7] { return { phases: $PREPARATION_ALONE, remainder: $NO_RENDERING, tiles: $tiles, evidence: $"schema ($schema)" } }
    let listed = (if $schema == 2 and $image != null { $PHASE_IMAGES | transpose image entry | where image == $image | get -o 0.entry } else { null })
    if $listed != null {
        return { phases: $listed.phases, remainder: $listed.remainder, tiles: $tiles, evidence: $"the listed image of ($listed.commit | str substring 0..<7), ($listed.set)" }
    }
    let why = (if $schema == 2 { "schema 2 with no listed image" } else { $"schema ($schema | default 'none')" })
    { phases: $UNKNOWN_PARTS, remainder: $UNKNOWN_PARTS, tiles: $tiles, evidence: $why }
}

# The schema 2 images whose parts are known, keyed by SHA-256
def phase-images []: nothing -> record {
    $PHASE_IMAGES
}
