# An API record's size in bytes
const RECORD = 64

# A tile dump header's record kind
const DUMP_KIND = 16

# A tile dump texel record's kind
const TEXELS_KIND = 17

# A console answer's record kind
const CONSOLE_KIND = 11

# The D frame's command, 68, as a console answer carries it
const CONSOLE_D = 68

# A tile's side in texels
export const SIDE = 64

# The texels a dump record carries, twelve, render.inc's DUMP_TEXELS
const DUMP_TEXELS = 12

# A tile's texel records in a dump, render.inc's DUMP_RECORDS at 64
const DUMP_RECORDS = 342

# The dump records' schema, render.inc's REPORT_SCHEMA_VERSION
const SCHEMA = 8

# The schema's byte offset in a dump record, render.inc's REPORT_SCHEMA
const SCHEMA_AT = 60

# A tile's records closed: count and padding problems, its texels if whole
def close-tile [tile: record, payloads: list<binary>, at: int, dump: int, bad: bool, --hash]: nothing -> record<tile: any, problems: list<any>> {
    let count = ($payloads | length)
    let tail = ($DUMP_RECORDS * $DUMP_TEXELS - $SIDE * $SIDE)
    let past = (if $count == 0 { [] } else { $payloads | last | bytes at (($DUMP_TEXELS - $tail) * 4)..<($DUMP_TEXELS * 4) | chunks 4 | into int --endian little | where {|w| $w != 0 } })
    let problems = ([
        (if $count != $DUMP_RECORDS { { reason: "count", record: $at, dump: $dump, found: $"($count) texel records of ($DUMP_RECORDS)" } })
        (if $count == $DUMP_RECORDS and ($past | is-not-empty) { { reason: "padding", record: $at, dump: $dump, found: $"($past | length) texels past the tile's last not zero" } })
    ] | compact)
    let whole = ((not $bad) and ($problems | is-empty))
    let bytes = (if $whole { $payloads | bytes collect | bytes at 0..<($SIDE * $SIDE * 4) } else { 0x[] })
    let read = (if not $whole { null } else if $hash { $tile | insert texels_sha256 ($bytes | hash sha256) } else { $tile | insert texels ($bytes | chunks 4 | into int --endian little | chunks $SIDE) })
    { tile: $read, problems: $problems }
}

# The tile dumps an API capture holds, each tile read whole, and every problem
export def read [api: binary, --hash]: nothing -> record<dumps: list<any>, problems: list<any>> {
    mut dumps = []
    mut problems = []
    mut tiles = []
    mut open = false
    mut tile: any = null
    mut header_at = 0
    mut payloads = []
    mut next = 0
    mut bad = false
    for e in ($api | chunks $RECORD | enumerate) {
        let r = $e.item
        let at = $e.index
        let dump = ($dumps | length)
        if ($r | bytes length) != $RECORD {
            $problems = ($problems | append { reason: "truncated", record: $at, dump: $dump, found: $"($r | bytes length) bytes of ($RECORD)" })
            break
        }
        let word = {|o: int| $r | bytes at $o..<($o + 4) | into int --endian little }
        let kind = (do $word 0)
        let command = (do $word 4)
        let answer = ($kind == $CONSOLE_KIND and $command == $CONSOLE_D)
        if ($kind == $DUMP_KIND or $answer) and $tile != null {
            let c = (close-tile $tile $payloads $header_at $dump $bad --hash=$hash)
            $problems = ($problems | append $c.problems)
            if $c.tile != null { $tiles = ($tiles | append $c.tile) }
            $tile = null
        }
        if $kind == $DUMP_KIND {
            $tile = { slot: (do $word 4), key: (do $word 8), surface: (do $word 12), level: (do $word 16), tx: (do $word 20), ty: (do $word 24), k: (do $word 28), w: (do $word 32), h: (do $word 36), frame: (do $word 40), generation: (do $word 44), state: (do $word 48), row: (do $word 52) }
            $header_at = $at
            $payloads = []
            $next = 0
            $open = true
            $bad = ((do $word $SCHEMA_AT) != $SCHEMA)
            if $bad { $problems = ($problems | append { reason: "header schema", record: $at, dump: $dump, found: $"schema (do $word $SCHEMA_AT)" }) }
        } else if $kind == $TEXELS_KIND {
            if $tile == null {
                $problems = ($problems | append { reason: "orphan", record: $at, dump: $dump, found: "a texel record outside any tile" })
            } else {
                let slot = (do $word 4)
                let first = (do $word 8)
                let schema = (do $word $SCHEMA_AT)
                let order = (if ($first mod $DUMP_TEXELS) != 0 { "first texel" } else if $first == ($next - $DUMP_TEXELS) { "repeated" } else if $first > $next { "missing" } else if $first < $next { "order" } else { "" })
                let found = ([
                    (if $slot != $tile.slot { { reason: "slot", record: $at, dump: $dump, found: $"slot ($slot) in tile ($tile.slot)'s records" } })
                    (if $schema != $SCHEMA { { reason: "schema", record: $at, dump: $dump, found: $"schema ($schema)" } })
                    (if $order != "" { { reason: $order, record: $at, dump: $dump, found: $"first texel ($first) where ($next) was due" } })
                ] | compact)
                if ($found | is-not-empty) {
                    $problems = ($problems | append $found)
                    $bad = true
                }
                $payloads = ($payloads | append ($r | bytes at 12..<60))
                $next = (if ($first mod $DUMP_TEXELS) == 0 { $first + $DUMP_TEXELS } else { $next + $DUMP_TEXELS })
            }
        } else if $answer {
            $dumps = ($dumps | append [$tiles])
            $tiles = []
            $open = false
        } else if $open {
            let what = (if $kind == $CONSOLE_KIND { $"kind ($kind), command ($command)" } else { $"kind ($kind)" })
            $problems = ($problems | append { reason: "foreign", record: $at, dump: $dump, found: $"a record of ($what) inside the dump" })
            if $tile != null { $bad = true }
        }
    }
    let ending = ($api | bytes length) // $RECORD
    if $tile != null {
        let c = (close-tile $tile $payloads $header_at ($dumps | length) $bad --hash=$hash)
        $problems = ($problems | append $c.problems)
    }
    if $open {
        $problems = ($problems | append { reason: "unfinished", record: $ending, dump: ($dumps | length), found: "a dump the capture ends inside, its D unanswered" })
    }
    { dumps: $dumps, problems: $problems }
}

# A capture's whole tiles a dump and every problem, saved to `out` as NUON
export def dumps [api: path, out: path] {
    let read = (read (open --raw $api | into binary))
    { tiles: ($read.dumps | each {|d| $d | length }), problems: $read.problems } | to nuon | save -f $out
}

# A capture's dumps keyed by tile header and texels' SHA-256, saved as NUON
export def keys [api: path, out: path] {
    let read = (read (open --raw $api | into binary) --hash)
    { dumps: $read.dumps, problems: $read.problems } | to nuon | save -f $out
}

# A texel of the builder fixture's texture: every channel varied, opaque
export def builder-texel [x: int, y: int]: nothing -> list<int> {
    [((17 * $x + 5 * $y) mod 256), ((3 * $x + 13 * $y) mod 256), ((7 * $x + 11 * $y + 64) mod 256), 255]
}

# A capture's bytes and where its pixels start, past the header's three lines
export def capture [file: path]: nothing -> record<bytes: binary, head: int> {
    let bytes = (open --raw $file | into binary)
    { bytes: $bytes, head: (($bytes | bytes index-of --all 0x[0a] | get 2) + 1) }
}
