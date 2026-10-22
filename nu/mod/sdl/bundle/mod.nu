use (path self ../../identity)
use (path self ../../nonce)
use (path self ../classify)
use (path self ../log)
use (path self ../symbols)
use (path self ../../walk)

# The QEMU version whose command queue the trace's bracket rests on
const traced_qemu = "11.1.2"

# A probed run's capture bundled with its tables and manifest, on its host
export def main [probe: path, bundle: path, --profile: string = "", --extra: list<string> = []] {
    let reader = (sdl-reader)
    let probe = ($probe | path expand)
    let bundle = ($bundle | path expand)
    let log = ($probe | path join "sdl.log")
    if not ($log | path exists) { error make {msg: $"($probe) holds no sdl.log to bundle"} }
    if ($bundle | path type) != null { error make {msg: $"($bundle) is already there; a bundle is written once"} }
    let identity_file = ($probe | path join "identity.nuon")
    let identity = (if ($identity_file | path exists) { open --raw $identity_file | into binary | decode | from nuon } else { null })
    let c = (classify sdl-classified $log "")
    let lined = ($c.process != null)
    let given = (if $identity == null { "" } else { $identity | get -o profile | default "" })
    let named = (if $profile != "" { $profile } else if $given != "" { $given } else if $lined { "generic" } else { "historical" })
    if $named not-in [paired generic historical] { error make {msg: $"a bundle's profile is paired, generic, or historical, not ($named)"} }
    if $lined and $named == "historical" { error make {msg: "the log carries the run's lines, so its bundle is paired or generic, never historical"} }
    if (not $lined) and $named != "historical" { error make {msg: $"the log has no process line, so it was written before the run's lines and its bundle is historical, not ($named)"} }
    if $named == "paired" {
        if $c.nonce == null { error make {msg: "a paired bundle needs the log's nonce line, and this log has none"} }
        let missing = (["api.out" "identity.nuon"] | where {|f| not ($probe | path join $f | path exists) })
        if not ($missing | is-empty) { error make {msg: $"a paired bundle needs ($missing | str join ' and ') beside the log in ($probe)"} }
    }
    let carried = (["api.out" "identity.nuon" "trace.log"] ++ $extra | uniq | where {|f| $probe | path join $f | path exists })
    let read = ($c.objects | where {|o| ($c.tables | get ($o.index | into string) | get state) == "read" })
    let hashed = ($read | each {|o|
        let before = (symbols sdl-stat $o.path)
        if $before != { inode: $o.inode, size: $o.size, mtime: $o.mtime } { error make {msg: $"($o.path) changed while bundling: it is no longer the file its line names"} }
        let sha256 = (open --raw $o.path | hash sha256)
        if (symbols sdl-stat $o.path) != $before { error make {msg: $"($o.path) changed while bundling, during its hash"} }
        { index: $o.index, sha256: $sha256 }
    })
    mkdir ($bundle | path join "tables")
    cp $log ($bundle | path join "sdl.log")
    for x in $hashed { $c.tables | get ($x.index | into string) | get nm | save --raw ($bundle | path join "tables" $"($x.index).nm") }
    let events = ($c.events | each {|e| { line: ($e.at + 1), stamp: $e.stamp, name: $e.name, render: $e.render, key: $e.key, kind: $e.kind, callers: $e.callers, evidence: $e.evidence } })
    let counts = ($events | get kind | uniq --count | reduce --fold {} {|k, acc| $acc | insert $k.value $k.count })
    { events: $events, decisions: $c.decisions, counts: $counts } | to nuon --indent 1 | save --raw ($bundle | path join "classified.nuon")
    for f in $carried {
        mkdir ($bundle | path join $f | path dirname)
        cp ($probe | path join $f) ($bundle | path join $f)
    }
    let files = (walk paths ($bundle | path join "**" "*") --no-dir | each {|p| { path: ($p | path relative-to $bundle), sha256: (open --raw $p | hash sha256), size: (ls -D $p | get 0.size | into int) } } | sort-by path)
    let field = {|name: string| if $identity == null { null } else { $identity | get -o $name } }
    let manifest = {
        bundle_schema: 2,
        profile: $named,
        reader: $reader,
        host: { os: $nu.os-info.name, kernel: $nu.os-info.kernel_version, hostname: (sys host | get hostname), qemu: (sdl-qemu-of ($c.objects | where index == 0 | get -o 0) ($hashed | where index == 0 | get -o 0.sha256)) },
        objects: ($c.objects | each {|o|
            let t = ($c.tables | get ($o.index | into string))
            let h = ($hashed | where index == $o.index | get -o 0)
            let table = (if $h == null { null } else { $"tables/($o.index).nm" })
            {
                index: $o.index, path: $o.path, inode: $o.inode, size: $o.size, mtime: $o.mtime,
                state: $t.state, why: $t.why, sha256: (if $h == null { null } else { $h.sha256 }),
                table: $table, table_sha256: (if $table == null { null } else { $files | where path == $table | get 0.sha256 }), source: $t.source,
            }
        }),
        files: $files,
        events: ($events | length),
        run: { process: $c.process, nonce: $c.nonce, capture_nonce: (do $field "capture_nonce"), qemu_pid: (do $field "qemu_pid"), api: (do $field "api"), sends: (do $field "sends") },
    }
    $manifest | to nuon --indent 1 | save --raw ($bundle | path join "bundle.nuon")
    $manifest
}

# The reader a bundle records, its provenance: jab's checkout, its interpreters
def sdl-reader []: nothing -> record<repos: table<repo: string, commit: oneof<string, nothing>, dirty: oneof<bool, nothing>>, runtime: table<role: string, version: string, sha256: oneof<string, nothing>>, executables: table<name: string, sha256: string>> {
    const root = (path self ../../../..)
    identity reader [$root]
}

# The QEMU a log names: its path, and its version and SHA-256 while unchanged
def sdl-qemu-of [exe: oneof<record, nothing>, sha256: oneof<string, nothing>]: nothing -> record<path: string, version: oneof<string, nothing>, sha256: oneof<string, nothing>> {
    if $exe == null { return { path: "", version: null, sha256: null } }
    if (symbols sdl-stat $exe.path) != { inode: $exe.inode, size: $exe.size, mtime: $exe.mtime } { return { path: $exe.path, version: null, sha256: null } }
    let version = (try { ^$exe.path --version | complete | get stdout | lines | get -o 0 } catch { null })
    { path: $exe.path, version: $version, sha256: (if $sha256 != null { $sha256 } else { open --raw $exe.path | hash sha256 }) }
}

# A bundle held to its manifest stage by stage, the first failing refusing it
export def bundle-check [bundle: path, --guest: closure] {
    let box = (sdl-reader)
    let dir = ($bundle | path expand)
    let refuse = {|stage: int, name: string, why: string| error make {msg: $"the bundle is refused at stage ($stage), ($name): ($why)"} }
    let manifest_file = ($dir | path join "bundle.nuon")
    if not ($manifest_file | path exists) { do $refuse 1 "the inventory" $"($dir) holds no bundle.nuon" }
    let m = (try { open --raw $manifest_file | into binary | decode | from nuon } catch {|e| do $refuse 1 "the inventory" $"bundle.nuon is no NUON the check reads: ($e.msg)" })
    if ($m | get -o bundle_schema) not-in [1 2] { do $refuse 1 "the inventory" $"bundle.nuon's bundle_schema is ($m | get -o bundle_schema | to nuon), where 1 and 2 are read" }
    let profile = ($m | get -o profile | default "")
    let listed = ($m | get -o files | default [])
    let names = ($listed | get -o path | default [])
    let present = (walk paths ($dir | path join "**" "*") --no-dir | each {|p| $p | path relative-to $dir } | where {|p| $p != "bundle.nuon" } | sort)
    let unlisted = ($present | where {|p| $p not-in $names })
    if not ($unlisted | is-empty) { do $refuse 1 "the inventory" $"files the manifest does not list: ($unlisted | str join ', ')" }
    for f in $listed {
        let file = ($dir | path join $f.path)
        if not ($file | path exists) { do $refuse 1 "the inventory" $"($f.path), listed, is not there" }
        let size = (ls -D $file | get 0.size | into int)
        let sha256 = (open --raw $file | hash sha256)
        if $size != $f.size or $sha256 != $f.sha256 { do $refuse 1 "the inventory" $"($f.path) is not the file the manifest lists: ($size) bytes of ($sha256), where it lists ($f.size) of ($f.sha256)" }
    }
    let required = (["sdl.log" "classified.nuon"] ++ (if $profile == "paired" { ["api.out" "identity.nuon"] } else { [] }))
    for r in $required { if $r not-in $names { do $refuse 1 "the inventory" $"the manifest lists no ($r), which a ($profile) bundle holds" } }
    let read = (try { log ($dir | path join "sdl.log") } catch {|e| do $refuse 2 "the correspondence" $"the reader refuses the log: ($e.msg)" })
    let objects = ($m | get -o objects | default [])
    if ($objects | length) != ($read.objects | length) { do $refuse 2 "the correspondence" $"the manifest lists ($objects | length) objects and the log's table ($read.objects | length)" }
    for pair in ($read.objects | zip $objects) {
        let o = $pair.0
        let e = $pair.1
        for k in [index path inode size mtime] {
            if ($o | get $k) != ($e | get -o $k) { do $refuse 2 "the correspondence" $"object ($o.index)'s ($k) is ($e | get -o $k | to nuon) in the manifest and ($o | get $k | to nuon) in the log's table" }
        }
        let table = ($e | get -o table)
        if ($e | get -o state) == "read" {
            if $table == null or $table not-in $names { do $refuse 2 "the correspondence" $"object ($o.index)'s table was read, and the manifest lists none for it" }
        } else if $table != null { do $refuse 2 "the correspondence" $"object ($o.index)'s table went unread, and the manifest lists one for it" }
    }
    let cls = (try { open --raw ($dir | path join "classified.nuon") | into binary | decode | from nuon } catch {|e| do $refuse 3 "the sequence" $"classified.nuon is no NUON the check reads: ($e.msg)" })
    let logged = ($read.events | each {|e| { line: ($e.at + 1), stamp: $e.stamp, name: $e.name, render: $e.render, key: (classify sdl-chain-key $e.frames) } })
    let held = ($cls.events | each {|e| { line: $e.line, stamp: $e.stamp, name: $e.name, render: $e.render, key: $e.key } })
    if ($logged | length) != ($held | length) { do $refuse 3 "the sequence" $"the log holds ($logged | length) events and classified.nuon ($held | length)" }
    for pair in ($logged | zip $held) {
        if $pair.0 != $pair.1 { do $refuse 3 "the sequence" $"the log's event at line ($pair.0.line) is ($pair.0 | to nuon), classified.nuon's ($pair.1 | to nuon)" }
    }
    let replay = (try { classify sdl-classified ($dir | path join "sdl.log") $dir } catch {|e| do $refuse 4 "the replay" $"the log classified from the bundle's tables is refused: ($e.msg)" })
    for pair in ($replay.events | zip $cls.events) {
        let carried = (($pair.1 | get -o evidence) != null)
        let got = { kind: $pair.0.kind, callers: $pair.0.callers } | merge (if $carried { { evidence: $pair.0.evidence } } else { {} })
        let want = { kind: $pair.1.kind, callers: $pair.1.callers } | merge (if $carried { { evidence: $pair.1.evidence } } else { {} })
        if $got != $want { do $refuse 4 "the replay" $"the event at line ($pair.1.line) replays as ($got | to nuon), where classified.nuon holds ($want | to nuon)" }
    }
    let read_events = ($cls.events | zip $replay.events | each {|p| $p.0 | upsert evidence $p.1.evidence })
    let run = (match $profile {
        "paired" => {
            let id = (open --raw ($dir | path join "identity.nuon") | into binary | decode | from nuon)
            let pid = ($id | get -o qemu_pid)
            let nonce = ($id | get -o capture_nonce)
            if $read.process == null { do $refuse 5 "the run" "the log has no process line" }
            if $pid == null or $pid == 0 { do $refuse 5 "the run" "the identity records no qemu_pid" }
            if $read.process != $pid { do $refuse 5 "the run" $"the log's process ($read.process) is not the identity's qemu_pid ($pid)" }
            if $read.nonce == null { do $refuse 5 "the run" "the log has no nonce line" }
            if $nonce == null or $nonce == 0 { do $refuse 5 "the run" "the identity records no capture_nonce" }
            if $read.nonce != (nonce hex $nonce) { do $refuse 5 "the run" $"the log's nonce ($read.nonce) is not the identity's capture_nonce, (nonce hex $nonce)" }
            if $guest == null { do $refuse 5 "the run" "the guest's echoed nonce goes unread: a paired bundle is checked with its program's reader of api.out, --guest" }
            let echoed = (do $guest ($dir | path join "api.out"))
            if $echoed == null or $echoed == 0 { do $refuse 5 "the run" "the guest echoed no nonce, its records reading 0" }
            if $echoed != $nonce { do $refuse 5 "the run" $"the guest echoed (nonce hex $echoed), where the run's nonce is (nonce hex $nonce)" }
            { process: $read.process, nonce: $read.nonce, capture_nonce: $nonce, qemu_pid: $pid, guest_nonce: $echoed }
        },
        "generic" | "historical" => { { process: $read.process, nonce: $read.nonce, capture_nonce: null, qemu_pid: null, guest_nonce: null } },
        _ => { do $refuse 5 "the run" $"the manifest's profile is ($profile | to nuon), where paired, generic, or historical is read" },
    })
    let trace = (if "trace.log" not-in $names { null } else {
        let version = ($m | get -o host.qemu.version | default "")
        if not ($version | str contains $"version ($traced_qemu)") { do $refuse 5 "the run" $"the trace's bracket rests on QEMU ($traced_qemu)'s command queue, and the bundle's QEMU reads ($version | to nuon): unsupported, never read on another version's assumption" }
        let uploads = ($replay.events | where kind == "upload" | each {|e| stamp-us $e.stamp })
        let text = (open --raw ($dir | path join "trace.log") | into binary | decode)
        try { trace-bracket $text $uploads } catch {|e| do $refuse 5 "the run" $e.msg }
    })
    let host = ($m | get -o reader)
    let commit_of = {|r| if ($r | describe | str starts-with 'record') { if ($r | get -o repos) != null { $r.repos | get -o 0.commit } else { $r | get -o jab } } }
    let hosted = (do $commit_of $host)
    { profile: $profile, run: $run, reader: { host: $host, box: $box, same: ($hosted != null and $hosted == (do $commit_of $box)) }, trace: $trace, events: $read_events }
}

# Each flip upload between its traced flush and the next traced command, in us
export def trace-bracket [trace: string, uploads: list<int>, --slow-ms: float = 2.0]: nothing -> record<flushes: int, uploads: int, set_scanouts: int, max_lag_us: oneof<int, nothing>, median_lag_us: oneof<int, nothing>, p99_lag_us: oneof<int, nothing>, resolution_us: int, open_last: bool, slow: list<record<upload: int, lag_us: int>>> {
    let commands = ($trace | lines | parse --regex '^(?P<at>\S+) (?P<name>virtio_gpu_cmd_res_flush|virtio_gpu_cmd_set_scanout)\b' | each {|c| { name: $c.name, us: (($c.at | into datetime | into int) // 1000) } })
    let back = ($commands | window 2 | enumerate | where {|w| $w.item.1.us < $w.item.0.us } | get -o 0)
    if $back != null { error make {msg: $"the trace's stamps step back at its traced command ($back.index + 2), a clock stepped back being no bracket"} }
    let behind = ($uploads | window 2 | enumerate | where {|w| $w.item.1 < $w.item.0 } | get -o 0)
    if $behind != null { error make {msg: $"the log's upload stamps step back at flip upload ($behind.index + 2), a clock stepped back being no bracket"} }
    let flushes = ($commands | enumerate | where {|c| $c.item.name == "virtio_gpu_cmd_res_flush" })
    if ($flushes | length) != ($uploads | length) { error make {msg: $"the trace holds ($flushes | length) flushes and the log ($uploads | length) flip uploads"} }
    let pairs = ($flushes | zip $uploads | enumerate | each {|e|
        let next = ($commands | get -o ($e.item.0.index + 1))
        { upload: ($e.index + 1), flush_us: $e.item.0.item.us, upload_us: $e.item.1, next_us: (if $next == null { null } else { $next.us }) }
    })
    let early = ($pairs | where {|p| $p.upload_us < $p.flush_us } | get -o 0)
    if $early != null { error make {msg: $"flip upload ($early.upload) lies outside its flush's bracket, ($early.flush_us - $early.upload_us) us before its flush"} }
    let late = ($pairs | where {|p| if $p.next_us == null { false } else { $p.upload_us > $p.next_us } } | get -o 0)
    if $late != null { error make {msg: $"flip upload ($late.upload) lies outside its flush's bracket, ($late.upload_us - $late.next_us) us past the next traced command"} }
    let lags = ($pairs | each {|p| $p.upload_us - $p.flush_us } | sort)
    let rank = {|q: float| $lags | get ([((($lags | length) * $q | math ceil) - 1) 0] | math max) }
    {
        flushes: ($flushes | length),
        uploads: ($uploads | length),
        set_scanouts: ($commands | where name == "virtio_gpu_cmd_set_scanout" | length),
        max_lag_us: (if ($lags | is-empty) { null } else { $lags | last }),
        median_lag_us: (if ($lags | is-empty) { null } else { do $rank 0.5 }),
        p99_lag_us: (if ($lags | is-empty) { null } else { do $rank 0.99 }),
        resolution_us: 1,
        open_last: (if ($pairs | is-empty) { false } else { ($pairs | last | get next_us) == null }),
        slow: ($pairs | where {|p| ($p.upload_us - $p.flush_us) > ($slow_ms * 1000.0) } | each {|p| { upload: $p.upload, lag_us: ($p.upload_us - $p.flush_us) } }),
    }
}

# A log stamp, the shim's seconds and six digits, as whole microseconds
def stamp-us [stamp: string]: nothing -> int {
    let parts = ($stamp | split row ".")
    ($parts.0 | into int) * 1000000 + ($parts.1 | into int)
}
