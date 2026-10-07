# gauge.nu: the game's frames measured over play. At each frame's start
# the program sends the frame before's records over the API, the frame's
# clock (kind 7), its drawing with the tile cache (kind 8), from schema 2
# its presentation (kind 10): the simulation's time, the next frame's
# start, the wait before the flip and the pacing around it, the pad's
# wakes and presses in the wait, the flip's attempts and refusals, and
# the cadence; and at schema 3 its packets (kind 12): the preparation and
# the raster apart, the commands, the flushes, the bindings invalidated,
# the bytes the packets held, and the frame whose simulation they were
# prepared from, the drawing's planes, walls, and sprites then
# preparation alone; and at schema 4 the raster's workers that drew them,
# 0 the serial backend, the grain, and the rounds' slowest worker, every
# worker's busy time, the dispatch, and the barrier. After the console's E
# the end marker (kind 9) names the final frame of the measurement, which
# the frames from 0 to it make up. render.inc lays the records out; this
# reader takes schemas 1 to 4. `run` plays a route on a build `--runs`
# times, headless or with `--host` in the host's window and audio, each
# run seeded by the console's R, asking its cadence by the console's C and
# with `--workers` its workers and grain by the console's W before its
# first frame; `play` puts the build in the host's window, audio, and gamepad
# for a person to play and closes the measurement after `--seconds`;
# `read` reads a capture either made; `compare` sets builds' captures
# side by side, a build being an image at the cadence it played on the
# machine it ran on, a walked leg per stretch of its path, refusing a run
# measured incomplete, invalid, or before validity was recorded, one that
# cannot be paired, one on a diagnostic machine or with QEMU words of its
# launch's own, one missing a leg another run holds, or runs on more than
# one machine, unless `--diagnostic`
# admits it, and a run with nothing to compare in it outright, every run's
# standing and missing legs kept. Each run keeps the route it played and
# its identity beside its capture, then gauge.nuon and the summary. The
# measurement is the capture read in order through the first end marker;
# what follows it counts for nothing. A frame passes the ceiling when its
# critical path, its start to the end of its reporting with the wait and
# the await apart, is under 15 ms; a measurement is valid when it is
# complete, every flip presented or refused as its cadence allows, every
# phase within its frame, every frame's clock agreeing with its state,
# from schema 2 every frame's start, critical path, wait, and await
# adding up to the next frame's start and its start, simulation, flip
# end, and next start in that order, from schema 3 every frame's
# drawing its preparation and its raster, the bytes its packets held its
# commands' and its span records', and its packets prepared from its own
# simulation, and at schema 4 every frame's workers at most WORKERS_MAX at
# a grain within the screen's rows, its round times none under the serial
# backend and its slowest worker, dispatch, and barrier within its raster,
# its busy time at least its slowest worker's and at most W times it with
# the W - 1 microseconds its conversions drop, and passes when it is
# valid and every frame in it passes.
# A capture holding no record of the clock's kinds, 7, 8, 9, 10, or 12,
# is a build older than them: it holds no measurement and is read from
# its state records alone, the drawing's and the game's microseconds.
# `bench-report` reads a run of a bench whose steps are this script's,
# every cadence's frames pooled. `just do gauge`, `just do gauge-play`,
# `just do gauge-read`, and `just do gauge-compare` run it, and `just
# bench game/fps/cadence` runs `play`, `run`, and `bench-report`.
# A run's identity is read through one reader (identity-of): the run's
# identity.nuon, its directory found beside its report before the path
# the report recorded, with an audited correction beside it applied
# (correction-of); else the copy its report embedded; else the report's
# one identity; a comparison names each run's source and corrections.
# `run` and `play` refuse an image whose build flags contradict the tree
# asked. `run --cpu` reads every QEMU thread's CPU at 5 s, at each
# placement, and at the route's end, kept whole in run.nuon and reported
# as host-time windows (cpu-windows).
use ../../../sdk/nu/jab.nu
use ../nu/map.nu
use ./pose.nu

# the workspace, four directories above this script
const WORKSPACE = (path self | path dirname | path join ".." ".." ".." | path expand)
const RECORD = 64
# the clock records' layouts this reader takes; a capture's sit at one
const SCHEMAS = [1 2 3 4]
const CEILING_US = 15000
const KIND_STATE = 1
const KIND_FRAME = 7
const KIND_DRAW = 8
const KIND_END = 9
const KIND_PRESENT = 10
const KIND_CONSOLE = 11
const KIND_PACKET = 12
# the console's commands as its records name them: P a placement, R a
# seed, C a cadence, W the raster's workers and grain
const CONSOLE_P = 80
const CONSOLE_R = 82
const CONSOLE_C = 67
const CONSOLE_W = 87
# the raster's workers a frame may have, render.inc's WORKERS_MAX, and the
# screen's rows, a grain's bound
const WORKERS_MAX = 2
const SCREEN_ROWS = 1080
# the cadences: 0 awaits after the flip, 1 waits before it only when
# presenting would be early, 2 holds every flip to the display's tick
const CADENCES = [0 1 2]
const CADENCE_AFTER_FLIP = 0
# the cap a frame's period comes from when a capture's identity names none
const CAP = 60
# the specification's harts; a machine of another count is diagnostic
const HARTS = 4
# a frame's next start less its start less its critical path, wait, and
# await: the microseconds the conversions drop, at most this
const RESIDUAL_US = 4
# the span records a frame holds before its spans go unrecorded
const SPAN_RECORDS = 65536
# a command's bytes in a packet, the polygon's record copied whole, and a
# span record's (render.inc's POLY_SIZE and SPAN_RECORD_SIZE)
const COMMAND_BYTES = 312
const SPAN_BYTES = 16
# a frame's drawing less its preparation and its raster: the microsecond
# the three conversions drop, at most this
const PACKET_RESIDUAL_US = 1
# the critical path's phases at each schema and the drawing's parts, each
# exclusive; tiles_us lies within planes_us and walls_us and is never
# added to them; from schema 3 the planes, walls, and sprites are
# preparation alone and the raster a part of its own
const PHASES = {
    "1": [game_us draw_us hud_us mix_us flip_us report_us],
    "2": [game_us draw_us hud_us mix_us pacing_us flip_us report_us],
    "3": [game_us draw_us hud_us mix_us pacing_us flip_us report_us],
    "4": [game_us draw_us hud_us mix_us pacing_us flip_us report_us],
}
const PARTS = {
    "1": [clear_us portals_us planes_us walls_us sprites_us],
    "2": [clear_us portals_us planes_us walls_us sprites_us],
    "3": [clear_us portals_us planes_us walls_us sprites_us raster_us],
    "4": [clear_us portals_us planes_us walls_us sprites_us raster_us],
}
# the drawing's parts whose meaning moved with the packets (compare): the
# phases, holding their rendering before the packets and preparation
# alone from them on; and the remainder, holding no rendering at schemas
# 1 and 3 and the raster in f59f7a7, the packet core before its record,
# which writes schema 2 with its phases preparation alone
const PHASE_FIELDS = [planes_us walls_us sprites_us]
const REMAINDER_FIELDS = [parts_unattributed_us]
const WITH_RENDERING = "with rendering"
const PREPARATION_ALONE = "preparation alone"
const NO_RENDERING = "holding no rendering"
const HOLDING_RASTER = "holding the raster"
const UNKNOWN_PARTS = "unknown"
# the schema 2 images whose parts are known, by the SHA-256 of the .jab
# image a run's identity records (build.image_sha256): f59f7a7's three
# sets, each built twice from a `git archive` export of that commit in
# two directories, the two images alike, with the SDK, the toolchain, and
# the flags they were built with
const PHASE_IMAGES = {
    "ef8d01fa7e52c0076b6ca735803ae8ddb9c5a80c016e47577c5df4a51ef02234": {
        commit: "f59f7a740873f9dfad4c3bcab8126271fe475fd4", set: "release", flags: "-march=rva23u64",
        sdk: "sdk/src at 9397f24, the workspace at 31e4023", toolchain: "GNU Binutils 2.47.20260726, riscv64-unknown-linux-gnu",
        phases: $PREPARATION_ALONE, remainder: $HOLDING_RASTER,
    },
    "5d723b3f14e3bedeca11f03b95a196eac116d4f5c3aba8906c93b5040fe32ca4": {
        commit: "f59f7a740873f9dfad4c3bcab8126271fe475fd4", set: "debug", flags: "--defsym DEBUG=1 -march=rva23u64",
        sdk: "sdk/src at 9397f24, the workspace at 31e4023", toolchain: "GNU Binutils 2.47.20260726, riscv64-unknown-linux-gnu",
        phases: $PREPARATION_ALONE, remainder: $HOLDING_RASTER,
    },
    "263c84ee5b9a1b1f355d0242b9d775df74f86d2e73b90dc0aba4d0b0e96d2cf8": {
        commit: "f59f7a740873f9dfad4c3bcab8126271fe475fd4", set: "debug,owner", flags: "--defsym DEBUG=1 --defsym OWNER=1 -march=rva23u64",
        sdk: "sdk/src at 9397f24, the workspace at 31e4023", toolchain: "GNU Binutils 2.47.20260726, riscv64-unknown-linux-gnu",
        phases: $PREPARATION_ALONE, remainder: $HOLDING_RASTER,
    },
}
# an unexplained phase outlier: a phase past OUTLIER_RATIO times its
# leg's median and OUTLIER_US over it, in a frame whose tile work stayed
# within twice its leg's median, the first frame after a placement apart
const OUTLIER_RATIO = 4
const OUTLIER_US = 2000
# after the E the final records and the end marker land within this,
# then the capture ends the run; the run's bound is past both
const DRAIN = 2sec
const BOUND_PAST = 3sec
# when a run's seed goes in, before the program's first frame
const SEED_AT = 200ms
# a flip's status: 0 presented, 1 refused before the tick, 2 no display,
# 3 the device refused it
const FLIP_PRESENTED = 0
const FLIP_EARLY = 1
# the statuses a valid measurement holds; 2, 3, or any other is a frame
# never shown
const FLIP_VALID = [0 1]
# the android events and what a round met, as the program reports them
const ANDROID_EVENTS = [none roused fired struck destroyed fallen waypoint]
const MET = [nothing geometry android]
# the standings a comparison refuses unless admitted as a diagnostic, and
# those it refuses even then, holding nothing a comparison can read; a
# run missing a leg is refused unless admitted too, whatever its standing
const REFUSED = [incomplete invalid unchecked unpaired diagnostic]
const REJECTED = [empty unclassified unusable]
# a run's workers and grain below schema 4 when its records cannot show
# them (effective-workers), a build of its own
const UNKNOWN_WORKERS = "unknown"
# the identity's fields a correction may change: the build's flags and its
# ELF's SHA-256, each read from beside the image at the run's start
const CORRECTABLE = ["build.flags" "build.elf_sha256"]
# where a run's effective identity came from (identity-of), none where
# its report holds no identity evidence (no-evidence)
const FROM_FILE = "file"
const FROM_EMBEDDED = "embedded"
const FROM_LEGACY = "legacy"
const FROM_NONE = "none"
# the identity a reading with no evidence carries, the capture alone's,
# its report's identity and never its run's (read-run)
const ALONE = { launched: false, note: "read from the capture alone; no identity was written at its launch" }
# how a found identity file binds to its report's run, strongest first
# (binding-of): the SHA-256 of the file the run records; the identity the
# run embeds, on every field but CORRECTABLE's; the report's one
# identity over LEGACY_FIELDS, the weaker binding; none where the report
# holds nothing to bind it to
const BOUND_HASH = "sha256"
const BOUND_EMBEDDED = "embedded"
const BOUND_LEGACY = "legacy"
const BOUND_NONE = "none"
# the report's one identity's fields a legacy binding compares, the mode
# less its seed, which is held against the run's own recorded seed
const LEGACY_FIELDS = ["build.image_sha256" "build.kernel_sha256" "assets" "route" "machine" "overrides" "mode" "cap" "toolchain" "qemu"]
# the CPU readings' whole window opens here, past the load (cpu-requests)
const CPU_FROM = 5sec

def main [] {
    print "nu gauge.nu run [--tree release|debug] [--kernel <jab.elf>] [--image <fps.jab>] [--route <route.nuon>] [--map <tree>] [--runs N] [--seeds [..]] [--cadence 0|1|2] [--workers 0|1|2] [--grain N] [--host] [--harts 1|2|4] [--qemu [<word>..]] [--cpu] [--out <dir>] [--label <name>]"
    print "nu gauge.nu play [--tree release|debug] [--seconds N] [--seed N] [--cadence 0|1|2] [--workers 0|1|2] [--grain N] [--harts 1|2|4] [--qemu [<word>..]] [--out <dir>] [--label <name>]"
    print "nu gauge.nu read <api.out> [--route <route.nuon>] [--out <dir>] [--label <name>]"
    print "nu gauge.nu compare <gauge.nuon>... [--field draw_us] [--bin-cm 50] [--out <file>]"
    print "nu gauge.nu bench-report <a bench run's directory>"
}

# Play the route on the build `runs` times and read every frame: the
# route's placements, its legs' `sends` (console command frames by their
# one-letter kind, each at its `at`), and its pad rows, an R with the
# run's seed and a C with the cadence before the first frame, with
# `--workers` a W with the workers and the grain beside them, the E at
# the route's end, the capture when the final records have landed. Headless with the sound
# recorded, or with `--host` in the window and the audio a run of the
# program has. `--qemu` words go on each launch's line after its own, and
# each run's identity then takes the machine and the words the launch
# returns, a diagnostic run. An image whose build flags contradict the
# tree asked is refused before any launch (flags-contradiction). With
# `--cpu`, every QEMU thread's CPU is read at the times cpu-requests
# names, the readings kept whole in run.nuon and each run's windows
# (cpu-windows) in the report.
def "main run" [
    --tree: string = "release"   # the build tree the kernel and the image come from, release or debug
    --kernel: string = ""        # the kernel's ELF, the tree's own unless given
    --image: string = ""         # the program's image, the tree's own unless given
    --route: string = ""         # the route, route_render_0.nuon unless given
    --map: string = ""           # the map tree the route plays on, the route's unless given
    --runs: int = 3              # the route's runs
    --seeds: list<int> = []      # each run's seed, run n's n unless given
    --cadence: int = 1           # the cadence each run asks for, the program's own 1 unless given
    --workers: int = -1          # the raster's workers each run asks for, 0 the serial backend; none asked, no W, unless given
    --grain: int = 32            # the rows a band asked with the workers, the program's own 32 unless given, 0 for a band a worker
    --host                       # the host's window and audio in place of none and the recording
    --out: string = ""           # where the runs land, a stamped directory under the tree's unless given
    --label: string = ""         # a name for the build in the summary
    --harts: int = 4             # the machine's harts, 1 or 2 for a diagnostic run
    --qemu: list<string> = []    # words on each launch's line after its own, the runs then diagnostic
    --cpu                        # every QEMU thread's CPU read at 5 s, each placement, and the route's end, as host-time windows
] {
    if $cadence not-in $CADENCES { error make { msg: $"--cadence is one of ($CADENCES | str join ', '), not ($cadence)" } }
    let asked = (workers-asked $workers $grain)
    jab machine-of $harts | ignore
    let at = (places $tree $kernel $image $out)
    let contradiction = (flags-contradiction (image-flags $at.image) $at.tree)
    if $contradiction != null { error make { msg: $contradiction } }
    let route_file = (if $route == "" { $env.FILE_PWD | path join "route_render_0.nuon" } else { $route | path expand })
    let route_bytes = (open --raw $route_file | into binary)
    let r = ($route_bytes | decode utf-8 | from nuon)
    let requests = (if $cpu { cpu-requests $r.legs $r.end } else { [] })
    let map_name = (if $map == "" { $r.map } else { $map })
    let disk = (romfs-of $at.game $map_name $at.out)
    let pad = ($at.out | path join "pad.nuon")
    $r.legs | each {|l| $l.pad } | flatten | sort-by at | to nuon | save --raw -f $pad
    let capture = ($r.end + $DRAIN)
    let seconds = ((($capture + $BOUND_PAST) / 1sec) | math ceil)
    let set = (if $at.tree == "debug" { "debug" } else { "" })
    let runs = (1..$runs | each {|n|
        let seed = ($seeds | get -o ($n - 1) | default $n)
        let run_out = ($at.out | path join $"run_($n)")
        mkdir $run_out
        $route_bytes | save --raw -f ($run_out | path join "route.nuon")
        let sends = ([{ at: $SEED_AT, bytes: (seed-frame $seed) }, { at: $SEED_AT, bytes: (cadence-frame $cadence) }]
            | append (workers-sends $asked)
            | append ($r.legs | each {|l| $l.places | each {|p| { at: $p.at, bytes: (pose pose-frame $p) } } } | flatten)
            | append ($r.legs | each {|l| $l | get -o sends | default [] | each {|s| { at: $s.at, bytes: (pose command-frame $s.kind) } } } | flatten)
            | append [{ at: $r.end, bytes: (pose command-frame "E") }]
            | sort-by at)
        let mode = { window: $host, sound: (if $host { "host" } else { "recorded" }), pad: "route", seed: $seed, cadence: $cadence, workers: $asked.workers, grain: $asked.grain, end: $r.end, capture: $capture }
        let id = (identity $at $set $map_name $route_file $mode $harts $qemu)
        $id | to nuon --indent 2 | save --raw -f ($run_out | path join "identity.nuon")
        let launched = (if $host {
            jab launch --kernel $at.kernel --image $at.image --out $run_out --set $set --live-sound --window --api --pad $pad --disk $disk --serial "fps" --send $sends --capture $capture --seconds $seconds --harts $harts --qemu $qemu --threads-at $requests
        } else {
            jab launch --kernel $at.kernel --image $at.image --out $run_out --set $set --sound --api --pad $pad --disk $disk --serial "fps" --send $sends --capture $capture --seconds $seconds --harts $harts --qemu $qemu --threads-at $requests
        })
        let ran = (outcome $launched)
        $ran | to nuon --indent 2 | save --raw -f ($run_out | path join "run.nuon")
        let ran_id = (launched-identity $id $launched)
        let id_sha = (write-identity $ran_id $run_out)
        let measured = (measure $launched.api $r.legs --cap ($id.cap | default $CAP))
        print (run-line $label $n $measured $ran)
        print (outcome-line $n $measured $ran)
        let windows = (if $cpu { cpu-windows $ran.thread_readings $r.legs $r.end } else { null })
        { run: $n, seed: $seed, out: $run_out, ran: $ran, measured: $measured, identity: $ran_id, corrections: null, identity_sha256: $id_sha, cpu: $windows }
    })
    report $label (open ($at.out | path join "run_1" "identity.nuon")) $runs $at.out
}

# Put the build in the host's window, with its audio and its own
# gamepad, for a person to play from the spawn: an R with the seed and a
# C with the cadence before the first frame, the E after `seconds`, the
# capture once the final records have landed, which closes the window.
# `--qemu` as `run` takes it, and an image whose build flags contradict the
# tree asked is refused as `run` refuses it.
def "main play" [
    --tree: string = "release"   # the build tree, release or debug
    --kernel: string = ""        # the kernel's ELF, the tree's own unless given
    --image: string = ""         # the program's image, the tree's own unless given
    --seconds: int = 120         # the measurement's length
    --seed: int = 1              # the seed the run sends
    --cadence: int = 1           # the cadence the run asks for, the program's own 1 unless given
    --workers: int = -1          # the raster's workers the run asks for, 0 the serial backend; none asked, no W, unless given
    --grain: int = 32            # the rows a band asked with the workers, the program's own 32 unless given, 0 for a band a worker
    --out: string = ""           # where the run lands, a stamped directory under the tree's unless given
    --label: string = ""         # a name for the build in the summary
    --harts: int = 4             # the machine's harts, 1 or 2 for a diagnostic run
    --qemu: list<string> = []    # words on the launch's line after its own, the run then diagnostic
] {
    if $cadence not-in $CADENCES { error make { msg: $"--cadence is one of ($CADENCES | str join ', '), not ($cadence)" } }
    let asked = (workers-asked $workers $grain)
    jab machine-of $harts | ignore
    let at = (places $tree $kernel $image $out)
    let contradiction = (flags-contradiction (image-flags $at.image) $at.tree)
    if $contradiction != null { error make { msg: $contradiction } }
    let disk = (romfs-of $at.game "render_0" $at.out)
    let set = (if $at.tree == "debug" { "debug" } else { "" })
    let end = ($seconds * 1sec)
    let capture = ($end + $DRAIN)
    let bound = ((($capture + $BOUND_PAST) / 1sec) | math ceil)
    let run_out = ($at.out | path join "run_1")
    mkdir $run_out
    let sends = ([{ at: $SEED_AT, bytes: (seed-frame $seed) }, { at: $SEED_AT, bytes: (cadence-frame $cadence) }]
        | append (workers-sends $asked)
        | append [{ at: $end, bytes: (pose command-frame "E") }])
    let mode = { window: true, sound: "host", pad: "host", seed: $seed, cadence: $cadence, workers: $asked.workers, grain: $asked.grain, end: $end, capture: $capture }
    let id = (identity $at $set "render_0" null $mode $harts $qemu)
    $id | to nuon --indent 2 | save --raw -f ($run_out | path join "identity.nuon")
    print $"gauge: play until the window closes, ($seconds) seconds measured from the start"
    let launched = (jab launch --kernel $at.kernel --image $at.image --out $run_out --set $set --live-sound --window --host-pad --api --disk $disk --serial "fps" --send $sends --capture $capture --seconds $bound --harts $harts --qemu $qemu)
    let ran = (outcome $launched)
    $ran | to nuon --indent 2 | save --raw -f ($run_out | path join "run.nuon")
    let ran_id = (launched-identity $id $launched)
    let id_sha = (write-identity $ran_id $run_out)
    let legs = [{ name: "play", places: [], pad: [] }]
    let measured = (measure $launched.api $legs --cap ($id.cap | default $CAP))
    print (run-line $label 1 $measured $ran)
    print (outcome-line 1 $measured $ran)
    report $label $ran_id [{ run: 1, seed: $seed, out: $run_out, ran: $ran, measured: $measured, identity: $ran_id, corrections: null, identity_sha256: $id_sha, cpu: null }] $at.out
}

# Read a capture, a run's api.out (read-capture).
def "main read" [
    api: path                    # the capture
    --route: string = ""         # the route the capture played, for its legs
    --out: string = ""           # where gauge.nuon lands, beside the capture unless given
    --label: string = ""         # a name for the build in the summary
] {
    read-capture $api $route $out $label
}

# Read a capture, a run's api.out: under the identity it was launched
# with (read-identity), through the reports it belongs to when there are
# any, else its own identity.nuon with its correction applied, else what
# the capture alone says, every directory passed over and every report
# reconciled named, the reading from a report's one identity or no
# evidence the report's identity and never the run's own (read-run); the
# run.nuon its launch wrote beside it; the legs from `route`, else the
# route kept beside the capture, else the one the identity names, refused
# unless it is the route that played (legs-for), and one leg, play, when
# no route is recorded; the report written in `out`, beside the capture
# when empty.
export def read-capture [api: path, route: string, out: string, label: string]: nothing -> nothing {
    let file = ($api | path expand)
    let dir = ($file | path dirname)
    let read_id = (read-identity $dir)
    for p in $read_id.passed { print $"gauge: passed over ($p.dir) at ($p.strength): ($p.reasons | str join '; ')" }
    if ($read_id.reports | length) > 1 { print $"gauge: the identity reconciled from ($read_id.reports | str join ' and ')" }
    let id = $read_id.identity
    let chosen = (legs-for $dir $id $route)
    let legs = $chosen.legs
    if $chosen.route != null and (not $chosen.checked) { print $"gauge: the legs from ($chosen.route), unchecked: the capture's identity records no route" }
    let run_file = ($dir | path join "run.nuon")
    let ran = (if ($run_file | path exists) { open $run_file } else { { status: null, fault: null, cpu_seconds: null, wall_seconds: null, qemu_binary: null, qemu: [], window: null, audio: null } })
    let measured = (measure (open --raw $file | into binary) $legs --cap ($id | get -o cap | default $CAP))
    print (run-line $label 1 $measured $ran)
    print (outcome-line 1 $measured $ran)
    let target = (if $out == "" { $dir } else { $out | path expand })
    mkdir $target
    let windows = (if ($ran | get -o thread_readings | default [] | is-empty) or $chosen.route == null { null } else { cpu-windows $ran.thread_readings $legs ($id | get -o mode.end | default 0sec) })
    report $label $id [(read-run $read_id $dir $ran $measured $windows)] $target
}

# The run record `read` writes for a reading (read-identity): the seed
# its report recorded, else, for the run's own identity, read from its
# file or embedded, that identity's, else null, never a report's one
# identity's; the identity the run's own for a file or an embedded
# reading, else null, a report's one identity or the placeholder its
# report's identity alone; the corrections, hash, source, binding, passes,
# and reports as read; the capture's directory, outcome, measurement, and
# CPU windows.
export def read-run [read_id: record, dir: string, ran: record, measured: record, windows: any]: nothing -> record {
    let own = ($read_id.from in [$FROM_FILE $FROM_EMBEDDED])
    let seed = (if $read_id.seed != null { $read_id.seed } else if $own { $read_id.identity | get -o mode.seed } else { null })
    {
        run: 1, seed: $seed, out: $dir, ran: $ran, measured: $measured, identity: (if $own { $read_id.identity } else { null }), corrections: $read_id.corrections,
        identity_sha256: $read_id.identity_sha256, identity_from: $read_id.from, binding: $read_id.binding,
        passed: $read_id.passed, reports: $read_id.reports, cpu: $windows,
    }
}

# Where a run's pieces are: the game, the workspace, the tree, the
# kernel and the image (the tree's own unless given), and the output
# directory, a stamped one under the tree's gauge unless given, made.
def places [tree: string, kernel: string, image: string, out: string]: nothing -> record<game: string, workspace: string, tree: string, kernel: string, image: string, out: string> {
    if $tree not-in [release debug] { error make { msg: $"--tree is release or debug, not ($tree)" } }
    let program = ($env.FILE_PWD | path join ".." | path expand)
    let game = $program
    let workspace = ($game | path join ".." ".." | path expand)
    let stamp = (date now | format date "%Y%m%d-%H%M%S")
    let built = (jab program-out $program $tree)
    let target = (if $out == "" { $built | path join "gauge" $stamp } else { $out | path expand })
    mkdir $target
    {
        game: $game,
        workspace: $workspace,
        tree: $tree,
        kernel: (if $kernel == "" { jab program-kernel $program $tree } else { $kernel | path expand }),
        image: (if $image == "" { $built | path join "fps.jab" } else { $image | path expand }),
        out: $target,
    }
}

# A map's tree as the romfs image the program reads, built in `out`.
def romfs-of [game: path, map: string, out: path]: nothing -> string {
    let tree = (jab program-shard $game "asset" | path join $map)
    if not ($tree | path join "map.nuon" | path exists) { error make { msg: $"no tree for ($map) at ($tree)" } }
    let disk = ($out | path join $"($map).romfs")
    let made = (^genromfs -d $tree -f $disk -V "fps" | complete)
    if $made.exit_code != 0 { error make { msg: $"genromfs on ($tree): ($made.stderr)" } }
    $disk
}

# The console's R frame: the seed as 64 bits in bytes 4 to 11.
export def seed-frame [seed: int]: nothing -> binary {
    [("R" | into binary), 0x[00 00 00], ($seed | into binary --endian little | bytes at 0..<8), (0..<52 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# The console's C frame: the cadence in byte 4.
export def cadence-frame [cadence: int]: nothing -> binary {
    [("C" | into binary), 0x[00 00 00], ($cadence | into binary --endian little | bytes at 0..<1), (0..<59 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# The console's W frame: the raster's workers in byte 4, 0 for the serial
# backend, and the rows a band in bytes 8 to 11, 0 for a band a worker.
export def workers-frame [workers: int, grain: int]: nothing -> binary {
    [("W" | into binary), 0x[00 00 00], ($workers | into binary --endian little | bytes at 0..<1), 0x[00 00 00], ($grain | into binary --endian little | bytes at 0..<4), (0..<52 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# The workers and grain a run asks for, as its identity records them:
# none, both null, for workers under 0, so no W goes out and the image's
# own default draws; else the workers, 0 to WORKERS_MAX, and the grain, 0
# to the screen's rows.
def workers-asked [workers: int, grain: int]: nothing -> record<workers: oneof<int, nothing>, grain: oneof<int, nothing>> {
    if $workers < 0 { return { workers: null, grain: null } }
    if $workers > $WORKERS_MAX { error make { msg: $"--workers is 0 to ($WORKERS_MAX), not ($workers)" } }
    if $grain < 0 or $grain > $SCREEN_ROWS { error make { msg: $"--grain is 0 to ($SCREEN_ROWS), not ($grain)" } }
    { workers: $workers, grain: $grain }
}

# The W a run's asked workers and grain send beside the seed, none when
# it asks none.
def workers-sends [asked: record]: nothing -> list<any> {
    if $asked.workers == null { [] } else { [{ at: $SEED_AT, bytes: (workers-frame $asked.workers $asked.grain) }] }
}

# What a run was, written beside its capture before it starts: the
# records' schemas this reader takes and the clock, the workspace the SDK
# and kernel come from, the program's own source, the build, the assets,
# the route, the cap, the machine (the harts asked for, a diagnostic run
# or not, -machine, the CPU, and the accelerator with its thread mode),
# the QEMU words of the launch's own (`overrides`), the host, the
# toolchain, and the mode: the window, the sound, the pad, the seed, the
# cadence asked for, the workers and grain asked for, null for none, and
# when the measurement closes. The build's flags are null, unknown, with
# no `flags` beside the image, and its provenance the `provenance.nuon`
# beside the image (ImageProvenance), null without one. The QEMU, the
# machine, and the words are the launch's, written in when it returns
# (launched-identity).
def identity [at: record, set: string, map: string, route: oneof<string, nothing>, mode: record, harts: int, qemu: list<string>]: nothing -> record {
    let built = ($at.image | path dirname)
    let flags = (image-flags $at.image)
    let prefix = (if $flags == null { null } else { $flags | split row " " | last })
    let provenance_file = ($built | path join "provenance.nuon")
    let jab_inc = ($at.workspace | path join "sdk" "src" "jab.inc")
    let cap = (open --raw $jab_inc | decode | parse --regex '\.set JAB_DISPLAY_FPS_CAP, (?P<cap>\d+)' | get -o 0.cap)
    let tree = (jab program-shard $at.game "asset" | path join $map)
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
            elf_sha256: (digest ($built | path join "fps.elf")),
            kernel: $at.kernel,
            kernel_sha256: (digest $at.kernel),
            provenance: (if ($provenance_file | path exists) { open $provenance_file } else { null }),
        },
        assets: { map: $map, tree: $tree, digest: (tree-digest $tree) },
        route: (if $route == null { null } else { { file: $route, sha256: (digest $route) } }),
        cap: (if $cap == null { null } else { $cap | into int }),
        machine: (jab machine-of $harts --overrides $qemu),
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
        },
        mode: $mode,
    }
}

# The QEMU a launch ran, the binary it resolved, and that binary's
# version.
def qemu-of [binary: string]: nothing -> record<binary: string, version: oneof<string, nothing>> {
    { binary: $binary, version: (try { ^$binary --version | complete | get stdout | lines | get -o 0 } catch { null }) }
}

# A run's identity once its launch returns: the QEMU it ran (qemu-of),
# and the machine and the words the launch's result carries in place of
# the ones asked for.
def launched-identity [id: record, launched: record]: nothing -> record {
    $id | upsert qemu (qemu-of $launched.qemu_binary) | upsert machine $launched.machine | upsert overrides $launched.overrides
}

# An image's build flags, the first line of the `flags` its build wrote
# beside it, or null, unknown, where there is none.
def image-flags [image: path]: nothing -> oneof<string, nothing> {
    let file = ($image | path expand | path dirname | path join "flags")
    if ($file | path exists) { open --raw $file | decode | lines | get -o 0 } else { null }
}

# Why an image's build flags contradict the tree a run asks for, none
# where they do not: DEBUG defined on a release run, or absent on a debug
# one. Flags missing are unknown and contradict nothing.
export def flags-contradiction [flags: oneof<string, nothing>, tree: string]: nothing -> oneof<string, nothing> {
    if $flags == null { return null }
    let debug = ($flags =~ '--defsym DEBUG=')
    if $tree == "release" and $debug { return $"the image's build flags define DEBUG where the run asks the release tree: ($flags)" }
    if $tree == "debug" and (not $debug) { return $"the image's build flags lack DEBUG where the run asks the debug tree: ($flags)" }
    null
}

# A run's identity file read with the correction beside it applied. The
# sidecar, identity_correction.nuon, names the identity file's SHA-256 and
# the image's (`build.image_sha256`), and for CORRECTABLE's fields alone
# the old value the file holds and the new one; a sidecar naming another
# file or image, an old value the file does not hold, no field, or a
# field outside CORRECTABLE stops the read. The corrections, null with no
# sidecar: the sidecar, its SHA-256, each field's old and new values, and
# the evidence it records.
export def correction-of [file: path]: nothing -> record<identity: record, corrections: any> {
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

# A run's identity written as its identity.nuon in `dir`, and the
# SHA-256 of the file's bytes as written, which the run's report records
# (RunBinding).
export def write-identity [id: record, dir: path]: nothing -> string {
    let file = ($dir | path join "identity.nuon")
    $id | to nuon --indent 2 | save --raw -f $file
    open --raw $file | into binary | hash sha256
}

# The directories a report's run may hold its identity file in, in the
# order identity-of tries them: beside the report, the directory named as
# the last component of the `out` the report recorded, or the report's
# own when the names match, so a moved report keeps its runs; then that
# recorded `out` itself. Expanded, each once; none without an `out`.
export def run-dirs [report: path, run: record]: nothing -> list<string> {
    let here = ($report | path expand | path dirname)
    let out = ($run | get -o out | default "")
    if $out == "" { return [] }
    let name = ($out | path basename)
    let adjacent = (if $name == ($here | path basename) { $here } else { $here | path join $name })
    [$adjacent ($out | path expand)] | uniq
}

# Whether `r` holds the dotted field `name`, key by key, a null value
# held as any other.
def holds-field [r: any, name: string]: nothing -> bool {
    mut at = $r
    for key in ($name | split row ".") {
        if not (($at | describe | str starts-with "record") and ($key in ($at | columns))) { return false }
        $at = ($at | get $key)
    }
    true
}

# The leaf fields where `a` and `b` differ, each named dotted from `at`
# with both values: two records compared key by key over both sides'
# keys, a key one side lacks read as null, anything else compared whole.
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

# A record less its seed, anything else as it is.
def less-seed [mode: any]: nothing -> any {
    if ($mode | describe | str starts-with "record") { $mode | reject -o seed } else { $mode }
}

# Where a file's identity, `found`, differs from a report's one identity,
# `batch`, over LEGACY_FIELDS: each field the batch holds compared, the
# mode less its seed, the file's seed against `seed`, the run's recorded
# one; the fields the batch lacks, and the seed when the run records
# none, unrecorded and not compared.
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

# Whether an identity, a report's or the one embedded for a run, is no
# evidence of its run: absent, or the placeholder a read of the capture
# alone writes, `launched` false (ALONE, and in a run as 7c37b3b's read
# embedded it).
def no-evidence [id: any]: nothing -> bool {
    if $id == null { return true }
    ($id | describe | str starts-with "record") and (($id | get -o launched) == false)
}

# An identity as evidence of its run, or null where it is none
# (no-evidence).
def evidence-of [id: any]: nothing -> any {
    if (no-evidence $id) { null } else { $id }
}

# An identity less CORRECTABLE's fields, the two a correction may change.
def less-correctable [id: any]: nothing -> any {
    if not ($id | describe | str starts-with "record") { return $id }
    $id | reject -o ...($CORRECTABLE | each {|f| $f | split row "." | into cell-path })
}

# How an identity file found for a report's run binds to it: at
# BOUND_HASH when the run records `identity_sha256`, the file's raw
# SHA-256, `sha`, equal to it; else at BOUND_EMBEDDED when the run embeds
# an identity that is evidence (evidence-of), a placeholder none, the
# file's identity as parsed, `found`, equal to it on
# every field but CORRECTABLE's; else at BOUND_LEGACY against the
# report's one identity, `legacy` (legacy-differences); else at
# BOUND_NONE, nothing to bind it to, no evidence (no-evidence) and the
# file taken unverified. Decided before any correction. `found` is null
# for a file that does not parse, `error` why, which binds at no strength
# but the hash. Bound or not, with the reasons it is not and the fields
# unrecorded.
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

# A run's effective identity and where it came from. The run's identity
# file, tried in each of its directories (run-dirs), when it binds to the
# run (binding-of), read with its correction applied (correction-of);
# else the identity the report embedded for the run where it is evidence
# (evidence-of), its correction provenance and its recorded
# `identity_sha256` with it; else the report's one identity, as a report
# from before per-run identities holds it; else, with no evidence
# (no-evidence), ALONE from `none`, a file found against no evidence
# still from the file, bound at BOUND_NONE, unverified. A
# directory whose file does not bind is passed over, named with its
# strength and reasons, its sidecar never read; a bound file that does
# not parse, or whose correction fails its checks, stops the read, never
# a fallback. The `identity_sha256` is the bound file's raw SHA-256, an
# embedded one as recorded, or null: never made from a parsed or corrected
# identity. The binding: the strength and the fields unrecorded, null
# without a file. The run's recorded seed beside it.
export def identity-of [report: path, run: record, legacy: any]: nothing -> record<identity: any, from: string, file: any, corrections: any, identity_sha256: any, binding: any, passed: list<any>, seed: any> {
    let seed = ($run | get -o seed)
    mut passed = []
    for dir in (run-dirs $report $run) {
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
        let read = (correction-of $file)
        return { identity: $read.identity, from: $FROM_FILE, file: $file, corrections: $read.corrections, identity_sha256: $sha, binding: { strength: $b.strength, unrecorded: $b.unrecorded }, passed: $passed, seed: $seed }
    }
    let embedded = (evidence-of ($run | get -o identity))
    if $embedded != null {
        return { identity: $embedded, from: $FROM_EMBEDDED, file: null, corrections: ($run | get -o corrections), identity_sha256: ($run | get -o identity_sha256), binding: null, passed: $passed, seed: $seed }
    }
    let from = (if (no-evidence $legacy) { $FROM_NONE } else { $FROM_LEGACY })
    { identity: (if $from == $FROM_NONE { $ALONE } else { $legacy }), from: $from, file: null, corrections: null, identity_sha256: null, binding: null, passed: $passed, seed: $seed }
}

# The identity a capture in `dir` was launched under. The reports it
# belongs to: gauge.nuon beside it and in its parent directory, a report
# belonging when one of its runs' directories (run-dirs) is the capture's,
# two such runs in one report stopping the read. Each belonging run read
# through identity-of, two reconciled (reconcile). With none, the
# capture's own identity.nuon read with its correction applied
# (correction-of), bound to nothing, BOUND_NONE, a parse or correction
# failure stopping the read; with no file, the capture alone, from
# `none`. Beside the identity-of fields, the reports read.
export def read-identity [dir: path]: nothing -> record {
    let here = ($dir | path expand)
    let reports = ([($here | path join "gauge.nuon") ($here | path dirname | path join "gauge.nuon")] | uniq | where {|f| $f | path exists })
    mut belonging = []
    for f in $reports {
        let g = (open $f)
        let runs = ($g | get -o runs | default [] | where {|r| $here in (run-dirs $f $r) })
        if ($runs | length) > 1 { error make { msg: $"($f) holds ($runs | length) runs in ($here), runs ($runs | get run | str join ', ')" } }
        if not ($runs | is-empty) { $belonging = ($belonging | append (identity-of $f ($runs | first) ($g | get -o identity) | insert report $f)) }
    }
    if ($belonging | length) == 2 { return (reconcile ($belonging | get 0) ($belonging | get 1) $here) }
    if ($belonging | length) == 1 { return ($belonging | first | reject report | insert reports [($belonging | first | get report)]) }
    let id_file = ($here | path join "identity.nuon")
    if ($id_file | path exists) {
        let read = (correction-of $id_file)
        let sha = (open --raw $id_file | into binary | hash sha256)
        return { identity: $read.identity, from: $FROM_FILE, file: $id_file, corrections: $read.corrections, identity_sha256: $sha, binding: { strength: $BOUND_NONE, unrecorded: [] }, passed: [], seed: null, reports: [] }
    }
    { identity: $ALONE, from: $FROM_NONE, file: null, corrections: null, identity_sha256: null, binding: null, passed: [], seed: null, reports: [] }
}

# A correction's substance, what two reports must agree on: its fields
# with their old and new values, the sidecar's SHA-256, and its evidence,
# the sidecar's path apart, so a relocated sidecar stays the same
# correction; null for none.
def correction-key [c: any]: nothing -> any {
    if $c == null { return null }
    { fields: ($c | get -o fields | default [] | sort-by field), sidecar_sha256: ($c | get -o sidecar_sha256), evidence: ($c | get -o evidence) }
}

# Where two readings of one run differ over LEGACY_FIELDS and
# CORRECTABLE's two, the comparison reconcile makes when either is a
# report's one identity: each field both identities hold, the mode less
# its seed, and each reading's seed, the run's recorded one for a report's
# one identity, else its identity's. A report's one identity holds its
# image's flags and ELF, one build for every run of its batch, so they
# compare here and reach `explains`, though binding leaves them out.
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

# Whether `c`, a reading's corrections, changed `field` from `from`, the
# other reading's value, to `to`, its own.
def explains [c: any, field: string, from: any, to: any]: nothing -> bool {
    if $c == null { return false }
    $c | get -o fields | default [] | any {|x| $x.field == $field and $x.old == $from and $x.new == $to }
}

# The reading reconcile keeps, the recorded `identity_sha256` with it,
# both readings' passed directories, and both reports.
def kept-of [kept: record, a: record, b: record]: nothing -> record {
    $kept | reject report | update identity_sha256 ([$a.identity_sha256 $b.identity_sha256] | compact | get -o 0) | update passed ($a.passed | append $b.passed) | insert reports [$a.report $b.report]
}

# Two reports' readings of one capture's run made one (read-identity). A
# reading from `none`, no evidence, yields to one with evidence, and of
# two such the report beside the capture is kept. Otherwise, their
# recorded `identity_sha256`, where both hold one, equal; their
# corrections, where both hold one, the same correction (correction-key).
# Their identities compared on every field, or over LEGACY_FIELDS and
# CORRECTABLE's two with each side's recorded seed where either is a
# report's one identity (shared-differences); each
# difference stands only where one side's correction changed that field
# from the other side's value to its own, a correction merely present
# explaining nothing. Anything else stops the read as ambiguous, naming
# both reports and each field with both values. The reading kept: the
# side whose correction explains the differences, else the one holding a
# correction, else the stronger source, the file before the embedded
# identity before the report's one, else the report beside the capture;
# the `identity_sha256` the one recorded, both readings' passes, and
# both reports.
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

# The workspace's commit and whether its tree held changes: where the
# SDK and the kernel came from.
def repo-of [workspace: path]: nothing -> record<dir: string, commit: string, dirty: bool> {
    let commit = (^git -C $workspace rev-parse --short HEAD | complete | get stdout | str trim)
    let status = (^git -C $workspace status --porcelain | complete | get stdout | str trim)
    { dir: $workspace, commit: $commit, dirty: ($status != "") }
}

# The program an image was built from: the directory its build wrote
# beside it as `home`, else, for an image built before that, the
# directory the image's nearest `.target` sits in.
def program-of [image: path]: nothing -> string {
    let marker = ($image | path expand | path dirname | path join "home")
    if ($marker | path exists) { return (open --raw $marker | decode | str trim) }
    let parts = ($image | path expand | path split)
    let marks = ($parts | enumerate | where {|e| $e.item == ".target" } | get index)
    if ($marks | is-empty) { $image | path expand | path dirname } else { $parts | first ($marks | last) | path join }
}

# The program's source revision: the commit an exported tree's
# source.nuon names, else the commit of the repository that tracks the
# program's manifest and main source, with whether they held changes;
# unknown otherwise. A repository merely enclosing an export, which
# tracks none of it, says nothing about it.
def program-source [dir: string]: nothing -> record<dir: string, commit: oneof<string, nothing>, dirty: oneof<bool, nothing>, from: oneof<string, nothing>> {
    let marker = ($dir | path join "source.nuon")
    if ($marker | path exists) { return { dir: $dir, commit: (open $marker | get -o commit), dirty: null, from: "source.nuon" } }
    let owned = (do { cd $dir; ^git ls-files --error-unmatch program.jab.toml src/main.S | complete })
    if $owned.exit_code != 0 { return { dir: $dir, commit: null, dirty: null, from: null } }
    let commit = (^git -C $dir rev-parse --short HEAD | complete | get stdout | str trim)
    let status = (do { cd $dir; ^git status --porcelain -- . | complete | get stdout | str trim })
    { dir: $dir, commit: $commit, dirty: ($status != ""), from: "git" }
}

# A file's SHA-256, or null when it is not there.
def digest [file: path]: nothing -> oneof<string, nothing> {
    if ($file | path exists) { open --raw $file | into binary | hash sha256 } else { null }
}

# A tree's digest: every file's path under it and its SHA-256, one a
# line in path order, hashed.
def tree-digest [tree: path]: nothing -> oneof<string, nothing> {
    if not ($tree | path exists) { return null }
    glob ($tree | path join "**" "*") | where {|f| ($f | path type) == "file" } | sort | each {|f| $"($f | path relative-to $tree) (open --raw $f | into binary | hash sha256)" } | str join (char nl) | hash sha256
}

# What a launch came to: its status, a fault line on the UART, the CPU
# and wall seconds, each QEMU thread's CPU over a second `jab launch
# --threads` held with that span, empty and null when none was held, every
# reading `--threads-at` asked for kept whole, and the machine it ran on,
# its line and its record.
def outcome [launched: record]: nothing -> record {
    {
        status: $launched.status,
        fault: ($launched.serial | lines | where {|l| $l starts-with "jab: " } | get -o 0),
        cpu_seconds: $launched.cpu_seconds,
        wall_seconds: $launched.wall_seconds,
        threads: ($launched | get -o threads | default []),
        threads_span: ($launched | get -o threads_span),
        thread_readings: ($launched | get -o thread_readings | default []),
        qemu_binary: $launched.qemu_binary,
        qemu: $launched.qemu,
        machine: $launched.machine,
        window: $launched.window,
        audio: $launched.audio,
    }
}

# The times a run's CPU is read at, the readings cpu-windows reads:
# CPU_FROM, every placement of the route, and the route's end, each once,
# in order.
export def cpu-requests [legs: list<any>, end: duration]: nothing -> list<duration> {
    [$CPU_FROM] | append ($legs | each {|l| $l.places | each {|p| $p.at } } | flatten) | append $end | uniq | sort
}

# A run's CPU readings as windows, the CPU contract. A reading's times are
# host seconds from the launch's start, which comes before QEMU's spawn
# where the frames' clock begins at the program's start; it is taken as
# the launch polls, every 100 ms, so its actual time trails its request;
# and a placement takes effect at the frame after it, so a window is host
# time near the legs and never a count of the guest's frames. The whole
# window runs from the reading at CPU_FROM to the one at the route's end;
# a leg's window from its first placement's reading to the next leg's
# first placement's, the last leg's to the end, the readings at a leg's
# further placements its subwindows; CPU_FROM's reading bounds the whole
# window alone. A window gives its actual interval and each thread's CPU
# seconds, the counters' difference, with its utilization, those seconds
# over the interval, null for a thread absent from either bound; a window
# whose bound is missing is missing, never bridged across.
export def cpu-windows [readings: list<any>, legs: list<any>, end: duration]: nothing -> record {
    let reading = {|at: duration|
        let s = ($at / 1sec)
        $readings | where {|r| (($r.requested - $s) | math abs) < 0.000001 } | get -o 0
    }
    let between = {|name: string, from: duration, to: duration| cpu-window $name (do $reading $from) (do $reading $to) $from $to }
    let starts = ($legs | where {|l| not ($l.places | is-empty) } | each {|l| { leg: $l.name, places: ($l.places | each {|p| $p.at }) } })
    let leg_windows = ($starts | enumerate | each {|e|
        let from = ($e.item.places | first)
        let to = (if ($e.index + 1) < ($starts | length) { $starts | get ($e.index + 1) | get places | first } else { $end })
        let marks = ($e.item.places | append $to)
        let subs = (if ($e.item.places | length) < 2 { [] } else {
            $marks | window 2 | enumerate | each {|w| do $between $"($e.item.leg) ($w.index + 1)" ($w.item | get 0) ($w.item | get 1) }
        })
        do $between $e.item.leg $from $to | insert subwindows $subs
    })
    { whole: (do $between "whole" $CPU_FROM $end), legs: $leg_windows }
}

# One CPU window between two readings (cpu-windows): missing when either
# reading is absent or was never taken.
def cpu-window [name: string, first: any, second: any, from: duration, to: duration]: nothing -> record {
    let base = { window: $name, requested_from: ($from / 1sec), requested_to: ($to / 1sec) }
    let taken = ($first != null and $second != null and ($first | get -o at) != null and ($second | get -o at) != null)
    if not $taken {
        return ($base | merge { missing: true, from: ($first | get -o at), to: ($second | get -o at), interval: null, threads: [] })
    }
    let interval = ($second.at - $first.at)
    let ids = ($first.threads | each {|t| $t.id } | append ($second.threads | each {|t| $t.id }) | uniq)
    let threads = ($ids | each {|id|
        let a = ($first.threads | where id == $id | get -o 0)
        let b = ($second.threads | where id == $id | get -o 0)
        let name = (if $b != null { $b.name } else { $a.name })
        if $a == null or $b == null { { id: $id, name: $name, cpu_seconds: null, utilization: null } } else {
            let seconds = ($b.cpu - $a.cpu)
            { id: $id, name: $name, cpu_seconds: $seconds, utilization: (if $interval > 0 { $seconds / $interval } else { null }) }
        }
    })
    $base | merge { missing: false, from: $first.at, to: $second.at, interval: $interval, threads: $threads }
}

# A record's 32-bit word at a byte offset, or its 64-bit one.
def u32-at [r: binary, at: int]: nothing -> int { $r | bytes at $at..<($at + 4) | into int --endian little }
def u64-at [r: binary, at: int]: nothing -> int { $r | bytes at $at..<($at + 8) | into int --endian little }

# A capture read in the order its records came, up to and including the
# first end marker: the state records, the n-th frame n's, with the
# placements the console answered before each, whether an R was answered
# before the first state and whether one came later, the same for a C and
# a W, the game's events with the frame each fell in, the frame, draw,
# presentation, and packet records, kinds 7, 8, 10, and 12, each field
# microseconds or a count, a packet record's workers, grain, and round
# times from its schema 4 and null below it, and the marker, kind 9, with
# its frame and schema, null when none came. What follows the marker is
# outside the measurement: its state records are counted as `past` and
# nothing else in it is read.
export def stream [api: binary]: nothing -> record<states: list<any>, events: list<any>, seeded: bool, late_seed: bool, cadence_set: bool, late_cadence: bool, workers_set: bool, late_workers: bool, frames: list<any>, draws: list<any>, presents: list<any>, packets: list<any>, end: oneof<record<frame: int, schema: int>, nothing>, past: int> {
    mut states = []
    mut events = []
    mut frames = []
    mut draws = []
    mut presents = []
    mut packets = []
    mut placed = 0
    mut seeded = false
    mut late_seed = false
    mut cadence_set = false
    mut late_cadence = false
    mut workers_set = false
    mut late_workers = false
    mut end: any = null
    mut past = 0
    for r in ($api | chunks $RECORD | where {|c| ($c | bytes length) == $RECORD }) {
        let kind = ($r | bytes at 0..<1 | into int)
        if $end != null {
            if $kind == $KIND_STATE { $past += 1 }
        } else if $kind == $KIND_CONSOLE {
            let command = ($r | bytes at 4..<5 | into int)
            if $command == $CONSOLE_P { $placed += 1 }
            if $command == $CONSOLE_R {
                if ($states | is-empty) { $seeded = true } else { $late_seed = true }
            }
            if $command == $CONSOLE_C {
                if ($states | is-empty) { $cadence_set = true } else { $late_cadence = true }
            }
            if $command == $CONSOLE_W {
                if ($states | is-empty) { $workers_set = true } else { $late_workers = true }
            }
        } else if $kind == $KIND_STATE {
            $states = ($states | append {
                frame: ($states | length), placed: $placed,
                sector: ($r | bytes at 4..<8 | into int --endian little --signed),
                x: (map float-at $r 8), y: (map float-at $r 12), z: (map float-at $r 16), yaw: (map float-at $r 20),
                draw_us: (u32-at $r 32), game_us: (u32-at $r 36),
            })
        } else if $kind >= 2 and $kind <= 6 {
            $events = ($events | append {
                frame: ($states | length), kind: $kind,
                fields: (0..<5 | each {|f| $r | bytes at (40 + $f * 4)..<(44 + $f * 4) | into int --endian little --signed }),
            })
        } else if $kind == $KIND_FRAME {
            $frames = ($frames | append {
                frame: (u32-at $r 4), start_us: (u64-at $r 8), critical_us: (u32-at $r 16), game_us: (u32-at $r 20),
                draw_us: (u32-at $r 24), hud_us: (u32-at $r 28), mix_us: (u32-at $r 32), flip_us: (u32-at $r 36),
                report_us: (u32-at $r 40), await_us: (u32-at $r 44), flip_done_us: (u64-at $r 48),
                flip_status: (u32-at $r 56), schema: (u32-at $r 60),
            })
        } else if $kind == $KIND_DRAW {
            $draws = ($draws | append {
                frame: (u32-at $r 4), clear_us: (u32-at $r 8), portals_us: (u32-at $r 12), planes_us: (u32-at $r 16),
                walls_us: (u32-at $r 20), sprites_us: (u32-at $r 24), tiles_us: (u32-at $r 28), tiles_built: (u32-at $r 32),
                tile_resets: (u32-at $r 36), tiled_pixels: (u32-at $r 40), lit_pixels: (u32-at $r 44),
                tile_bytes: (u32-at $r 48), tile_peak: (u32-at $r 52), spans: (u32-at $r 56), schema: (u32-at $r 60),
            })
        } else if $kind == $KIND_PRESENT {
            $presents = ($presents | append {
                frame: (u32-at $r 4), simulation_us: (u64-at $r 8), next_start_us: (u64-at $r 16), wait_us: (u32-at $r 24),
                pacing_us: (u32-at $r 28), wakes: (u32-at $r 32), wait_presses: (u32-at $r 36), flip_attempts: (u32-at $r 40),
                refusals: (u32-at $r 44), cadence: (u32-at $r 48), schema: (u32-at $r 60),
            })
        } else if $kind == $KIND_PACKET {
            let schema = (u32-at $r 60)
            let workers = (if $schema >= 4 {
                { workers: (u32-at $r 36), grain: (u32-at $r 40), slowest_us: (u32-at $r 44), busy_us: (u32-at $r 48), dispatch_us: (u32-at $r 52), barrier_us: (u32-at $r 56) }
            } else {
                { workers: null, grain: null, slowest_us: null, busy_us: null, dispatch_us: null, barrier_us: null }
            })
            $packets = ($packets | append ({
                frame: (u32-at $r 4), preparation_us: (u32-at $r 8), raster_us: (u32-at $r 12), commands: (u32-at $r 16),
                flushes: (u32-at $r 20), invalidated: (u32-at $r 24), packet_bytes: (u32-at $r 28), snapshot: (u32-at $r 32),
                schema: $schema,
            } | merge $workers))
        } else if $kind == $KIND_END {
            $end = { frame: (u32-at $r 4), schema: (u32-at $r 60) }
        }
    }
    {
        states: $states, events: $events, seeded: $seeded, late_seed: $late_seed, cadence_set: $cadence_set,
        late_cadence: $late_cadence, workers_set: $workers_set, late_workers: $late_workers, frames: $frames,
        draws: $draws, presents: $presents, packets: $packets, end: $end, past: $past,
    }
}

# The schema a capture's clock records sit at: its end marker's, else its
# first clock record's; null for a capture with none.
def schema-of [s: record]: nothing -> oneof<int, nothing> {
    if $s.end != null { return $s.end.schema }
    let first = ($s.frames | append $s.draws | append $s.presents | append $s.packets | get -o 0)
    if $first == null { null } else { $first.schema }
}

# The critical path's phases at a schema, schema 1's for one this reader
# does not take.
def phases-of [schema: oneof<int, nothing>]: nothing -> list<string> {
    $PHASES | get -o ($schema | default 1 | into string) | default ($PHASES | get "1")
}

# The drawing's parts at a schema, schema 1's for one this reader does
# not take.
def parts-of [schema: oneof<int, nothing>]: nothing -> list<string> {
    $PARTS | get -o ($schema | default 1 | into string) | default ($PARTS | get "1")
}

# What a run's moved parts measure, the phases' class and the
# remainder's, with the evidence: schema 1 its phases with rendering and
# its remainder holding none, the rendering inside the phases; schemas 3
# and 4 their phases preparation alone and their remainder holding no
# rendering, the raster a part of its own, by the workers or not; schema
# 2 a listed image's classes
# (PHASE_IMAGES) by the SHA-256 its identity records, whatever its
# identity's commit or dirty flag says, since the commit is the
# checkout's at launch and never the image's; any other run unknown. A
# measurement written before schema 2 was read is at schema 1, as compare
# hands it here.
def parts-meaning [schema: any, image: any]: nothing -> record<phases: string, remainder: string, evidence: string> {
    if $schema == 1 { return { phases: $WITH_RENDERING, remainder: $NO_RENDERING, evidence: "schema 1" } }
    if $schema == 3 { return { phases: $PREPARATION_ALONE, remainder: $NO_RENDERING, evidence: "schema 3" } }
    if $schema == 4 { return { phases: $PREPARATION_ALONE, remainder: $NO_RENDERING, evidence: "schema 4" } }
    let listed = (if $schema == 2 and $image != null { $PHASE_IMAGES | transpose image entry | where image == $image | get -o 0.entry } else { null })
    if $listed != null {
        return { phases: $listed.phases, remainder: $listed.remainder, evidence: $"the listed image of ($listed.commit | str substring 0..<7), ($listed.set)" }
    }
    let why = (if $schema == 2 { "schema 2 with no listed image" } else { $"schema ($schema | default 'none')" })
    { phases: $UNKNOWN_PARTS, remainder: $UNKNOWN_PARTS, evidence: $why }
}

# The schema 2 images whose parts are known (PHASE_IMAGES), by SHA-256.
export def phase-images []: nothing -> record {
    $PHASE_IMAGES
}

# A capture measured: its window, every frame in it as a row with its
# leg, the leg's summaries, the outliers, and the outcomes. The window is
# the capture read in order through its first end marker (stream): it is
# complete when its clock records sit at one schema this reader takes,
# the marker names the final frame, and every frame from 0 to it has its
# state, its frame record, its draw record, from schema 2 its
# presentation record, and from schema 3 its packet record before the
# marker, numbered in order with none twice; what follows the marker
# counts for nothing, a record sent late or a second marker alike. A
# complete window is valid unless a flip was never shown or not presented
# as its cadence requires, a phase or a part sums past its whole, a
# frame's clock disagrees with its state, or from schema 2 a frame's
# presentation or from schema 3 its packets break their rules (invalidity);
# it passes when it is valid and no frame reaches the ceiling. A frame is
# fast when its critical path is under the period of `cap`, whatever its
# cadence. A capture with no record of the clock's kinds, 7, 8, 9, 10, or
# 12, is a build older than them: its rows are its state records' alone
# and it holds no window. Any one of them marks the capture clocked and
# holds it to its window.
export def measure [api: binary, legs: list<any>, --cap: int = 60]: nothing -> record {
    let s = (stream $api)
    let clocked = (([$s.frames $s.draws $s.presents $s.packets] | any {|k| not ($k | is-empty) }) or $s.end != null)
    let schema = (if $clocked { schema-of $s } else { null })
    let final = (if $s.end == null { null } else { $s.end.frame })
    let problems = (if not $clocked { [] } else { window-problems $s $schema })
    let complete = ($clocked and ($problems | is-empty))
    let last = (if not $clocked { ($s.states | length) - 1 } else if $final == null { ($s.frames | length) - 1 } else { $final })
    let rows = (rows-of $s $legs $last $schema)
    let invalid = (if $complete { invalidity $rows $schema } else { [] })
    let valid = ($complete and ($invalid | is-empty))
    let period_us = (1000000 / $cap)
    let names = ($legs | get name)
    let summaries = ($names | each {|n| leg-summary $n ($rows | where leg == $n) $period_us } | where frames > 0)
    {
        clocked: $clocked,
        schema: $schema,
        complete: $complete,
        final: $final,
        problems: $problems,
        valid: $valid,
        invalid: $invalid,
        seeded: $s.seeded,
        late_seed: $s.late_seed,
        cadence_set: $s.cadence_set,
        late_cadence: $s.late_cadence,
        cadences: ($rows | get -o cadence | compact | uniq | sort),
        workers_set: $s.workers_set,
        late_workers: $s.late_workers,
        workers: ($rows | get -o workers | compact | uniq | sort),
        grains: ($rows | get -o grain | compact | uniq | sort),
        period_us: $period_us,
        frames: ($rows | length),
        past_window: $s.past,
        passes: ($valid and ($rows | where {|r| $r.over } | is-empty)),
        over: (if $clocked { $rows | where {|r| $r.over == true } | length } else { null }),
        whole: (leg-summary "whole" $rows $period_us),
        legs: $summaries,
        outliers: (if $clocked { outliers $rows $schema } else { [] }),
        outcomes: (outcomes-of $s.events $rows $last),
        rows: $rows,
    }
}

# What keeps a window from being complete, read from the records before
# its end marker alone: no marker, a capture whose schema this reader
# does not take, a clock record at a schema other than the capture's, a
# record numbered out of order or twice, and a frame short of a record or
# one too many, the presentation records counted from schema 2 and the
# packet records from schema 3.
def window-problems [s: record, schema: oneof<int, nothing>]: nothing -> list<string> {
    mut problems = []
    if $s.end == null {
        $problems = ($problems | append "no end marker: the measurement never closed")
    }
    if $schema not-in $SCHEMAS {
        $problems = ($problems | append $"the clock records at schema ($schema), this reader's being ($SCHEMAS | str join ', ')")
    }
    let last = (if $s.end == null { ($s.frames | length) - 1 } else { $s.end.frame })
    let at = ($schema | default 1)
    let records = ([[name items]; [frame $s.frames] [draw $s.draws]]
        | append (if $at >= 2 { [[name items]; [presentation $s.presents]] } else { [] })
        | append (if $at >= 3 { [[name items]; [packet $s.packets]] } else { [] }))
    for kind in $records {
        let order = ($kind.items | enumerate | where {|e| $e.item.frame != $e.index } | length)
        if $order > 0 { $problems = ($problems | append $"($order) ($kind.name) records out of order or repeated") }
        if ($kind.items | length) != ($last + 1) { $problems = ($problems | append $"($kind.items | length) ($kind.name) records before the end marker for ($last + 1) frames") }
    }
    if ($s.states | length) != ($last + 1) { $problems = ($problems | append $"($s.states | length) state records before the end marker for ($last + 1) frames") }
    let marker = (if $s.end == null { [] } else { [$s.end.schema] })
    let others = ($s.frames | append $s.draws | append $s.presents | append $s.packets | each {|r| $r.schema } | append $marker | uniq | where {|v| $v != $schema })
    if not ($others | is-empty) { $problems = ($problems | append $"clock records at schemas ($others | str join ', ') in a capture at schema ($schema)") }
    $problems
}

# What makes a complete window invalid. At any schema: a flip at a status
# other than presented or refused as early, which is a frame never shown;
# a frame whose phases or whose drawing's parts sum past their whole; a
# frame whose clock record's drawing or game time differs from its
# state's. From schema 2: a frame without its presentation record, which
# the rest are read without; a cadence outside 0 to 2; under cadence 0 a wait
# or a pacing, or attempts other than one; under 1 and 2 a final flip not
# presented, since those cadences flip again on a refusal; attempts other
# than the refusals and the final attempt, which is a refusal itself only
# when its status says so; a frame whose next start less its start is not
# its critical path, its wait, and its await to within RESIDUAL_US; a
# frame whose start, simulation, flip end, and next start do not come in
# that order, so no submission age is negative, a frame that reached no
# flip keeping a flip end from before its start; and a next start that is
# not the next frame's start. From schema 3: a frame without its packet
# record, which the rest are read without; a frame whose drawing less its
# preparation and its raster is not 0 to PACKET_RESIDUAL_US, so the raster
# lies within the drawing; a frame whose packets' bytes are not its
# commands' and its span records'; and a frame whose packets were
# prepared from another frame's simulation, a stale snapshot drawn. At
# schema 4: a frame drawn by more than WORKERS_MAX workers; one at a grain
# past the screen's rows; one of the serial backend, 0 workers, carrying
# a round's time; one whose slowest worker, dispatch, or barrier is past
# its raster, each a part of the raster's span on hart 0; and one whose
# workers' busy time is less than its slowest worker's, which it sums, or
# past W times it with the W - 1 microseconds the conversions drop, since
# each round's busy time is at most W times its slowest and each total is
# converted once.
def invalidity [rows: list<any>, schema: oneof<int, nothing>]: nothing -> list<string> {
    let unshown = ($rows | where {|r| $r.flip_status not-in $FLIP_VALID })
    let negative = ($rows | where {|r| $r.unattributed_us < 0 or $r.parts_unattributed_us < 0 })
    let misaligned = ($rows | where {|r| not $r.aligned })
    let base = [
        (if ($unshown | is-empty) { null } else { $"($unshown | length) flips at status ($unshown | get flip_status | uniq | each {|v| $v | into string } | str join ', '), never shown" }),
        (if ($negative | is-empty) { null } else { $"($negative | length) frames whose phases or parts sum past their whole" }),
        (if ($misaligned | is-empty) { null } else { $"($misaligned | length) frames whose clock record differs from their state's" }),
    ]
    let at = ($schema | default 1)
    if $at < 2 { return ($base | compact) }
    let every = $rows
    let unrecorded = ($every | where {|r| $r.cadence == null })
    let rows = ($every | where {|r| $r.cadence != null })
    let outside = ($rows | where {|r| $r.cadence not-in $CADENCES })
    let after = ($rows | where {|r| $r.cadence == $CADENCE_AFTER_FLIP })
    let waited = ($after | where {|r| $r.wait_us != 0 or $r.pacing_us != 0 })
    let retried = ($after | where {|r| $r.flip_attempts != 1 })
    let unpresented = ($rows | where {|r| $r.cadence in [1 2] and $r.flip_status != $FLIP_PRESENTED })
    let counted = ($rows | where {|r| $r.flip_attempts != ($r.refusals + (if $r.flip_status == $FLIP_EARLY { 0 } else { 1 })) })
    let unbalanced = ($rows | where {|r| $r.residual_us < 0 or $r.residual_us > $RESIDUAL_US })
    let disordered = ($rows | where {|r| not ($r.start_us <= $r.simulation_us and $r.simulation_us <= $r.flip_done_us and $r.flip_done_us <= $r.next_start_us) })
    let broken = ($rows | window 2 | where {|w| $w.0.next_start_us != $w.1.start_us })
    let presented = [
        (if ($unrecorded | is-empty) { null } else { $"($unrecorded | length) frames without a presentation record" }),
        (if ($outside | is-empty) { null } else { $"($outside | length) frames at a cadence outside 0 to 2" }),
        (if ($waited | is-empty) { null } else { $"($waited | length) frames under cadence 0 with a wait or a pacing" }),
        (if ($retried | is-empty) { null } else { $"($retried | length) frames under cadence 0 whose flip was attempted other than once" }),
        (if ($unpresented | is-empty) { null } else { $"($unpresented | length) frames under cadence 1 or 2 whose final flip was not presented" }),
        (if ($counted | is-empty) { null } else { $"($counted | length) frames whose attempts are not their refusals and their final attempt" }),
        (if ($unbalanced | is-empty) { null } else { $"($unbalanced | length) frames whose next start less their start is not their critical path, wait, and await" }),
        (if ($disordered | is-empty) { null } else { $"($disordered | length) frames whose start, simulation, flip end, and next start are out of order" }),
        (if ($broken | is-empty) { null } else { $"($broken | length) frames whose next start is not the next frame's start" }),
    ]
    if $at < 3 { return ($base | append $presented | compact) }
    let unpacked = ($every | where {|r| $r.raster_us == null })
    let packed = ($every | where {|r| $r.raster_us != null })
    let unsplit = ($packed | where {|r| $r.packet_residual_us < 0 or $r.packet_residual_us > $PACKET_RESIDUAL_US })
    let unsized = ($packed | where {|r| $r.packet_bytes != ($r.commands * $COMMAND_BYTES + $r.spans * $SPAN_BYTES) })
    let stale = ($packed | where {|r| $r.snapshot != $r.frame })
    let packets = [
        (if ($unpacked | is-empty) { null } else { $"($unpacked | length) frames without a packet record" }),
        (if ($unsplit | is-empty) { null } else { $"($unsplit | length) frames whose drawing is not their preparation and their raster" }),
        (if ($unsized | is-empty) { null } else { $"($unsized | length) frames whose packets' bytes are not their commands' and their span records'" }),
        (if ($stale | is-empty) { null } else { $"($stale | length) frames whose packets were prepared from another frame's simulation" }),
    ]
    if $at < 4 { return ($base | append $presented | append $packets | compact) }
    let crowded = ($packed | where {|r| ($r.workers | default 0) > $WORKERS_MAX })
    let coarse = ($packed | where {|r| ($r.grain | default 0) > $SCREEN_ROWS })
    let serial_timed = ($packed | where {|r| $r.workers == 0 and ([$r.slowest_us $r.busy_us $r.dispatch_us $r.barrier_us] | any {|t| ($t | default 0) != 0 }) })
    let overtimed = ($packed | where {|r| ($r.workers | default 0) > 0 and ([$r.slowest_us $r.dispatch_us $r.barrier_us] | any {|t| ($t | default 0) > $r.raster_us }) })
    let short_busy = ($packed | where {|r| ($r.workers | default 0) > 0 and ($r.busy_us | default 0) < ($r.slowest_us | default 0) })
    let long_busy = ($packed | where {|r| let w = ($r.workers | default 0); $w > 0 and ($r.busy_us | default 0) > ($w * ($r.slowest_us | default 0) + $w - 1) })
    $base | append $presented | append $packets | append [
        (if ($crowded | is-empty) { null } else { $"($crowded | length) frames drawn by more than ($WORKERS_MAX) workers" }),
        (if ($coarse | is-empty) { null } else { $"($coarse | length) frames at a grain past the screen's ($SCREEN_ROWS) rows" }),
        (if ($serial_timed | is-empty) { null } else { $"($serial_timed | length) frames of the serial backend carrying a round's time" }),
        (if ($overtimed | is-empty) { null } else { $"($overtimed | length) frames whose slowest worker, dispatch, or barrier is past their raster" }),
        (if ($short_busy | is-empty) { null } else { $"($short_busy | length) frames whose workers' busy time is less than their slowest's" }),
        (if ($long_busy | is-empty) { null } else { $"($long_busy | length) frames whose workers' busy time is past W times their slowest's" }),
    ] | compact
}

# Every frame from 0 to `last` as one row: its leg (by the placements
# answered before it), whether a placement opened it, its state, and
# with the clock records its phases, the time it left unattributed, its
# flip's interval from the presented one before and its latency from
# its start, the drawing's parts, and the tile cache's counts; from
# schema 2 its presentation too, the submission age from its simulation
# to its presented flip's end and the residual its next start leaves past
# its start, critical path, wait, and await; from schema 3 its packets,
# the preparation, the raster, the commands, the flushes, the bindings
# invalidated, the bytes, the snapshot, and what its drawing leaves past
# its preparation and its raster, and at schema 4 the workers, the grain,
# and the rounds' slowest worker, busy time, dispatch, and barrier.
# Without the clock records the clock's columns are null, the
# presentation's below schema 2 or without its record, the packets' below
# schema 3 or without theirs, and the workers' below schema 4.
def rows-of [s: record, legs: list<any>, last: int, schema: oneof<int, nothing>]: nothing -> list<any> {
    let names = ($legs | get name)
    let reach = ($legs | enumerate | each {|e| $legs | first ($e.index + 1) | each {|l| $l.places | length } | math sum })
    let phases = (phases-of $schema)
    let parts = (parts-of $schema)
    let at = ($schema | default 1)
    mut rows = []
    mut previous_flip: any = null
    for e in ($s.states | first ($last + 1) | enumerate) {
        let st = $e.item
        let leg_at = ($reach | enumerate | where {|r| $r.item >= $st.placed } | get -o 0.index | default (($names | length) - 1))
        let entry = (if $e.index == 0 { true } else { ($s.states | get ($e.index - 1) | get placed) != $st.placed })
        let f = ($s.frames | get -o $st.frame)
        let d = ($s.draws | get -o $st.frame)
        let p = (if $at >= 2 { $s.presents | get -o $st.frame } else { null })
        let k = (if $at >= 3 { $s.packets | get -o $st.frame } else { null })
        let base = {
            frame: $st.frame, leg: ($names | get $leg_at), entry: $entry, sector: $st.sector,
            x: $st.x, y: $st.y, z: $st.z, yaw: $st.yaw, draw_us: $st.draw_us, game_us: $st.game_us,
        }
        if $f == null or $d == null {
            $rows = ($rows | append ($base | merge (clockless)))
        } else {
            let presented = ($f.flip_status == $FLIP_PRESENTED)
            let interval = (if $presented and $previous_flip != null { $f.flip_done_us - $previous_flip } else { null })
            if $presented { $previous_flip = $f.flip_done_us }
            let shown = (if $p == null { presentationless } else { {
                cadence: $p.cadence, simulation_us: $p.simulation_us, next_start_us: $p.next_start_us,
                wait_us: $p.wait_us, pacing_us: $p.pacing_us, wakes: $p.wakes, wait_presses: $p.wait_presses,
                flip_attempts: $p.flip_attempts, refusals: $p.refusals,
                submission_age_us: (if $presented { $f.flip_done_us - $p.simulation_us } else { null }),
                residual_us: ($p.next_start_us - $f.start_us - ($f.critical_us + $p.wait_us + $f.await_us)),
            } })
            let timed = ($f | upsert pacing_us ($shown.pacing_us | default 0))
            let packed = (if $k == null { packetless } else { {
                preparation_us: $k.preparation_us, raster_us: $k.raster_us, commands: $k.commands, flushes: $k.flushes,
                invalidated: $k.invalidated, packet_bytes: $k.packet_bytes, snapshot: $k.snapshot,
                packet_residual_us: ($f.draw_us - $k.preparation_us - $k.raster_us),
                workers: $k.workers, grain: $k.grain, slowest_us: $k.slowest_us, busy_us: $k.busy_us,
                dispatch_us: $k.dispatch_us, barrier_us: $k.barrier_us,
            } })
            let drawn = ($d | upsert raster_us ($packed.raster_us | default 0))
            $rows = ($rows | append ($base | merge {
                start_us: $f.start_us, critical_us: $f.critical_us, hud_us: $f.hud_us, mix_us: $f.mix_us,
                flip_us: $f.flip_us, report_us: $f.report_us, await_us: $f.await_us, flip_done_us: $f.flip_done_us,
                flip_status: $f.flip_status, flip_interval_us: $interval, latency_us: ($f.flip_done_us - $f.start_us),
                unattributed_us: ($f.critical_us - ($phases | each {|ph| $timed | get $ph } | math sum)),
                clear_us: $d.clear_us, portals_us: $d.portals_us, planes_us: $d.planes_us, walls_us: $d.walls_us,
                sprites_us: $d.sprites_us, tiles_us: $d.tiles_us,
                parts_unattributed_us: ($f.draw_us - ($parts | each {|pt| $drawn | get $pt } | math sum)),
                tiles_built: $d.tiles_built, tile_resets: $d.tile_resets, tiled_pixels: $d.tiled_pixels,
                lit_pixels: $d.lit_pixels, fallback_pixels: ($d.lit_pixels - $d.tiled_pixels),
                tile_bytes: $d.tile_bytes, tile_peak: $d.tile_peak, spans: $d.spans, spans_over: ($d.spans > $SPAN_RECORDS),
                over: ($f.critical_us >= $CEILING_US),
                aligned: ($f.draw_us == $st.draw_us and $f.game_us == $st.game_us),
            } | merge $shown | merge $packed))
        }
    }
    $rows
}

# The clock's columns of a row with no clock records, all null, the
# presentation's and the packets' among them.
def clockless []: nothing -> record {
    [start_us critical_us hud_us mix_us flip_us report_us await_us flip_done_us flip_status flip_interval_us latency_us unattributed_us clear_us portals_us planes_us walls_us sprites_us tiles_us parts_unattributed_us tiles_built tile_resets tiled_pixels lit_pixels fallback_pixels tile_bytes tile_peak spans spans_over over aligned]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
    | merge (presentationless)
    | merge (packetless)
}

# The presentation's columns of a row below schema 2, all null.
def presentationless []: nothing -> record {
    [cadence simulation_us next_start_us wait_us pacing_us wakes wait_presses flip_attempts refusals submission_age_us residual_us]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}

# The packets' columns of a row below schema 3, all null, the workers'
# among them.
def packetless []: nothing -> record {
    [preparation_us raster_us commands flushes invalidated packet_bytes snapshot packet_residual_us workers grain slowest_us busy_us dispatch_us barrier_us]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}

# A value list's count, least, median, 95th and 99th percentiles where
# twenty and a hundred values allow, and greatest, each by nearest rank.
def stats [values: list<any>]: nothing -> record {
    let v = ($values | compact)
    let n = ($v | length)
    if $n == 0 { return { count: 0, min: null, median: null, p95: null, p99: null, max: null } }
    let s = ($v | sort)
    let rank = {|q: float| $s | get ((($q * $n) | math ceil) - 1) }
    { count: $n, min: ($s | first), median: (do $rank 0.5), p95: (if $n >= 20 { do $rank 0.95 } else { null }), p99: (if $n >= 100 { do $rank 0.99 } else { null }), max: ($s | last) }
}

# A sum that is 0 for no values.
def total [values: list<any>]: nothing -> int {
    let v = ($values | compact)
    if ($v | is-empty) { 0 } else { $v | math sum }
}

# A leg's frames summed up: the counts, then with the clock records the
# critical path and every phase, the flips, the unattributed time, the
# drawing's parts, the tile cache, the presentation, the packets, and the
# workers that drew them with their rounds' times, the fast frames, their
# critical path under `period_us`, with those among them that waited
# before their flip apart; the drawing's and the game's times alone
# without them.
def leg-summary [name: string, rows: list<any>, period_us: number]: nothing -> record {
    let clocked = ($rows | where {|r| $r.critical_us != null })
    let base = { leg: $name, frames: ($rows | length), entries: ($rows | where entry | length), draw: (stats ($rows | get draw_us)), game: (stats ($rows | get game_us)) }
    if ($clocked | is-empty) { return $base }
    let fast = ($clocked | where {|r| $r.critical_us < $period_us })
    let held = ($clocked | get packet_bytes | compact)
    $base | merge {
        over: ($clocked | where {|r| $r.over } | length),
        fast: ($fast | length),
        fast_waited: ($fast | where {|r| ($r.wait_us | default 0) > 0 } | length),
        wait: (stats ($clocked | get wait_us)),
        pacing: (stats ($clocked | get pacing_us)),
        submission_age: (stats ($clocked | get submission_age_us)),
        wakes: (total ($clocked | get wakes)),
        wait_presses: (total ($clocked | get wait_presses)),
        attempts: (total ($clocked | get flip_attempts)),
        refusals: (total ($clocked | get refusals)),
        critical: (stats ($clocked | get critical_us)),
        hud: (stats ($clocked | get hud_us)),
        mix: (stats ($clocked | get mix_us)),
        flip: (stats ($clocked | get flip_us)),
        report: (stats ($clocked | get report_us)),
        await: (stats ($clocked | get await_us)),
        flips_early: ($clocked | where {|r| $r.flip_status == $FLIP_EARLY } | length),
        flips_failed: ($clocked | where {|r| $r.flip_status > $FLIP_EARLY } | length),
        flip_interval: (stats ($clocked | get flip_interval_us)),
        latency: (stats ($clocked | get latency_us)),
        unattributed: (stats ($clocked | get unattributed_us)),
        parts_unattributed: (stats ($clocked | get parts_unattributed_us)),
        clear: (stats ($clocked | get clear_us)),
        portals: (stats ($clocked | get portals_us)),
        planes: (stats ($clocked | get planes_us)),
        walls: (stats ($clocked | get walls_us)),
        sprites: (stats ($clocked | get sprites_us)),
        tiles: (stats ($clocked | get tiles_us)),
        tiles_built: (total ($clocked | get tiles_built)),
        building_frames: ($clocked | where {|r| $r.tiles_built > 0 } | length),
        tiled_pixels: (total ($clocked | get tiled_pixels)),
        fallback_pixels: (total ($clocked | get fallback_pixels)),
        tile_bytes_max: ($clocked | get tile_bytes | math max),
        tile_peak: ($clocked | get tile_peak | math max),
        tile_resets: ($clocked | get tile_resets | math max),
        spans_max: ($clocked | get spans | math max),
        spans_over: ($clocked | where {|r| $r.spans_over } | length),
        misaligned: ($clocked | where {|r| not $r.aligned } | length),
        preparation: (stats ($clocked | get preparation_us)),
        raster: (stats ($clocked | get raster_us)),
        commands: (stats ($clocked | get commands)),
        flushes: (total ($clocked | get flushes)),
        invalidated: (total ($clocked | get invalidated)),
        packet_bytes_max: (if ($held | is-empty) { null } else { $held | math max }),
        workers: ($clocked | get workers | compact | uniq | sort),
        grains: ($clocked | get grain | compact | uniq | sort),
        slowest: (stats ($clocked | get slowest_us)),
        busy: (stats ($clocked | get busy_us)),
        dispatch: (stats ($clocked | get dispatch_us)),
        barrier: (stats ($clocked | get barrier_us)),
    }
}

# The unexplained phase outliers: in a frame no placement opened, a
# phase past OUTLIER_RATIO times its leg's median and OUTLIER_US over
# it, the frame's tile work within twice its leg's median. Kept in
# every statistic; a host stall is one explanation, not the finding.
def outliers [rows: list<any>, schema: oneof<int, nothing>]: nothing -> list<any> {
    let clocked = ($rows | where {|r| $r.critical_us != null })
    let watched = (phases-of $schema)
    $clocked | get leg | uniq | each {|leg|
        let these = ($clocked | where leg == $leg)
        let medians = ($watched | append "tiles_us" | reduce --fold {} {|p, acc| $acc | insert $p ((stats ($these | get $p)).median | default 0) })
        $these | where {|r| not $r.entry } | each {|r|
            let phases = ($watched | where {|p| let v = ($r | get $p | default 0); let m = ($medians | get $p); $v > ($OUTLIER_RATIO * $m) and ($v - $m) > $OUTLIER_US })
            let tiles_held = ($r.tiles_us <= (2 * ([($medians | get tiles_us) 100] | math max)))
            if ($phases | is-empty) or (not $tiles_held) { null } else {
                { frame: $r.frame, leg: $leg, phases: ($phases | each {|p| { phase: $p, us: ($r | get $p), median: ($medians | get $p) } }), critical_us: $r.critical_us }
            }
        } | compact
    } | flatten
}

# The play's outcomes within the window: the rounds by what they met,
# the androids' events by kind, the times the frame was struck, the
# pickups, and the sectors each leg's frames stood in.
def outcomes-of [events: list<any>, rows: list<any>, last: int]: nothing -> record {
    let inside = ($events | where {|e| $e.frame <= $last })
    let rounds = ($inside | where kind == 2 | each {|e| $MET | get -o ($e.fields | get 0) | default "unknown" } | uniq --count | each {|c| { met: $c.value, count: $c.count } })
    let androids = ($inside | where kind == 3 | each {|e| $ANDROID_EVENTS | get -o ($e.fields | get 0) | default "unknown" } | uniq --count | each {|c| { event: $c.value, count: $c.count } })
    {
        rounds: $rounds,
        androids: $androids,
        struck: ($inside | where kind == 4 | length),
        pickups: ($inside | where kind == 5 | length),
        sectors: ($rows | get leg | uniq | each {|leg| { leg: $leg, sectors: ($rows | where leg == $leg | get sector | uniq) } }),
    }
}

# One line on a run: complete or not and why, valid or not and why,
# passing or not, the schema, the critical path's spread, the seed, the
# cadence from schema 2, the workers and grain from schema 4, a program
# fault.
def run-line [label: string, n: int, m: record, ran: record]: nothing -> string {
    let name = (if $label == "" { "" } else { $"($label): " })
    let fault = (if ($ran.fault? | default null) == null { "" } else { $"; a program fault: ($ran.fault)" })
    if not $m.clocked {
        return $"gauge: ($name)run ($n): ($m.frames) frames from the state records alone; draw (spread $m.whole.draw), game (spread $m.whole.game)($fault)"
    }
    let state = (if not $m.complete {
        $"incomplete: ($m.problems | str join '; ')"
    } else if not $m.valid {
        $"complete but invalid: ($m.invalid | str join '; ')"
    } else if $m.passes {
        "complete, valid, passes"
    } else {
        $"complete, valid, fails: ($m.over) of ($m.frames) frames at or over 15 ms"
    })
    let seed = (if $m.seeded and (not $m.late_seed) { "seeded" } else if $m.late_seed { "seeded late, no paired comparison" } else { "unseeded" })
    let cadence = (if ($m.schema | default 1) < 2 {
        ""
    } else if $m.cadence_set and (not $m.late_cadence) {
        $"; cadence ($m.cadences | each {|c| $c | into string } | str join ', ')"
    } else if $m.late_cadence {
        "; cadence asked late, no paired comparison"
    } else {
        "; no cadence asked"
    })
    let workers = (if ($m.schema | default 1) < 4 {
        ""
    } else if ($m.late_workers? | default false) {
        "; workers asked late, no paired comparison"
    } else {
        $"; workers ($m.workers | each {|w| $w | into string } | str join ', ') at grain ($m.grains | each {|g| $g | into string } | str join ', ')"
    })
    $"gauge: ($name)run ($n): ($state); ($m.frames) frames to frame ($m.final) at schema ($m.schema), critical (spread $m.whole.critical) ms; ($seed)($cadence)($workers)($fault)"
}

# One line on what a run played and on what: the rounds by what they
# met, the androids' events, the times the player was struck, the
# pickups, the window, and the audio backend's driver.
def outcome-line [n: int, m: record, ran: record]: nothing -> string {
    let o = $m.outcomes
    let rounds = (if ($o.rounds | is-empty) { "none" } else { $o.rounds | each {|r| $"($r.met) ($r.count)" } | str join ", " })
    let androids = (if ($o.androids | is-empty) { "none" } else { $o.androids | each {|a| $"($a.event) ($a.count)" } | str join ", " })
    let window = ($ran.window? | default "unknown")
    let audio = ($ran.audio? | default "unknown" | split row "," | first)
    $"gauge:   run ($n) played: rounds ($rounds); androids ($androids); struck ($o.struck); pickups ($o.pickups); window ($window), audio ($audio)"
}

# A spread in milliseconds: least, median, 95th, 99th, greatest.
def spread [s: record]: nothing -> string {
    [$s.min $s.median $s.p95 $s.p99 $s.max] | each {|v| ms $v } | str join " / "
}

# Microseconds as milliseconds to a tenth, or a dash for none.
def ms [us: any]: nothing -> string {
    if $us == null { "-" } else { $"(($us / 1000.0) | math round --precision 1)" }
}

# A report's document: the label, the first run's identity as the
# report's one, the ceiling, every run with its outcome, its measurement
# less its rows, its effective identity and correction provenance, the
# SHA-256 of its identity file as recorded, null where none is, and from
# a read where the identity came from, its binding, the directories
# passed over, and the reports read, and its CPU windows, null without
# readings, and every row with its run.
export def report-doc [label: string, id: record, runs: list<any>]: nothing -> record {
    {
        label: $label,
        identity: $id,
        ceiling_us: $CEILING_US,
        runs: ($runs | each {|r| {
            run: $r.run, seed: $r.seed, out: $r.out, ran: $r.ran, measured: ($r.measured | reject rows),
            identity: ($r | get -o identity), corrections: ($r | get -o corrections), identity_sha256: ($r | get -o identity_sha256),
            identity_from: ($r | get -o identity_from), binding: ($r | get -o binding), passed: ($r | get -o passed),
            reports: ($r | get -o reports), cpu: ($r | get -o cpu),
        } }),
        rows: ($runs | each {|r| $r.measured.rows | each {|row| $row | insert run $r.run } } | flatten),
    }
}

# The report: every run's measurement and outcome under the identity
# (report-doc), written as gauge.nuon in `out`, a previous one there
# retired, its legs and its outliers printed.
def report [label: string, id: record, runs: list<any>, out: path]: nothing -> nothing {
    let file = ($out | path join "gauge.nuon")
    jab retire $file (jab target-root $WORKSPACE)
    report-doc $label $id $runs | to nuon | save --raw $file
    for r in $runs {
        for l in $r.measured.legs {
            if ($l.critical? | default null) == null {
                print $"gauge:   run ($r.run) ($l.leg): ($l.frames) frames; draw (spread $l.draw), game (spread $l.game)"
            } else {
                print $"gauge:   run ($r.run) ($l.leg): ($l.frames) frames, ($l.over) at or over, ($l.fast) fast and ($l.fast_waited) of them waited; critical (spread $l.critical); draw (ms $l.draw.median), preparation (ms $l.preparation.median), raster (ms $l.raster.median), slowest worker (ms $l.slowest.median), dispatch (ms $l.dispatch.median), barrier (ms $l.barrier.median), game (ms $l.game.median), flip (ms $l.flip.median), report (ms $l.report.median), await (ms $l.await.median), wait (ms $l.wait.median), pacing (ms $l.pacing.median), tiles (ms $l.tiles.median) median; ($l.tiles_built) cells built over ($l.building_frames) frames, ($l.tiled_pixels) tiled and ($l.fallback_pixels) fallback lit pixels; flips early ($l.flips_early), refusals ($l.refusals); unattributed (ms $l.unattributed.max) at most"
            }
        }
        let o = $r.measured.outliers
        if not ($o | is-empty) { print $"gauge:   run ($r.run): ($o | length) unexplained phase outliers, the first at frame ($o | first | get frame)" }
    }
    print $"gauge: ($file)"
}

# The legs a capture's frames are assigned to, from the route that
# played it: the route given, else the copy kept beside the capture,
# else the file the identity names, and whichever it is must have the
# SHA-256 the identity recorded, or the read stops naming both. A
# capture whose identity records no route is one leg, play, unless a
# route is given, which then goes unchecked.
export def legs-for [dir: path, id: record, route: string]: nothing -> record<legs: list<any>, route: oneof<string, nothing>, checked: bool> {
    let recorded = ($id | get -o route.sha256)
    let kept = ($dir | path join "route.nuon")
    let named = ($id | get -o route.file | default "")
    let file = (if $route != "" { $route | path expand } else if ($kept | path exists) { $kept } else { $named })
    if $file == "" { return { legs: [{ name: "play", places: [], pad: [] }], route: null, checked: false } }
    if not ($file | path exists) { error make { msg: $"the route ($file) is not there" } }
    let bytes = (open --raw $file | into binary)
    let sha = ($bytes | hash sha256)
    if $recorded != null and $sha != $recorded {
        error make { msg: $"the route ($file) has SHA-256 ($sha) where the capture's identity recorded ($recorded): its legs are not the ones that played" }
    }
    { legs: ($bytes | decode utf-8 | from nuon | get legs), route: $file, checked: ($recorded != null) }
}

# Set builds' captures side by side: each run of each gauge.nuon a
# measurement, a build an image at the cadence its runs played
# (effective-cadence) by the workers at the grain they played
# (effective-workers) on the machine their identities record, its runs
# its batches, named by the label less a trailing _<n>, one name a build
# and one build a name, each run keeping the cadence, the workers, and
# the grain its identity asked beside those it played, its identity read
# through identity-of with its source, binding, passes, and corrections
# named, and a build
# whose runs' identities differ in its flags or its ELF refused; for each leg a
# value of `field` a run, a leg
# whose eye travels one bin or more taken per bin of its path over the
# bins every run reached, a shorter one over its frames, so a leg's value
# is its path's and not its frame count's. Every run is classified before
# any leg is measured (standing-of): one measured incomplete, invalid, or
# unchecked, one that cannot be paired, or one on a diagnostic machine or
# with QEMU words of its launch's own is refused unless `diagnostic`
# admits it, and one empty, unclassified, or
# unusable is refused even then. A run's expected legs are every leg any
# compared run holds, and one missing any is refused unless `diagnostic`
# admits it, its missing legs then an explicit missing result in its run
# and in its build's row in place of a value, never a mean over fewer
# batches. The comparison fails with every refused run's file, run, and
# reasons. Runs on more than one machine, a recorded one or none, are
# refused unless `diagnostic` admits them. A comparison on a phase of the
# drawing or its remainder, whose meanings moved with the packets, is
# refused, `diagnostic` or not, when its runs' classes differ or any is
# unknown (parts-meaning), each run keeping its classes. The method with
# the machines, the bins, every run's standing, cadences, machine, missing
# legs, and bins with their medians, and the table, each row naming its
# build's machine, its batches' standings, and the batches missing its
# leg, come back together.
export def compare [files: list<string>, field: string, bin_cm: int, --diagnostic]: nothing -> record {
    let classified = ($files | each {|f|
        let file = ($f | path expand)
        let g = (open $file)
        let build = ($g.label | str replace --regex '_\d+$' '')
        let all_rows = ($g.rows? | default [])
        $g.runs | each {|r|
            let effective = (identity-of $file $r ($g | get -o identity))
            let id = $effective.identity
            let image = ($id | get -o build.image_sha256 | default "")
            let requested = ($id | get -o mode.cadence)
            let asked = { workers: ($id | get -o mode.workers), grain: ($id | get -o mode.grain) }
            let machine = ($id | get -o machine)
            let overrides = ($id | get -o overrides)
            let measured = ($r.measured? | default null)
            let rows = ($all_rows | where run == $r.run)
            let standing = (standing-of $measured $rows $field $requested $asked $machine $overrides)
            let schema = ($measured | get -o schema | default 1)
            let played = (effective-workers $measured $asked)
            {
                file: $file, label: $g.label, build: $build, image: $image, machine: $machine,
                requested_cadence: $requested, effective_cadence: (effective-cadence $measured $requested), run: $r.run,
                requested_workers: $asked.workers, requested_grain: $asked.grain,
                effective_workers: $played.workers, effective_grain: $played.grain,
                flags: ($id | get -o build.flags), elf_sha256: ($id | get -o build.elf_sha256),
                identity_from: $effective.from, identity_file: $effective.file, corrections: $effective.corrections,
                identity_sha256: $effective.identity_sha256, binding: $effective.binding, passed: $effective.passed,
                schema: $schema, parts: (parts-meaning $schema (if $image == "" { null } else { $image })),
                standing: $standing.standing, reasons: $standing.reasons, rows: $rows,
                held: (if ($rows | is-empty) { [] } else { $rows | get leg | uniq }),
            }
        }
    } | flatten)
    let expected = ($classified | get held | flatten | uniq)
    let covered = ($classified | each {|r| $r | insert missing ($expected | where {|leg| $leg not-in $r.held }) })
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
            $"the comparison refuses ($stopped | length) runs: an empty, unclassified, or unusable run always,"
            "an incomplete, invalid, unchecked, unpaired, or diagnostic one, or one missing a leg another run"
            "holds, unless --diagnostic admits it, marked"
        ] | str join " ")
        let named = ($stopped | get causes | flatten)
        error make { msg: ([$head] | append $named | str join "\n  ") }
    }
    let machines = ($covered | get machine | uniq)
    if ($machines | length) > 1 and (not $diagnostic) {
        let head = $"the runs ran on ($machines | length) machines, a comparison's runs on one unless --diagnostic admits them"
        error make { msg: ([$head] | append ($machines | each {|m| machine-text $m }) | str join "\n  ") }
    }
    let class = (if $field in $PHASE_FIELDS { "phases" } else if $field in $REMAINDER_FIELDS { "remainder" } else { null })
    if $class != null {
        let classes = ($covered | each {|r| $r.parts | get $class } | uniq)
        if ($classes | length) > 1 or ($UNKNOWN_PARTS in $classes) {
            let head = ([
                $"the comparison on ($field) refuses runs whose ($class) measure different things or unknown ones,"
                "--diagnostic or not: a schema 2 run's parts are known by a listed image alone"
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
        $r | reject rows held | insert legs ($legs | append $absent)
    })
    let builds = ($runs | get build | uniq)
    let made_of = {|r| { image: $r.image, cadence: $r.effective_cadence, machine: $r.machine, workers: $r.effective_workers, grain: $r.effective_grain } }
    for b in $builds {
        let made = ($runs | where build == $b | each {|r| do $made_of $r } | uniq)
        if ($made | length) > 1 { error make { msg: $"the captures labelled ($b) come from ($made | length) builds, an image at a cadence by its workers on a machine each: ($made | to nuon); a build's batches are one build" } }
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
    let common = ($expected | each {|leg|
        let measured = ($runs | each {|r| $r.legs | where {|l| $l.leg == $leg and $l.kind != "missing" } | get -o 0 } | compact)
        let kinds = ($measured | get kind | uniq)
        if ($kinds | length) > 1 { error make { msg: $"the leg ($leg) is walked in some runs and stands in others" } }
        let bins = (if ($kinds | first) == "path" {
            let sets = ($measured | each {|m| $m.bins | get bin })
            $sets | reduce --fold ($sets | first) {|s, acc| $acc | where {|x| $x in $s } }
        } else { [] })
        { leg: $leg, kind: ($kinds | first), runs: ($measured | length), missing: (($runs | length) - ($measured | length)), bins: $bins }
    })
    let valued = ($runs | each {|r|
        $r | merge { legs: ($r.legs | each {|l|
            let c = ($common | where leg == $l.leg | first)
            let picked = ($l.bins | where {|b| $b.bin in $c.bins })
            let value = (if $l.kind == "missing" { null } else if $l.kind == "frames" { $l.median } else if ($picked | is-empty) { null } else { $picked | get median | math avg })
            $l | insert value $value
        }) }
    })
    let table = ($builds | each {|b|
        let batches = ($valued | where build == $b)
        $expected | each {|leg|
            let entries = ($batches | each {|r| $r.legs | where leg == $leg | get 0 })
            let missing = ($entries | where {|l| $l.kind == "missing" } | length)
            let values = ($entries | get value | compact)
            let whole = ($missing == 0 and (not ($values | is-empty)))
            {
                build: $b, leg: $leg, machine: ($batches | get 0.machine),
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
                "a build is an image's SHA-256 at the cadence its runs played by the workers at the grain they"
                "played on the machine their identities record: the cadence the one asked from schema 2, and 0"
                "below it, where a request other than 0 leaves the run unpaired; the workers and grain its frames"
                "were drawn by from schema 4; below it the serial backend, 0 at grain 0, for a run with a W 0"
                "answered before its first frame and no W after it, and unknown for any other, which leaves the run"
                "unpaired and under --diagnostic a build of its own, never one with a known configuration, workers"
                "asked above 0 leaving it unpaired too; a capture's label less a trailing _<n> names it, one name a"
                "build and one build a name, and its runs are its batches, whose identities hold one build's flags"
                "and ELF; each run keeps the cadence, workers, and grain asked beside those played"
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
                "a run's machine is the one its identity records, its harts, whether it is diagnostic, -machine,"
                "the CPU, and the accelerator, or none for a capture older than the record; a run on a diagnostic"
                "machine or with QEMU words of its launch's own stands diagnostic, runs on more than one machine"
                "are refused unless --diagnostic admits them, and each table row names its build's machine"
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
                "diagnostic, a run on a machine its identity records as diagnostic, fewer harts than the"
                "specification's four, or whose identity carries QEMU words of its launch's own, each named; those"
                "five refused unless --diagnostic admits it; or valid; each table row names its batches' standings"
            ] | str join " "),
            coverage: ([
                "a run's expected legs are every leg any compared run holds; a run missing one is refused unless"
                "--diagnostic admits it, and then each leg it misses is an explicit missing result in its run and"
                "its build's row is missing in place of a value, never a mean over fewer batches"
            ] | str join " "),
            parts: ([
                "planes_us, walls_us, and sprites_us hold their rendering at schema 1 and are preparation alone at"
                "schemas 3 and 4; parts_unattributed_us holds no rendering at all three and the raster in f59f7a7's"
                "schema 2 images; a schema 2 run's parts are known by a listed image's SHA-256 alone, whatever its"
                "identity's commit says, else unknown; a comparison on these fields is refused, --diagnostic or"
                "not, when its runs' classes differ or any is unknown, and every other field compares across schemas"
            ] | str join " "),
            admitted: $diagnostic,
            machines: $machines,
        },
        common: $common,
        runs: $valued,
        table: $table,
    }
}

# A run's standing in a comparison, from its measurement and its own
# rows for the compared field: unclassified, its measurement recording no
# clocked, true or false; empty, no rows; unusable, a value of the field
# that is not a number or a leg holding no number in it; unpaired, a
# build older than the clock records, read from its states alone;
# incomplete, with the problems; unchecked, complete but measured before
# the analyzer recorded validity; invalid, with the reasons; unpaired, a
# run that cannot be paired with another (unpaired-reasons); diagnostic,
# a run on a machine its identity records as diagnostic or whose identity
# carries QEMU words of its launch's own, the words and a hart count other
# than the specification's four named; or valid.
def standing-of [
    m: oneof<record, nothing>    # the run's measurement as its gauge.nuon holds it
    rows: list<any>              # the run's rows
    field: string                # the column compared
    requested: any               # the cadence the run's identity asked for, null when it names none
    asked: record                # the workers and grain its identity asked for, each null when it names none
    machine: any                 # the machine the run's identity records, null when it records none
    overrides: any               # the QEMU words its identity records, null when it records none
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
    let marked = ($machine != null and ($machine | get -o diagnostic) == true)
    if $marked or (not ($words | is-empty)) {
        let harts = ($machine | get -o harts)
        let causes = ([
            (if ($words | is-empty) { null } else { $"QEMU words of its launch's own: ($words | str join ' ')" }),
            (if $harts == null or $harts == $HARTS { null } else { $"a diagnostic machine of ($harts) harts, not the specification's four" }),
        ] | compact)
        let why = (if ($causes | is-empty) { ["a machine its identity records as diagnostic"] } else { $causes })
        return { standing: "diagnostic", reasons: $why }
    }
    { standing: "valid", reasons: [] }
}

# Why a clocked run cannot be paired with another, none when it can: its
# seed and cadence (cadence-unpaired), then its workers and grain
# (workers-unpaired).
def unpaired-reasons [m: record, requested: any, asked: record]: nothing -> list<string> {
    cadence-unpaired $m $requested | append (workers-unpaired $m $asked)
}

# Why a clocked run's seed or cadence keeps it from pairing, none when
# they do not: no seed answered before its first frame, or one answered
# after it; below schema 2, an identity asking a cadence other than 0,
# which a program writing schema 1 cannot play, the request read as the
# identity holds it before effective-cadence puts 0 in its place; and
# from schema 2, no cadence asked before its first frame, or one asked
# after it, an identity asking no cadence from 0 to 2, or a frame at a
# cadence other than the one asked. A measurement written before schema 2
# was read is at schema 1.
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

# The cadence a run played, the one a build is named by: the one its
# identity asked from schema 2; below it 0, the one cadence a program
# writing schema 1 or no clock records has, set only after
# unpaired-reasons has held the request to it. A measurement written
# before schema 2 was read is at schema 1.
def effective-cadence [m: oneof<record, nothing>, requested: any]: nothing -> any {
    if ($m | get -o schema | default 1) >= 2 { $requested } else { $CADENCE_AFTER_FLIP }
}

# Why a clocked run's workers keep it from pairing, none when they do
# not. Below schema 4 the records hold no workers: a run legacy-serial
# holds to the serial backend pairs; an identity asking workers above 0
# asks what such a capture cannot show; any other run's workers are
# unknown, since 1a9986e drew with workers at schema 3 where every older
# build drew with the serial backend, and the reasons say why: none asked,
# no W 0 answered before the first frame, or a W after it. From schema 4
# with workers asked, no W answered before the first frame, one answered
# after it, or a frame drawn by other workers or at another grain than
# asked; with none asked, a W answered after the first frame, or frames
# drawn by more than one count of workers or at more than one grain.
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

# Whether a run below schema 4 drew with the serial backend: W 0 asked,
# answered before its first frame, and no W after it. An older build has
# no other raster, and 1a9986e takes a W 0 to the serial backend.
def legacy-serial [m: oneof<record, nothing>, asked: record]: nothing -> bool {
    let wanted = ($asked | get -o workers)
    let answered = ($m | get -o workers_set | default false)
    let late = ($m | get -o late_workers | default false)
    $wanted == 0 and $answered and (not $late)
}

# The workers and grain a run played, which a build is named by beside
# its cadence: below schema 4 the serial backend, 0 workers at grain 0
# whatever grain it asked, for a run legacy-serial holds to it, and
# UNKNOWN_WORKERS for both otherwise, which workers-unpaired refuses and
# --diagnostic admits as a build of its own; from schema 4 the one count
# its frames were drawn by, the grain theirs above 0 workers and 0 at
# none, each null where its frames hold more than one, which
# workers-unpaired refuses.
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

# Why a run's rows give nothing to compare in `field`, read from the rows'
# own values: a value that is not a number, and a leg holding no number
# in it; none when they give something.
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

# A leg's frames reduced for a comparison: the eye's travel in metres,
# and either its frames' median, standing, or its path cut into bins of
# `bin_cm` with each bin's frames and their median.
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
        return { leg: $leg, kind: "frames", frames: ($rows | length), path_m: $travelled, median: (stats ($rows | get $field)).median, bins: [] }
    }
    let bins = ($placed | group-by {|p| $p.bin | into string } | transpose bin entries | each {|g| { bin: ($g.bin | into int), frames: ($g.entries | length), median: (stats ($g.entries | get value)).median } } | sort-by bin)
    { leg: $leg, kind: "path", frames: ($rows | length), path_m: $travelled, median: null, bins: $bins }
}

# Set builds' captures side by side (compare), a build an image at a
# cadence: every leg's value of `--field` a run, a build's mean and half
# spread a leg, printed, marked with its runs' standings other than
# valid; a run measured incomplete, invalid, or before validity was
# recorded, one that cannot be paired, or one missing a leg another run
# holds, refused unless `--diagnostic` admits it, and one with nothing to
# compare refused even then, each named with its file, its run, and the
# reasons; under `--diagnostic` a leg some batch of a build is missing
# prints as missing in place of a value; the method, the bins every run
# reached, each run's standing, missing legs, and bins with their
# medians, and the table go to `--out`, a previous comparison there
# retired.
def "main compare" [
    ...files: string                 # the gauge.nuon files compared
    --field: string = "draw_us"      # the row's column compared
    --bin-cm: int = 50               # a walked leg's bin, in centimetres of its path
    --out: string = ""               # where the comparison lands, compare.nuon in the program's gauge shard of the target unless given
    --diagnostic                     # admit runs measured incomplete, invalid, unchecked, or unpaired, or missing a leg, marked
] {
    let result = (compare $files $field $bin_cm --diagnostic=$diagnostic)
    let target = (if $out == "" { jab program-shard ($env.FILE_PWD | path join ".." | path expand) "gauge" | path join "compare.nuon" } else { $out | path expand })
    mkdir ($target | path dirname)
    jab retire $target (jab target-root $WORKSPACE)
    $result | to nuon --indent 2 | save --raw $target
    for t in $result.table {
        let marks = ($t.standings | where {|s| $s != "valid" })
        let marked = (if ($marks | is-empty) { "" } else { $"; ($marks | str join ', ')" })
        let value = (if $t.missing > 0 {
            $"missing in ($t.missing) of ($t.batches) batches"
        } else if $t.value_us == null {
            $"no value, no bin reached by every run, ($t.batches) batches"
        } else {
            $"(ms $t.value_us) ms, half spread (ms $t.half_spread_us), ($t.batches) batches"
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

# A run's frames in order, each with the interval from the presenting
# call before it to its own, both read at the call's start, the flip's
# end less the call: null for a frame not presented and for the first
# presented; null with `call_unknown` set for a frame presented after a
# retried flip, whose `flip_us` sums every attempt so its call's start
# is unknown, and for the next frame presented after it; and with
# whether the frame before it ran past the period. The clocked frames
# alone.
def presented-calls [rows: list<any>, period: number]: nothing -> list<any> {
    mut previous: any = null
    mut known = false
    mut seen = false
    mut late = false
    mut out = []
    for r in ($rows | where {|x| ($x | get -o critical_us) != null }) {
        let presented = (($r | get -o flip_status) == $FLIP_PRESENTED)
        let single = (($r | get -o flip_attempts | default 1) <= 1)
        let done = ($r | get -o flip_done_us)
        let flip = ($r | get -o flip_us)
        let start = (if $presented and $single and $done != null and $flip != null { $done - $flip } else { null })
        let interval = (if $start != null and $known { $start - $previous } else { null })
        let unknown = ($presented and $seen and $interval == null)
        $out = ($out | append ($r | insert call_interval_us $interval | insert call_unknown $unknown | insert after_late $late))
        if $presented {
            $seen = true
            $known = ($start != null)
            $previous = $start
        }
        $late = ($r.critical_us >= $period)
    }
    $out
}

# Frames pooled: the counts; the presented interval, the interval
# between presenting calls, the submission age, the critical path, the
# drawing, the wait, the pacing, and the await by nearest rank (stats);
# the presenting calls' known intervals on the tick grid, within a
# millisecond of a whole number of periods, counted by that number, the
# rest off it, and the intervals unknown after a retried flip apart
# (presented-calls); the wakes, attempts, and refusals; the flips early
# and failed; the frames at or over the ceiling; the fast frames, under
# the period, and those of them that waited; and the catch-up intervals,
# under half a period after a frame past it, of the known.
def bench-frames [rows: list<any>, period: number]: nothing -> record {
    if ($rows | is-empty) { return { frames: 0 } }
    let calls = (column-of $rows "call_interval_us" | compact)
    let multiples = ($calls | each {|c|
        let k = (($c / $period) | math round)
        if $k >= 1 and ((($c - $k * $period) | math abs) <= 1000) { $k } else { null }
    } | compact)
    let critical = {|r| $r | get -o critical_us }
    {
        frames: ($rows | length),
        presented: ($rows | where {|r| ($r | get -o flip_status) == $FLIP_PRESENTED } | length),
        interval: (stats (column-of $rows "flip_interval_us")),
        call_interval: (stats $calls),
        grid: ($multiples | uniq --count | sort-by value | each {|c| { periods: $c.value, intervals: $c.count } }),
        off_grid: (($calls | length) - ($multiples | length)),
        unknown_calls: ($rows | where {|r| ($r | get -o call_unknown) == true } | length),
        submission_age: (stats (column-of $rows "submission_age_us")),
        critical: (stats (column-of $rows "critical_us")),
        draw: (stats (column-of $rows "draw_us")),
        wait: (stats (column-of $rows "wait_us")),
        pacing: (stats (column-of $rows "pacing_us")),
        await: (stats (column-of $rows "await_us")),
        wakes: (total (column-of $rows "wakes")),
        attempts: (total (column-of $rows "flip_attempts")),
        refusals: (total (column-of $rows "refusals")),
        flips_early: ($rows | where {|r| ($r | get -o flip_status) == $FLIP_EARLY } | length),
        flips_failed: ($rows | where {|r| ($r | get -o flip_status | default $FLIP_PRESENTED) > $FLIP_EARLY } | length),
        over: ($rows | where {|r| (do $critical $r | default 0) >= $CEILING_US } | length),
        fast: ($rows | where {|r| let c = (do $critical $r); $c != null and $c < $period } | length),
        fast_waited: ($rows | where {|r| let c = (do $critical $r); $c != null and $c < $period and ($r | get -o wait_us | default 0) > 0 } | length),
        catch_up: ($rows | where {|r| let i = ($r | get -o call_interval_us); ($r | get -o after_late) == true and $i != null and $i < ($period / 2) } | length),
    }
}

# A column of rows, null in a row that lacks it, as a capture older than
# a field leaves it.
def column-of [rows: list<any>, name: string]: nothing -> list<any> {
    $rows | each {|r| $r | get -o $name }
}

# One step of a bench's run as its gauge.nuon holds it: a play when its
# identity names the host's own pad, else a batch of the route; its
# cadence and period; the machine and the QEMU its identity records; and
# every run with its standing and reasons as a comparison classifies it
# (standing-of) from its own identity (identity-of), its CPU seconds over
# wall seconds, its outcomes, and its frames (presented-calls). A step
# with no gauge.nuon holds no runs.
def bench-step [dir: path, label: string, state: any]: nothing -> record {
    let file = ($dir | path join $label "gauge.nuon")
    if not ($file | path exists) { return { label: $label, state: $state, kind: null, cadence: null, period_us: null, machine: null, qemu: null, file: null, runs: [] } }
    let g = (open $file)
    let period = (1000000 / ($g.identity | get -o cap | default $CAP))
    let requested = ($g.identity | get -o mode.cadence)
    let machine = ($g.identity | get -o machine)
    let all_rows = ($g.rows? | default [])
    let runs = ($g.runs | each {|r|
        let m = ($r | get -o measured)
        let rows = ($all_rows | where run == $r.run)
        let id = (identity-of $file $r ($g | get -o identity) | get identity)
        let asked = { workers: ($id | get -o mode.workers), grain: ($id | get -o mode.grain) }
        let standing = (standing-of $m $rows "critical_us" ($id | get -o mode.cadence) $asked ($id | get -o machine) ($id | get -o overrides))
        let ran = ($r | get -o ran | default {})
        let wall = ($ran | get -o wall_seconds | default 0)
        let cpu = ($ran | get -o cpu_seconds)
        {
            run: $r.run,
            seed: ($r | get -o seed),
            standing: $standing.standing,
            reasons: $standing.reasons,
            cpu_over_wall: (if $wall == 0 or $cpu == null { null } else { $cpu / $wall }),
            outcomes: ($m | get -o outcomes),
            rows: (presented-calls $rows $period),
        }
    })
    let kind = (if ($g.identity | get -o mode.pad) == "host" { "play" } else { "route" })
    let qemu = ($g.identity | get -o qemu.version)
    { label: $label, state: $state, kind: $kind, cadence: $requested, period_us: $period, machine: $machine, qemu: $qemu, file: $file, runs: $runs }
}

# A cadence's steps of one kind: the valid runs (standing-of) pooled,
# their CPU seconds over wall seconds and their frames (bench-frames);
# every other run, one on a diagnostic machine among them, kept apart
# with its standing, its reasons, and its own frames, a diagnostic
# outside the pool; and each run's standing and outcomes.
def bench-cadence [steps: list<any>, cadence: any]: nothing -> record {
    let runs = ($steps | each {|s| $s.runs | each {|r| $r | insert label $s.label } } | flatten)
    let period = ($steps | first | get period_us)
    let pooled = ($runs | where standing == "valid")
    let apart = ($runs | where standing != "valid")
    {
        cadence: $cadence,
        steps: ($steps | get label),
        runs: ($runs | length),
        valid: ($pooled | length),
        standings: ($runs | each {|r| { label: $r.label, run: $r.run, standing: $r.standing, reasons: $r.reasons } }),
        cpu_over_wall: ($pooled | each {|r| $r.cpu_over_wall }),
        outcomes: ($runs | each {|r| { label: $r.label, run: $r.run, outcomes: $r.outcomes } }),
        frames: (bench-frames ($pooled | each {|r| $r.rows } | flatten) $period),
        apart: ($apart | each {|r| { label: $r.label, run: $r.run, standing: $r.standing, reasons: $r.reasons, cpu_over_wall: $r.cpu_over_wall, frames: (bench-frames $r.rows $period) } }),
    }
}

# A cadence's lines in a bench's report, milliseconds to a tenth as
# least, median, 95th, 99th, and greatest.
def bench-cadence-text [c: record]: nothing -> list<string> {
    let f = $c.frames
    let cpu = ($c.cpu_over_wall | compact)
    let core = (if ($cpu | is-empty) { "-" } else if (($cpu | math max) - ($cpu | math min)) < 0.005 { $"($cpu | first | math round --precision 2)" } else { $"($cpu | math min | math round --precision 2) to ($cpu | math max | math round --precision 2)" })
    let head = $"  cadence ($c.cadence | default 'none asked'), ($c.steps | str join ' '): ($c.runs) runs, ($c.valid) valid and pooled; the process at ($core) of a core"
    let apart = ($c.apart | each {|a|
        let seen = (if $a.frames.frames == 0 { "no frames" } else { $"($a.frames.frames) frames, presented every (ms $a.frames.interval.median) ms at the median" })
        $"    left out of the pool, a diagnostic: ($a.label) run ($a.run), ($a.standing): ($a.reasons | str join '; '); ($seen)"
    })
    if $f.frames == 0 { return ([$head "    no valid run to pool"] ++ $apart) }
    let grid = (if ($f.grid | is-empty) { "none" } else { $f.grid | each {|g| $"($g.intervals) at ($g.periods)P" } | str join ", " })
    [
        $head
        $"    ($f.frames) frames, ($f.presented) presented every (spread $f.interval)"
        $"    submission age (spread $f.submission_age)"
        $"    critical path (spread $f.critical); drawing (spread $f.draw)"
        $"    wait (spread $f.wait); pacing (ms $f.pacing.median) and await (ms $f.await.median) at the median"
        $"    presenting calls on the tick grid: ($grid); ($f.off_grid) off it; ($f.unknown_calls) unknown after a retried flip; ($f.catch_up) catch-up"
        $"    ($f.fast) fast, ($f.fast_waited) of them waited; ($f.over) at or over 15 ms; flips early ($f.flips_early), failed ($f.flips_failed); wakes ($f.wakes), refusals ($f.refusals)"
    ] ++ $apart
}

# A machine as a run's identity records it, in words: its harts and
# whether it is diagnostic, -machine, the CPU, and the accelerator, or
# unrecorded for an identity older than the record.
def machine-text [m: any]: nothing -> string {
    if $m == null { return "unrecorded" }
    let kind = (if ($m | get -o diagnostic) == true { ", diagnostic" } else { "" })
    $"($m | get -o harts) harts($kind), -machine ($m | get -o machine), -cpu ($m | get -o cpu), -accel ($m | get -o accel)"
}

# A bench's report as text: the steps, the machines and QEMUs they ran
# on, each kind's cadences, then the comparisons.
export def bench-text [doc: record]: nothing -> string {
    let named = (if $doc.bench == null { "" } else { $"($doc.bench) " })
    let ran = ($doc.steps | where file != null)
    let machines = ($ran | each {|s| { machine: $s.machine, qemu: $s.qemu } } | uniq | each {|m|
        let labels = ($ran | where {|s| $s.machine == $m.machine and $s.qemu == $m.qemu } | get label)
        $"machine: (machine-text $m.machine); ($m.qemu | default 'QEMU unrecorded'): ($labels | str join ' ')"
    })
    let head = [
        $"bench ($named)run ($doc.stamp | default '-') in ($doc.dir)"
        $"steps: ($doc.steps | each {|s| $'($s.label) (if $s.file == null { 'no capture' } else { $s.state | default 'read' })' } | str join ', ')"
    ] ++ $machines
    let kinds = ($doc.groups | each {|g|
        let title = (if $g.kind == "play" { "your play" } else { "the route" })
        [$"($title), per cadence, ms as least / median / 95th / 99th / greatest:"] ++ ($g.cadences | each {|c| bench-cadence-text $c } | flatten)
    } | flatten)
    let compared = ($doc.compared | each {|c|
        if ($c | get -o error) != null { [$"the route at 50 cm on ($c.field): refused even as a diagnostic, ($c.error | lines | first)"] } else {
            let title = (if $c.diagnostic {
                [$"the route at 50 cm, ($c.field) by leg, a diagnostic admitting the runs a comparison refuses: ($c.refused | lines | first)"]
            } else {
                [$"the route at 50 cm, ($c.field) by leg, ms with the half spread:"]
            })
            $title ++ ($c.table | get build | uniq | each {|b|
                let rows = ($c.table | where build == $b)
                let legs = ($rows | each {|t| if $t.value_us == null { $"($t.leg) -" } else { $"($t.leg) (ms $t.value_us) \((ms $t.half_spread_us)\)" } })
                let marks = ($rows | get standings | flatten | uniq | where {|s| $s != "valid" })
                let marked = (if ($marks | is-empty) { "" } else { $"; admits ($marks | str join ', ')" })
                $"  ($b): ($legs | str join ', ')($marked)"
            })
        }
    } | flatten)
    $head ++ $kinds ++ $compared | str join "\n"
}

# A bench's report over the steps a run of the bench wrote in `dir`,
# each a directory holding its gauge.nuon, in the order bench.nuon lists
# them, else every directory's by name: each step with its machine and
# QEMU (bench-step); the plays, each on the host's own pad, and the
# route's batches apart, each per cadence with its valid runs pooled,
# untrimmed, and every other run kept apart as a diagnostic
# (bench-cadence); then the route's batches compared at 50 cm on
# critical_us and draw_us, a build a cadence, its batches its steps
# (compare), and when the comparison refuses a run, compared again as a
# diagnostic admitting it, marked.
export def bench-doc [dir: path]: nothing -> record {
    let dir = ($dir | path expand)
    let listed = ($dir | path join "bench.nuon")
    let bench = (if ($listed | path exists) { open $listed } else { null })
    let labels = (if $bench != null { $bench.steps | get label } else { ls $dir | where type == dir | get name | each {|d| $d | path basename } | where {|d| $d != "watch" } | sort })
    let steps = ($labels | each {|label|
        let state = (if $bench == null { null } else { $bench.steps | where label == $label | get -o 0.state })
        bench-step $dir $label $state
    })
    let groups = (["play" "route"] | each {|kind|
        let these = ($steps | where kind == $kind)
        { kind: $kind, cadences: ($these | get cadence | uniq | sort | each {|c| bench-cadence ($these | where cadence == $c) $c }) }
    } | where {|g| not ($g.cadences | is-empty) })
    let files = ($steps | where kind == "route" | get file)
    let compared = (if ($files | is-empty) { [] } else {
        ["critical_us" "draw_us"] | each {|field|
            try { { field: $field, diagnostic: false, table: (compare $files $field 50 | get table) } } catch {|refusal|
                try { { field: $field, diagnostic: true, refused: $refusal.msg, table: (compare $files $field 50 --diagnostic | get table) } } catch {|e| { field: $field, error: $e.msg } }
            }
        }
    })
    {
        bench: ($bench | get -o bench),
        stamp: ($bench | get -o stamp),
        dir: $dir,
        steps: ($steps | each {|s| $s | reject runs }),
        groups: $groups,
        compared: $compared,
    }
}

# A bench's report, `nu gauge.nu bench-report <dir>` (bench-doc):
# report.nuon and report.txt written in `dir`, any there before retired,
# and the text printed.
def "main bench-report" [dir: path] {
    let dir = ($dir | path expand)
    let doc = (bench-doc $dir)
    let text = (bench-text $doc)
    let nuon_file = ($dir | path join "report.nuon")
    let text_file = ($dir | path join "report.txt")
    jab retire $nuon_file (jab target-root $WORKSPACE)
    jab retire $text_file (jab target-root $WORKSPACE)
    $doc | to nuon --indent 1 | save --raw $nuon_file
    $text + "\n" | save --raw $text_file
    print $text
    print $"gauge: ($nuon_file)"
}
