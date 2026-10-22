use (path self ../../../../../../nu/mod/build)
use (path self ../../../../../../nu/mod/target)
use (path self ../identity)
use (path self ../report)
use (path self ../stream)
use (path self ../measure/summary)
use (path self ../identity) [FROM_FILE]
use (path self ../measure/presentation) [CADENCES CADENCE_AFTER_FLIP]
use (path self ../stream) [UNKNOWN_PARTS]

# The workspace's root, resolved from this file's own path
const WORKSPACE = path self ../../../../../..

# The harts of the one machine before named specs, 1KA1's
const HARTS = 3

# The drawing's phase fields whose meaning moved with the packets
const PHASE_FIELDS = [planes_us walls_us sprites_us]

# The drawing's remainder field, whose meaning moved with the packets
const REMAINDER_FIELDS = [parts_unattributed_us]

# The fields whose meaning moved with the tile pool at schema 5
const TILE_FIELDS = [planes_us walls_us tiles_us tiles_built tile_bytes tile_peak]

# The standings a comparison refuses unless admitted as a diagnostic
const REFUSED = [incomplete invalid unchecked unpaired diagnostic]

# The standings a comparison refuses even as a diagnostic
const REJECTED = [empty unclassified unusable unrouted]

# A run's workers and grain where its records below schema 4 cannot show them
const UNKNOWN_WORKERS = "unknown"

# Builds' captures set side by side by leg, every run classified first
export def main [files: list<string>, field: string, bin_cm: int, --diagnostic]: nothing -> record {
    let classified = ($files | each {|f|
        let file = ($f | path expand)
        let g = (open $file)
        let build = ($g.label | str replace --regex '_\d+$' '')
        let all_rows = ($g.rows? | default [])
        $g.runs | each {|r|
            let effective = (identity request $file $r ($g | get -o identity))
            let id = $effective.identity
            let image = ($id | get -o build.image_sha256 | default "")
            let requested = $effective.cadence
            let asked = { workers: $effective.workers, grain: $effective.grain }
            let machine = $effective.machine
            let overrides = ($id | get -o overrides)
            let measured = ($r.measured? | default null)
            let rows = ($all_rows | where run == $r.run)
            let held = (if ($rows | is-empty) { [] } else { $rows | get leg | uniq })
            let route = (report route-of $file $r $effective)
            let stray = (if $route.legs == null { [] } else { $held | where {|leg| $leg not-in $route.legs } })
            let unrouted = (if $route.problem != null {
                [$route.problem]
            } else if not ($stray | is-empty) {
                [$"its rows hold legs its route ($route.file) does not name: ($stray | str join ', ')"]
            } else { [] })
            let classed = (standing-of $measured $rows $field $requested $asked $machine $overrides)
            let standing = (if ($classed.standing in $REJECTED) or ($unrouted | is-empty) { $classed } else { { standing: "unrouted", reasons: $unrouted } })
            let schema = ($measured | get -o schema | default 1)
            let played = (effective-workers $measured $asked)
            {
                file: $file, label: $g.label, build: $build, image: $image, kernel: $effective.kernel, machine: $machine,
                requested_cadence: $requested, effective_cadence: (effective-cadence $measured $requested), run: $r.run,
                selection: $effective.selection, requested_workers: $asked.workers, requested_grain: $asked.grain,
                effective_workers: $played.workers, effective_grain: $played.grain,
                flags: ($id | get -o build.flags), elf_sha256: ($id | get -o build.elf_sha256),
                identity_from: $effective.from, identity_file: $effective.file, corrections: $effective.corrections,
                identity_sha256: $effective.identity_sha256, binding: $effective.binding, passed: $effective.passed,
                schema: $schema, parts: (stream parts-meaning $schema (if $image == "" { null } else { $image })),
                route: (if $route.sha256 == null { null } else { { file: $route.file, sha256: $route.sha256 } }),
                route_legs: $route.legs,
                standing: $standing.standing, reasons: $standing.reasons, rows: $rows, held: $held,
                probed: ($effective | get -o probed | default false),
            }
        }
    } | flatten)
    let route_key = {|r| $r.route | get -o sha256 }
    let routes = ($classified | each --keep-empty {|r| do $route_key $r } | uniq | each {|k|
        let these = ($classified | where {|r| (do $route_key $r) == $k })
        let named = ($these | get route_legs | compact)
        let legs = (if $k == null or ($named | is-empty) { $these | get held | flatten | uniq } else { $named | first })
        { sha256: $k, file: ($these | get route | compact | get -o 0.file), legs: $legs }
    })
    let covered = ($classified | each {|r|
        let expected = ($routes | where {|t| $t.sha256 == (do $route_key $r) } | first | get legs)
        $r | insert expected $expected | insert missing ($expected | where {|leg| $leg not-in $r.held })
    })
    let stopped = ($covered | each {|r|
        let standing = (if ($r.standing in $REJECTED) or ((not $diagnostic) and ($r.standing in $REFUSED)) {
            $"($r.file) run ($r.run), ($r.standing): ($r.reasons | str join '; ')"
        } else { null })
        let partial = (if $diagnostic or ($r.missing | is-empty) or ($r.standing in $REJECTED) { null } else {
            $"($r.file) run ($r.run), partial: missing the legs ($r.missing | str join ', ')"
        })
        if $standing == null and $partial == null { null } else { { causes: ([$standing $partial] | compact) } }
    } | compact)
    if not ($stopped | is-empty) {
        let head = ([
            $"the comparison refuses ($stopped | length) runs: an empty, unclassified, unusable, or unrouted run always,"
            "an incomplete, invalid, unchecked, unpaired, or diagnostic one, or one missing a leg another run"
            "holds, unless --diagnostic admits it, marked"
        ] | str join " ")
        let named = ($stopped | get causes | flatten)
        error make { msg: ([$head] | append $named | str join "\n  ") }
    }
    let machines = ($covered | get machine | uniq)
    if ($machines | length) > 1 and (not $diagnostic) {
        let head = $"the runs ran on ($machines | length) machines, a comparison's runs on one unless --diagnostic admits them"
        error make { msg: ([$head] | append ($machines | each {|m| report machine-text $m }) | str join "\n  ") }
    }
    if ($routes | length) > 1 and (not $diagnostic) {
        let head = $"the runs played ($routes | length) routes, a comparison's runs on one unless --diagnostic admits them"
        error make { msg: ([$head] | append ($routes | each {|t| report route-text $t }) | str join "\n  ") }
    }
    let moved = ([
        (if $field in $PHASE_FIELDS { "phases" } else { null })
        (if $field in $REMAINDER_FIELDS { "remainder" } else { null })
        (if $field in $TILE_FIELDS { "tiles" } else { null })
    ] | compact)
    for class in $moved {
        let classes = ($covered | each {|r| $r.parts | get $class } | uniq)
        if ($classes | length) > 1 or ($UNKNOWN_PARTS in $classes) {
            let head = ([
                $"the comparison on ($field) refuses runs whose ($class) measure different things or unknown ones,"
                "--diagnostic or not: a schema 2 run's parts are known by a listed image alone, and the tiles"
                "moved to the pool's boundary at schema 5"
            ] | str join " ")
            let named = ($covered | each {|r| $"($r.file) run ($r.run), schema ($r.schema | default 'none'), image ($r.image): ($r.parts | get $class), by ($r.parts.evidence)" })
            error make { msg: ([$head] | append $named | str join "\n  ") }
        }
    }
    let runs = ($covered | each {|r|
        let legs = ($r.held | each {|leg|
            leg-measure ($r.rows | where leg == $leg) $leg $field $bin_cm
        })
        let absent = ($r.missing | each {|leg| { leg: $leg, kind: "missing", frames: 0, path_m: null, median: null, bins: [] } })
        $r | reject rows held route_legs | insert legs ($legs | append $absent)
    })
    let builds = ($runs | get build | uniq)
    let made_of = {|r| { image: $r.image, kernel: $r.kernel, cadence: $r.effective_cadence, machine: $r.machine, workers: $r.effective_workers, grain: $r.effective_grain, route: (do $route_key $r), selection: $r.selection, probed: ($r | get -o probed | default false) } }
    for b in $builds {
        let made = ($runs | where build == $b | each {|r| do $made_of $r } | uniq)
        if ($made | length) > 1 { error make { msg: $"the captures labelled ($b) come from ($made | length) builds, an image on a kernel at a cadence by its workers on a machine and a route under a selection, probed or not, each: ($made | to nuon); a build's batches are one build" } }
    }
    for made in ($runs | each {|r| do $made_of $r } | uniq) {
        let names = ($runs | where {|r| (do $made_of $r) == $made } | get build | uniq)
        if ($names | length) > 1 { error make { msg: $"one build, ($made | to nuon), is labelled ($names | str join ' and '); a build has one name" } }
    }
    for b in $builds {
        let built = ($runs | where build == $b | each {|r| { flags: $r.flags, elf_sha256: $r.elf_sha256 } } | uniq)
        if ($built | length) > 1 {
            let named = ($runs | where build == $b | each {|r| $"($r.file) run ($r.run), its identity from ($r.identity_from): flags ($r.flags | to nuon), ELF ($r.elf_sha256 | to nuon)" })
            error make { msg: ([$"the runs of ($b) differ in build.flags or build.elf_sha256, its identities' record of one build"] | append $named | str join "\n  ") }
        }
    }
    let common = ($routes | each {|t|
        let these = ($runs | where {|r| (do $route_key $r) == $t.sha256 })
        $t.legs | each {|leg|
            let measured = ($these | each {|r| $r.legs | where {|l| $l.leg == $leg and $l.kind != "missing" } | get -o 0 } | compact)
            if ($measured | is-empty) {
                { route: $t.sha256, leg: $leg, kind: "missing", runs: 0, missing: ($these | length), bins: [] }
            } else {
                let kinds = ($measured | get kind | uniq)
                if ($kinds | length) > 1 { error make { msg: $"the leg ($leg) is walked in some runs and stands in others" } }
                let bins = (if ($kinds | first) == "path" {
                    let sets = ($measured | each {|m| $m.bins | get bin })
                    $sets | reduce --fold ($sets | first) {|s, acc| $acc | where {|x| $x in $s } }
                } else { [] })
                { route: $t.sha256, leg: $leg, kind: ($kinds | first), runs: ($measured | length), missing: (($these | length) - ($measured | length)), bins: $bins }
            }
        }
    } | flatten)
    let valued = ($runs | each {|r|
        let rk = (do $route_key $r)
        $r | merge { legs: ($r.legs | each {|l|
            let c = ($common | where {|x| $x.route == $rk and $x.leg == $l.leg } | first)
            let picked = ($l.bins | where {|b| $b.bin in $c.bins })
            let value = (if $l.kind == "missing" { null } else if $l.kind == "frames" { $l.median } else if ($picked | is-empty) { null } else { $picked | get median | math avg })
            $l | insert value $value
        }) }
    })
    let table = ($builds | each {|b|
        let batches = ($valued | where build == $b)
        let rk = (do $route_key ($batches | first))
        $batches | first | get expected | each {|leg|
            let entries = ($batches | each {|r| $r.legs | where leg == $leg | get 0 })
            let missing = ($entries | where {|l| $l.kind == "missing" } | length)
            let values = ($entries | get value | compact)
            let whole = ($missing == 0 and (not ($values | is-empty)))
            {
                build: $b, leg: $leg, route: $rk, selection: ($batches | get 0.selection), machine: ($batches | get 0.machine),
                probed: ($batches | get 0.probed),
                value_us: (if $whole { $values | math avg } else { null }),
                half_spread_us: (if $whole { (($values | math max) - ($values | math min)) / 2 } else { null }),
                batches: ($batches | length), missing: $missing, standings: ($batches | get standing | uniq),
            }
        }
    } | flatten)
    {
        method: {
            field: $field,
            bin_cm: $bin_cm,
            path: "the eye's travel over the floor, x and y, summed from the leg's first frame",
            walked: "a leg whose path reaches one bin is taken per bin; a shorter one, standing, over its frames",
            bin_value: "a bin's value is the median of its frames' values by nearest rank",
            leg_value: "a walked leg's value is the mean of its bin values over the bins every run in the comparison reached; a standing leg's is its frames' median by nearest rank",
            stationary_tail: "no frame is cut: frames standing at a walked leg's end fall in its last bin and count as that one bin",
            grouping: ([
                "a build is an image's SHA-256 on its kernel's, none for an identity recording no kernel, at the"
                "cadence its runs played by the workers at the grain they played on the machine their identities"
                "record: the cadence the one asked from schema 2, and 0"
                "below it, where a request other than 0 leaves the run unpaired; the workers and grain its frames"
                "were drawn by from schema 4; below it the serial backend, 0 at grain 0, for a run with a W 0"
                "answered before its first frame and no W after it, and unknown for any other, which leaves the run"
                "unpaired and under --diagnostic a build of its own, never one with a known configuration, workers"
                "asked above 0 leaving it unpaired too; under its selection, automatic when its identity asks no"
                "workers and forced when it asks a count, so an automatic run and a forced one are two builds"
                "whatever they played; observed by the sdl shim or not, its identity naming the shim, so a probed"
                "run and a plain one are two builds too; a capture's label less a trailing _<n> names it, one name"
                "a build and one"
                "build a name, and its runs are its batches, whose identities hold one build's flags and ELF; each"
                "run keeps its selection and the cadence, workers, and grain asked beside those played, all read"
                "from its own identity (run-request), never the report's summary unless that is its identity"
            ] | str join " "),
            identities: ([
                "each run's identity is its own file, its directory found beside its report before the path the"
                "report recorded, when the file binds to the run: by the SHA-256 the run records, else equal to the"
                "identity the run embeds on every field but build.flags and build.elf_sha256, else, weaker, equal"
                "to the report's one identity on the image, kernel, assets, route, machine, overrides, mode less"
                "its seed, cap, toolchain, and QEMU, with the run's own seed, a field it lacks named unrecorded;"
                "a directory whose file does not bind is passed over and named; the bound file with an audited"
                "correction beside it applied to build.flags and build.elf_sha256 alone; else the identity its"
                "report embedded; else the report's one identity; each run names its source, its binding, the"
                "directories passed over, and its corrections, and a bound file that does not parse or whose"
                "correction fails its checks stops the comparison"
            ] | str join " "),
            machine: ([
                "a run's machine is the one its identity records, a named spec's, its name, cores, RAM, and display,"
                "or a custom machine's, its harts and RAM, with -machine, the CPU, and the accelerator, a legacy"
                "record from before named specs its harts and whether it is diagnostic, or none for a capture older"
                "than the record; a run on a custom machine, on one its legacy record marks diagnostic, or with QEMU"
                "words of its launch's own stands diagnostic, runs on more than one machine, a named spec's and a"
                "legacy record's among them, are refused unless --diagnostic admits them, and each table row names"
                "its build's machine"
            ] | str join " "),
            table: ([
                "a build's value for a leg is the mean of its runs' values and the half spread is half their range,"
                "both null when a batch is missing the leg or no bin was reached by every run; a row a build and leg"
            ] | str join " "),
            standing: ([
                "a run stands as its measurement and its own rows record it, classified before any leg is measured:"
                "unclassified, its measurement recording no clocked; empty, no rows; unusable, a value of the field"
                "that is not a number or a leg holding no number in it; those three refused even under --diagnostic;"
                "incomplete, invalid, or unchecked (complete but measured before validity was recorded); unpaired, a"
                "build older than the clock records, read from its states alone, whose console answers a seed it"
                "never takes, or a run not seeded before its first frame or seeded again after it, or below schema"
                "2 one whose identity asks a cadence other than 0, which such a capture cannot play, or from schema 2"
                "one whose cadence was not asked before its first frame or was asked again after it, whose identity"
                "asks no cadence from 0 to 2, or with a frame at another cadence, or below schema 4 one whose identity"
                "asks workers above 0 or whose workers are unknown, no W 0 answered before its first frame or a W"
                "after it, or from schema 4 one asking workers not asked before its first frame or"
                "asked again after it or with a frame drawn by other workers or at another grain, or asking none"
                "with workers asked after its first frame or frames at more than one count of workers or grain;"
                "diagnostic, a run on a custom machine, on one its legacy record marks diagnostic, any count of harts"
                "but the specification's three, or whose identity carries QEMU words of its launch's own, each named; those"
                "five refused unless --diagnostic admits it; or valid; each table row names its batches' standings"
            ] | str join " "),
            route: ([
                "a run's route is the route.nuon beside its bound identity file, else in the first of its run"
                "directories holding one, else the file its identity names, held to the SHA-256 its identity"
                "recorded; a recorded route missing, of another digest, or not naming every leg its rows hold"
                "leaves the run unrouted, refused even under --diagnostic; runs on more than one route, the runs"
                "whose identities record none counting as one, are refused unless --diagnostic admits them, then"
                "kept apart, the route a part of what a build is, and each table row names its route"
            ] | str join " "),
            coverage: ([
                "a run's expected legs are its route's, in its order, or for a run whose identity records no route"
                "every leg any compared run recording none holds; a run missing one is refused unless --diagnostic"
                "admits it, and then each leg it misses is an explicit missing result in its run and its build's"
                "row is missing in place of a value, never a mean over fewer batches; the bins every run reached"
                "are its route's runs', and a leg no run reached is missing in its common entry and every batch"
            ] | str join " "),
            parts: ([
                "planes_us, walls_us, and sprites_us hold their rendering at schema 1 and are preparation alone at"
                "schemas 3 to 5; parts_unattributed_us holds no rendering at those and the raster in f59f7a7's"
                "schema 2 images; a schema 2 run's parts are known by a listed image's SHA-256 alone, whatever its"
                "identity's commit says, else unknown; planes_us, walls_us, tiles_us, tiles_built, tile_bytes, and"
                "tile_peak hold the tiles' construction inside the plane and wall phases below schema 5 and the"
                "pool's boundary apart at 5; a comparison on these fields is refused, --diagnostic or not, when its"
                "runs' classes differ or any is unknown, and every other field compares across schemas"
            ] | str join " "),
            admitted: $diagnostic,
            machines: $machines,
            routes: $routes,
        },
        common: $common,
        runs: $valued,
        table: $table,
    }
}

# A run's standing in a comparison, valid or why not, with reasons
export def standing-of [
    m: oneof<record, nothing>
    rows: list<any>
    field: string
    requested: any
    asked: record
    machine: any
    overrides: any
]: nothing -> record<standing: string, reasons: list<string>> {
    let clocked = ($m | get -o clocked)
    if ($clocked | describe) != "bool" {
        let why = (if $m == null {
            "the run records no measurement"
        } else {
            "its measurement records no clocked, true or false"
        })
        return { standing: "unclassified", reasons: [$why] }
    }
    if ($rows | is-empty) { return { standing: "empty", reasons: ["the file holds no rows for the run"] } }
    let unusable = (unusable-reasons $rows $field)
    if not ($unusable | is-empty) { return { standing: "unusable", reasons: $unusable } }
    if not $clocked {
        let why = "clockless: a build older than the clock records, read from its states alone, whose console answers a seed it never takes"
        return { standing: "unpaired", reasons: [$why] }
    }
    if not ($m.complete? | default false) { return { standing: "incomplete", reasons: ($m.problems? | default []) } }
    if $m.valid? == null {
        let why = "measured before the analyzer recorded validity: re-read its capture with gauge read"
        return { standing: "unchecked", reasons: [$why] }
    }
    if not $m.valid { return { standing: "invalid", reasons: ($m.invalid? | default []) } }
    let unpaired = (unpaired-reasons $m $requested $asked)
    if not ($unpaired | is-empty) { return { standing: "unpaired", reasons: $unpaired } }
    let words = ($overrides | default [])
    let custom = ($machine | get -o diagnostic)
    let built = (($custom | describe) | str starts-with "record")
    let legacy = ($custom == true)
    let marked = ($legacy or (not (($machine | get -o overrides | default []) | is-empty)))
    if $built or $marked or (not ($words | is-empty)) {
        let harts = ($machine | get -o harts)
        let causes = ([
            (if ($words | is-empty) { null } else { $"QEMU words of its launch's own: ($words | str join ' ')" }),
            (if $built { $"a custom machine of ($custom.harts) harts and ($custom.ram_gib) GiB, no named spec" } else if $legacy and $harts != null and $harts != $HARTS { $"a diagnostic machine of ($harts) harts, not the specification's three" } else { null }),
        ] | compact)
        let why = (if ($causes | is-empty) { ["a machine its identity records as diagnostic"] } else { $causes })
        return { standing: "diagnostic", reasons: $why }
    }
    { standing: "valid", reasons: [] }
}

# Why a clocked run cannot be paired: its seed and cadence, then workers
def unpaired-reasons [m: record, requested: any, asked: record]: nothing -> list<string> {
    cadence-unpaired $m $requested | append (workers-unpaired $m $asked)
}

# Why a clocked run's seed or cadence keeps it from pairing
def cadence-unpaired [m: record, requested: any]: nothing -> list<string> {
    let schema = ($m | get -o schema | default 1)
    let seeded = ($m | get -o seeded | default false)
    let late_seed = ($m | get -o late_seed | default false)
    let seeds = [
        (if $seeded { null } else { "unseeded: no seed answered before the first frame" }),
        (if $late_seed { "a seed answered after the first frame" } else { null }),
    ]
    if $schema < 2 {
        let legacy = (if $requested == null or $requested == 0 { null } else {
            $"the identity asks cadence ($requested), which a capture below schema 2 cannot play"
        })
        return ($seeds | append $legacy | compact)
    }
    let cadence_set = ($m | get -o cadence_set | default false)
    let late_cadence = ($m | get -o late_cadence | default false)
    let cadences = ($m | get -o cadences | default [])
    let asked = (if $requested == null {
        "the identity asks no cadence"
    } else if $requested not-in $CADENCES {
        $"the identity asks cadence ($requested), outside 0 to 2"
    } else { null })
    let others = (if $requested == null { [] } else { $cadences | where {|c| $c != $requested } })
    $seeds | append [
        (if $cadence_set { null } else { "no cadence asked before the first frame" }),
        (if $late_cadence { "a cadence asked after the first frame" } else { null }),
        $asked,
        (if ($others | is-empty) { null } else { $"frames at cadence ($others | each {|c| $c | into string } | str join ', ') where the identity asked ($requested)" }),
    ] | compact
}

# The cadence a run played: its asked one from schema 2, else 0
def effective-cadence [m: oneof<record, nothing>, requested: any]: nothing -> any {
    if ($m | get -o schema | default 1) >= 2 { $requested } else { $CADENCE_AFTER_FLIP }
}

# Why a clocked run's workers or grain keep it from pairing
def workers-unpaired [m: record, asked: record]: nothing -> list<string> {
    let schema = ($m | get -o schema | default 1)
    let wanted = ($asked | get -o workers)
    let grain = ($asked | get -o grain)
    let answered = ($m | get -o workers_set | default false)
    let late = (if ($m | get -o late_workers | default false) { "workers asked after the first frame" } else { null })
    if $schema < 4 {
        if $wanted != null and $wanted > 0 {
            return [$"the identity asks ($wanted) workers, which a capture below schema 4 cannot show"]
        }
        if (legacy-serial $m $asked) { return [] }
        return ([
            "the workers that drew it are unknown: below schema 4 a capture is the serial backend only with a W 0 answered before its first frame and no W after it"
            (if $wanted == null { "no workers asked" } else if not $answered { "no W 0 answered before the first frame" } else { null })
            $late
        ] | compact)
    }
    let drawn = ($m | get -o workers | default [])
    let grains = ($m | get -o grains | default [])
    if $wanted == null {
        return ([
            $late,
            (if ($drawn | length) > 1 { $"frames drawn by ($drawn | each {|w| $w | into string } | str join ' and ') workers, none asked" } else { null }),
            (if ($grains | length) > 1 { $"frames at grains ($grains | each {|g| $g | into string } | str join ' and '), none asked" } else { null }),
        ] | compact)
    }
    let other_workers = ($drawn | where {|w| $w != $wanted })
    let other_grains = ($grains | where {|g| $g != $grain })
    [
        (if $answered { null } else { "no workers asked before the first frame" }),
        $late,
        (if ($other_workers | is-empty) { null } else { $"frames drawn by ($other_workers | each {|w| $w | into string } | str join ', ') workers where the identity asked ($wanted)" }),
        (if ($other_grains | is-empty) { null } else { $"frames at a grain of ($other_grains | each {|g| $g | into string } | str join ', ') where the identity asked ($grain)" }),
    ] | compact
}

# Whether a run below schema 4 drew serially: W 0 answered in time, no later W
def legacy-serial [m: oneof<record, nothing>, asked: record]: nothing -> bool {
    let wanted = ($asked | get -o workers)
    let answered = ($m | get -o workers_set | default false)
    let late = ($m | get -o late_workers | default false)
    $wanted == 0 and $answered and (not $late)
}

# The workers and grain a run played, unknown or null where unclear
def effective-workers [m: oneof<record, nothing>, asked: record]: nothing -> record<workers: any, grain: any> {
    if ($m | get -o schema | default 1) < 4 {
        return (if (legacy-serial $m $asked) { { workers: 0, grain: 0 } } else { { workers: $UNKNOWN_WORKERS, grain: $UNKNOWN_WORKERS } })
    }
    let drawn = ($m | get -o workers | default [])
    let grains = ($m | get -o grains | default [])
    let workers = (if ($drawn | length) == 1 { $drawn | first } else { null })
    let grain = (if $workers == 0 { 0 } else if ($grains | length) == 1 { $grains | first } else { null })
    { workers: $workers, grain: $grain }
}

# Why a run's rows give nothing to compare in the field
def unusable-reasons [rows: list<any>, field: string]: nothing -> list<string> {
    let values = ($rows | each {|r|
        { frame: ($r | get -o frame), leg: ($r | get -o leg), value: ($r | get -o $field) }
    })
    let typed = ($values | where {|v| $v.value != null and ($v.value | describe) not-in [int float] })
    let bare = ($values | get leg | uniq | where {|leg|
        $values | where {|v| $v.leg == $leg and $v.value != null } | is-empty
    })
    let typed_reasons = (if ($typed | is-empty) { [] } else {
        [$"frame ($typed.0.frame)'s ($field) is a ($typed.0.value | describe), not a number"]
    })
    $typed_reasons | append ($bare | each {|leg| $"the leg ($leg) holds no number in ($field)" })
}

# A leg's frames reduced for comparison: its travel, a median or path bins
def leg-measure [rows: list<any>, leg: string, field: string, bin_cm: int]: nothing -> record {
    mut travelled = 0.0
    mut previous: any = null
    mut placed = []
    for r in $rows {
        if $previous != null { $travelled = $travelled + (((($r.x - $previous.x) ** 2) + (($r.y - $previous.y) ** 2)) | math sqrt) }
        $previous = $r
        $placed = ($placed | append { bin: (($travelled * 100 / $bin_cm) | math floor), value: ($r | get $field) })
    }
    if ($travelled * 100) < $bin_cm {
        return { leg: $leg, kind: "frames", frames: ($rows | length), path_m: $travelled, median: (summary stats ($rows | get $field)).median, bins: [] }
    }
    let bins = ($placed | group-by {|p| $p.bin | into string } | transpose bin entries | each {|g| { bin: ($g.bin | into int), frames: ($g.entries | length), median: (summary stats ($g.entries | get value)).median } } | sort-by bin)
    { leg: $leg, kind: "path", frames: ($rows | length), path_m: $travelled, median: null, bins: $bins }
}

# Builds compared by leg and printed, the comparison saved, to `--out` if given
export def report [
    ...files: string
    --field: string = "draw_us"
    --bin-cm: int = 50
    --out: string = ""
    --diagnostic
] {
    let result = (main $files $field $bin_cm --diagnostic=$diagnostic)
    let target = (if $out == "" { build program-shard ($WORKSPACE | path join "kit" "fierce") "gauge" | path join "compare.nuon" } else { $out | path expand })
    mkdir ($target | path dirname)
    target retire $target (target root $WORKSPACE)
    $result | to nuon --indent 2 | save --raw $target
    for t in $result.table {
        let marks = ($t.standings | where {|s| $s != "valid" })
        let marked = (if ($marks | is-empty) { "" } else { $"; ($marks | str join ', ')" })
        let value = (if $t.missing > 0 {
            $"missing in ($t.missing) of ($t.batches) batches"
        } else if $t.value_us == null {
            $"no value, no bin reached by every run, ($t.batches) batches"
        } else {
            $"(report ms $t.value_us) ms, half spread (report ms $t.half_spread_us), ($t.batches) batches"
        })
        print $"gauge: ($t.build) ($t.leg): ($value)($marked)"
    }
    let corrected = ($result.runs | where {|r| $r.corrections != null })
    let fallen = ($result.runs | where {|r| $r.identity_from != $FROM_FILE })
    if not ($corrected | is-empty) {
        print $"gauge: identities corrected by their sidecars: ($corrected | each {|r| $'($r.label) run ($r.run), ($r.corrections.fields | get field | str join ' and ')' } | str join '; ')"
    }
    if not ($fallen | is-empty) {
        print $"gauge: identities read from their reports, not their runs' files: ($fallen | each {|r| $'($r.label) run ($r.run), ($r.identity_from)' } | str join '; ')"
    }
    print $"gauge: ($target)"
}
