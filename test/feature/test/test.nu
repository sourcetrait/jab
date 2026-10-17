# feature's integration test: a synthetic feature on hart ownership by
# role, one program printing a line a step and sending a record a frame
# over the API, read on 1KA1's machine, its three harts, declared; on a
# custom machine of four, diagnostic; and on four with hart 2 failed by
# jab.late=2, a sparse grant.
# The program reserves its manifest's graphics harts, renders frames of 64
# rows on its grant, and takes a feature of its manifest's I/O harts, the
# grant's highest, admitted only while the grant past them keeps the
# reservation, at startup before graphics starts and at a mode transition,
# its harts taken from graphics at a safe boundary: their band held inside
# a frame, the hold released only on the join's path, the frame joined,
# then the harts' workers stopped. Every expected line is worked out from
# the machine's online secondaries and the manifest's counts, never the
# generated constants, so a program reading a wrong constant shows it:
# - harts and reserve: the online secondaries, the reservation's answer,
#   its grant, and the reservation's harts.
# - check: the grant's count, the feature's harts, and the admission.
# - admitted at startup: the claim's answer and id, its harts and the grant
#   left; a second claim of a hart of the grant left refused at the floor;
#   graphics started on the grant left; then the feature's run.
# - the feature's run: its worker started under the claim's id; four
#   frames beside it; its release refused busy while its worker waits on
#   its hart; its result joined, the hart that made it and the value; its
#   harts' stop, nothing interrupted; its release; the stale id's start and
#   release refused; graphics back on its harts; four frames on the grant.
# - admitted at the transition: the held band's claim refused busy; the
#   stop after the join, nothing interrupted, the hold released; the claim
#   under a fresh id; a graphics start on its harts refused for their
#   owner; then the feature's run.
# - refused: the kernel's claim refused at the floor at startup and busy
#   at the transition, nothing moved, graphics on the whole grant.
# - end: every graphics worker stopped, nothing interrupted, and the
#   frames sent.
# An expired hold, read first from the transfer's stop line, fails the run
# as unexercised. The API's bytes are read whole before any frame is held:
# whole records, as many as the machine's path makes, numbered from 0 in
# order; then each frame's masks, its rows by the hart its band is dealt
# to, and the sum of its rows' words against the host's own reckoning. The
# reader is proven on the first machine's bytes by the last record dropped,
# the first duplicated over the second, and the last cut short. Under DEBUG
# the debug channel carries each change of ownership.
use ../../../sdk/nu/jab.nu
use std/assert

const ROWS = 64
const BAND_ROWS = 8
const ROW_STEPS = 4096
const FEATURE_STEPS = 1048576
const FEATURE_SEED = 0x2545f4914f6cdd1d
const RECORD_BYTES = 96
const FRAMES = 4
const HOLD_RELEASED = 2
const HOLD_EXPIRED = 3
const LOW_57 = 0x01ffffffffffffff
const LOW_32 = 0xffffffff

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let debug = ($set | str contains "DEBUG")
    let manifest = (open ($env.FILE_PWD | path join ".." "program.jab.toml"))
    let reserved = $manifest.reserved.gfx_harts
    let feature = $manifest.feature.synthetic.io_harts
    let constants = (open --raw ($out | path join "jab_manifest.inc") | into binary | decode | lines | str join "; ")
    print $"feature: image (open --raw $image | into binary | hash sha256), built with ($constants)"
    let machines = ([
        { name: "three", spec: "1ka1", harts: 0, bootargs: "", online: [1 2] }
        { name: "four", spec: "", harts: 4, bootargs: "", online: [1 2 3] }
    ] ++ (if $debug { [
        { name: "sparse", spec: "", harts: 4, bootargs: "jab.late=2", online: [1 3] }
    ] } else { [] }))
    let result = (xorshift $FEATURE_SEED $FEATURE_STEPS)
    let most = ($machines | each {|m| (plan-of $m.online $reserved $feature).frames } | math max)
    let words = (frame-words $most)
    mut held = []
    mut first: any = null
    for m in $machines {
        let run = (jab launch --kernel $kernel --image $image --out ($out | path join $m.name) --set $set --spec $m.spec --harts $m.harts --bootargs $m.bootargs --seconds 30 --api)
        let plan = (plan-of $m.online $reserved $feature)
        let got = ($run.serial | lines)
        let stop = ($got | where {|l| $l | str starts-with "transition stop " } | get -o 0)
        if $stop != null {
            let fields = ($stop | split row " ")
            let interrupted = ($fields | get -o 4 | default "?")
            let hold = ($fields | get -o 6 | default "?")
            let present = (if ($plan.held in (record-numbers $run.api)) { "a record holds the held frame" } else { "no record holds the held frame" })
            assert ($hold != ($HOLD_EXPIRED | into string)) $"($m.name): the hold expired, the stop interrupted ($interrupted) and ($present), the transfer unexercised"
        }
        let want = (expected $m.online $reserved $feature $result)
        for row in ($want | enumerate) {
            assert equal ($got | get -o $row.index) $row.item $"($m.name), line ($row.index + 1): ($run.serial)"
        }
        assert equal ($got | length) ($want | length) $"($m.name): nothing after the program's last line: ($run.serial)"
        assert equal $run.status 0 $"($m.name): exit status: ($run.serial)"
        assert equal (open --raw $run.qemu_log) "" $"($m.name): QEMU has no complaint about the guest"
        assert equal [$run.declared $run.diagnostic] [true ($m.spec == "")] $"($m.name): a declared run, diagnostic on a custom machine and on 1KA1 not: ($run.declared), ($run.diagnostic)"
        if $debug {
            if $m.bootargs != "" { assert ($run.debug | str contains $"jab: bootargs ($m.bootargs)") $"($m.name): the knob reached the kernel: ($run.debug)" }
            let changes = ($run.debug | lines | where {|l| ["jab: harts reserved " "jab: harts claimed " "jab: harts released "] | any {|p| $l | str starts-with $p } })
            assert equal $changes (changes $m.online $reserved $feature) $"($m.name): each change of ownership on the debug channel: ($changes)"
        }
        let read = (read-frames $run.api $plan.frames)
        assert ($read.problem == null) $"($m.name): the API's frames read whole: ($read.problem)"
        for f in $read.frames {
            let p = ($plan.masks | get $f.number)
            assert equal [$f.gfx $f.feature] [$p.gfx $p.feature] $"($m.name), frame ($f.number): its graphics and feature masks"
            assert equal $f.renderers (dealt $p.gfx) $"($m.name), frame ($f.number): each row by the hart its band is dealt to"
            assert equal $f.sum (wrapping-sum ($words | get $f.number)) $"($m.name), frame ($f.number): the sum of its rows' words"
        }
        if $first == null { $first = { api: $run.api, frames: $plan.frames } }
        $held = ($held | append $"($m.name) ($plan.frames) frames")
    }
    let api = $first.api
    let n = $first.frames
    let dropped = ($api | bytes at 0..<(($n - 1) * $RECORD_BYTES))
    let duplicated = (bytes build ($api | bytes at 0..<$RECORD_BYTES) ($api | bytes at 0..<$RECORD_BYTES) ($api | bytes at (2 * $RECORD_BYTES)..))
    let cut = ($api | bytes at 0..<(($n * $RECORD_BYTES) - 1))
    let refusals = [
        { case: "the last record dropped", problem: (read-frames $dropped $n).problem, says: "records where the run makes" }
        { case: "the first record duplicated over the second", problem: (read-frames $duplicated $n).problem, says: "out of order" }
        { case: "the last record cut short", problem: (read-frames $cut $n).problem, says: "cut a record short" }
    ]
    for r in $refusals {
        assert (($r.problem != null) and ($r.problem | str contains $r.says)) $"the reader refuses ($r.case): ($r.problem)"
    }
    print $"feature: ($machines | length) machines, every line and frame held, ($held | str join ', '); the reader's ($refusals | length) negatives refused"
    print "feature: ok"
}

# What a machine whose online secondaries are `online` makes of the
# manifest's counts: its grant, the feature's harts (the grant's highest)
# and the grant left, the admission, the frames sent, each frame's
# graphics and feature masks, and the held frame's number, null where the
# feature is refused.
def plan-of [online: list<int>, reserved: int, feature: int]: nothing -> record {
    let grant = (mask-of $online)
    let want = (mask-of ($online | sort | last $feature))
    let left = ($grant - $want)
    let admit = ((($online | length) - $feature) >= $reserved)
    if not $admit {
        return { grant: $grant, want: $want, left: $left, admit: false, frames: (2 * $FRAMES), masks: (1..(2 * $FRAMES) | each {|i| { gfx: $grant, feature: 0 } }), held: null }
    }
    let beside = (1..$FRAMES | each {|i| { gfx: $left, feature: $want } })
    let whole = (1..$FRAMES | each {|i| { gfx: $grant, feature: 0 } })
    let masks = ($beside ++ $whole ++ [{ gfx: $grant, feature: 0 }] ++ $beside ++ $whole)
    { grant: $grant, want: $want, left: $left, admit: true, frames: ($masks | length), masks: $masks, held: (2 * $FRAMES) }
}

# The program's lines on a machine whose online secondaries are `online`,
# the feature's result `result`.
def expected [online: list<int>, reserved: int, feature: int, result: int]: nothing -> list<string> {
    let p = (plan-of $online $reserved $feature)
    let count = ($online | length)
    let head = [
        $"harts ($p.grant)"
        $"reserve 0 ($p.grant) owned ($p.grant)"
        $"startup check ($count) want ($p.want) admit (if $p.admit { 1 } else { 0 })"
    ]
    if not $p.admit {
        return ($head ++ [
            $"startup claim 4 id 0 owned 0 left ($p.grant)"
            $"startup graphics ($p.grant) refused 0"
            $"transition check ($count) want ($p.want) admit 0"
            $"transition claim 3 id 0 owned 0 left ($p.grant)"
            $"end stop ($p.grant) interrupted 0 frames ($p.frames)"
        ])
    }
    let made = ($online | sort | last $feature | each {|h| $" ($h) (hex16 $result)" } | str join "")
    let run = [
        "feature start 0"
        "feature release 2"
        $"feature result($made)"
        $"feature stop ($p.want) interrupted 0"
        $"feature released 0 ($p.want) left ($p.grant)"
        "feature stale 7 1"
        "feature return 0"
    ]
    $head ++ [
        $"startup claim 0 id 2 owned ($p.want) left ($p.left)"
        $"startup second 4 left ($p.left)"
        $"startup graphics ($p.left) refused 0"
    ] ++ $run ++ [
        $"transition check ($count) want ($p.want) admit 1"
        $"transition busy 3 left ($p.grant)"
        $"transition stop ($p.want) interrupted 0 hold ($HOLD_RELEASED)"
        $"transition claim 0 id 3 owned ($p.want) left ($p.left)"
        $"transition owner ($p.want)"
    ] ++ $run ++ [
        $"end stop ($p.grant) interrupted 0 frames ($p.frames)"
    ]
}

# The debug channel's line for each change of ownership, in order: the
# reservation with its grant, then each claim and its release with its
# harts, where the feature is admitted.
def changes [online: list<int>, reserved: int, feature: int]: nothing -> list<string> {
    let p = (plan-of $online $reserved $feature)
    let reservation = [$"jab: harts reserved ($reserved) grant 0x(hex16 $p.grant)"]
    if not $p.admit { return $reservation }
    $reservation ++ ([2 3] | each {|id| [$"jab: harts claimed ($id) 0x(hex16 $p.want)" $"jab: harts released ($id) 0x(hex16 $p.want)"] } | flatten)
}

# The frames sent over the API, read whole before any is held: the bytes
# a whole number of records, `count` of them, numbered from 0 in order,
# each its number, its graphics and feature masks, the sum of its rows'
# words, and each row's renderer; `problem` the first fault, null with
# none.
def read-frames [api: binary, count: int] {
    let size = ($api | bytes length)
    if ($size mod $RECORD_BYTES) != 0 { return { frames: [], problem: $"the API's ($size) bytes cut a record short" } }
    let n = ($size // $RECORD_BYTES)
    if $n != $count { return { frames: [], problem: $"($n) records where the run makes ($count)" } }
    mut frames = []
    for i in 0..<$n {
        let at = ($i * $RECORD_BYTES)
        let r = ($api | bytes at $at..<($at + $RECORD_BYTES))
        let number = ($r | bytes at 0..<8 | into int --endian little)
        if $number != $i { return { frames: [], problem: $"record ($i) numbered ($number), out of order" } }
        let renderers = ($r | bytes at 32..<96 | chunks 1 | each {|b| $b | into int })
        $frames = ($frames | append { number: $number, gfx: ($r | bytes at 8..<16 | into int --endian little), feature: ($r | bytes at 16..<24 | into int --endian little), sum: ($r | bytes at 24..<32 | into int --endian little --signed), renderers: $renderers })
    }
    { frames: $frames, problem: null }
}

# The numbers of the whole records among the bytes, read leniently, for
# the expiry's report of whether the held frame went out.
def record-numbers [api: binary]: nothing -> list<int> {
    let n = (($api | bytes length) // $RECORD_BYTES)
    if $n == 0 { return [] }
    0..<$n | each {|i| $api | bytes at ($i * $RECORD_BYTES)..<($i * $RECORD_BYTES + 8) | into int --endian little }
}

# Each row's renderer in a frame on the graphics harts `gfx`: its band
# dealt by index over the harts in ascending order, eight rows a band.
def dealt [gfx: int]: nothing -> list<int> {
    let harts = (1..7 | where {|h| ($gfx bit-and (1 bit-shl $h)) != 0 })
    let n = ($harts | length)
    0..<$ROWS | each {|r| $harts | get (($r // $BAND_ROWS) mod $n) }
}

# Every row's word of frames 0 to `frames` less one: an xorshift64 run of
# ROW_STEPS from the frame's number and the row's, plus one.
def frame-words [frames: int]: nothing -> list<list<int>> {
    0..<$frames | each {|f| 0..<$ROWS | each {|r| xorshift ((($f bit-shl 8) bit-or $r) + 1) $ROW_STEPS } }
}

# An xorshift64 run of `steps` from `seed` (13, 7, 17), its right shift
# logical as the guest's srli, nushell's being arithmetic.
def xorshift [seed: int, steps: int]: nothing -> int {
    mut x = $seed
    for i in 1..$steps {
        $x = ($x bit-xor ($x bit-shl 13))
        $x = ($x bit-xor (($x bit-shr 7) bit-and $LOW_57))
        $x = ($x bit-xor ($x bit-shl 17))
    }
    $x
}

# The words summed with the guest's wrapping add, by 32-bit halves, since
# nushell's own add refuses an overflow.
def wrapping-sum [words: list<int>]: nothing -> int {
    let low = ($words | each {|w| $w bit-and $LOW_32 } | math sum | into int)
    let high = ($words | each {|w| ($w bit-shr 32) bit-and $LOW_32 } | math sum | into int)
    let top = (($high + ($low bit-shr 32)) bit-and $LOW_32)
    ($top bit-shl 32) bit-or ($low bit-and $LOW_32)
}

# A mask of the harts listed.
def mask-of [harts: list<int>]: nothing -> int {
    $harts | reduce --fold 0 {|h, acc| $acc bit-or (1 bit-shl $h) }
}

# A value's 64 bits as sixteen lowercase hex digits, as the guest's
# put_hex writes them.
def hex16 [value: int]: nothing -> string {
    let high = (($value bit-shr 32) bit-and $LOW_32)
    let low = ($value bit-and $LOW_32)
    [$high $low] | each {|half| $half | format number | get lowerhex | str replace "0x" "" | fill --alignment right --character "0" --width 8 } | str join ""
}
