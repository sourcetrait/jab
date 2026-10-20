use (path self ../cpu)
use (path self ../identity)
use (path self ../measure)
use (path self ../report)
use (path self ../identity) [FROM_EMBEDDED FROM_FILE]
use (path self ../measure) [CAP]

# The workspace's root, resolved from this file's own path
const WORKSPACE = path self ../../../../../..

# A run's capture, its api.out, read and reported by read-capture
export def main [
    api: path
    --route: string = ""
    --out: string = ""
    --label: string = ""
] {
    read-capture $api $route $out $label
}

# A capture read under its launch identity and its route's legs, report written
def read-capture [api: path, route: string, out: string, label: string]: nothing -> nothing {
    let file = ($api | path expand)
    let dir = ($file | path dirname)
    let read_id = (identity read $dir)
    for p in $read_id.passed { print $"gauge: passed over ($p.dir) at ($p.strength): ($p.reasons | str join '; ')" }
    if ($read_id.reports | length) > 1 { print $"gauge: the identity reconciled from ($read_id.reports | str join ' and ')" }
    let id = $read_id.identity
    let chosen = (report legs-for $dir $id $route)
    let legs = $chosen.legs
    if $chosen.route != null and (not $chosen.checked) { print $"gauge: the legs from ($chosen.route), unchecked: the capture's identity records no route" }
    let run_file = ($dir | path join "run.nuon")
    let ran = (if ($run_file | path exists) { open $run_file } else { { status: null, fault: null, cpu_seconds: null, wall_seconds: null, qemu_binary: null, qemu: [], window: null, audio: null } })
    let measured = (measure (open --raw $file | into binary) $legs --cap ($id | get -o cap | default $CAP))
    print (report run-line $label 1 $measured $ran)
    print (report outcome-line 1 $measured $ran)
    let served = (report service-line 1 $measured)
    if $served != null { print $served }
    let target = (if $out == "" { $dir } else { $out | path expand })
    mkdir $target
    let windows = (if ($ran | get -o thread_readings | default [] | is-empty) or $chosen.route == null { null } else { cpu windows $ran.thread_readings $legs ($id | get -o mode.end | default 0sec) })
    report write $label $id [(read-run $read_id $dir $ran $measured $windows)] $target
}

# A kept bench step's report made again from its runs, each stream measured anew
export def batch [step: path, --label: string = "", --out: string = ""] {
    let reader = (identity repo-of $WORKSPACE)
    let dir = ($step | path expand)
    let kept = (glob ($dir | path join "run_*") | where {|d| ($d | path type) == "dir" and (($d | path basename) =~ '^run_[0-9]+$') })
    if ($kept | is-empty) { error make { msg: $"($dir) holds no run_<n> directory, so it is no kept step" } }
    let name = (if $label == "" { $dir | path basename } else { $label })
    let runs = ($kept | each {|d| { n: ($d | path basename | str substring 4.. | into int), dir: $d } } | sort-by n | each {|r| batch-run $name $r.n $r.dir })
    let target = (if $out == "" { $dir } else { $out | path expand })
    mkdir $target
    let revision = { reader: $reader, from: $dir, written: (date now | format date "%Y-%m-%dT%H:%M:%S%z") }
    report write $name ($runs | first | get identity) $runs $target --reread $revision
}

# One kept run read anew: its identity, route, run record, stream, and CPU
def batch-run [label: string, n: int, dir: string]: nothing -> record {
    let needed = ([identity.nuon run.nuon api.out] | where {|f| not ($dir | path join $f | path exists) })
    if not ($needed | is-empty) { error make { msg: $"($dir) holds no ($needed | str join ', '), so it is no kept run" } }
    let file = ($dir | path join "identity.nuon")
    let raw = (open --raw $file | into binary)
    let read = (identity corrected $file)
    let id = $read.identity
    let chosen = (report legs-for $dir $id "")
    let ran = (open ($dir | path join "run.nuon"))
    let measured = (measure (open --raw ($dir | path join "api.out") | into binary) $chosen.legs --cap ($id | get -o cap | default $CAP))
    print (report run-line $label $n $measured $ran)
    print (report outcome-line $n $measured $ran)
    let served = (report service-line $n $measured)
    if $served != null { print $served }
    let windows = (if ($ran | get -o thread_readings | default [] | is-empty) or $chosen.route == null { null } else { cpu windows $ran.thread_readings $chosen.legs ($id | get -o mode.end | default 0sec) })
    { run: $n, seed: ($id | get -o mode.seed), out: $dir, ran: $ran, measured: $measured, identity: $id, corrections: $read.corrections, identity_sha256: ($raw | hash sha256), cpu: $windows, audio: (kept-audio $dir) }
}

# A run's audio reading as its play kept it, audio.nuon beside its stream, null for none
def kept-audio [dir: string]: nothing -> any {
    let file = ($dir | path join "audio.nuon")
    if ($file | path exists) { open $file } else { null }
}

# The run record a read writes: its seed, own identity, provenance, and result
def read-run [read_id: record, dir: string, ran: record, measured: record, windows: any]: nothing -> record {
    let own = ($read_id.from in [$FROM_FILE $FROM_EMBEDDED])
    let seed = (if $read_id.seed != null { $read_id.seed } else if $own { $read_id.identity | get -o mode.seed } else { null })
    {
        run: 1, seed: $seed, out: $dir, ran: $ran, measured: $measured, identity: (if $own { $read_id.identity } else { null }), corrections: $read_id.corrections,
        identity_sha256: $read_id.identity_sha256, identity_from: $read_id.from, binding: $read_id.binding,
        passed: $read_id.passed, reports: $read_id.reports, cpu: $windows, audio: (kept-audio $dir),
    }
}
