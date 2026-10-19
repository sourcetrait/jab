use (path self ../identity)
use (path self ../launch)
use (path self ../machine)
use (path self ../process)
use (path self ../sdl/bundle)
use (path self ../spec)
use (path self ../walk)

# The workspace's root, resolved from this file's own path
const WORKSPACE = path self ../../..

# A package's manifest, at its root
export const MANIFEST = "package.nuon"

# The words that name a run's guest inputs, each of which a packaged step takes from the package
const INPUTS = ["--image" "--kernel" "--assets" "--route"]

# A file's length in bytes and its SHA-256
def file-of [file: path]: nothing -> record<bytes: int, sha256: string> {
    { bytes: (ls -D $file | get 0.size | into int), sha256: (open --raw $file | hash sha256) }
}

# A package made from its spec: every artifact laid at its path, identical files stored once, one tar
export def make [spec: path, stage: path, out: path]: nothing -> record {
    let s = (open $spec)
    let stage = ($stage | path expand)
    let out = ($out | path expand)
    if ($stage | path exists) { error make {msg: $"($stage) exists; a package is staged once into a fresh directory"} }
    if ($out | path exists) { error make {msg: $"($out) exists; a package is written once"} }
    let root = ($stage | path join $s.name)
    mkdir $root
    let rows = ($s.artifacts | each {|a|
        let from = ($a.from | path expand)
        if not ($from | path exists) { error make {msg: $"the spec's ($a.role) ($from) is not there"} }
        let files = (if ($from | path type) == "dir" { walk paths ($from | path join "**" "*") --no-dir | sort | each {|f| { from: $f, at: ($a.at | path join ($f | path relative-to $from)) } } } else { [{ from: $from, at: $a.at }] })
        $files | each {|f|
            let dest = ($root | path join $f.at)
            if ($dest | path exists) { error make {msg: $"two artifacts lie at ($f.at)"} }
            mkdir ($dest | path dirname)
            cp $f.from $dest
            { role: $a.role, path: $f.at, meta: ($a | get -o meta) } | merge (file-of $dest)
        }
    } | flatten)
    let shared = ($rows | group-by sha256 | transpose sha256 rows | where {|g| ($g.rows | length) > 1 })
    for g in $shared {
        let kept = ($root | path join ($g.rows | first | get path))
        for r in ($g.rows | skip 1) {
            let linked = (^ln -f $kept ($root | path join $r.path) | complete)
            if $linked.exit_code != 0 { error make {msg: $"linking ($r.path) to its identical ($kept): ($linked.stderr)"} }
        }
    }
    let manifest = {
        schema: 1, name: $s.name, made: (date now | format date "%Y-%m-%dT%H:%M:%S%z"), maker: (identity reader [$WORKSPACE]),
        artifacts: $rows, identities: ($s | get -o identities | default {}),
    }
    $manifest | to nuon --indent 1 | save --raw ($root | path join $MANIFEST)
    let tarred = (do { cd $stage; ^tar -cf $out $s.name | complete })
    if $tarred.exit_code != 0 { error make {msg: $"tar of ($root) ended with ($tarred.exit_code): ($tarred.stderr | str trim)"} }
    {
        package: $out, sha256: (open --raw $out | hash sha256), root: $root, artifacts: ($rows | length),
        bytes: ($rows | get bytes | math sum), stored_once: ($shared | each {|g| { sha256: $g.sha256, paths: ($g.rows | get path) } }),
    }
}

# A package's files held to its manifest by SHA-256 and role, every problem named
export def check [dir: path]: nothing -> record<artifacts: int, problems: list<string>> {
    let root = ($dir | path expand)
    let file = ($root | path join $MANIFEST)
    if not ($file | path exists) { return { artifacts: 0, problems: [$"($root) holds no ($MANIFEST)"] } }
    let m = (open $file)
    let listed = ($m.artifacts | get path)
    let problems = ($m.artifacts | each {|a|
        let at = ($root | path join $a.path)
        if not ($at | path exists) { $"($a.role) ($a.path) is not there" } else {
            let found = (file-of $at)
            if $found.sha256 != $a.sha256 or $found.bytes != $a.bytes { $"($a.role) ($a.path) is ($found.bytes) bytes of SHA-256 ($found.sha256), where the manifest lists ($a.bytes) of ($a.sha256)" }
        }
    } | compact)
    let present = (walk paths ($root | path join "**" "*") --no-dir | each {|p| $p | path relative-to $root } | where {|p| $p != $MANIFEST })
    let foreign = ($present | where {|p| $p not-in $listed } | each {|p| $"($p) is no artifact of the manifest" })
    { artifacts: ($m.artifacts | length), problems: ($problems ++ $foreign) }
}

# A packaged artifact of a role at a path in the package, or why it is none
def artifact [root: string, m: record, rel: string, role: string]: nothing -> record<path: string, problems: list<string>> {
    let row = ($m.artifacts | where path == $rel | get -o 0)
    let path = ($root | path join $rel)
    if $row == null { return { path: $path, problems: [$"($rel) is no artifact of the package"] } }
    if $row.role != $role { return { path: $path, problems: [$"($rel) is the package's ($row.role), where the preflight takes its ($role)"] } }
    { path: $path, problems: [] }
}

# Every step of a packaged bench taking its guest inputs from the package, else each named
def rebuild-problems [root: string, bench: path]: nothing -> list<string> {
    let b = (open $bench)
    $b.steps | where {|s| not ($s | get -o gate | default false) } | each {|s|
        let words = ($s.run | each {|w| $w | str replace --all "{package}" $root })
        let route_run = ($words | window 2 | any {|pair| $pair.0 == "gauge" and $pair.1 == "run" })
        let required = (if $route_run { $INPUTS } else { $INPUTS | take 3 })
        let named = ($required | where {|flag| $flag not-in $words } | each {|flag| $"step ($s.label) names no ($flag), so its run would take the tree's" })
        let outside = ($INPUTS | each {|flag|
            let at = ($words | enumerate | where item == $flag | get -o 0.index)
            if $at == null { null } else {
                let value = ($words | get -o ($at + 1) | default "")
                if not ($value | str starts-with $root) { $"step ($s.label)'s ($flag) is ($value), outside the package" }
            }
        } | compact)
        $named ++ $outside
    } | flatten
}

# The bench's preflight: the package, the spec on this host, the launch as it will run, the capture path, no rebuild
export def preflight [dir: path, --spec: string, --image: string, --kernel: string, --tree: string, --serial: string, --bench: string, --out: string, --label: string = ""] {
    let root = ($dir | path expand)
    let out = ($out | path expand)
    mkdir $out
    let checked = (check $root)
    let m = (if ($root | path join $MANIFEST | path exists) { open ($root | path join $MANIFEST) } else { { artifacts: [] } })
    let img = (artifact $root $m $image "image")
    let krn = (artifact $root $m $kernel "kernel")
    let trd = (artifact $root $m $tree "assets")
    let bch = (artifact $root $m $bench "bench")
    let row = (try { spec row $WORKSPACE $spec } catch {|e| { problem: $e.msg } })
    let cores = (sys cpu | length)
    let memory = (sys mem | get total)
    let host_problems = (if ($row | get -o problem) != null { [$row.problem] } else {
        [
            (if $cores < $row.cores { $"this host has ($cores) cores where ($row.name) takes ($row.cores) harts" })
            (if $memory < $row.ram { $"this host has ($memory) of memory where ($row.name) takes ($row.ram)" })
        ] | compact
    })
    let running = (process jab-pids)
    let ports = (if ($running | is-empty) { [] } else { [$"a Jab QEMU runs already, pids ($running | str join ', '), whose ports and pipes a run would share"] })
    let inputs = ($checked.problems ++ $img.problems ++ $krn.problems ++ $trd.problems ++ $bch.problems)
    let disk = ($out | path join "disk.romfs")
    let made = (if not ($inputs | is-empty) { null } else { ^genromfs -d $trd.path -f $disk -V "fps" | complete })
    let disk_problems = (if $made != null and $made.exit_code != 0 { [$"genromfs over the packaged tree: ($made.stderr | str trim)"] } else { [] })
    let ready = ($inputs | is-empty) and ($disk_problems | is-empty) and (($row | get -o problem) == null)
    let planned = (if not $ready { null } else { try {
        launch plan --kernel $krn.path --image $img.path --out ($out | path join "plan") --api --disk $disk --serial $serial --window --live-sound --spec $spec --workspace $WORKSPACE
    } catch {|e| { problem: $e.msg } } })
    let launch_problems = (if $planned != null and ($planned | get -o problem) != null { [$"the launch as it will run: ($planned.problem)"] } else { [] })
    let qemu = (if $planned == null or ($planned | get -o problem) != null { null } else {
        let resolved = (which $planned.qemu_binary | where type == "external" | get -o 0.path | default $planned.qemu_binary)
        { binary: $planned.qemu_binary, file: $resolved, version: (try { ^$planned.qemu_binary --version | complete | get stdout | lines | get -o 0 } catch { null }), sha256: (if ($resolved | path exists) { open --raw $resolved | hash sha256 } else { null }) }
    })
    let linux = ($nu.os-info.name == "linux")
    let capture = (if not $linux {
        { checked: false, why: $"the sdl probe preloads its shim on Linux alone, so ($nu.os-info.name)'s capture path is its declared limits" }
    } else if not ($ready and ($launch_problems | is-empty) and ($ports | is-empty)) {
        { checked: false, why: "the launch was refused before the probe" }
    } else { try {
        let probe = ($out | path join "probe")
        let ran = (launch --kernel $krn.path --image $img.path --out $probe --api --disk $disk --serial $serial --window --live-sound --spec $spec --seconds 12 --capture 8sec --sdl-probe ($probe | path join "sdl.log") --profile generic --workspace $WORKSPACE)
        bundle $probe ($probe | path join "bundle") --profile generic | ignore
        bundle bundle-check ($probe | path join "bundle") | ignore
        { checked: true, status: $ran.status, shim: $ran.shim, shim_sha256: (if $ran.shim != "" and ($ran.shim | path exists) { open --raw $ran.shim | hash sha256 } else { null }), bundle: ($probe | path join "bundle"), why: "" }
    } catch {|e| { checked: false, problem: $e.msg, why: "the probed launch, its bundle, or its check refused" } } })
    let capture_problems = (if ($capture | get -o problem) != null { [$"the capture path: ($capture.problem)"] } else { [] })
    let rebuild = (if ($bch.problems | is-empty) { rebuild-problems $root $bch.path } else { [] })
    let refusals = ($inputs | each {|p| $"the package: ($p)" }) ++ ($host_problems | each {|p| $"the host: ($p)" }) ++ ($ports | each {|p| $"the ports: ($p)" }) ++ $disk_problems ++ $launch_problems ++ $capture_problems ++ ($rebuild | each {|p| $"no rebuild: ($p)" })
    let record = {
        package: $root, manifest_sha256: (if ($root | path join $MANIFEST | path exists) { open --raw ($root | path join $MANIFEST) | hash sha256 } else { null }), checked: $checked,
        spec: (if ($row | get -o problem) == null { $row } else { null }), machine: (if ($row | get -o problem) == null { machine resolve $WORKSPACE $spec 0 } else { null }),
        host: { os: $nu.os-info.name, cores: $cores, memory: $memory, hostname: (sys host | get -o hostname) },
        launcher: (identity reader [$WORKSPACE]),
        launch: (if $planned == null or ($planned | get -o problem) != null { null } else {
            { qemu: $qemu, timeout: { path: $planned.timeout_binary, version: $planned.timeout_version, override: $planned.timeout_override }, window: $planned.window, audio: $planned.audio, env: ($planned.env | merge { SDL_VIDEODRIVER: ($env.SDL_VIDEODRIVER? | default null), JAB_DISPLAY: ($env.JAB_DISPLAY? | default null), JAB_AUDIO: ($env.JAB_AUDIO? | default null) }), machine: $planned.machine }
        }),
        capture: $capture, rebuild: $rebuild, refusals: $refusals,
    }
    $record | to nuon --indent 1 | save --raw -f ($out | path join "preflight.nuon")
    for r in $refusals { print $"package: preflight refuses ($r)" }
    if not ($refusals | is-empty) { error make {msg: $"the preflight refuses ($refusals | length) items; no run follows"} }
    print $"package: the preflight holds: ($checked.artifacts) artifacts by SHA-256, ($row.name) on this host's ($cores) cores, QEMU ($qemu.version | default 'unversioned'), the window ($record.launch.window), (if $capture.checked { 'the capture path checked' } else { $capture.why }); ($out | path join 'preflight.nuon')"
}
