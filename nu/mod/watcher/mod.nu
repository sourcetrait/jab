use (path self ../bench)
use (path self ../process)
use (path self ../target)
use (path self ../workspace)

# Where a watch records: watch.nuonl in the workspace's target
def watch-file [ws: path]: nothing -> string {
    target root $ws | path join "watch.nuonl"
}

# A recording's first line on its QEMU: host, version, machine, window, kernel
def watch-header [pid: int, started: datetime]: nothing -> record {
    let command = (ps -l | where pid == $pid | get -o 0.command | default "")
    let window = ($command | parse --regex '-display (?P<w>\S+)' | get -o 0.w | default "")
    let kernel = ($command | parse --regex '-kernel (?P<k>\S+)' | get -o 0.k | default "")
    let smp = ($command | parse --regex '-smp (?P<n>\d+)' | get -o 0.n | default "")
    let machine = ($command | parse --regex '-machine (?P<m>\S+)' | get -o 0.m | default "")
    let cpu = ($command | parse --regex '-cpu (?P<c>\S+)' | get -o 0.c | default "")
    let accel = ($command | parse --regex '-accel (?P<a>\S+)' | get -o 0.a | default "")
    let stamp_file = (if $kernel == "" { "" } else { $kernel | path dirname | path join "flags" })
    let stamp = (if $stamp_file != "" and ($stamp_file | path exists) { open --raw $stamp_file | decode | str trim } else { "" })
    let symbols = ($stamp | parse --regex '--defsym (?P<s>[A-Z0-9_]+)=1' | get s)
    let binary = (process command-binary $command)
    let qemu = (try { ^$binary --version | complete | get stdout | lines | get -o 0 | default "" } catch { "" })
    { os: $nu.os-info.name, arch: $nu.os-info.arch, qemu: $qemu, harts: (if $smp == "" { null } else { $smp | into int }), machine: $machine, cpu: $cpu, accel: $accel, window: $window, kernel: $kernel, symbols: $symbols, pid: $pid, started: ($started | format date "%Y-%m-%dT%H:%M:%S") }
}

# The running Jab QEMU recorded per thread each second, reported when it ends
export def main [ws: path, --skip: float = 5.0]: nothing -> nothing {
    let pids = (process jab-pids)
    if ($pids | is-empty) { error make {msg: "no jab is running"} }
    let pid = ($pids | first)
    let file = (watch-file $ws)
    mkdir ($file | path dirname)
    target retire $file (target root $ws)
    let started = (date now)
    let run = (watch-header $pid $started)
    ({ run: $run } | to nuon) + (char nl) | save --raw $file
    print $"jab watch: recording ($pid) to ($file), ($run.symbols | str join ', ') under ($run.window)"
    if ($pids | length) > 1 { print $"jab watch: ($pids | length) jab processes; recording the first" }
    mut last: any = null
    loop {
        if (process jab-pids | where {|p| $p == $pid } | is-empty) { print "jab watch: the run has ended"; break }
        let at = (((date now) - $started) / 1sec)
        let threads = (process threads-of $pid)
        ({ at: $at, threads: $threads, rss: (process memory-of $pid) } | to nuon) + (char nl) | save --raw --append $file
        let previous = $last
        if $previous != null {
            let seconds = ($at - $previous.at)
            let rates = ($threads | each {|t|
                let before = ($previous.threads | where id == $t.id | get -o 0.cpu | default $t.cpu)
                { name: $t.name, rate: (($t.cpu - $before) / $seconds) }
            } | where rate >= 0.01 | sort-by rate --reverse)
            print $"($at | math round)s  ($rates | each {|r| $'($r.name) ($r.rate | math round -p 2)' } | str join '  ')"
        }
        $last = { at: $at, threads: $threads }
        sleep 1sec
    }
    print (watch-report-of $file $skip | to nuon --indent 2)
}

# A watch recording's report: steady and peak CPU per thread past the load
def watch-report-of [file: path, skip: float]: nothing -> record {
    let lines = (open --raw $file | decode | lines | where {|l| ($l | str trim) != "" })
    let header = ($lines | first | from nuon)
    let recorded = ($lines | skip 1 | each {|l| $l | from nuon })
    let after = ($recorded | where at >= $skip)
    let skipped = (if ($after | length) >= 2 { $skip } else { 0.0 })
    let samples = (if ($after | length) >= 2 { $after } else { $recorded })
    if ($samples | length) < 2 { error make {msg: $"the run ended after ($samples | length) samples, too few for a report; watch a run of two seconds or more"} }
    let first = ($samples | first)
    let last = ($samples | last)
    let seconds = ($last.at - $first.at)
    let threads = ($last.threads | get id | each {|id|
        let series = ($samples | each {|s|
            let t = ($s.threads | where id == $id | get -o 0)
            if $t == null { null } else { { at: $s.at, cpu: $t.cpu, name: $t.name } }
        } | compact)
        if ($series | length) < 2 { null } else {
            let steady = ((($series | last).cpu - ($series | first).cpu) / (($series | last).at - ($series | first).at))
            let rates = ($series | window 2 | each {|w| ($w.1.cpu - $w.0.cpu) / ($w.1.at - $w.0.at) })
            let stable = (not ($rates | any {|r| $r < -0.001 or $r > 1.05 }))
            { name: ($series | last).name, id: $id, steady: ($steady | math round -p 3), peak: (if $stable { $rates | math max | math round -p 3 } else { null }), stable: $stable }
        }
    } | compact | where steady >= 0.005 | sort-by steady --reverse)
    let names = ($last.threads | get name)
    let tcg = (if ($names | any {|n| $n == "ALL CPUs/TCG" }) { "single-threaded" } else if ($names | any {|n| $n =~ '^CPU \d+/TCG$' }) { "multi-threaded" } else { null })
    let resident = ($samples | each {|s| $s | get -o rss } | compact | sort)
    {
        run: $header.run,
        skipped: $skipped,
        seconds: ($seconds | math round -p 1),
        samples: ($samples | length),
        tcg: $tcg,
        process: (if ($threads | is-empty) { 0.0 } else { $threads | get steady | math sum | math round -p 3 }),
        threads: $threads,
        memory: (if ($resident | is-empty) { null } else { { median: ($resident | get ((($resident | length) * 0.5 | math ceil) - 1)), peak: ($resident | last), samples: ($resident | length) } }),
    }
}

# A watch report's resident memory in words, median and peak in MiB
def memory-text [memory: any]: nothing -> string {
    if $memory == null { "" } else { $"; resident ($memory.median / 1048576 | math round) MiB at the median, ($memory.peak / 1048576 | math round) at the peak" }
}

# A watch report's busiest threads as one short line
def watch-top [threads: list<any>]: nothing -> string {
    $threads | first 4 | each {|t| $"($t.name) ($t.steady)" } | str join ", "
}

# A recording's threads' rates over its last samples, as one short line
def watch-rates [file: path, span: int]: nothing -> string {
    let samples = (open --raw $file | decode | lines | where {|l| ($l | str trim) != "" } | skip 1)
    if ($samples | length) < 2 { return "" }
    let last = ($samples | last | from nuon)
    let first = ($samples | last ([($span + 1) ($samples | length)] | math min) | first | from nuon)
    let seconds = ($last.at - $first.at)
    if $seconds <= 0 { return "" }
    $last.threads | each {|t|
        let before = ($first.threads | where id == $t.id | get -o 0.cpu | default $t.cpu)
        { name: $t.name, rate: (($t.cpu - $before) / $seconds) }
    } | where rate >= 0.01 | sort-by rate --reverse | first 4 | each {|r| $"($r.name) ($r.rate | math round --precision 2)" } | str join "  "
}

# Every QEMU of a bench's run recorded per step, reported and packed at its end
export def bench [ws: path, name?: string, --skip: float = 5.0]: nothing -> nothing {
    let ws = ($ws | path expand)
    if not (workspace is-workspace $ws) { error make {msg: $"($ws) is no workspace's root"} }
    if $name == null { print (bench bench-list $ws); return }
    let b = (bench bench-at $ws $name)
    let state_file = (bench bench-home $b | path join "state.nuon")
    let before = (bench bench-state $state_file)
    mut state: any = (if $before != null and (bench bench-live $before) { $before } else { null })
    if $state == null { print $"jab watch: waiting for ($b.name) to start: `./do bench ($b.name)` in another terminal" }
    while $state == null {
        sleep 1sec
        let s = (bench bench-state $state_file)
        if $s != null and ($before == null or $s.stamp != $before.stamp) { $state = $s }
    }
    let run = $state.dir
    let stamp = $state.stamp
    let root = (target root $ws)
    let labels = ($b.def.steps | get label)
    let watch_dir = ($run | path join "watch")
    mkdir $watch_dir
    print $"jab watch: recording ($b.name)'s run ($stamp), ($state.total) steps, into ($watch_dir)"
    mut seen = []
    mut label = ""
    mut tick = 0
    loop {
        let read = (bench bench-state $state_file)
        let current = (if $read != null and $read.stamp == $stamp { $read } else { $state })
        if $current.label != "" and $current.label != $label { print $"jab watch: step ($current.step) of ($current.total), ($current.label)" }
        $label = $current.label
        let found = (bench bench-qemus $run)
        let pids = ($found | each {|q| $q.pid })
        let known = ($seen | each {|e| $e.pid })
        for q in ($found | where {|x| $x.pid not-in $known }) {
            let pid = $q.pid
            let step = (bench bench-step-of $q.command $run $labels)
            let n = (($seen | where {|e| $e.label == $step } | length) + 1)
            let file = ($watch_dir | path join $"($step)-($n).nuonl")
            let started = (date now)
            target retire $file $root
            ({ run: (watch-header $pid $started) } | to nuon) + (char nl) | save --raw $file
            $seen = ($seen | append { pid: $pid, label: $step, n: $n, file: $file, started: $started, ended: false })
            print $"jab watch: ($step), QEMU ($n), ($pid)"
        }
        let now = (date now)
        for e in ($seen | enumerate | where {|x| not $x.item.ended }) {
            if $e.item.pid in $pids {
                ({ at: (($now - $e.item.started) / 1sec), threads: (process threads-of $e.item.pid), rss: (process memory-of $e.item.pid) } | to nuon) + (char nl) | save --raw --append $e.item.file
            } else {
                let i = $e.index
                $seen = ($seen | enumerate | each {|x| if $x.index == $i { $x.item | merge { ended: true } } else { $x.item } })
                let r = (try { watch-report-of $e.item.file $skip } catch { null })
                print (if $r == null { $"jab watch: ($e.item.label), QEMU ($e.item.n) ended, too short to report" } else { $"jab watch: ($e.item.label), QEMU ($e.item.n) ended: ($r.process) of a core over ($r.seconds) s; (watch-top $r.threads)(memory-text $r.memory)" })
            }
        }
        $tick += 1
        if ($tick mod 5) == 0 {
            for e in ($seen | where {|x| not $x.ended }) {
                let rates = (watch-rates $e.file 5)
                if $rates != "" { print $"  ($e.label) ($e.n): ($rates)" }
            }
        }
        let finished = ($current.state in [done failed]) or (not (process process-alive ($current.pid | into string)))
        if $finished and ($pids | is-empty) and ($seen | all {|x| $x.ended }) { break }
        sleep 1sec
    }
    let last = (bench bench-state $state_file)
    let ended = (if $last == null or $last.stamp != $stamp { "superseded by a later run" } else if $last.state in [done failed] { $last.state } else { "ended unfinished" })
    let per = ($seen | each {|e|
        let w = (try { watch-report-of $e.file $skip } catch {|err| { error: $err.msg } })
        { step: $e.label, n: $e.n, pid: $e.pid, file: $e.file, watch: $w }
    })
    let text_file = ($run | path join "report.txt")
    print ""
    print $"jab watch: ($b.name)'s run ($stamp) ($ended)"
    print (if ($text_file | path exists) { open --raw $text_file | decode | str trim --right } else { "the bench wrote no report" })
    print "per QEMU, the steady CPU seconds a second:"
    for p in $per {
        print (if ($p.watch | get -o error) != null { $"  ($p.step) ($p.n): ($p.watch.error)" } else { $"  ($p.step) ($p.n): ($p.watch.process) of a core over ($p.watch.seconds) s; (watch-top $p.watch.threads)(memory-text $p.watch.memory)" })
    }
    let report_file = ($run | path join "report.nuon")
    let whole = {
        bench: $b.name, run: $stamp, dir: $run, state: $ended,
        steps: (try { open ($run | path join "bench.nuon") | get steps } catch { null }),
        report: (if ($report_file | path exists) { open $report_file } else { null }),
        watch: $per,
    }
    let out = ($run | path join "watch.nuon")
    target retire $out $root
    $whole | to nuon --indent 2 | save --raw $out
    let packed = (try { { tar: (bench bench-tar ($run | path dirname) $stamp $b.name $root), error: "" } } catch {|e| { tar: null, error: $e.msg } })
    print (if $packed.tar == null { $"jab watch: ($out); the run is left unpacked in its directory: ($packed.error)" } else { $"jab watch: everything in ($packed.tar)" })
}
