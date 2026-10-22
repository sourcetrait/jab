use (path self ../../stream)
use (path self ../presentation) [FLIP_PRESENTED]
use (path self ../../report) [CEILING_US]

# The span records a frame holds before its spans go unrecorded
const SPAN_RECORDS = 65536

# Every frame from 0 to `last` as a row: its leg, state, and records' columns
export def rows-of [s: record, legs: list<any>, last: int, schema: oneof<int, nothing>]: nothing -> list<any> {
    let names = ($legs | get name)
    let reach = ($legs | enumerate | each {|e| $legs | first ($e.index + 1) | each {|l| $l.places | length } | math sum })
    let phases = (stream phases-of $schema)
    let parts = (stream parts-of $schema)
    let at = ($schema | default 1)
    mut rows = []
    mut previous_flip: any = null
    for e in ($s.states | first ($last + 1) | enumerate) {
        let st = $e.item
        let leg_at = ($reach | enumerate | where {|r| $r.item >= $st.placed } | get -o 0.index | default (($names | length) - 1))
        let entry = (if $e.index == 0 { true } else { ($s.states | get ($e.index - 1) | get placed) != $st.placed })
        let f = ($s.frames | get -o $st.frame)
        let d = ($s.draws | get -o $st.frame)
        let p = (if $at >= 2 { $s.presents | get -o $st.frame } else { null })
        let k = (if $at >= 3 { $s.packets | get -o $st.frame } else { null })
        let t = (if $at >= 5 { $s.tiles | get -o $st.frame } else { null })
        let o = (if $at >= 5 { $s.storages | get -o $st.frame } else { null })
        let governing = (if $at >= 5 { $s.configs | where {|x| $x.from <= $st.frame } } else { [] })
        let pool = ((if $t == null { tileless } else { $t | reject frame schema })
            | merge (if $o == null { storageless } else { $o | reject frame schema })
            | merge (if ($governing | is-empty) { configless } else { $governing | last | reject schema arrival_states arrival_frames }))
        let h = (if $at >= 6 { $s.harts | get -o $st.frame } else { null })
        let masks = (if $h == null { hartsless } else { $h | reject frame schema })
        let rc = (if $at >= 7 { $s.receipts | get -o $st.frame } else { null })
        let receipt = (if $rc == null { receiptless } else {
            let bounded = ($at >= 8)
            { receipt_stamp: $rc.stamp, receipt_tick: $rc.tick, ordinal: $rc.ordinal, first_ordinal: $rc.first_ordinal, call_start: (if $bounded { $rc.call_start } else { null }), call_end: (if $bounded { $rc.call_end } else { null }) }
        })
        let sv = ($s.services | get -o $st.frame)
        let served = (if ($s.services | is-empty) { {} } else if $sv == null { serviceless } else {
            { service_us: $sv.service_us, service_applied: $sv.applied, service_rejected: $sv.rejected, service_age_us: $sv.age_us, service_depth: $sv.depth, service_skipped: $sv.skipped, service_flags: $sv.flags }
        })
        let base = {
            frame: $st.frame, leg: ($names | get $leg_at), entry: $entry, sector: $st.sector,
            x: $st.x, y: $st.y, z: $st.z, yaw: $st.yaw, pitch: $st.pitch, roll: $st.roll,
            draw_us: $st.draw_us, game_us: $st.game_us,
        } | merge $served
        if $f == null or $d == null {
            $rows = ($rows | append ($base | merge (clockless) | merge $pool | merge $masks | merge $receipt))
        } else {
            let presented = ($f.flip_status == $FLIP_PRESENTED)
            let interval = (if $presented and $previous_flip != null { $f.flip_done_us - $previous_flip } else { null })
            if $presented { $previous_flip = $f.flip_done_us }
            let shown = (if $p == null { presentationless } else { {
                cadence: $p.cadence, simulation_us: $p.simulation_us, next_start_us: $p.next_start_us,
                wait_us: $p.wait_us, pacing_us: $p.pacing_us, wakes: $p.wakes, wait_presses: $p.wait_presses,
                flip_attempts: $p.flip_attempts, refusals: $p.refusals,
                submission_age_us: (if $presented { $f.flip_done_us - $p.simulation_us } else { null }),
                residual_us: ($p.next_start_us - $f.start_us - ($f.critical_us + $p.wait_us + $f.await_us)),
            } })
            let timed = ($f | upsert pacing_us ($shown.pacing_us | default 0))
            let packed = (if $k == null { packetless } else { {
                preparation_us: $k.preparation_us, raster_us: $k.raster_us, commands: $k.commands, flushes: $k.flushes,
                invalidated: $k.invalidated, packet_bytes: $k.packet_bytes, snapshot: $k.snapshot,
                packet_residual_us: ($f.draw_us - $k.preparation_us - $k.raster_us),
                workers: $k.workers, grain: $k.grain, slowest_us: $k.slowest_us, busy_us: $k.busy_us,
                dispatch_us: $k.dispatch_us, barrier_us: $k.barrier_us,
            } })
            let drawn = ($d | upsert raster_us ($packed.raster_us | default 0))
            $rows = ($rows | append ($base | merge {
                start_us: $f.start_us, critical_us: $f.critical_us, hud_us: $f.hud_us, mix_us: $f.mix_us,
                flip_us: $f.flip_us, report_us: $f.report_us, await_us: $f.await_us, flip_done_us: $f.flip_done_us,
                flip_status: $f.flip_status, completion_interval_us: $interval, acceptance_interval_us: null,
                latency_us: ($f.flip_done_us - $f.start_us),
                unattributed_us: ($f.critical_us - ($phases | each {|ph| $timed | get $ph } | math sum) - ($served.service_us? | default 0)),
                clear_us: $d.clear_us, portals_us: $d.portals_us, planes_us: $d.planes_us, walls_us: $d.walls_us,
                sprites_us: $d.sprites_us, tiles_us: $d.tiles_us,
                parts_unattributed_us: ($f.draw_us - ($parts | each {|pt| $drawn | get $pt } | math sum)),
                tiles_built: $d.tiles_built, tile_resets: $d.tile_resets, tiled_pixels: $d.tiled_pixels,
                lit_pixels: $d.lit_pixels, fallback_pixels: ($d.lit_pixels - $d.tiled_pixels),
                tile_bytes: $d.tile_bytes, tile_peak: $d.tile_peak, spans: $d.spans, spans_over: ($d.spans > $SPAN_RECORDS),
                over: ($f.critical_us >= $CEILING_US),
                aligned: ($f.draw_us == $st.draw_us and $f.game_us == $st.game_us),
            } | merge $shown | merge $packed | merge $pool | merge $masks | merge $receipt))
        }
    }
    $rows
}

# A row's receipt columns, all null, below schema 7 or without its record
def receiptless []: nothing -> record {
    [receipt_stamp receipt_tick ordinal first_ordinal call_start call_end]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}

# A row's service columns, all null, but on a SERVICE build's frame
def serviceless []: nothing -> record {
    [service_us service_applied service_rejected service_age_us service_depth service_skipped service_flags]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}

# A row's harts masks, all null, below schema 6 or without its record
def hartsless []: nothing -> record {
    [online floor grant claimed started active reported]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}

# A row's clock columns, all null, presentation's and packets' among them
def clockless []: nothing -> record {
    [start_us critical_us hud_us mix_us flip_us report_us await_us flip_done_us flip_status completion_interval_us acceptance_interval_us latency_us unattributed_us clear_us portals_us planes_us walls_us sprites_us tiles_us parts_unattributed_us tiles_built tile_resets tiled_pixels lit_pixels fallback_pixels tile_bytes tile_peak spans spans_over over aligned]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
    | merge (presentationless)
    | merge (packetless)
}

# A row's presentation columns, all null, below schema 2
def presentationless []: nothing -> record {
    [cadence simulation_us next_start_us wait_us pacing_us wakes wait_presses flip_attempts refusals submission_age_us residual_us]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}

# A row's packet columns, workers' among them, all null, below schema 3
def packetless []: nothing -> record {
    [preparation_us raster_us commands flushes invalidated packet_bytes snapshot packet_residual_us workers grain slowest_us busy_us dispatch_us barrier_us]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}

# A row's tile record columns, all null, below schema 5 or without one
def tileless []: nothing -> record {
    [admitted dropped filtered batch_source batch_admitted merged unprocessed evicted build_us overrun_us hit_blocks straddling_blocks missed_blocks]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}

# A row's storage record columns, all null, below schema 5 or without one
def storageless []: nothing -> record {
    [slots_used slots_effective building ring_fill requesting merge_entries memory memory_peak]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}

# A row's configuration columns, all null, below schema 5 or none in force
def configless []: nothing -> record {
    [merge_us from tile_shift tile_size slots config_effective quota allowance_us config_flags guarantee ring recent directory_bytes tile_memory]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}
