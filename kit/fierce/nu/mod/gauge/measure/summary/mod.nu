use (path self ../../stream)
use (path self ../presentation) [FLIP_EARLY]

# The multiple of its leg's median an outlier phase must pass
const OUTLIER_RATIO = 4

# The microseconds over its leg's median an outlier phase must pass
const OUTLIER_US = 2000

# The android events' names, indexed as the program reports them
const ANDROID_EVENTS = [none roused fired struck destroyed fallen waypoint]

# What a round met, named, indexed as the program reports it
const MET = [nothing geometry android]

# A list's count, least, median, 95th, 99th, and greatest by nearest rank
export def stats [values: list<any>]: nothing -> record {
    let v = ($values | compact)
    let n = ($v | length)
    if $n == 0 { return { count: 0, min: null, median: null, p95: null, p99: null, max: null } }
    let s = ($v | sort)
    let rank = {|q: float| $s | get ((($q * $n) | math ceil) - 1) }
    { count: $n, min: ($s | first), median: (do $rank 0.5), p95: (if $n >= 20 { do $rank 0.95 } else { null }), p99: (if $n >= 100 { do $rank 0.99 } else { null }), max: ($s | last) }
}

# A list's sum with nulls dropped, 0 for no values
export def total [values: list<any>]: nothing -> int {
    let v = ($values | compact)
    if ($v | is-empty) { 0 } else { $v | math sum }
}

# A leg's frames summed up: counts, phases, flips, parts, pool, workers
export def leg-summary [name: string, rows: list<any>, period_us: number]: nothing -> record {
    let clocked = ($rows | where {|r| $r.critical_us != null })
    let base = { leg: $name, frames: ($rows | length), entries: ($rows | where entry | length), draw: (stats ($rows | get draw_us)), game: (stats ($rows | get game_us)) }
    if ($clocked | is-empty) { return $base }
    let fast = ($clocked | where {|r| $r.critical_us < $period_us })
    let held = ($clocked | get packet_bytes | compact)
    $base | merge {
        over: ($clocked | where {|r| $r.over } | length),
        fast: ($fast | length),
        fast_waited: ($fast | where {|r| ($r.wait_us | default 0) > 0 } | length),
        wait: (stats ($clocked | get wait_us)),
        pacing: (stats ($clocked | get pacing_us)),
        submission_age: (stats ($clocked | get submission_age_us)),
        wakes: (total ($clocked | get wakes)),
        wait_presses: (total ($clocked | get wait_presses)),
        attempts: (total ($clocked | get flip_attempts)),
        refusals: (total ($clocked | get refusals)),
        critical: (stats ($clocked | get critical_us)),
        hud: (stats ($clocked | get hud_us)),
        mix: (stats ($clocked | get mix_us)),
        flip: (stats ($clocked | get flip_us)),
        report: (stats ($clocked | get report_us)),
        await: (stats ($clocked | get await_us)),
        flips_early: ($clocked | where {|r| $r.flip_status == $FLIP_EARLY } | length),
        flips_failed: ($clocked | where {|r| $r.flip_status > $FLIP_EARLY } | length),
        completion_interval: (stats ($clocked | get completion_interval_us)),
        acceptance_interval: (stats ($clocked | get acceptance_interval_us)),
        latency: (stats ($clocked | get latency_us)),
        unattributed: (stats ($clocked | get unattributed_us)),
        parts_unattributed: (stats ($clocked | get parts_unattributed_us)),
        clear: (stats ($clocked | get clear_us)),
        portals: (stats ($clocked | get portals_us)),
        planes: (stats ($clocked | get planes_us)),
        walls: (stats ($clocked | get walls_us)),
        sprites: (stats ($clocked | get sprites_us)),
        tiles: (stats ($clocked | get tiles_us)),
        tiles_built: (total ($clocked | get tiles_built)),
        building_frames: ($clocked | where {|r| $r.tiles_built > 0 } | length),
        tiled_pixels: (total ($clocked | get tiled_pixels)),
        fallback_pixels: (total ($clocked | get fallback_pixels)),
        tile_bytes_max: ($clocked | get tile_bytes | math max),
        tile_peak: ($clocked | get tile_peak | math max),
        tile_resets: ($clocked | get tile_resets | math max),
        spans_max: ($clocked | get spans | math max),
        spans_over: ($clocked | where {|r| $r.spans_over } | length),
        misaligned: ($clocked | where {|r| not $r.aligned } | length),
        preparation: (stats ($clocked | get preparation_us)),
        raster: (stats ($clocked | get raster_us)),
        commands: (stats ($clocked | get commands)),
        flushes: (total ($clocked | get flushes)),
        invalidated: (total ($clocked | get invalidated)),
        packet_bytes_max: (if ($held | is-empty) { null } else { $held | math max }),
        workers: ($clocked | get workers | compact | uniq | sort),
        grains: ($clocked | get grain | compact | uniq | sort),
        grants: ($clocked | get grant | compact | uniq | sort),
        actives: ($clocked | get active | compact | uniq | sort),
        slowest: (stats ($clocked | get slowest_us)),
        busy: (stats ($clocked | get busy_us)),
        dispatch: (stats ($clocked | get dispatch_us)),
        barrier: (stats ($clocked | get barrier_us)),
        admitted: (total ($clocked | get admitted)),
        dropped: (total ($clocked | get dropped)),
        filtered: (total ($clocked | get filtered)),
        merged: (total ($clocked | get merged)),
        unprocessed: (total ($clocked | get unprocessed)),
        evicted: (total ($clocked | get evicted)),
        build: (stats ($clocked | get build_us)),
        overrun: (stats ($clocked | get overrun_us)),
        hit_blocks: (total ($clocked | get hit_blocks)),
        straddling_blocks: (total ($clocked | get straddling_blocks)),
        missed_blocks: (total ($clocked | get missed_blocks)),
        slots_used_max: (greatest ($clocked | get slots_used)),
        ring_fill_max: (greatest ($clocked | get ring_fill)),
        memory_peak: (greatest ($clocked | get memory_peak)),
    } | merge (if "service_us" in ($clocked | columns) { {
        service: (stats ($clocked | get service_us)),
        service_applied: (total ($clocked | get service_applied)),
        service_depth_max: (greatest ($clocked | get service_depth)),
        service_skipped: (greatest ($clocked | get service_skipped)),
    } } else { {} })
}

# A list's greatest value with nulls dropped, null for none
export def greatest [values: list<any>]: nothing -> any {
    let v = ($values | compact)
    if ($v | is-empty) { null } else { $v | math max }
}

# The unexplained phase outliers in frames no placement opened
export def outliers [rows: list<any>, schema: oneof<int, nothing>]: nothing -> list<any> {
    let clocked = ($rows | where {|r| $r.critical_us != null })
    let watched = (stream phases-of $schema)
    $clocked | get leg | uniq | each {|leg|
        let these = ($clocked | where leg == $leg)
        let medians = ($watched | append "tiles_us" | reduce --fold {} {|p, acc| $acc | insert $p ((stats ($these | get $p)).median | default 0) })
        $these | where {|r| not $r.entry } | each {|r|
            let phases = ($watched | where {|p| let v = ($r | get $p | default 0); let m = ($medians | get $p); $v > ($OUTLIER_RATIO * $m) and ($v - $m) > $OUTLIER_US })
            let tiles_held = ($r.tiles_us <= (2 * ([($medians | get tiles_us) 100] | math max)))
            if ($phases | is-empty) or (not $tiles_held) { null } else {
                { frame: $r.frame, leg: $leg, phases: ($phases | each {|p| { phase: $p, us: ($r | get $p), median: ($medians | get $p) } }), critical_us: $r.critical_us }
            }
        } | compact
    } | flatten
}

# The play's outcomes in the window: rounds, android events, strikes, pickups
export def outcomes-of [events: list<any>, rows: list<any>, last: int]: nothing -> record {
    let inside = ($events | where {|e| $e.frame <= $last })
    let rounds = ($inside | where kind == 2 | each {|e| $MET | get -o ($e.fields | get 0) | default "unknown" } | uniq --count | each {|c| { met: $c.value, count: $c.count } })
    let androids = ($inside | where kind == 3 | each {|e| $ANDROID_EVENTS | get -o ($e.fields | get 0) | default "unknown" } | uniq --count | each {|c| { event: $c.value, count: $c.count } })
    {
        rounds: $rounds,
        androids: $androids,
        struck: ($inside | where kind == 4 | length),
        pickups: ($inside | where kind == 5 | length),
        sectors: ($rows | get leg | uniq | each {|leg| { leg: $leg, sectors: ($rows | where leg == $leg | get sector | uniq) } }),
    }
}
