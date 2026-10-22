use (path self ../bound)
use (path self ../nonce)
use (path self ../nutype)
use (path self ../target)
use (path self ../tool)

# The launch's models, beside the SDK's modules
const types = path self ../../type/launch

# The SDK's own checkout, which builds the supervisor
const sdk = path self ../../..

# The supervisor's startup allowance, from its own start
export const startup_allowance = 11sec

# The caller's backstop on a startup, from before the spawn, and on a cancel
export const backstop = 14sec

# The bound's escalation past a run's seconds, timeout's --kill-after
export const kill_after = 5sec

# QEMU's own exit awaited this long after a clean end or a broken pipe
export const grace = 2sec

# A termination's wait between TERM and KILL
export const term_grace = 1sec

# A schedule's bounds in nanoseconds: startup, retry, screen, CPU, and graces
export def bounds []: nothing -> record<startup_ns: int, retry_ns: int, screen_ns: int, screen_poll_ns: int, cpu_ns: int, grace_ns: int, term_ns: int> {
    {
        startup_ns: ($startup_allowance | into int),
        retry_ns: (10ms | into int),
        screen_ns: (5sec | into int),
        screen_poll_ns: (50ms | into int),
        cpu_ns: (100ms | into int),
        grace_ns: ($grace | into int),
        term_ns: ($term_grace | into int),
    }
}

# The models of a launch's schedule, receipt, and record, by name
def model [name: string]: nothing -> string {
    open --raw ($types | path join $"($name).nutype") | decode
}

# A schedule held to its model; each problem a line of the refusal
export def held [schedule: record]: nothing -> nothing {
    let problems = (nutype problems $schedule (model "Schedule") "Schedule.nutype")
    if not ($problems | is-empty) { error make {msg: $"the launch's schedule breaks its model:\n($problems | str join (char nl))"} }
}

# The supervisor's binary, jabpipe built from this SDK's own checkout
export def binary []: nothing -> string {
    tool shim ($sdk | path expand) "jabpipe" --bin
}

# A launch's control token: a fresh 64-bit value, 1 to 2^63 - 1
export def token []: nothing -> int {
    random int 1..
}

# A control file's path in `dir`: launch-<token>.<kind>.json
export def control [dir: path, token: string, kind: string]: nothing -> string {
    $dir | path join $"launch-($token).($kind).json"
}

# A value written whole as JSON: a temporary name beside it, moved into place
def write-whole [file: path, value: any]: nothing -> nothing {
    let temporary = ($file | path dirname | path join $".($file | path basename).(random int 1..).tmp")
    $value | to json --raw | save --raw $temporary
    mv $temporary $file
}

# A control file's value once it is there, null while it is not
def read-control [file: path]: nothing -> any {
    if not ($file | path exists) { return null }
    try { open --raw $file | decode | from json } catch { null }
}

# Every control file of a token's moved into the retire home
def retire-controls [dir: path, token: string, root: path]: nothing -> nothing {
    for kind in [schedule readiness authorization cancel outcome receipt] {
        let file = (control $dir $token $kind)
        if ($file | path exists) { target retire $file $root }
    }
}

# A lock call under the bound, its answer; one the bound ended is `timeout`
def lock-call [binary: string, bound: string, words: list<string>]: nothing -> record {
    let r = (^$bound 2 $binary lock ...$words | complete)
    if $r.exit_code == 124 { return { outcome: "timeout", why: "the lock call outlived its bound", record: null } }
    try { $r.stdout | from json } catch { { outcome: "error", why: $"the lock call said ($r.stdout | str trim) ($r.stderr | str trim)", record: null } }
}

# An alarm: a job that sleeps its bound, then tells the launch's tag it fired
def alarm [tag: int, source: string, after: duration]: nothing -> int {
    job spawn { sleep $after; { token: $tag, source: $source } | job send --tag $tag 0 }
}

# A launch's next message on its tag within `wait`, a retired source's discarded
export def receive [tag: int, retired: list<string>, wait: oneof<duration, nothing>]: nothing -> oneof<record, nothing> {
    loop {
        let message = (if $wait == null { job recv --tag $tag } else { try { job recv --tag $tag --timeout $wait } catch { return null } })
        if ($message | describe | str starts-with "record") and ($message | get -o token) == $tag and ($message | get -o source) not-in $retired {
            return $message
        }
        if $wait != null { return null }
    }
}

# A launch's tag emptied of messages once each source is received or retired
def drain [tag: int]: nothing -> nothing {
    while (try { job recv --tag $tag --timeout 0sec; true } catch { false }) {}
}

# A run's group ended by the kept record: TERM, a second, KILL, confirmed empty
def forced [binary: string, readiness: record]: nothing -> record {
    let gate = $readiness.gate
    if $gate.group == null or $gate.start == null { return { outcome: "refused", why: "the record names no group to end", running: [] } }
    let r = (^$binary group terminate --group ($gate.group | into string) --leader ($gate.pid | into string) --start ($gate.start | into string) | complete)
    try { $r.stdout | from json } catch { { outcome: "error", why: $"the group call said ($r.stdout | str trim) ($r.stderr | str trim)", running: [] } }
}

# A bounded launch under its supervisor: lock, startup, alarms, and receipt
export def bounded [schedule: record, root: path, seconds: int]: nothing -> record<receipt: oneof<record, nothing>, incomplete: oneof<string, nothing>, schedule_sha256: string, launch: string> {
    held $schedule
    let withhold = (($env.JAB_LAUNCH_TEST? | default "") == "withhold")
    let binary = (binary)
    let bound = (bound timeout).path
    let token = $schedule.token
    let tag = ($token | decode hex | into int --endian big)
    let dir = $schedule.dir
    let schedule_file = (control $dir $token "schedule")
    let readiness_file = (control $dir $token "readiness")
    let launch_file = ($dir | path join "launch.nuon")
    if ($launch_file | path exists) { target retire $launch_file $root }
    write-whole $schedule_file $schedule
    let schedule_sha256 = (open --raw $schedule_file | hash sha256)
    let acquired = (lock-call $binary $bound ["acquire" "--token" $token "--caller" ($nu.pid | into string)])
    if $acquired.outcome != "ok" {
        retire-controls $dir $token $root
        error make {msg: $"the launch lock refused this launch, ($acquired.outcome): ($acquired.why)"}
    }
    mut alarms = { startup: (alarm $tag "startup" $backstop) }
    let supervisor = (job spawn {
        let r = (^$binary supervise --token $token --schedule $schedule_file | complete)
        { token: $tag, source: "supervisor", result: $r } | job send --tag $tag 0
    })
    mut retired = []
    mut readiness: any = null
    mut sent = "none"
    mut outcome: any = null
    mut result: any = null
    mut fired: any = null
    while $outcome == null and $result == null and $fired == null {
        let message = (receive $tag $retired 10ms)
        if $message != null {
            if $message.source == "supervisor" { $result = $message.result } else { $fired = $message.source }
        }
        if $readiness == null { $readiness = (read-control $readiness_file) }
        if $readiness != null and $sent == "none" {
            let copied = (lock-call $binary $bound ["state" "--token" $token "--state" "running" "--readiness" $readiness_file])
            if $copied.outcome != "ok" {
                write-whole (control $dir $token "cancel") { token: $token }
                $sent = "cancel"
            } else if $withhold {
                $sent = "withheld"
            } else {
                write-whole (control $dir $token "authorization") { token: $token }
                $sent = "authorization"
            }
        }
        $outcome = (read-control (control $dir $token "outcome"))
    }
    try { job kill $alarms.startup }
    $retired = ($retired | append "startup")
    if $fired == "startup" and $sent != "authorization" {
        if $sent != "cancel" { write-whole (control $dir $token "cancel") { token: $token } }
        try { job kill $supervisor }
        drain $tag
        lock-call $binary $bound ["release" "--token" $token] | ignore
        retire-controls $dir $token $root
        error make {msg: $"the launch's supervisor gave no outcome within the caller's backstop of ($backstop); nothing measured ran"}
    }
    let went = ($outcome != null and $outcome.decision == "go")
    if $result == null and $fired == null {
        let after = (if $went { $seconds * 1sec + $kill_after + $grace + 1sec } else { $grace + 1sec })
        $alarms = ($alarms | insert ending (alarm $tag (if $went { "completion" } else { "cancellation" }) $after))
    }
    while $result == null and $fired == null {
        let message = (receive $tag $retired null)
        if $message != null {
            if $message.source == "supervisor" { $result = $message.result } else { $fired = $message.source }
        }
    }
    try { job kill ($alarms | get -o ending | default (-1)) }
    mut incomplete: any = null
    if $result == null {
        $incomplete = $"the ($fired) alarm: no exit receipt from the supervisor in time"
        let record = (if $readiness == null { read-control $readiness_file } else { $readiness })
        let ended = (if $record == null { { outcome: "refused", why: "no readiness was ever read", running: [] } } else { forced $binary $record })
        try { job kill $supervisor }
        if $ended.outcome == "ok" {
            lock-call $binary $bound ["release" "--token" $token] | ignore
        } else {
            lock-call $binary $bound ["state" "--token" $token "--state" "cleanup"] | ignore
            $incomplete = $"($incomplete); the group's end: ($ended.outcome), ($ended.why)"
        }
    } else {
        lock-call $binary $bound ["release" "--token" $token] | ignore
    }
    drain $tag
    let receipt = (if $result == null { null } else { read-control (control $dir $token "receipt") })
    if $result != null and $receipt == null {
        retire-controls $dir $token $root
        error make {msg: $"the supervisor ended with ($result.exit_code) and left no receipt: ($result.stderr | str trim)"}
    }
    if $receipt != null {
        let problems = (nutype problems $receipt (model "Receipt") "Receipt.nutype")
        if not ($problems | is-empty) {
            retire-controls $dir $token $root
            error make {msg: $"the launch's receipt breaks its model, so none of it is read:\n($problems | str join (char nl))"}
        }
    }
    let record = { schedule_sha256: $schedule_sha256, receipt: $receipt, incomplete: $incomplete }
    $record | to nuon --indent 2 | save --raw $launch_file
    retire-controls $dir $token $root
    $record | insert launch $launch_file
}

# An interactive run under its supervisor in the terminal's foreground
export def interactive [schedule: record, root: path]: nothing -> nothing {
    held $schedule
    let binary = (binary)
    for f in (glob ($schedule.dir | path join "launch-*.json")) { target retire $f $root }
    let file = (control $schedule.dir $schedule.token "schedule")
    write-whole $file $schedule
    ^$binary supervise --token $schedule.token --schedule $file
}

# A control token as the supervisor takes it, sixteen lowercase hex digits
export def hex [token: int]: nothing -> string {
    nonce hex $token
}
