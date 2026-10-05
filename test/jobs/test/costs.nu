# jobs's costs: what a job of jab_jobs.inc's mailboxes costs around its
# work, at jobs of 10 us, 100 us, 1 ms, and 10 ms, with one worker and
# then with every worker the machine has, from the program's costs
# scenario. The dispatch is a worker's: from hart 0's look at the clock
# before it publishes to the worker's look after its await takes the job.
# The barrier is the round's: from the last worker's look before its
# completion to hart 0's look after its join returns. Both are elapsed time
# by rdtime, the machine's 10 MHz clock, as distributions over a hundred
# rounds a size. `just bench test/jobs/costs` runs it on a release build
# and reports; the test runs it once on its debug one.
use ../../../sdk/nu/jab.nu

const SIZES_US = [10 100 1000 10000]
const ROUNDS = 100
const TICKS_PER_US = 10

# One launch of the costs scenario, its samples as distributions in
# microseconds. Untyped because launch's record is wide.
export def measure [kernel: path, image: path, out: path, set: string, --harts: int = 4] {
    let send = [[at, bytes]; [1sec, ("c" | into binary)]]
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --send $send --harts $harts --seconds 60)
    let line = ($run.serial | lines | where {|l| $l starts-with "jobs: costs, workers " } | get -o 0)
    if $run.status != 0 or $line == null { error make { msg: $"the costs scenario ended with ($run.status): ($run.serial)" } }
    let parsed = ($line | parse "jobs: costs, workers {w}, {n} bytes" | first)
    let workers = ($parsed.w | into int)
    let n = ($parsed.n | into int)
    let bytes = $run.api
    if ($bytes | bytes length) != $n { error make { msg: $"($n) bytes of samples said, ($bytes | bytes length) came over the API" } }
    let words = (0..<($n // 4) | each {|i| $bytes | bytes at ($i * 4)..<($i * 4 + 4) | into int --endian little })
    let configs = (if $workers == 1 { [1] } else { [1 $workers] })
    let expected = ($configs | each {|c| ($c + 1) * $ROUNDS * ($SIZES_US | length) } | math sum)
    if ($words | length) != $expected { error make { msg: $"($words | length) samples, ($expected) expected for ($configs) workers" } }
    mut at = 0
    mut rows = []
    for c in $configs {
        let per = ($c + 1)
        for s in $SIZES_US {
            let block = ($words | skip $at | first ($ROUNDS * $per))
            $at = $at + ($ROUNDS * $per)
            let dispatch = ($block | enumerate | where {|e| ($e.index mod $per) < $c } | get item)
            let barrier = ($block | enumerate | where {|e| ($e.index mod $per) == $c } | get item)
            $rows = ($rows | append { workers: $c, size_us: $s, dispatch: (stats $dispatch), barrier: (stats $barrier) })
        }
    }
    { workers: $workers, harts: $harts, machine: $run.machine, qemu: $run.qemu, rows: $rows }
}

# A distribution of clock ticks in microseconds: its count, least,
# median, 90th and 99th percentiles by the nearest rank, and greatest.
def stats [ticks: list<int>]: nothing -> record<n: int, min: float, p50: float, p90: float, p99: float, max: float> {
    let us = ($ticks | each {|t| $t / $TICKS_PER_US } | sort)
    let n = ($us | length)
    let rank = {|q: float| $us | get (((($n - 1) * $q) | math round) | into int) }
    { n: $n, min: ($us | first), p50: (do $rank 0.5), p90: (do $rank 0.9), p99: (do $rank 0.99), max: ($us | last) }
}

# The costs as lines to read.
export def text [doc: record]: nothing -> string {
    let head = $"jobs: costs on ($doc.harts) harts, ($doc.workers) workers at most, microseconds elapsed by rdtime"
    let lines = ($doc.rows | each {|r|
        let d = $r.dispatch
        let b = $r.barrier
        $"  workers ($r.workers), ($r.size_us) us jobs: dispatch median ($d.p50), p90 ($d.p90), max ($d.max); barrier median ($b.p50), p90 ($b.p90), max ($b.max)"
    })
    [$head] ++ $lines | str join "\n"
}

def main [] {
    print "nu costs.nu run [--tree release|debug] [--harts 2|4] [--out <dir>] [--label <name>]"
    print "nu costs.nu report <a bench run's directory>"
}

# The bench's step: the costs on the tree's build, kept as costs.nuon in
# `out`.
def "main run" [--tree: string = "release", --out: string = "", --label: string = "", --harts: int = 4] {
    if $tree not-in [release debug] { error make { msg: $"--tree is release or debug, not ($tree)" } }
    let program = ($env.FILE_PWD | path join ".." | path expand)
    let built = (jab program-out $program $tree)
    let out = (if $out == "" { $built | path join "costs" (date now | format date "%Y%m%d-%H%M%S") } else { $out | path expand })
    mkdir $out
    let set = (if $tree == "debug" { "debug" } else { "" })
    let doc = (measure (jab program-kernel $program $tree) ($built | path join "jobs.jab") ($out | path join "launch") $set --harts $harts)
    $doc | to nuon --indent 2 | save --raw -f ($out | path join "costs.nuon")
    print (text $doc)
}

# The bench's report: every step's costs, as report.nuon and report.txt
# in the run's directory.
def "main report" [dir: path] {
    let dir = ($dir | path expand)
    let docs = (glob ($dir | path join "*" "costs.nuon") | sort | each {|f| open $f })
    if ($docs | is-empty) { error make { msg: $"no costs.nuon under ($dir)" } }
    let text = ($docs | each {|d| text $d } | str join "\n")
    $docs | to nuon --indent 1 | save --raw -f ($dir | path join "report.nuon")
    $text + "\n" | save --raw -f ($dir | path join "report.txt")
    print $text
}
