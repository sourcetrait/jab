use (path self ../presentation) [CADENCES CADENCE_AFTER_FLIP FLIP_EARLY FLIP_PRESENTED FLIP_VALID]

# The batch source of the first boundary, which consumes none
const NO_BATCH = 4294967295

# The most raster workers a frame may have through schema 5
const WORKERS_MAX_TO_FIVE = 2

# The ABI's harts, a harts mask's bound
const HARTS_MAX = 8

# The validity bound in microseconds on the residual the conversions drop
const RESIDUAL_US = 4

# A packet command's bytes by schema, the polygon record copied whole
const COMMAND_BYTES = { "3": 312, "4": 312, "5": 232, "6": 232, "7": 232, "8": 232 }

# A span record's bytes in a packet
const SPAN_BYTES = 16

# The microsecond a drawing may run past its preparation and raster
const PACKET_RESIDUAL_US = 1

# The screen's rows, a grain's bound
export const SCREEN_ROWS = 1080

# What makes a complete window invalid, schema by schema
export def invalidity [rows: list<any>, schema: oneof<int, nothing>]: nothing -> list<string> {
    let unshown = ($rows | where {|r| $r.flip_status not-in $FLIP_VALID })
    let negative = ($rows | where {|r| $r.unattributed_us < 0 or $r.parts_unattributed_us < 0 })
    let misaligned = ($rows | where {|r| not $r.aligned })
    let base = [
        (if ($unshown | is-empty) { null } else { $"($unshown | length) flips at status ($unshown | get flip_status | uniq | each {|v| $v | into string } | str join ', '), never shown" }),
        (if ($negative | is-empty) { null } else { $"($negative | length) frames whose phases or parts sum past their whole" }),
        (if ($misaligned | is-empty) { null } else { $"($misaligned | length) frames whose clock record differs from their state's" }),
    ]
    let at = ($schema | default 1)
    if $at < 2 { return ($base | compact) }
    let every = $rows
    let unrecorded = ($every | where {|r| $r.cadence == null })
    let rows = ($every | where {|r| $r.cadence != null })
    let outside = ($rows | where {|r| $r.cadence not-in $CADENCES })
    let after = ($rows | where {|r| $r.cadence == $CADENCE_AFTER_FLIP })
    let waited = ($after | where {|r| $r.wait_us != 0 or $r.pacing_us != 0 })
    let retried = ($after | where {|r| $r.flip_attempts != 1 })
    let unpresented = ($rows | where {|r| $r.cadence in [1 2] and $r.flip_status != $FLIP_PRESENTED })
    let counted = ($rows | where {|r| $r.flip_attempts != ($r.refusals + (if $r.flip_status == $FLIP_EARLY { 0 } else { 1 })) })
    let unbalanced = ($rows | where {|r| $r.residual_us < 0 or $r.residual_us > $RESIDUAL_US })
    let disordered = ($rows | where {|r| not ($r.start_us <= $r.simulation_us and $r.simulation_us <= $r.flip_done_us and $r.flip_done_us <= $r.next_start_us) })
    let broken = ($rows | window 2 | where {|w| $w.0.next_start_us != $w.1.start_us })
    let presented = [
        (if ($unrecorded | is-empty) { null } else { $"($unrecorded | length) frames without a presentation record" }),
        (if ($outside | is-empty) { null } else { $"($outside | length) frames at a cadence outside 0 to 2" }),
        (if ($waited | is-empty) { null } else { $"($waited | length) frames under cadence 0 with a wait or a pacing" }),
        (if ($retried | is-empty) { null } else { $"($retried | length) frames under cadence 0 whose flip was attempted other than once" }),
        (if ($unpresented | is-empty) { null } else { $"($unpresented | length) frames under cadence 1 or 2 whose final flip was not presented" }),
        (if ($counted | is-empty) { null } else { $"($counted | length) frames whose attempts are not their refusals and their final attempt" }),
        (if ($unbalanced | is-empty) { null } else { $"($unbalanced | length) frames whose next start less their start is not their critical path, wait, and await" }),
        (if ($disordered | is-empty) { null } else { $"($disordered | length) frames whose start, simulation, flip end, and next start are out of order" }),
        (if ($broken | is-empty) { null } else { $"($broken | length) frames whose next start is not the next frame's start" }),
    ]
    if $at < 3 { return ($base | append $presented | compact) }
    let unpacked = ($every | where {|r| $r.raster_us == null })
    let packed = ($every | where {|r| $r.raster_us != null })
    let unsplit = ($packed | where {|r| $r.packet_residual_us < 0 or $r.packet_residual_us > $PACKET_RESIDUAL_US })
    let command_bytes = ($COMMAND_BYTES | get ($at | into string))
    let unsized = ($packed | where {|r| $r.packet_bytes != ($r.commands * $command_bytes + $r.spans * $SPAN_BYTES) })
    let stale = ($packed | where {|r| $r.snapshot != $r.frame })
    let packets = [
        (if ($unpacked | is-empty) { null } else { $"($unpacked | length) frames without a packet record" }),
        (if ($unsplit | is-empty) { null } else { $"($unsplit | length) frames whose drawing is not their preparation and their raster" }),
        (if ($unsized | is-empty) { null } else { $"($unsized | length) frames whose packets' bytes are not their commands' and their span records'" }),
        (if ($stale | is-empty) { null } else { $"($stale | length) frames whose packets were prepared from another frame's simulation" }),
    ]
    if $at < 4 { return ($base | append $presented | append $packets | compact) }
    let crowded = (if $at >= 6 { [] } else { $packed | where {|r| ($r.workers | default 0) > $WORKERS_MAX_TO_FIVE } })
    let coarse = ($packed | where {|r| ($r.grain | default 0) > $SCREEN_ROWS })
    let serial_timed = ($packed | where {|r| $r.workers == 0 and ([$r.slowest_us $r.busy_us $r.dispatch_us $r.barrier_us] | any {|t| ($t | default 0) != 0 }) })
    let overtimed = ($packed | where {|r| ($r.workers | default 0) > 0 and ([$r.slowest_us $r.dispatch_us $r.barrier_us] | any {|t| ($t | default 0) > $r.raster_us }) })
    let short_busy = ($packed | where {|r| ($r.workers | default 0) > 0 and ($r.busy_us | default 0) < ($r.slowest_us | default 0) })
    let long_busy = ($packed | where {|r| let w = ($r.workers | default 0); $w > 0 and ($r.busy_us | default 0) > ($w * ($r.slowest_us | default 0) + $w - 1) })
    let workers = [
        (if ($crowded | is-empty) { null } else { $"($crowded | length) frames drawn by more than ($WORKERS_MAX_TO_FIVE) workers" }),
        (if ($coarse | is-empty) { null } else { $"($coarse | length) frames at a grain past the screen's ($SCREEN_ROWS) rows" }),
        (if ($serial_timed | is-empty) { null } else { $"($serial_timed | length) frames of the serial backend carrying a round's time" }),
        (if ($overtimed | is-empty) { null } else { $"($overtimed | length) frames whose slowest worker, dispatch, or barrier is past their raster" }),
        (if ($short_busy | is-empty) { null } else { $"($short_busy | length) frames whose workers' busy time is less than their slowest's" }),
        (if ($long_busy | is-empty) { null } else { $"($long_busy | length) frames whose workers' busy time is past W times their slowest's" }),
    ]
    if $at < 5 { return ($base | append $presented | append $packets | append $workers | compact) }
    if $at < 6 { return ($base | append $presented | append $packets | append $workers | append (pool-invalidity $every) | compact) }
    $base | append $presented | append $packets | append $workers | append (pool-invalidity $every) | append (harts-invalidity $every) | compact
}

# The count of harts a mask holds
def popcount [mask: int]: nothing -> int {
    0..<$HARTS_MAX | where {|h| (($mask bit-shr $h) bit-and 1) == 1 } | length
}

# What makes a schema 6 window invalid in its harts' masks
def harts-invalidity [rows: list<any>]: nothing -> list<any> {
    let unharted = ($rows | where {|r| $r.online == null })
    let masked = ($rows | where {|r| $r.online != null })
    let unhoused = ($masked | where {|r| ($r.active bit-and $r.started) != $r.active })
    let ungranted = ($masked | where {|r| ($r.started bit-and $r.grant) != $r.started })
    let miscounted = ($masked | where {|r| $r.workers != null and $r.workers != (popcount $r.active) })
    let misreported = ($masked | where {|r| $r.reported != $r.active })
    let doubled = ($masked | where {|r| ($r.claimed bit-and $r.grant) != 0 })
    let offline = ($masked | where {|r| ($r.grant bit-and $r.online) != $r.grant or ($r.claimed bit-and $r.online) != $r.claimed })
    let impossible = ($masked | where {|r| ($r.online bit-and 1) != 0 or $r.online >= (1 bit-shl $HARTS_MAX) })
    let underfloor = ($masked | where {|r| (popcount $r.grant) < $r.floor })
    [
        (if ($unharted | is-empty) { null } else { $"($unharted | length) frames without a harts record" }),
        (if ($unhoused | is-empty) { null } else { $"($unhoused | length) frames dispatched to a hart holding no raster worker" }),
        (if ($ungranted | is-empty) { null } else { $"($ungranted | length) frames with a raster worker on a hart outside the grant" }),
        (if ($miscounted | is-empty) { null } else { $"($miscounted | length) frames whose packet record's workers are not their active harts' count" }),
        (if ($misreported | is-empty) { null } else { $"($misreported | length) frames whose reporting harts are not their active" }),
        (if ($doubled | is-empty) { null } else { $"($doubled | length) frames with a claimed hart inside the grant" }),
        (if ($offline | is-empty) { null } else { $"($offline | length) frames whose grant or claimed harts lie outside the online secondaries" }),
        (if ($impossible | is-empty) { null } else { $"($impossible | length) frames whose online mask holds hart 0 or a hart past the ABI's bound" }),
        (if ($underfloor | is-empty) { null } else { $"($underfloor | length) frames whose grant holds fewer harts than its floor" }),
    ]
}

# What makes a schema 5 window invalid in its tile pool
def pool-invalidity [rows: list<any>]: nothing -> list<any> {
    let untiled = ($rows | where {|r| $r.admitted == null })
    let unstored = ($rows | where {|r| $r.slots_used == null })
    let unconfigured = ($rows | where {|r| $r.tile_memory == null })
    let pooled = ($rows | where {|r| $r.admitted != null and $r.slots_used != null and $r.tile_memory != null })
    let by_frame = ($pooled | reduce --fold {} {|r, acc| $acc | upsert ($r.frame | into string) $r.admitted })
    let overfull = ($pooled | where {|r| $r.slots_used > $r.slots_effective or $r.building > $r.slots_effective })
    let beyond = ($pooled | where {|r| $r.slots_effective > $r.slots })
    let overbuilt = ($pooled | where {|r| $r.tiles_built > $r.slots_effective or $r.evicted > $r.slots_effective })
    let unbuilt = ($pooled | where {|r| $r.building > $r.slots_used })
    let overtime = ($pooled | where {|r| $r.build_us > $r.tiles_us })
    let overmerged = ($pooled | where {|r| $r.merged > $r.batch_admitted })
    let overspent = ($pooled | where {|r| ($r.merged + $r.unprocessed) > $r.batch_admitted })
    let unsourced = ($pooled | where {|r| if $r.frame == 0 { $r.batch_source != $NO_BATCH } else { $r.batch_source != ($r.frame - 1) } })
    let unsentinel = ($pooled | where {|r| $r.frame == 0 and ($r.batch_admitted != 0 or $r.merged != 0 or $r.unprocessed != 0) })
    let overmemory = ($pooled | where {|r| $r.memory > $r.tile_memory or $r.memory > $r.memory_peak or $r.memory_peak > $r.tile_memory })
    let falling = ($pooled | window 2 | where {|w| $w.1.memory_peak < $w.0.memory_peak or $w.1.tile_peak < $w.0.tile_peak })
    let unbatched = ($pooled | where {|r| $r.frame > 0 and ($by_frame | get -o ($r.batch_source | into string)) != null and ($by_frame | get ($r.batch_source | into string)) != $r.batch_admitted })
    let unconfigured_slots = ($pooled | where {|r| $r.slots_effective != $r.config_effective })
    let unsized = ($pooled | where {|r| $r.tile_bytes != ($r.slots_used * $r.tile_size) })
    let unasked = ($pooled | where {|r| $r.missed_blocks != ($r.admitted + $r.dropped + $r.filtered) })
    [
        (if ($untiled | is-empty) { null } else { $"($untiled | length) frames without a tile record" }),
        (if ($unstored | is-empty) { null } else { $"($unstored | length) frames without a storage record" }),
        (if ($unconfigured | is-empty) { null } else { $"($unconfigured | length) frames with no configuration of the tile pool in force" }),
        (if ($overfull | is-empty) { null } else { $"($overfull | length) frames whose slots in use or BUILDING slots pass the effective slots" }),
        (if ($beyond | is-empty) { null } else { $"($beyond | length) frames whose effective slots pass the physical" }),
        (if ($overbuilt | is-empty) { null } else { $"($overbuilt | length) frames that built or evicted past the effective slots" }),
        (if ($unbuilt | is-empty) { null } else { $"($unbuilt | length) frames with more BUILDING slots than slots in use" }),
        (if ($overtime | is-empty) { null } else { $"($overtime | length) frames whose construction passes their boundary's time" }),
        (if ($overmerged | is-empty) { null } else { $"($overmerged | length) frames that merged past their batch's admitted requests" }),
        (if ($overspent | is-empty) { null } else { $"($overspent | length) frames that merged and left unprocessed past their batch's admitted requests" }),
        (if ($unsourced | is-empty) { null } else { $"($unsourced | length) frames whose batch is not the frame before's" }),
        (if ($unsentinel | is-empty) { null } else { $"($unsentinel | length) first boundaries whose sentinel batch holds requests" }),
        (if ($overmemory | is-empty) { null } else { $"($overmemory | length) frames whose memory in use passes TILE_MEMORY or its high-water, or whose high-water passes TILE_MEMORY" }),
        (if ($falling | is-empty) { null } else { $"($falling | length) frames whose memory's or tiles' high-water fell" }),
        (if ($unbatched | is-empty) { null } else { $"($unbatched | length) frames whose batch's admitted requests are not its source frame's admissions" }),
        (if ($unconfigured_slots | is-empty) { null } else { $"($unconfigured_slots | length) frames whose effective slots are not their configuration's" }),
        (if ($unsized | is-empty) { null } else { $"($unsized | length) frames whose tile bytes are not their slots in use's" }),
        (if ($unasked | is-empty) { null } else { $"($unasked | length) frames whose blocks drawn without their tiles are not their requests admitted, dropped, and filtered" }),
    ]
}
