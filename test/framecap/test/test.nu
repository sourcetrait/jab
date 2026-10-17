# framecap's integration test: a burst of flips is refused past the
# first, sixty-four awaited frames, whole and rectangular, take at
# least sixty-four periods of the cap, read from the SDK, a rectangle
# past the edge is refused with 4, a list of rectangles flips as one
# and a list with a bad one or none is refused, the kernel reports the
# symbols it was built with, and the hart halts while it waits, so
# QEMU's CPU time stays well under the run's length. Every flip's
# receipt holds what the kernel answers beside its status: the
# decision's stamp in a1, the eligibility tick it read in a2, the
# present ordinal in a3. Five more launches, each a scenario picked over
# the API with a GPU knob, hold the receipts of a whole flip's refused
# transfer and refused flush, each followed by a flip that finds the
# clock where the refused one left it, a refused transfer in a list, a
# refused transfer in a list's first batch, and a stuck source. Built
# with FLIP_BATCH, SubmitWait's candidate, the whole flip goes as one
# batch, so its refused transfer's flush shows the old frame again and
# counts; the whole flip's scenarios run before the list's, so a defect
# of the batch the two share fails at the candidate's own case.
use ../../../sdk/nu/jab.nu
use std/assert

# Sixty-four awaited frames, half of them whole and half a rectangle
const FRAMES = 64
# A receipt's kinds, as main.S names them
const KIND = {closed: 1, burst: 2, whole: 3, rect: 4, badrect: 5, rects: 6, badrects: 7, norects: 8, before_print: 9, after_print: 10, old: 11, list: 12, long: 13, badxfer: 14, badflush: 15, held: 16, failed: 17, after: 18}
# What main.S leaves in a1 to a3 before the stuck scenario's last flip
const SENTINEL = 0x5a5a5a5a
# The colours the screen scenarios paint, as a screen reads them
const OLD = "204060"
const NEW = "c08040"
# The list's three rectangles' centres, from main.S's three_rects
const LIST_CENTRES = [[200 150] [600 150] [1000 150]]
# A pixel outside every rectangle
const OUTSIDE = [1500 800]
# The GPU's virtio device id, the stuck knob's value
const GPU = 16

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let batched = ("FLIP_BATCH" in ($set | split row ","))
    let cap = (open --raw ($env.FILE_PWD | path join ".." ".." ".." "sdk" "src" "jab.inc") | decode | parse --regex '\.set JAB_DISPLAY_FPS_CAP, (?P<cap>\d+)' | get 0.cap | into int)
    let run = (jab launch --kernel $kernel --image $image --out ($out | path join "plain") --set $set)
    assert equal $run.status 0 $"exit status, with the UART: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    let receipts = (receipts-of $run.serial)
    assert equal ($receipts | length) 135 $"every flip's receipt kept: ($receipts | length)"
    let closed = ($receipts | where kind == $KIND.closed | first)
    assert equal [$closed.status $closed.a1 $closed.a2 $closed.a3] [2 0 0 0] $"a flip before the open answers 2 and observes nothing: ($closed)"
    for r in $receipts { stamp-holds $r }
    ordinal-holds $receipts
    let burst = ($receipts | where kind == $KIND.burst)
    let refused = ($burst | where status == 1 | length)
    assert ($refused >= 60) $"the burst is refused past the first flip: ($refused) of 63"
    for kind in [badrect badrects norects] {
        let r = ($receipts | where kind == ($KIND | get $kind) | first)
        assert equal [$r.status $r.a1 $r.a2] [4 0 0] $"($kind) is refused with 4 before any decision: ($r)"
    }
    let rects = ($receipts | where kind == $KIND.rects | first)
    assert equal $rects.status 0 "a list of two rectangles goes through as one flip"
    let flags = ($run.serial | parse --regex 'flags=(?P<flags>\d+)' | get 0.flags | into int)
    assert equal $flags 1 $"the kernel reports DEBUG and nothing else, as every test build sets it: flags ($flags)"
    let least = ($FRAMES / $cap)
    assert ($run.wall_seconds >= $least) $"sixty-four frames at ($cap) a second take at least ($least | math round -p 2) seconds: ($run.wall_seconds)"
    assert ($run.wall_seconds < ($least + 4.0)) $"and not much more: ($run.wall_seconds)"
    print $"framecap: ($refused) refused; QEMU used ($run.cpu_seconds) CPU seconds over ($run.wall_seconds | math round -p 2) seconds"
    assert ($run.cpu_seconds < ($run.wall_seconds * 0.5)) "the hart halts while it waits"

    let transfer = (scenario $kernel $image ($out | path join "transfer") $set "t" "jab.badxfer=3" --capture 3sec)
    let old = ($transfer.receipts | where kind == $KIND.old | first)
    let flip = ($transfer.receipts | where kind == $KIND.badxfer | first)
    stamp-holds $flip
    assert equal $flip.status 3 $"a whole flip with its transfer refused answers 3: ($flip)"
    if $batched {
        assert equal $flip.a3 ($old.a3 + 1) $"the batched whole flip's flush answered OK after its refused transfer counts its present: ($flip.a3) after ($old.a3)"
    } else {
        assert equal $flip.a3 $old.a3 $"its present uncounted: ($flip.a3) after ($old.a3)"
    }
    let screen = (jab screen $transfer.run.screen)
    assert equal (jab pixel $screen 960 540) $OLD "the screen the old frame"
    assert equal (refusals $transfer.run "transfer") 1 "QEMU refused the transfer"
    assert equal (refusals $transfer.run "flush") 0 (if $batched { "and no flush, which showed the old frame again" } else { "and no flush was issued" })
    clock-holds $transfer.receipts $KIND.badxfer "transfer"

    let flush = (scenario $kernel $image ($out | path join "flush") $set "f" "jab.badflush=2")
    let flip = ($flush.receipts | where kind == $KIND.badflush | first)
    stamp-holds $flip
    assert equal $flip.status 3 $"a whole flip with its flush refused answers 3: ($flip)"
    assert equal $flip.a3 1 $"its present uncounted, the ordinal the open's: ($flip.a3)"
    assert equal (refusals $flush.run "flush") 1 "QEMU refused the flush"
    clock-holds $flush.receipts $KIND.badflush "flush"

    let list = (scenario $kernel $image ($out | path join "list") $set "l" "jab.badxfer=3 jab.badxferat=2" --capture 3sec)
    let old = ($list.receipts | where kind == $KIND.old | first)
    let flip = ($list.receipts | where kind == $KIND.list | first)
    stamp-holds $flip
    assert equal $flip.status 3 $"the list with its second transfer refused answers 3: ($flip)"
    assert equal $flip.a3 ($old.a3 + 1) $"the list's flush answered OK counts its present: ($flip.a3) after ($old.a3)"
    let screen = (jab screen $list.run.screen)
    let shown = ($LIST_CENTRES | each {|c| jab pixel $screen $c.0 $c.1 })
    assert equal $shown [$NEW $OLD $NEW] $"the first and third rectangles the new frame's, the second the old: ($shown)"
    assert equal (jab pixel $screen $OUTSIDE.0 $OUTSIDE.1) $OLD "outside the rectangles the old frame"
    assert equal (refusals $list.run "transfer") 1 "QEMU refused one transfer"

    let long = (scenario $kernel $image ($out | path join "long") $set "b" "jab.badxfer=2 jab.badxferat=1")
    let flip = ($long.receipts | where kind == $KIND.long | first)
    stamp-holds $flip
    assert equal $flip.status 3 $"a list past a batch with a first-batch transfer refused answers 3: ($flip)"
    assert equal $flip.a3 1 $"its last batch and its flush never sent, the ordinal the open's: ($flip.a3)"
    assert equal (refusals $long.run "transfer") 1 "QEMU refused one transfer, the first batch's"
    assert equal (refusals $long.run "flush") 0 "and no flush"

    let held = (scenario $kernel $image ($out | path join "held") $set "s" $"jab.hold=($GPU)")
    let before = ($held.receipts | where kind == $KIND.held | first)
    assert equal $before.status 0 $"the held source's first flip presents: ($before)"
    assert ($held.run.serial | str contains "jab: interrupt source") $"the held source fails: ($held.run.serial)"
    let flip = ($held.receipts | where kind == $KIND.failed | first)
    assert equal $flip.status 3 $"a flip after the source failed answers 3: ($flip)"
    assert equal [$flip.a1 $flip.a2] [0 0] $"a refused-before-the-check flip observes no decision: ($flip)"
    assert equal $flip.a3 $before.a3 $"and its ordinal unchanged: ($flip.a3) after ($before.a3)"
    let whole = (if $batched { "the whole flip batched, its refused transfer's flush counted" } else { "the whole flip's refused transfer and flush uncounted" })
    print $"framecap: receipts on ($receipts | length) flips; ($whole), the clock untouched by either; the list's present counted, the long list's not; the stuck source's after-check zeros"
    print "framecap: ok"
}

# A refused flip leaves the frame clock where it stood: the flip of a
# pixel right after it presents at the tick the refused one read, where a
# clock moved on would refuse it as early, at the next tick.
def clock-holds [receipts: table, kind: int, what: string] {
    let failed = ($receipts | where kind == $kind | first)
    let after = ($receipts | where kind == $KIND.after | first)
    stamp-holds $after
    assert equal [$after.status $after.a2] [0 $failed.a2] $"the refused ($what) leaves the clock where it stood, the next flip presenting at its tick: ($after) after ($failed)"
}

# A scenario's launch: the API on the machine, the scenario's letter sent
# half a second in, the knobs on the kernel's command line; the run and
# its receipts. Untyped because launch's record is wide.
def scenario [kernel: path, image: path, out: path, set: string, letter: string, bootargs: string, --capture: duration = 0sec] {
    let send = [[at, bytes]; [500ms, ($letter | into binary)]]
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --send $send --bootargs $bootargs --capture $capture)
    assert ($run.serial | str contains "framecap: scenario done") $"scenario ($letter) ran to its end: ($run.serial)"
    { run: $run, receipts: (receipts-of $run.serial) }
}

# Each `receipt` line main.S printed, its fields read from hex.
def receipts-of [serial: string]: nothing -> table<kind: int, status: int, before: int, a1: int, a2: int, a3: int, after: int> {
    $serial | lines | where {|l| $l | str starts-with "receipt " } | parse "receipt {kind} {status} {before} {a1} {a2} {a3} {after}" | each {|r|
        {
            kind: ($r.kind | into int --radix 16)
            status: ($r.status | into int --radix 16)
            before: ($r.before | into int --radix 16)
            a1: ($r.a1 | into int --radix 16)
            a2: ($r.a2 | into int --radix 16)
            a3: ($r.a3 | into int --radix 16)
            after: ($r.after | into int --radix 16)
        }
    }
}

# A flip that reached its decision holds its stamp inside the program's
# bracket of the call, at or past its tick when it presented or failed
# after the check, and before it when refused as early.
def stamp-holds [r: record] {
    if $r.status in [0 1 3] {
        assert ($r.before <= $r.a1 and $r.a1 <= $r.after) $"a flip's stamp inside its call: ($r)"
    }
    if $r.status in [0 3] {
        assert ($r.a1 >= $r.a2) $"a presented flip's stamp at or past its tick: ($r)"
    }
    if $r.status == 1 {
        assert ($r.a1 < $r.a2) $"an early flip's stamp before its tick: ($r)"
    }
}

# The present ordinal from the open's present, 1: one more each presented
# flip, the print's present before the flip after it, unchanged on every
# other answer.
def ordinal-holds [receipts: table] {
    mut last = 1
    for r in ($receipts | skip 1) {
        let printed = (if $r.kind == $KIND.after_print { 1 } else { 0 })
        let expected = ($last + $printed + (if $r.status == 0 { 1 } else { 0 }))
        assert equal $r.a3 $expected $"the present ordinal rises by one a presented flip and a print: ($r) after ($last)"
        $last = $r.a3
    }
}

# How many of QEMU's guest-error lines refuse a transfer or a flush for
# its bounds.
def refusals [run: record, kind: string]: nothing -> int {
    open --raw $run.qemu_log | decode | lines | where {|l| $l | str contains $"($kind) bounds outside resource" } | length
}
