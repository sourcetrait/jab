# workers's scaling: the proof's fixed frame drawn over and over for four
# seconds by one, two, then three workers on the same four-hart machine,
# from the program's bench scenarios, the workers' count a digit over the
# API. A run gives the frames and the stretch's milliseconds by the
# program's clock, the last frame's hash, each worker's rows over every
# frame, each hart's vCPU thread's CPU over a held second inside the
# stretch, and the last frame's bands as intervals with their harts.
# Concurrency is the worker harts' summed CPU over the held second past
# the second itself, which one host core cannot give; the hashes equal
# across the runs and the rows summing to the frames' say the work was
# right and done once; the bands' overlap, their summed time over the
# frame's span, is the supporting record. `just bench
# example/workers/scaling` runs it on a release build and reports; the
# test runs the three-worker run once on its debug one.
use ../../../sdk/nu/jab.nu

# when the held second starts: inside the stretch, which begins once the
# digit lands a second in and lasts four
const HELD_AT = 2sec
const BANDS = 135
const BAND_ROWS = 8
const ROWS = 1080
const TICKS_PER_MS = 10000
const MAX_WORKERS = 3
# past this the workers ran at once, by their summed CPU over the held
# second and by their bands' summed time over the frame's span: one at a
# time gives 1 at most, and /proc's hundredths a thread let a serial run
# read a little past it
const AT_ONCE = 1.5

# One launch of a bench scenario. Untyped because launch's record is wide.
export def measure [kernel: path, image: path, out: path, set: string, --workers: int = 3] {
    if $workers < 1 or $workers > $MAX_WORKERS { error make { msg: $"--workers is 1 to ($MAX_WORKERS), not ($workers)" } }
    let send = [[at, bytes]; [1sec, ($workers | into string | into binary)]]
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --send $send --harts 4 --seconds 40 --threads $HELD_AT)
    let line = ($run.serial | lines | where {|l| $l starts-with "workers: bench " } | get -o 0)
    if $run.status != 0 or $line == null { error make { msg: $"the bench scenario ended with ($run.status): ($run.serial)" } }
    let p = ($line | parse "workers: bench {w} frames {frames} ms {ms} hash {hash} rows {r0} {r1} {r2}" | get -o 0)
    if $p == null { error make { msg: $"the bench's line unread: ($line)" } }
    let frames = ($p.frames | into int)
    let ms = ($p.ms | into int)
    let rows = [($p.r0 | into int) ($p.r1 | into int) ($p.r2 | into int)]
    let bytes = $run.api
    let want = ($BANDS * 16 + $ROWS)
    if ($bytes | bytes length) != $want { error make { msg: $"($want) bytes of bands and owners expected, ($bytes | bytes length) came over the API" } }
    let owners = ($bytes | bytes at ($BANDS * 16)..<$want | chunks 1 | each {|b| $b | into int })
    let bands = (0..<$BANDS | each {|b|
        let at = ($b * 16)
        {
            band: $b,
            start: ($bytes | bytes at $at..<($at + 8) | into int --endian little),
            end: ($bytes | bytes at ($at + 8)..<($at + 16) | into int --endian little),
            hart: ($owners | get ($b * $BAND_ROWS)),
        }
    })
    let harts = ($run.threads | where {|t| $t.name =~ '^CPU \d+/TCG$' } | each {|t| { hart: ($t.name | parse "CPU {n}/TCG" | get 0.n | into int), cpu: $t.cpu } } | sort-by hart)
    let worker_cpu = ($harts | where hart > 0 | get cpu | math sum)
    let o = (overlap $bands)
    {
        workers: ($p.w | into int),
        frames: $frames,
        ms: $ms,
        fps: ($frames * 1000 / $ms),
        hash: $p.hash,
        rows: $rows,
        owners: $owners,
        bands: $bands,
        overlap: $o,
        harts: $harts,
        worker_cpu: $worker_cpu,
        at_once: $AT_ONCE,
        cpu_at_once: ($worker_cpu > $AT_ONCE),
        bands_at_once: ($o.concurrency > $AT_ONCE),
        machine: $run.machine,
        qemu: $run.qemu,
    }
}

# A frame's bands in time: its span from the first band's start to the
# last's end, the bands' summed time, their ratio (one band at a time is
# 1), and the share of the span that two bands or more were running, by a
# sweep of the starts and ends, an end before a start at the same tick.
def overlap [bands: list<record<band: int, start: int, end: int, hart: int>>]: nothing -> record<span_ms: float, busy_ms: float, concurrency: float, overlapped: float> {
    let first = ($bands | get start | math min)
    let last = ($bands | get end | math max)
    let span = ($last - $first)
    let busy = ($bands | each {|b| $b.end - $b.start } | math sum)
    let events = ($bands | each {|b| [[at, step]; [$b.start, 1] [$b.end, -1]] } | flatten | sort-by at step)
    mut depth = 0
    mut since = $first
    mut doubled = 0
    for e in $events {
        if $depth >= 2 { $doubled += ($e.at - $since) }
        $since = $e.at
        $depth += $e.step
    }
    {
        span_ms: ($span / $TICKS_PER_MS | into float),
        busy_ms: ($busy / $TICKS_PER_MS | into float),
        concurrency: (if $span == 0 { 0.0 } else { $busy / $span | into float }),
        overlapped: (if $span == 0 { 0.0 } else { $doubled / $span | into float }),
    }
}

# A run's record as lines to read.
export def text [doc: record]: nothing -> string {
    let cpu = ($doc.harts | each {|h| $"hart ($h.hart) ($h.cpu | math round --precision 2)" } | str join ", ")
    let o = $doc.overlap
    [
        $"workers ($doc.workers): ($doc.frames) frames in ($doc.ms) ms, ($doc.fps | math round --precision 2) a second; hash ($doc.hash); rows ($doc.rows | str join ' ')"
        $"  CPU over the held second: ($cpu); the workers' harts ($doc.worker_cpu | math round --precision 2) s"
        $"  the last frame's bands: ($o.busy_ms | math round --precision 1) ms of work over a span of ($o.span_ms | math round --precision 1) ms, ($o.concurrency | math round --precision 2) at once on average, two or more for ($o.overlapped * 100 | math round --precision 1) percent of it"
    ] | str join "\n"
}

def main [] {
    print "nu scaling.nu run [--tree release|debug] [--workers 1|2|3] [--out <dir>] [--label <name>]"
    print "nu scaling.nu report <a bench run's directory>"
}

# The bench's step: one run on the tree's build, kept as scaling.nuon in
# `out`.
def "main run" [--tree: string = "release", --out: string = "", --label: string = "", --workers: int = 3] {
    if $tree not-in [release debug] { error make { msg: $"--tree is release or debug, not ($tree)" } }
    let program = ($env.FILE_PWD | path join ".." | path expand)
    let built = (jab program-out $program $tree)
    let out = (if $out == "" { $built | path join "scaling" (date now | format date "%Y%m%d-%H%M%S") } else { $out | path expand })
    mkdir $out
    let set = (if $tree == "debug" { "debug" } else { "" })
    let doc = (measure (jab program-kernel $program $tree) ($built | path join "workers.jab") ($out | path join "launch") $set --workers $workers)
    $doc | to nuon --indent 2 | save --raw -f ($out | path join "scaling.nuon")
    print (text $doc)
}

# The bench's report: every step's run with its speed against one
# worker's, whether the hashes agree and each run's rows sum to its
# frames', and whether the workers ran at once, as report.nuon and
# report.txt in the run's directory; it fails when the work was wrong or
# done twice, after writing both.
def "main report" [dir: path] {
    let dir = ($dir | path expand)
    let docs = (glob ($dir | path join "*" "scaling.nuon") | each {|f| open $f } | sort-by workers)
    if ($docs | is-empty) { error make { msg: $"no scaling.nuon under ($dir)" } }
    let base = ($docs | where workers == 1 | get -o 0.fps)
    let hashes = ($docs | get hash | uniq)
    let wrong = ($docs | where {|d| ($d.rows | math sum) != ($d.frames * $ROWS) } | get workers)
    let lines = ($docs | each {|d|
        let speed = (if $base == null { "no one-worker run to compare with" } else { $"($d.fps / $base | math round --precision 2) times one worker's frames a second" })
        let ran = (if $d.workers < 2 { "" } else if $d.cpu_at_once and $d.bands_at_once { $"; at once, the workers' CPU and the bands' overlap past ($d.at_once)" } else { $"; not shown at once, the workers' CPU or the bands' overlap ($d.at_once) or less" })
        $"(text $d)\n  ($speed)($ran)"
    })
    let verdict = [
        (if ($hashes | length) == 1 { $"the hashes agree: ($hashes.0)" } else { $"the hashes differ: ($hashes | str join ', ')" })
        (if ($wrong | is-empty) { "every run's rows sum to its frames'" } else { $"rows short of or past the frames' with workers ($wrong | str join ', ')" })
    ]
    let text = ([$"workers: scaling on ($docs.0.machine.harts) harts, time by rdtime, CPU by /proc"] ++ $lines ++ $verdict | str join "\n")
    $docs | to nuon --indent 1 | save --raw -f ($dir | path join "report.nuon")
    $text + "\n" | save --raw -f ($dir | path join "report.txt")
    print $text
    if ($hashes | length) != 1 or not ($wrong | is-empty) { error make { msg: "the work was wrong or done twice" } }
}
