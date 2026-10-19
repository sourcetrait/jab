use ../../identity
use ../../nonce
use ../classify
use ../log
use ../symbols
use ../../walk

# A probed run's capture bundled with its tables and manifest, on its host
export def main [probe: path, bundle: path, --profile: string = "", --extra: list<string> = []] {
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
    let events = ($c.events | each {|e| { line: ($e.at + 1), stamp: $e.stamp, name: $e.name, render: $e.render, key: $e.key, kind: $e.kind, callers: $e.callers } })
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
        reader: (sdl-reader),
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
        let got = { kind: $pair.0.kind, callers: $pair.0.callers }
        let want = { kind: $pair.1.kind, callers: $pair.1.callers }
        if $got != $want { do $refuse 4 "the replay" $"the event at line ($pair.1.line) replays as ($got | to nuon), where classified.nuon holds ($want | to nuon)" }
    }
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
        let flushes = (open --raw ($dir | path join "trace.log") | into binary | decode | lines
            | parse --regex '^(?P<at>\S+) virtio_gpu_cmd_res_flush\b'
            | each {|c| ($c.at | into datetime | into int) / 1e9 })
        let uploads = ($replay.events | where kind == "upload" | get ts)
        if ($flushes | length) != ($uploads | length) { do $refuse 5 "the run" $"the trace holds ($flushes | length) flushes and the log ($uploads | length) flip uploads" }
        let lags = ($flushes | zip $uploads | each {|p| ($p.1 - $p.0) * 1000.0 })
        let off = ($lags | enumerate | where {|l| $l.item < 0.0 or $l.item >= 5.0 })
        if not ($off | is-empty) { do $refuse 5 "the run" $"flip upload ($off | first | get index | $in + 1) lies ($off | first | get item | math round -p 3) ms after its flush, outside the 5 ms after it" }
        { flushes: ($flushes | length), uploads: ($uploads | length), max_lag_ms: (if ($lags | is-empty) { null } else { $lags | math max | math round -p 3 }) }
    })
    let host = ($m | get -o reader)
    let box = (sdl-reader)
    let commit_of = {|r| if ($r | describe | str starts-with 'record') { if ($r | get -o repos) != null { $r.repos | get -o 0.commit } else { $r | get -o jab } } }
    let hosted = (do $commit_of $host)
    { profile: $profile, run: $run, reader: { host: $host, box: $box, same: ($hosted != null and $hosted == (do $commit_of $box)) }, trace: $trace, events: $cls.events }
}
