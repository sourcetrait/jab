use (path self ../cpu)
use (path self ../identity)
use (path self ../measure)
use (path self ../report)
use (path self ../identity) [FROM_EMBEDDED FROM_FILE]
use (path self ../measure) [CAP]

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
    let target = (if $out == "" { $dir } else { $out | path expand })
    mkdir $target
    let windows = (if ($ran | get -o thread_readings | default [] | is-empty) or $chosen.route == null { null } else { cpu windows $ran.thread_readings $legs ($id | get -o mode.end | default 0sec) })
    report write $label $id [(read-run $read_id $dir $ran $measured $windows)] $target
}

# The run record a read writes: its seed, own identity, provenance, and result
def read-run [read_id: record, dir: string, ran: record, measured: record, windows: any]: nothing -> record {
    let own = ($read_id.from in [$FROM_FILE $FROM_EMBEDDED])
    let seed = (if $read_id.seed != null { $read_id.seed } else if $own { $read_id.identity | get -o mode.seed } else { null })
    {
        run: 1, seed: $seed, out: $dir, ran: $ran, measured: $measured, identity: (if $own { $read_id.identity } else { null }), corrections: $read_id.corrections,
        identity_sha256: $read_id.identity_sha256, identity_from: $read_id.from, binding: $read_id.binding,
        passed: $read_id.passed, reports: $read_id.reports, cpu: $windows,
    }
}
