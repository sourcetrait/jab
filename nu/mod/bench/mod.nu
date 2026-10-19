use ../build
use ../host
use ../process
use ../target
use ../walk
use ../workspace

# The benches of a workspace's programs, `<program>/<bench>` each
def benches-of [ws: path]: nothing -> list<string> {
    workspace programs-of $ws | each {|p|
        walk paths ($ws | path expand | path join $p "bench" "*.nuon") | sort | each {|f| $"($p)/($f | path parse | get stem)" }
    } | flatten
}

# The bench a name names, its program and definition held to its shape
export def bench-at [ws: path, name: string] {
    let words = ($name | split row "/" | where {|w| $w != "" })
    let all = (benches-of $ws)
    if ($words | length) < 2 { error make {msg: $"a bench by its program's path and its name, `just bench <program>/<bench>`: ($all | str join ', ')"} }
    let bench = ($words | last)
    let program = (workspace program-path $ws ($words | drop 1))
    let file = ($ws | path expand | path join $program "bench" $"($bench).nuon")
    if not ($file | path exists) { error make {msg: $"no bench ($bench) in ($program); the benches: ($all | str join ', ')"} }
    let def = (open $file)
    if ($def | get -o summary) == null or ($def | get -o steps) == null { error make {msg: $"($file) needs a summary and steps"} }
    let labels = ($def.steps | each {|s| $s | get -o label | default "" })
    if ($labels | any {|l| $l == "" }) or ($labels | uniq | length) != ($labels | length) { error make {msg: $"($file): every step needs a label of its own"} }
    if ($def.steps | any {|s| ($s | get -o run | default [] | is-empty) }) { error make {msg: $"($file): every step needs `run`, its script and the script's arguments"} }
    { name: $"($program)/($bench)", program: $program, dir: ($ws | path expand | path join $program), bench: $bench, file: $file, def: $def }
}

# Where a bench's runs land, beside the state file a watch reads
export def bench-home [b: record]: nothing -> string {
    build program-shard $b.dir "bench" | path join $b.bench
}

# The list `just bench` prints: each bench with its summary
export def bench-list [ws: path]: nothing -> string {
    let shown = (benches-of $ws | each {|n|
        let b = (bench-at $ws $n)
        $"  just bench ($n)\n      ($b.def.summary)"
    })
    (["the benches, `just bench <program>/<bench>` with `just watch bench <program>/<bench>` in a second terminal:"] ++ $shown) | str join "\n"
}

# A bench's state file as its run last wrote it; null when there is none
export def bench-state [file: path]: nothing -> oneof<record, nothing> {
    if not ($file | path exists) { return null }
    try { open $file } catch { null }
}

# Whether the run a state describes is under way, its process alive
export def bench-live [s: record]: nothing -> bool {
    ($s.state not-in [done failed]) and (process process-alive ($s.pid | into string))
}

# A bench's state file written whole through a file moved over it
def bench-save-state [file: path, state: record]: nothing -> nothing {
    let next = $"($file).next"
    $state | to nuon | save --raw -f $next
    mv -f $next $file
}

# A bench's run packed into one tar beside its directory: the tar's path
export def bench-tar [home: path, stamp: string, name: string, root: path] {
    let file = ($home | path join $"($name | str replace --all '/' '_')-($stamp).tar")
    target retire $file $root
    let r = (do { cd $home; ^tar -cf ($file | path basename) $stamp | complete })
    if $r.exit_code != 0 { error make {msg: $"tar of ($home | path join $stamp) ended with ($r.exit_code): ($r.stderr | str trim)"} }
    $file
}

# A program's bench, every step in order, then its report and its tar
export def main [ws: path, name?: string, --only: string = ""] {
    let ws = ($ws | path expand)
    if not (workspace is-workspace $ws) { error make {msg: $"($ws) is no workspace's root"} }
    if $name == null { print (bench-list $ws); return }
    let b = (bench-at $ws $name)
    let labels = ($b.def.steps | get label)
    let picked = ($only | split row "," | each {|l| $l | str trim } | where {|l| $l != "" })
    let unknown = ($picked | where {|l| $l not-in $labels })
    if not ($unknown | is-empty) { error make {msg: $"($b.name) has no step ($unknown | str join ', '); its steps: ($labels | str join ', ')"} }
    let steps = (if ($picked | is-empty) { $b.def.steps } else { $b.def.steps | where {|s| $s.label in $picked } })
    let tree = ($b.def | get -o tree | default "release")
    let names = (target tree-symbols $tree)
    let home = (bench-home $b)
    let stamp = (date now | format date "%Y%m%d-%H%M%S")
    let dir = ($home | path join $stamp)
    if ($dir | path exists) { error make {msg: $"a run of ($b.name) started this second, at ($dir)"} }
    mkdir $dir
    let state_file = ($home | path join "state.nuon")
    let record_file = ($dir | path join "bench.nuon")
    let total = ($steps | length)
    let base = { bench: $b.name, stamp: $stamp, dir: $dir, pid: $nu.pid, started: (date now | format date "%Y-%m-%dT%H:%M:%S"), total: $total }
    mut record: record = {
        bench: $b.name, summary: $b.def.summary, tree: $tree, stamp: $stamp, started: $base.started, file: $b.file,
        steps: ($steps | each {|s| { label: $s.label, attend: ($s | get -o attend), run: $s.run, state: "pending", exit: null, seconds: null } }),
        report: null, state: "building",
    }
    $record | to nuon --indent 2 | save --raw $record_file
    bench-save-state $state_file ($base | merge { step: 0, label: "", state: "building" })
    print $"jab bench: ($b.name), ($total) steps, into ($dir): ($b.def.summary)"
    let broken = (try {
        let m = (open ($ws | path join "workspace.jab.toml"))
        build build-kernel ($ws | path join $m.kernel) $names
        build prepare $b.dir "build"
        build build-program $b.dir $names
        null
    } catch {|e| $e.msg })
    if $broken != null {
        $record = ($record | merge { state: "failed" })
        $record | to nuon --indent 2 | save --raw -f $record_file
        bench-save-state $state_file ($base | merge { step: 0, label: "", state: "failed" })
        error make {msg: $"($b.name): the build failed: ($broken)"}
    }
    for entry in ($steps | enumerate) {
        let s = $entry.item
        let n = ($entry.index + 1)
        bench-save-state $state_file ($base | merge { step: $n, label: $s.label, state: "running" })
        let attend = ($s | get -o attend)
        if $attend != null {
            print $"jab bench: step ($n) of ($total), ($s.label): ($attend)"
            for left in 10..1 { print -n $"\r  starting in ($left) s "; sleep 1sec }
            print ""
        } else {
            print $"jab bench: step ($n) of ($total), ($s.label)"
        }
        let script = ($b.dir | path join ($s.run | first))
        let started = (date now)
        let code = (try {
            ^nu $script ...($s.run | skip 1) --out ($dir | path join $s.label) --label $s.label
            0
        } catch { $env.LAST_EXIT_CODE? | default 1 })
        let seconds = ((((date now) - $started) / 1sec) | math round --precision 1)
        let i = $entry.index
        let outcome = { state: (if $code == 0 { "done" } else { "failed" }), exit: $code, seconds: $seconds }
        let updated = ($record.steps | enumerate | each {|e| if $e.index == $i { $e.item | merge $outcome } else { $e.item } })
        $record = ($record | merge { steps: $updated })
        $record | to nuon --indent 2 | save --raw -f $record_file
        if $code != 0 { print $"jab bench: ($s.label) failed with exit ($code); on to the next step" }
    }
    bench-save-state $state_file ($base | merge { step: $total, label: "", state: "reporting" })
    let report = ($b.def | get -o report)
    let reported = (if $report == null { null } else {
        try { ^nu ($b.dir | path join ($report | first)) ...($report | skip 1) $dir; 0 } catch { $env.LAST_EXIT_CODE? | default 1 }
    })
    let failed = ($record.steps | where state != "done" | get label)
    let final = (if ($failed | is-empty) and ($reported == null or $reported == 0) { "done" } else { "failed" })
    $record = ($record | merge { report: $reported, state: $final })
    $record | to nuon --indent 2 | save --raw -f $record_file
    let packed = (try { { tar: (bench-tar $home $stamp $b.name (target root $ws)), error: "" } } catch {|e| { tar: null, error: $e.msg } })
    bench-save-state $state_file ($base | merge { step: $total, label: "", state: $final })
    let failures = (if ($failed | is-empty) { "" } else { $"; failed: ($failed | str join ', ')" })
    let unreported = (if $reported == null or $reported == 0 { "" } else { $"; the report failed with exit ($reported)" })
    if $packed.tar == null { print $"jab bench: the run is left unpacked in its directory: ($packed.error)" }
    if ($dir | path join "watch" | path exists) { print "jab bench: the watch recording this run packs it again, its recording included, when it ends" }
    print $"jab bench: ($b.name) ($final), ($total) steps($failures)($unreported); everything in (if $packed.tar == null { $dir } else { $packed.tar })"
    if $final != "done" { exit 1 }
}

# The QEMUs of a bench's run, each its pid and command line
export def bench-qemus [run: path]: nothing -> list<record<pid: int, command: string>> {
    ps -l | where {|p| ((process command-binary $p.command | path basename) == (host exe-name $process.qemu_name)) and ($p.command | str contains $run) } | each {|p| { pid: $p.pid, command: $p.command } }
}

# The step a QEMU of a bench's run belongs to, by its command line
export def bench-step-of [command: string, run: path, labels: list<string>]: nothing -> string {
    let parts = ($command | split row $"($run)/")
    if ($parts | length) < 2 { return "unknown" }
    let named = ($parts | get 1 | split row "/" | first)
    if $named in $labels { $named } else { "unknown" }
}
