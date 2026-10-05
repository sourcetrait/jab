# jobs's integration test: jab_jobs.inc's mailboxes over the worker
# calls, a line a fixture read line by line, on machines of two and four
# harts, one worker and three:
# - Idle: every worker asleep in its await while hart 0 holds two seconds;
#   on four harts each worker's vCPU thread under 0.05 s of CPU over a held
#   second.
# - Races, a thousand rounds each, every round a job a worker and a join,
#   each worker's output checked and its completions counted: before (each
#   worker lingers past its completion, so the next job is published before
#   it waits), during (hart 0 lingers before publishing, so every worker is
#   asleep), spurious (a wake with nothing published, then the job), after
#   (hart 0 lingers before its join, so every job is done before the join
#   looks).
# - EmptyFull: a fresh mailbox free, a published job's not, free again
#   once its worker's completion is joined, the output the job's.
# - Wrap: three jobs of three 1 ms bands from generation 0xfffffffe, through
#   the wrap to 1, each done and whole, so a cancel word matching a stale
#   generation would end the generation-0 job cancelled.
# - Cancel: a job cancelled a band in, done as cancelled before its last
#   band; a job cancelled before it is published, done as cancelled with
#   no band run.
# Then the costs scenario once on four harts (costs.nu, which `just bench
# test/jobs/costs` runs on a release build): every sample in, each a
# distribution, held to no number, since a debug build's TCG times are
# no measure.
use ../../../sdk/nu/jab.nu
use ./costs.nu
use std/assert

const ROUNDS = 1000
# the CPU seconds an asleep worker's vCPU thread may take over a held
# second, as test/harts holds an idle hart's
const IDLE_CPU = 0.05
# when the held second starts, inside the program's two-second idle, which
# begins once the scenario's letter lands a second in
const HELD_AT = 1500ms

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let threads = ($nu.os-info.name == "linux")
    mut seen = []
    for harts in [2 4] {
        let w = ($harts - 1)
        let held = ($threads and $harts == 4)
        let send = [[at, bytes]; [1sec, ("f" | into binary)]]
        let run = (jab launch --kernel $kernel --image $image --out ($out | path join $"fixture_($harts)") --set $set --send $send --harts $harts --seconds 40 --threads (if $held { $HELD_AT } else { 0sec }))
        let lines = [
            [fixture, line];
            [Workers, $"jobs: scenario fixture, workers ($w)"]
            [Idle, $"idle ($w) workers held"]
            [RaceBefore, $"before ($ROUNDS) rounds, 0 wrong, ($ROUNDS * $w) completions"]
            [RaceDuring, $"during ($ROUNDS) rounds, 0 wrong, ($ROUNDS * $w) completions"]
            [RaceSpurious, $"spurious ($ROUNDS) rounds, 0 wrong, ($ROUNDS * $w) completions"]
            [RaceAfter, $"after ($ROUNDS) rounds, 0 wrong, ($ROUNDS * $w) completions"]
            [EmptyFull, "free 1 then 0 then 1, out 36"]
            [Wrap, "wrap 3 jobs, generation 1, 0 wrong, statuses 0 0 0, bands 3 3 3"]
            [Cancel, "cancel during 1 under 1, cancel before 1 bands 0"]
            [Done, "jobs: done"]
        ]
        let got = ($run.serial | lines)
        for row in ($lines | enumerate) {
            assert equal ($got | get -o $row.index) $row.item.line $"($row.item.fixture) on ($harts) harts, line ($row.index + 1): ($run.serial)"
        }
        assert equal ($got | length) ($lines | length) $"Done on ($harts) harts: nothing after the program's last line: ($run.serial)"
        assert equal $run.status 0 $"exit status on ($harts) harts: ($run.serial)"
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on ($harts) harts"
        if $held {
            assert (not ($run.threads | is-empty)) $"Idle: the threads read over the held second: ($run.threads)"
            for h in 1..$w {
                let thread = ($run.threads | where name == $"CPU ($h)/TCG" | get -o 0)
                assert ($thread != null) $"Idle: hart ($h)'s thread among ($run.threads | get name)"
                assert ($thread.cpu <= $IDLE_CPU) $"Idle: hart ($h)'s worker, asleep in its await, took ($thread.cpu) s of CPU over the held second, past ($IDLE_CPU)"
            }
        }
        $seen = ($seen | append $"($harts) harts: ($got | skip 1 | first 2 | str join '; ')")
    }

    let doc = (costs measure $kernel $image ($out | path join "costs") $set --harts 4)
    assert equal $doc.workers 3 $"Costs: three workers on four harts: ($doc.workers)"
    assert equal ($doc.rows | length) 8 $"Costs: four sizes for one worker and for three: ($doc.rows | length)"
    for r in $doc.rows {
        assert equal $r.dispatch.n (100 * $r.workers) $"Costs: a dispatch a worker a round at ($r.size_us) us, ($r.workers) workers: ($r.dispatch.n)"
        assert equal $r.barrier.n 100 $"Costs: a barrier a round at ($r.size_us) us, ($r.workers) workers: ($r.barrier.n)"
        assert ($r.dispatch.min > 0 and $r.barrier.min >= 0) $"Costs: every interval forward in time: ($r)"
    }
    print $"jobs: ($seen | str join '; ')"
    print (costs text $doc)
    print "jobs: ok"
}
