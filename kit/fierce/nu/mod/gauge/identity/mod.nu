use ../../../../../../nu/mod/build
use ../../../../../../nu/mod/walk

# The clock records' schemas this reader takes
export const SCHEMAS = [1 2 3 4 5 6 7]

# A run's selection when its identity asks no workers
const AUTOMATIC = "automatic"

# A run's selection when its identity asks a count of workers
const FORCED = "forced"

# The identity fields a correction may change: build flags, ELF SHA-256
const CORRECTABLE = ["build.flags" "build.elf_sha256"]

# An effective identity's source when it is the run's own file
export const FROM_FILE = "file"

# An effective identity's source when its report embedded it
export const FROM_EMBEDDED = "embedded"

# An effective identity's source when it is the report's one
const FROM_LEGACY = "legacy"

# An effective identity's source when there is no evidence
const FROM_NONE = "none"

# The placeholder identity of a reading from the capture alone
const ALONE = { launched: false, note: "read from the capture alone; no identity was written at its launch" }

# The strongest binding: the file's SHA-256 the run records
const BOUND_HASH = "sha256"

# A binding to the identity the run embeds, all but CORRECTABLE's fields
const BOUND_EMBEDDED = "embedded"

# The weaker binding to the report's one identity over LEGACY_FIELDS
const BOUND_LEGACY = "legacy"

# No binding: nothing in the report to bind the file to
const BOUND_NONE = "none"

# The report identity's fields a legacy binding compares
const LEGACY_FIELDS = ["build.image_sha256" "build.kernel_sha256" "assets" "route" "machine" "overrides" "mode" "cap" "toolchain" "qemu"]

# A run's identity before its launch: the build, the machine, the mode
export def new [at: record, set: string, map: string, route: oneof<string, nothing>, mode: record, machine: record, qemu: list<string>]: nothing -> record {
    let built = ($at.image | path dirname)
    let flags = (image-flags $at.image)
    let prefix = (if $flags == null { null } else { $flags | split row " " | last })
    let provenance_file = ($built | path join "provenance.nuon")
    let jab_inc = ($at.workspace | path join "sdk" "src" "jab.inc")
    let cap = (open --raw $jab_inc | decode | parse --regex '\.set JAB_DISPLAY_FPS_CAP, (?P<cap>\d+)' | get -o 0.cap)
    let tree = (build program-shard $at.game "asset" | path join $map)
    let host = (sys host)
    let cpus = (sys cpu)
    {
        launched: true,
        schemas: $SCHEMAS,
        clock: "the guest's time counter, JAB_TIME_HZ ticks a second, as microseconds; a start and a flip's end since the program's start",
        written: (date now | format date "%Y-%m-%dT%H:%M:%S%z"),
        workspace: (repo-of $at.workspace),
        program: (program-source (program-of $at.image)),
        build: {
            tree: $at.tree,
            set: $set,
            flags: $flags,
            image: $at.image,
            image_sha256: (digest $at.image),
            elf_sha256: (digest ($at.image | path parse | update extension "elf" | path join)),
            kernel: $at.kernel,
            kernel_sha256: (digest $at.kernel),
            provenance: (if ($provenance_file | path exists) { open $provenance_file } else { null }),
        },
        assets: { map: $map, tree: $tree, digest: (tree-digest $tree) },
        route: (if $route == null { null } else { { file: $route, sha256: (digest $route) } }),
        cap: (if $cap == null { null } else { $cap | into int }),
        machine: ($machine | update overrides $qemu),
        overrides: $qemu,
        qemu: null,
        host: {
            os: $nu.os-info.name,
            name: ($host | get -o name),
            os_version: ($host | get -o os_version),
            kernel_version: ($host | get -o kernel_version),
            hostname: ($host | get -o hostname),
            cpu: ($cpus | get -o 0.brand),
            cores: ($cpus | length),
            memory: (sys mem | get -o total),
        },
        toolchain: {
            prefix: $prefix,
            assembler: (if $prefix == null { null } else { try { ^$"($prefix)as" --version | complete | get stdout | lines | get -o 0 } catch { null } }),
            link: (try { ls -l ($at.workspace | path join "extern") | where {|e| ($e.name | path basename) == "riscv" } | get -o 0.target } catch { null }),
            tools: (if $prefix == null { null } else { { as: (resolved-file $"($prefix)as"), ld: (resolved-file $"($prefix)ld"), objcopy: (resolved-file $"($prefix)objcopy") } }),
        },
        mode: $mode,
    }
}

# The QEMU a launch ran: its binary, version, and resolved file's SHA-256
def qemu-of [binary: string]: nothing -> record<binary: string, version: oneof<string, nothing>, sha256: oneof<string, nothing>> {
    { binary: $binary, version: (try { ^$binary --version | complete | get stdout | lines | get -o 0 } catch { null }), sha256: (resolved-file $binary | get sha256) }
}

# The file a command resolves to and its SHA-256, both null for none
export def resolved-file [command: string]: nothing -> record<path: oneof<string, nothing>, sha256: oneof<string, nothing>> {
    let file = (if ($command | path exists) { $command | path expand } else { which $command | where type == "external" | get -o 0.path })
    { path: $file, sha256: (if $file == null { null } else { open --raw $file | hash sha256 }) }
}

# A run's identity once launched: the QEMU, machine, words, capture fields
export def launched-identity [id: record, launched: record]: nothing -> record {
    $id | upsert qemu (qemu-of $launched.qemu_binary) | upsert machine $launched.machine | upsert overrides $launched.overrides | merge ($launched | get -o capture | default {})
}

# An image's build flags, its flags file's first line, null when absent
export def image-flags [image: path]: nothing -> oneof<string, nothing> {
    let file = ($image | path expand | path dirname | path join "flags")
    if ($file | path exists) { open --raw $file | decode | lines | get -o 0 } else { null }
}

# Why an image's flags contradict the asked tree over DEBUG, null if not
export def contradiction [flags: oneof<string, nothing>, tree: string]: nothing -> oneof<string, nothing> {
    if $flags == null { return null }
    let debug = ($flags =~ '--defsym DEBUG=')
    if $tree == "release" and $debug { return $"the image's build flags define DEBUG where the run asks the release tree: ($flags)" }
    if $tree == "debug" and (not $debug) { return $"the image's build flags lack DEBUG where the run asks the debug tree: ($flags)" }
    null
}

# An identity file read with its sidecar correction checked and applied
export def corrected [file: path]: nothing -> record<identity: record, corrections: any> {
    let raw = (open --raw $file | into binary)
    let id = ($raw | decode utf-8 | from nuon)
    let sidecar = ($file | path expand | path dirname | path join "identity_correction.nuon")
    if not ($sidecar | path exists) { return { identity: $id, corrections: null } }
    let side_raw = (open --raw $sidecar | into binary)
    let c = ($side_raw | decode utf-8 | from nuon)
    let file_sha = ($raw | hash sha256)
    let image = ($id | get -o build.image_sha256)
    if ($c | get -o identity_sha256) != $file_sha {
        error make { msg: $"($sidecar) corrects an identity of SHA-256 ($c | get -o identity_sha256), where ($file) has ($file_sha)" }
    }
    if ($c | get -o image_sha256) != $image {
        error make { msg: $"($sidecar) corrects a run of the image ($c | get -o image_sha256), where ($file) records ($image)" }
    }
    let fields = ($c | get -o fields | default {})
    let named = ($fields | columns)
    if ($named | is-empty) { error make { msg: $"($sidecar) names no field to correct" } }
    let foreign = ($named | where {|f| $f not-in $CORRECTABLE })
    if not ($foreign | is-empty) {
        error make { msg: $"($sidecar) names ($foreign | str join ', '), where a correction holds ($CORRECTABLE | str join ' and ') alone" }
    }
    mut changes = []
    for f in $named {
        let entry = ($fields | get $f)
        if not ("old" in ($entry | columns) and "new" in ($entry | columns)) {
            error make { msg: $"($sidecar)'s ($f) holds no old and new value" }
        }
        let path = ($f | split row "." | into cell-path)
        let current = ($id | get -o $path)
        if $current != $entry.old {
            error make { msg: $"($sidecar) holds ($f) as ($entry.old | to nuon), where ($file) holds ($current | to nuon)" }
        }
        $changes = ($changes | append { field: $f, path: $path, old: $entry.old, new: $entry.new })
    }
    let corrected = ($changes | reduce --fold $id {|ch, acc| $acc | upsert $ch.path $ch.new })
    {
        identity: $corrected,
        corrections: {
            sidecar: $sidecar,
            sidecar_sha256: ($side_raw | hash sha256),
            fields: ($changes | each {|ch| { field: $ch.field, old: $ch.old, new: $ch.new } }),
            evidence: ($c | get -o evidence),
        },
    }
}

# A run's identity saved as identity.nuon in `dir`, and the file's SHA-256
export def write [id: record, dir: path]: nothing -> string {
    let file = ($dir | path join "identity.nuon")
    $id | to nuon --indent 2 | save --raw -f $file
    open --raw $file | into binary | hash sha256
}

# The directories a report's run may keep its identity in, in try order
export def dirs [report: path, run: record]: nothing -> list<string> {
    let here = ($report | path expand | path dirname)
    let out = ($run | get -o out | default "")
    if $out == "" { return [] }
    let name = ($out | path basename)
    let adjacent = (if $name == ($here | path basename) { $here } else { $here | path join $name })
    [$adjacent ($out | path expand)] | uniq
}

# Whether a value holds a dotted field key by key, a null value counting
def holds-field [r: any, name: string]: nothing -> bool {
    mut at = $r
    for key in ($name | split row ".") {
        if not (($at | describe | str starts-with "record") and ($key in ($at | columns))) { return false }
        $at = ($at | get $key)
    }
    true
}

# The leaf fields where two values differ, each named dotted with both
def differing [a: any, b: any, at: string]: nothing -> list<any> {
    let both = (($a | describe | str starts-with "record") and ($b | describe | str starts-with "record"))
    if not $both { return (if $a == $b { [] } else { [{ field: $at, a: $a, b: $b }] }) }
    mut found = []
    for key in ($a | columns | append ($b | columns) | uniq) {
        let name = (if $at == "" { $key } else { $"($at).($key)" })
        $found = ($found | append (differing ($a | get -o $key) ($b | get -o $key) $name))
    }
    $found
}

# A record without its seed, anything else unchanged
def less-seed [mode: any]: nothing -> any {
    if ($mode | describe | str starts-with "record") { $mode | reject -o seed } else { $mode }
}

# Where a file's identity differs from a report's one over LEGACY_FIELDS
def legacy-differences [found: any, batch: any, seed: any]: nothing -> record<differ: list<any>, unrecorded: list<string>> {
    mut differ = []
    mut unrecorded = []
    for name in $LEGACY_FIELDS {
        if not (holds-field $batch $name) { $unrecorded = ($unrecorded | append $name); continue }
        let path = ($name | split row "." | into cell-path)
        let a = ($found | get -o $path)
        let b = ($batch | get -o $path)
        $differ = ($differ | append (if $name == "mode" { differing (less-seed $a) (less-seed $b) $name } else { differing $a $b $name }))
    }
    if $seed == null {
        $unrecorded = ($unrecorded | append "mode.seed")
    } else if ($found | get -o mode.seed) != $seed {
        $differ = ($differ | append { field: "mode.seed", a: ($found | get -o mode.seed), b: $seed })
    }
    { differ: $differ, unrecorded: $unrecorded }
}

# Whether an identity is no evidence of its run: absent, or launched false
def no-evidence [id: any]: nothing -> bool {
    if $id == null { return true }
    ($id | describe | str starts-with "record") and (($id | get -o launched) == false)
}

# An identity as evidence of its run, null where it is none
def evidence-of [id: any]: nothing -> any {
    if (no-evidence $id) { null } else { $id }
}

# An identity without CORRECTABLE's two fields
def less-correctable [id: any]: nothing -> any {
    if not ($id | describe | str starts-with "record") { return $id }
    $id | reject -o ...($CORRECTABLE | each {|f| $f | split row "." | into cell-path })
}

# How a found identity file binds to a report's run: strength and reasons
def binding-of [found: any, error: any, sha: string, run: record, legacy: any]: nothing -> record<strength: string, bound: bool, reasons: list<string>, unrecorded: list<string>> {
    let recorded = ($run | get -o identity_sha256)
    let embedded = (evidence-of $run.identity?)
    let batch = (evidence-of $legacy)
    let strength = (if $recorded != null { $BOUND_HASH } else if $embedded != null { $BOUND_EMBEDDED } else if $batch != null { $BOUND_LEGACY } else { $BOUND_NONE })
    if $strength == $BOUND_HASH {
        let bound = ($sha == $recorded)
        return { strength: $strength, bound: $bound, reasons: (if $bound { [] } else { [$"its SHA-256 ($sha) is not the run's recorded ($recorded)"] }), unrecorded: [] }
    }
    if $found == null { return { strength: $strength, bound: false, reasons: [$"it does not parse: ($error)"], unrecorded: [] } }
    if $strength == $BOUND_NONE { return { strength: $strength, bound: true, reasons: [], unrecorded: [] } }
    let compared = (if $strength == $BOUND_EMBEDDED {
        { differ: (differing (less-correctable $found) (less-correctable $embedded) ""), unrecorded: [] }
    } else {
        legacy-differences $found $batch ($run | get -o seed)
    })
    let reasons = ($compared.differ | each {|d|
        let holder = (if $strength == $BOUND_EMBEDDED { "the run's embedded identity's" } else if $d.field == "mode.seed" { "the run's recorded" } else { "the report's identity's" })
        $"its ($d.field) ($d.a | to nuon), ($holder) ($d.b | to nuon)"
    })
    { strength: $strength, bound: ($reasons | is-empty), reasons: $reasons, unrecorded: $compared.unrecorded }
}

# A run's effective identity and its source: file, embedded, report, or none
export def of [report: path, run: record, legacy: any]: nothing -> record<identity: any, from: string, file: any, corrections: any, identity_sha256: any, binding: any, passed: list<any>, seed: any> {
    let seed = ($run | get -o seed)
    mut passed = []
    for dir in (dirs $report $run) {
        let file = ($dir | path join "identity.nuon")
        if not ($file | path exists) { continue }
        let raw = (open --raw $file | into binary)
        let sha = ($raw | hash sha256)
        let parsed = (try { { found: ($raw | decode utf-8 | from nuon), error: null } } catch {|e| { found: null, error: $e.msg } })
        let b = (binding-of $parsed.found $parsed.error $sha $run $legacy)
        if not $b.bound {
            $passed = ($passed | append { dir: $dir, strength: $b.strength, reasons: $b.reasons })
            continue
        }
        if $parsed.found == null { error make { msg: $"($file) binds to its run by its SHA-256 but does not parse: ($parsed.error)" } }
        let read = (corrected $file)
        return { identity: $read.identity, from: $FROM_FILE, file: $file, corrections: $read.corrections, identity_sha256: $sha, binding: { strength: $b.strength, unrecorded: $b.unrecorded }, passed: $passed, seed: $seed }
    }
    let embedded = (evidence-of ($run | get -o identity))
    if $embedded != null {
        return { identity: $embedded, from: $FROM_EMBEDDED, file: null, corrections: ($run | get -o corrections), identity_sha256: ($run | get -o identity_sha256), binding: null, passed: $passed, seed: $seed }
    }
    let from = (if (no-evidence $legacy) { $FROM_NONE } else { $FROM_LEGACY })
    { identity: (if $from == $FROM_NONE { $ALONE } else { $legacy }), from: $from, file: null, corrections: null, identity_sha256: null, binding: null, passed: $passed, seed: $seed }
}

# A report's run as its own identity asks it: selection, cadence, workers
export def request [report: path, run: record, legacy: any]: nothing -> record {
    let effective = (of $report $run $legacy)
    let id = $effective.identity
    let workers = ($id | get -o mode.workers)
    $effective | merge {
        selection: (if $workers == null { $AUTOMATIC } else { $FORCED }),
        cadence: ($id | get -o mode.cadence),
        workers: $workers,
        grain: ($id | get -o mode.grain),
        machine: ($id | get -o machine),
        kernel: ($id | get -o build.kernel_sha256),
        qemu: ($id | get -o qemu.version),
        pad: ($id | get -o mode.pad),
        cap: ($id | get -o cap),
        probed: (($id | get -o shim | default "") != ""),
    }
}

# The identity a capture's directory was launched under, reports reconciled
export def read [dir: path]: nothing -> record {
    let here = ($dir | path expand)
    let reports = ([($here | path join "gauge.nuon") ($here | path dirname | path join "gauge.nuon")] | uniq | where {|f| $f | path exists })
    mut belonging = []
    for f in $reports {
        let g = (open $f)
        let runs = ($g | get -o runs | default [] | where {|r| $here in (dirs $f $r) })
        if ($runs | length) > 1 { error make { msg: $"($f) holds ($runs | length) runs in ($here), runs ($runs | get run | str join ', ')" } }
        if not ($runs | is-empty) { $belonging = ($belonging | append (of $f ($runs | first) ($g | get -o identity) | insert report $f)) }
    }
    if ($belonging | length) == 2 { return (reconcile ($belonging | get 0) ($belonging | get 1) $here) }
    if ($belonging | length) == 1 { return ($belonging | first | reject report | insert reports [($belonging | first | get report)]) }
    let id_file = ($here | path join "identity.nuon")
    if ($id_file | path exists) {
        let read = (corrected $id_file)
        let sha = (open --raw $id_file | into binary | hash sha256)
        return { identity: $read.identity, from: $FROM_FILE, file: $id_file, corrections: $read.corrections, identity_sha256: $sha, binding: { strength: $BOUND_NONE, unrecorded: [] }, passed: [], seed: null, reports: [] }
    }
    { identity: $ALONE, from: $FROM_NONE, file: null, corrections: null, identity_sha256: null, binding: null, passed: [], seed: null, reports: [] }
}

# A correction's substance two reports must share, its sidecar's path aside
def correction-key [c: any]: nothing -> any {
    if $c == null { return null }
    { fields: ($c | get -o fields | default [] | sort-by field), sidecar_sha256: ($c | get -o sidecar_sha256), evidence: ($c | get -o evidence) }
}

# Where two readings of one run differ over legacy and correctable fields
def shared-differences [a: record, b: record]: nothing -> list<any> {
    mut differ = []
    for name in ($LEGACY_FIELDS | append $CORRECTABLE) {
        if not ((holds-field $a.identity $name) and (holds-field $b.identity $name)) { continue }
        let path = ($name | split row "." | into cell-path)
        let x = ($a.identity | get -o $path)
        let y = ($b.identity | get -o $path)
        $differ = ($differ | append (if $name == "mode" { differing (less-seed $x) (less-seed $y) $name } else { differing $x $y $name }))
    }
    let sa = (if $a.from == $FROM_LEGACY { $a.seed } else { $a.identity | get -o mode.seed })
    let sb = (if $b.from == $FROM_LEGACY { $b.seed } else { $b.identity | get -o mode.seed })
    if $sa != null and $sb != null and $sa != $sb { $differ = ($differ | append { field: "mode.seed", a: $sa, b: $sb }) }
    $differ
}

# Whether a reading's corrections changed a field from the other's value
def explains [c: any, field: string, from: any, to: any]: nothing -> bool {
    if $c == null { return false }
    $c | get -o fields | default [] | any {|x| $x.field == $field and $x.old == $from and $x.new == $to }
}

# The reading reconcile keeps, with the hash, both passes, and both reports
def kept-of [kept: record, a: record, b: record]: nothing -> record {
    $kept | reject report | update identity_sha256 ([$a.identity_sha256 $b.identity_sha256] | compact | get -o 0) | update passed ($a.passed | append $b.passed) | insert reports [$a.report $b.report]
}

# Two reports' readings of one capture's run made one, else refused
def reconcile [a: record, b: record, here: string]: nothing -> record {
    let a_none = ($a.from == $FROM_NONE)
    let b_none = ($b.from == $FROM_NONE)
    if $a_none or $b_none {
        let kept = (if $a_none and (not $b_none) { $b } else if $b_none and (not $a_none) { $a } else if ($a.report | path dirname) == $here { $a } else { $b })
        return (kept-of $kept $a $b)
    }
    let named = $"($a.report) and ($b.report) read the run in ($here) differently"
    if $a.identity_sha256 != null and $b.identity_sha256 != null and $a.identity_sha256 != $b.identity_sha256 {
        error make { msg: $"($named): an identity of SHA-256 ($a.identity_sha256) against ($b.identity_sha256)" }
    }
    let ka = (correction-key $a.corrections)
    let kb = (correction-key $b.corrections)
    if $ka != null and $kb != null and $ka != $kb {
        error make { msg: $"($named): two corrections, ($ka | to nuon) against ($kb | to nuon)" }
    }
    let legacy = ($a.from == $FROM_LEGACY or $b.from == $FROM_LEGACY)
    let differ = (if $legacy { shared-differences $a $b } else { differing $a.identity $b.identity "" })
    mut unexplained = []
    mut by = ""
    for d in $differ {
        if (explains $a.corrections $d.field $d.b $d.a) { $by = "a" } else if (explains $b.corrections $d.field $d.a $d.b) { $by = "b" } else { $unexplained = ($unexplained | append $d) }
    }
    if not ($unexplained | is-empty) {
        let fields = ($unexplained | each {|d| $"($d.field): ($d.a | to nuon) against ($d.b | to nuon)" })
        error make { msg: ([$"($named), each field unexplained by a correction:"] | append $fields | str join "\n  ") }
    }
    let rank = {|s: record| [$FROM_FILE $FROM_EMBEDDED $FROM_LEGACY] | enumerate | where item == $s.from | get -o 0.index | default 3 }
    let kept = (if $by == "a" { $a } else if $by == "b" { $b } else if $ka != null and $kb == null { $a } else if $kb != null and $ka == null { $b } else if (do $rank $a) < (do $rank $b) { $a } else if (do $rank $b) < (do $rank $a) { $b } else if ($a.report | path dirname) == $here { $a } else { $b })
    kept-of $kept $a $b
}

# The workspace's commit and whether its tree held changes
def repo-of [workspace: path]: nothing -> record<dir: string, commit: string, dirty: bool> {
    let commit = (^git -C $workspace rev-parse --short HEAD | complete | get stdout | str trim)
    let status = (^git -C $workspace status --porcelain | complete | get stdout | str trim)
    { dir: $workspace, commit: $commit, dirty: ($status != "") }
}

# A path under the old game/fps read at kit/fierce where the old is gone
export def moved [file: string]: nothing -> string {
    if $file == "" or ($file | path exists) { return $file }
    let parts = ($file | path split)
    let at = ($parts | window 2 | enumerate | where {|w| $w.item == ["game" "fps"] } | get -o 0.index)
    if $at == null { return $file }
    $parts | first $at | append ["kit" "fierce"] | append ($parts | skip ($at + 2)) | path join
}

# The program directory an image was built from, by its home file or .target
def program-of [image: path]: nothing -> string {
    let marker = ($image | path expand | path dirname | path join "home")
    if ($marker | path exists) { return (moved (open --raw $marker | decode | str trim)) }
    let parts = ($image | path expand | path split)
    let marks = ($parts | enumerate | where {|e| $e.item == ".target" } | get index)
    if ($marks | is-empty) { $image | path expand | path dirname } else { $parts | first ($marks | last) | path join }
}

# The program's source revision: source.nuon's, else git's, else unknown
def program-source [dir: string]: nothing -> record<dir: string, commit: oneof<string, nothing>, dirty: oneof<bool, nothing>, from: oneof<string, nothing>> {
    let marker = ($dir | path join "source.nuon")
    if ($marker | path exists) { return { dir: $dir, commit: (open $marker | get -o commit), dirty: null, from: "source.nuon" } }
    let owned = (do { cd $dir; ^git ls-files --error-unmatch program.jab.toml src/main.S | complete })
    if $owned.exit_code != 0 { return { dir: $dir, commit: null, dirty: null, from: null } }
    let commit = (^git -C $dir rev-parse --short HEAD | complete | get stdout | str trim)
    let status = (do { cd $dir; ^git status --porcelain -- . | complete | get stdout | str trim })
    { dir: $dir, commit: $commit, dirty: ($status != ""), from: "git" }
}

# A file's SHA-256, null when it is absent
def digest [file: path]: nothing -> oneof<string, nothing> {
    if ($file | path exists) { open --raw $file | into binary | hash sha256 } else { null }
}

# A tree's digest: each file's path and SHA-256 a line in order, hashed
export def tree-digest [tree: path]: nothing -> oneof<string, nothing> {
    if not ($tree | path exists) { return null }
    walk paths ($tree | path join "**" "*") | where {|f| ($f | path type) == "file" } | sort | each {|f| $"($f | path relative-to $tree) (open --raw $f | into binary | hash sha256)" } | str join (char nl) | hash sha256
}
