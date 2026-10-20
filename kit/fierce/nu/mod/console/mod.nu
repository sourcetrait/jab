use (path self ../../../../../nu/mod/word)
use (path self ../pose)

# When a run's seed goes in, before the program's first frame
export const SEED_AT = 200ms

# The P frame's command byte, a placement, as a console record carries it
export const CONSOLE_P = 80

# The seed Render Zero's walk sends before its first frame
export const CLOCK_SEED = 7

# The cadence Render Zero's walk asks before its first frame
export const CLOCK_CADENCE = 0

# When the seed and the cadence go in before the first frame
export const CLOCK_SEED_AT = 200ms

# The capture nonce Render One's launch sends in its I
export const RECEIPT_NONCE = 0x0fed_cba9_8765_4321

# When a view read from the tile pool is first placed
export const PLACE_AT = 1500ms

# When the view is placed again, its frame read settled
export const SETTLE_AT = 2300ms

# The default's rows a band, render.inc's
export const GRAIN_DEFAULT = 32

# Render Zero's spawn view: the spawn's eye and yaw
export const SPAWN_POSE = { name: "spawn", x: 29.0, y: 2.5, z: 1.6, yaw: 150, pitch: 0 }

# The R frame: the seed as 64 bits in bytes 4 to 11
export def seed [seed: int]: nothing -> binary {
    [("R" | into binary), 0x[00 00 00], ($seed | into binary --endian little | bytes at 0..<8), (0..<52 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# The C frame: the cadence in byte 4
export def cadence [cadence: int]: nothing -> binary {
    [("C" | into binary), 0x[00 00 00], ($cadence | into binary --endian little | bytes at 0..<1), (0..<59 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# The I frame: the capture nonce in bytes 4 to 11, echoed in the load record
export def nonce [nonce: int]: nothing -> binary {
    [("I" | into binary), 0x[00 00 00], ($nonce | into binary --endian little | bytes at 0..<8), (0..<52 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# A run's sends before its route's: R, C, and I at SEED_AT, then any W
export def run-sends [seed: int, cadence: int, nonce: int, asked: record]: nothing -> list<any> {
    [{ at: $SEED_AT, bytes: (seed $seed) }, { at: $SEED_AT, bytes: (cadence $cadence) }, { at: $SEED_AT, bytes: (nonce $nonce) }]
    | append (workers-sends $asked)
}

# The W frame: the raster's workers in byte 4, a band's rows in bytes 8 to 11
export def workers [workers: int, grain: int]: nothing -> binary {
    [("W" | into binary), 0x[00 00 00], ($workers | into binary --endian little | bytes at 0..<1), 0x[00 00 00], ($grain | into binary --endian little | bytes at 0..<4), (0..<52 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# The W at SEED_AT for a run's asked workers and grain, none if none asked
export def workers-sends [asked: record]: nothing -> list<any> {
    if $asked.workers == null { [] } else { [{ at: $SEED_AT, bytes: (workers $asked.workers $asked.grain) }] }
}

# The L frame: tiles forgotten, lumels set, construction frozen or lifted
export def level [bright: bool, held: bool, --parity, --gradient]: nothing -> binary {
    let flag = {|on: bool| if $on { 0x[01] } else { 0x[00] } }
    [("L" | into binary), 0x[00 00 00], (do $flag $bright), (do $flag $held), (do $flag $gradient), (do $flag $parity), (0..<56 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# The B frame, a debug build's: a surface's every tile built at every level
export def build [surface: int]: nothing -> binary {
    [("B" | into binary), 0x[00 00 00], ($surface | into binary | bytes at 0..<4), (0..<56 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# The D frame, a debug build's: a surface's READY tiles written to the API
export def dump [surface: int, --building]: nothing -> binary {
    [("D" | into binary), 0x[00 00 00], ($surface | into binary | bytes at 0..<4), (if $building { 0x[01] } else { 0x[00] }), (0..<55 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# The M frame, a debug build's: every block's level raised, a HUD stamp
export def raise [levels: int, --stamp]: nothing -> binary {
    [("M" | into binary), 0x[00 00 00], ($levels | into binary | bytes at 0..<1), (if $stamp { 0x[01] } else { 0x[00] }), (0..<58 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# A view placed at PLACE_AT and SETTLE_AT, read settled on its tiles
export def settled [placed: record]: nothing -> list<any> {
    [{ at: $PLACE_AT, bytes: (pose pose-frame $placed) }, { at: $SETTLE_AT, bytes: (pose pose-frame $placed) }]
}

# The J frame, a debug build's: a worker delayed or faulted, rounds cancelled
export def jobs [delayed: int, delay_us: int, cancel: bool, fault: int, --hold]: nothing -> binary {
    [("J" | into binary), 0x[00 00 00], ($delayed | into binary | bytes at 0..<1), 0x[00 00 00], ($delay_us | into binary | bytes at 0..<4), (if $cancel { 0x[01] } else { 0x[00] }), ($fault | into binary | bytes at 0..<1), (if $hold { 0x[01] } else { 0x[00] }), (0..<49 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# The H frame, a debug build's: the grant's highest harts taken, or given back
export def harts [take: int]: nothing -> binary {
    [("H" | into binary), 0x[00 00 00], ($take | into binary | bytes at 0..<1), (0..<59 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# The Q frame, a CENSUS build's: a context line's chunk in bytes
export def census [chunk: int]: nothing -> binary {
    [("Q" | into binary), 0x[00 00 00], ($chunk | into binary | bytes at 0..<4), (0..<56 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# The K frame, a debug build's: the commands and spans a packet holds
export def packet [commands: int, spans: int]: nothing -> binary {
    let word = {|v: int| $v | into binary | bytes at 0..<4 }
    [("K" | into binary), 0x[00 00 00], (do $word $commands), (do $word $spans), (0..<52 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# The O frame, a debug build's: the pool's modes, trace, cold start, caps
export def pool [--modes: int = 0, --trace, --cold, --slots: int = 0, --guarantee: int = 0, --ring: int = 0, --merge-us: int = 0, --quota: int = 0]: nothing -> binary {
    let word = {|v: int| $v | into binary | bytes at 0..<4 }
    let flag = {|on: bool| if $on { 0x[01] } else { 0x[00] } }
    [("O" | into binary), 0x[00 00 00], ($modes | into binary | bytes at 0..<1), (do $flag $trace), (do $flag $cold), 0x[00], (do $word $slots), (do $word $guarantee), (do $word $ring), (do $word $merge_us), (do $word $quota), (0..<36 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# The V frame, a SERVICE build's: the service started with its load, or stopped
export def service [start: bool, --total: int = 0, --frames: int = 0, --lockstep, --corrupt: int = -1, --delay-us: int = 0]: nothing -> binary {
    [
        ("V" | into binary) 0x[00 00 00]
        (if $start { 0x[01] } else { 0x[00] }) (if $lockstep { 0x[01] } else { 0x[00] }) 0x[00 00]
        (word le $total 4) (word le $frames 4) (word le ($corrupt + 1) 8) (word le $delay_us 4) (word zeros 36)
    ] | bytes collect
}

# The S frame, a debug build's: stalls, a forced flip, and a consume spin
export def stall [on: bool, standing: int, once: int, forced: bool, spin: int]: nothing -> binary {
    [
        ("S" | into binary) 0x[00 00 00]
        (if $on { 0x[01] } else { 0x[00] }) (if $forced { 0x[01] } else { 0x[00] }) 0x[00 00]
        (word le $standing 4) (word le $once 4) (word le $spin 4) (word zeros 44)
    ] | bytes collect
}
