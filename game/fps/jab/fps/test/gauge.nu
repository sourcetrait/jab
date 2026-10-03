# gauge.nu: the game's frames measured over play. At each frame's start
# the program sends the frame before's two records over the API, the
# frame's clock (kind 7) and its drawing with the tile cache (kind 8),
# and after the console's E the end marker (kind 9) naming the final
# frame of the measurement, which the frames from 0 to it make up;
# render.inc lays the records out, schema 1. `run` plays a route on a
# build `--runs` times, headless or with `--host` in the host's window
# and audio, each run seeded by the console's R before its first frame;
# `play` puts the build in the host's window, audio, and gamepad for a
# person to play and closes the measurement after `--seconds`; `read`
# reads a capture either made. Each writes the run's identity beside its
# capture at launch, then gauge.nuon and the summary. A frame passes the
# ceiling when its critical path, its start to the end of its reporting
# with the await apart, is under 15 ms; a measurement passes when it is
# complete and every frame in it passes. A capture of a build older
# than the clock records holds no measurement and is read from its state
# records alone, the drawing's and the game's microseconds. `just gauge`,
# `just gauge-play`, and `just gauge-read` build and run it.
use ../../../../../sdk/nu/jab.nu
use ../../../nu/map.nu
use ./pose.nu

const RECORD = 64
const SCHEMA = 1
const CEILING_US = 15000
const KIND_STATE = 1
const KIND_FRAME = 7
const KIND_DRAW = 8
const KIND_END = 9
const KIND_CONSOLE = 11
# the console's commands as its records name them: P a placement, R a seed
const CONSOLE_P = 80
const CONSOLE_R = 82
# the span records a frame holds before its spans go unrecorded
const SPAN_RECORDS = 65536
# the critical path's phases and the drawing's parts, each exclusive;
# tiles_us lies within planes_us and walls_us and is never added to them
const PHASES = [game_us draw_us hud_us mix_us flip_us report_us]
const PARTS = [clear_us portals_us planes_us walls_us sprites_us]
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
# the android events and what a round met, as the program reports them
const ANDROID_EVENTS = [none roused fired struck destroyed fallen waypoint]
const MET = [nothing geometry android]

def main [] {
    print "nu gauge.nu run [--tree release|debug] [--kernel <jab.elf>] [--image <fps.jab>] [--route <route.nuon>] [--map <tree>] [--runs N] [--seeds [..]] [--host] [--out <dir>] [--label <name>]"
    print "nu gauge.nu play [--tree release|debug] [--seconds N] [--seed N] [--out <dir>] [--label <name>]"
    print "nu gauge.nu read <api.out> [--route <route.nuon>] [--out <dir>] [--label <name>]"
}

# Play the route on the build `runs` times and read every frame: the
# route's placements and pad rows, an R with the run's seed before the
# first frame, the E at the route's end, the capture when the final
# records have landed. Headless with the sound recorded, or with
# `--host` in the window and the audio a run of the program has.
def "main run" [
    --tree: string = "release"   # the build tree the kernel and the image come from, release or debug
    --kernel: string = ""        # the kernel's ELF, the tree's own unless given
    --image: string = ""         # the program's image, the tree's own unless given
    --route: string = ""         # the route, route_factory.nuon unless given
    --map: string = ""           # the map tree the route plays on, the route's unless given
    --runs: int = 3              # the route's runs
    --seeds: list<int> = []      # each run's seed, run n's n unless given
    --host                       # the host's window and audio in place of none and the recording
    --out: string = ""           # where the runs land, a stamped directory under the tree's unless given
    --label: string = ""         # a name for the build in the summary
] {
    let at = (places $tree $kernel $image $out)
    let route_file = (if $route == "" { $env.FILE_PWD | path join "route_factory.nuon" } else { $route | path expand })
    let r = (open $route_file)
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
        let sends = ([{ at: $SEED_AT, bytes: (seed-frame $seed) }]
            | append ($r.legs | each {|l| $l.places | each {|p| { at: $p.at, bytes: (pose pose-frame $p) } } } | flatten)
            | append [{ at: $r.end, bytes: (pose command-frame "E") }]
            | sort-by at)
        let mode = { window: $host, sound: (if $host { "host" } else { "recorded" }), pad: "route", seed: $seed, end: $r.end, capture: $capture }
        identity $at $set $map_name $route_file $mode | to nuon --indent 2 | save --raw -f ($run_out | path join "identity.nuon")
        let launched = (if $host {
            jab launch --kernel $at.kernel --image $at.image --out $run_out --set $set --live-sound --window --api --pad $pad --disk $disk --serial "fps" --send $sends --capture $capture --seconds $seconds
        } else {
            jab launch --kernel $at.kernel --image $at.image --out $run_out --set $set --sound --api --pad $pad --disk $disk --serial "fps" --send $sends --capture $capture --seconds $seconds
        })
        let ran = (outcome $launched)
        $ran | to nuon --indent 2 | save --raw -f ($run_out | path join "run.nuon")
        let measured = (measure $launched.api $r.legs)
        print (run-line $label $n $measured $ran)
        { run: $n, seed: $seed, out: $run_out, ran: $ran, measured: $measured }
    })
    report $label (open ($at.out | path join "run_1" "identity.nuon")) $runs $at.out
}

# Put the build in the host's window, with its audio and its own
# gamepad, for a person to play from the spawn: an R with the seed
# before the first frame, the E after `seconds`, the capture once the
# final records have landed, which closes the window.
def "main play" [
    --tree: string = "release"   # the build tree, release or debug
    --kernel: string = ""        # the kernel's ELF, the tree's own unless given
    --image: string = ""         # the program's image, the tree's own unless given
    --seconds: int = 120         # the measurement's length
    --seed: int = 1              # the seed the run sends
    --out: string = ""           # where the run lands, a stamped directory under the tree's unless given
    --label: string = ""         # a name for the build in the summary
] {
    let at = (places $tree $kernel $image $out)
    let disk = (romfs-of $at.game "factory" $at.out)
    let set = (if $at.tree == "debug" { "debug" } else { "" })
    let end = ($seconds * 1sec)
    let capture = ($end + $DRAIN)
    let bound = ((($capture + $BOUND_PAST) / 1sec) | math ceil)
    let run_out = ($at.out | path join "run_1")
    mkdir $run_out
    let sends = [{ at: $SEED_AT, bytes: (seed-frame $seed) }, { at: $end, bytes: (pose command-frame "E") }]
    let mode = { window: true, sound: "host", pad: "host", seed: $seed, end: $end, capture: $capture }
    identity $at $set "factory" null $mode | to nuon --indent 2 | save --raw -f ($run_out | path join "identity.nuon")
    print $"gauge: play until the window closes, ($seconds) seconds measured from the start"
    let launched = (jab launch --kernel $at.kernel --image $at.image --out $run_out --set $set --live-sound --window --host-pad --api --disk $disk --serial "fps" --send $sends --capture $capture --seconds $bound)
    let ran = (outcome $launched)
    $ran | to nuon --indent 2 | save --raw -f ($run_out | path join "run.nuon")
    let legs = [{ name: "play", places: [], pad: [] }]
    let measured = (measure $launched.api $legs)
    print (run-line $label 1 $measured $ran)
    report $label (open ($run_out | path join "identity.nuon")) [{ run: 1, seed: $seed, out: $run_out, ran: $ran, measured: $measured }] $at.out
}

# Read a capture, a run's api.out: with the identity.nuon and run.nuon
# its launch wrote beside it, or without them as what the capture alone
# says; the legs from the route the identity names, else `--route`, else
# one leg, play.
def "main read" [
    api: path                    # the capture
    --route: string = ""         # the route the capture played, for its legs
    --out: string = ""           # where gauge.nuon lands, beside the capture unless given
    --label: string = ""         # a name for the build in the summary
] {
    let file = ($api | path expand)
    let dir = ($file | path dirname)
    let id_file = ($dir | path join "identity.nuon")
    let id = (if ($id_file | path exists) { open $id_file } else { { launched: false, note: "read from the capture alone; no identity was written at its launch" } })
    let route_file = (if $route != "" { $route | path expand } else { $id | get -o route.file | default "" })
    let legs = (if $route_file != "" and ($route_file | path exists) { open $route_file | get legs } else { [{ name: "play", places: [], pad: [] }] })
    let run_file = ($dir | path join "run.nuon")
    let ran = (if ($run_file | path exists) { open $run_file } else { { status: null, fault: null, cpu_seconds: null, wall_seconds: null, qemu_binary: null, qemu: [], window: null, audio: null } })
    let measured = (measure (open --raw $file | into binary) $legs)
    print (run-line $label 1 $measured $ran)
    let target = (if $out == "" { $dir } else { $out | path expand })
    mkdir $target
    report $label $id [{ run: 1, seed: ($id | get -o mode.seed), out: $dir, ran: $ran, measured: $measured }] $target
}

# Where a run's pieces are: the game, the workspace, the tree, the
# kernel and the image (the tree's own unless given), and the output
# directory, a stamped one under the tree's gauge unless given, made.
def places [tree: string, kernel: string, image: string, out: string]: nothing -> record<game: string, workspace: string, tree: string, kernel: string, image: string, out: string> {
    if $tree not-in [release debug] { error make { msg: $"--tree is release or debug, not ($tree)" } }
    let program = ($env.FILE_PWD | path join ".." | path expand)
    let game = ($program | path join ".." ".." | path expand)
    let workspace = ($game | path join ".." ".." | path expand)
    let stamp = (date now | format date "%Y%m%d-%H%M%S")
    let target = (if $out == "" { $program | path join ".target" $tree "fps" "gauge" $stamp } else { $out | path expand })
    mkdir $target
    {
        game: $game,
        workspace: $workspace,
        tree: $tree,
        kernel: (if $kernel == "" { $workspace | path join ".target" $tree "kernel" "jab.elf" } else { $kernel | path expand }),
        image: (if $image == "" { $program | path join ".target" $tree "fps" "fps.jab" } else { $image | path expand }),
        out: $target,
    }
}

# A map's tree as the romfs image the program reads, built in `out`.
def romfs-of [game: path, map: string, out: path]: nothing -> string {
    let tree = ($game | path join ".target" "asset" $map)
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

# What a run was, written beside its capture before it starts: the
# records' schema and clock, the build and its source, the assets, the
# route, the cap, the QEMU, the host, the toolchain, and the mode: the
# window, the sound, the pad, the seed, and when the measurement closes.
def identity [at: record, set: string, map: string, route: oneof<string, nothing>, mode: record]: nothing -> record {
    let built = ($at.image | path dirname)
    let flags_file = ($built | path join "flags")
    let flags = (if ($flags_file | path exists) { open --raw $flags_file | decode | lines | first } else { "" })
    let prefix = ($flags | split row " " | last)
    let jab_inc = ($at.workspace | path join "sdk" "src" "jab.inc")
    let cap = (open --raw $jab_inc | decode | parse --regex '\.set JAB_DISPLAY_FPS_CAP, (?P<cap>\d+)' | get -o 0.cap)
    let tree = ($at.game | path join ".target" "asset" $map)
    let qemu = (qemu-of $at.workspace $at.image)
    let host = (sys host)
    let cpus = (sys cpu)
    {
        launched: true,
        schema: $SCHEMA,
        clock: "the guest's time counter, JAB_TIME_HZ ticks a second, as microseconds; a start and a flip's end since the program's start",
        written: (date now | format date "%Y-%m-%dT%H:%M:%S%z"),
        jab: (repo-of $at.workspace),
        build: {
            tree: $at.tree,
            set: $set,
            flags: $flags,
            image: $at.image,
            image_sha256: (digest $at.image),
            elf_sha256: (digest ($built | path join "fps.elf")),
            kernel: $at.kernel,
            kernel_sha256: (digest $at.kernel),
        },
        assets: { map: $map, tree: $tree, digest: (tree-digest $tree) },
        route: (if $route == null { null } else { { file: $route, sha256: (digest $route) } }),
        cap: (if $cap == null { null } else { $cap | into int }),
        qemu: $qemu,
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
            assembler: (try { ^$"($prefix)as" --version | complete | get stdout | lines | get -o 0 } catch { null }),
            link: (try { ls -l ($at.workspace | path join "extern") | where {|e| ($e.name | path basename) == "riscv" } | get -o 0.target } catch { null }),
        },
        mode: $mode,
    }
}

# The QEMU a launch of the image runs on and its version.
def qemu-of [workspace: path, image: path]: nothing -> record<binary: string, version: oneof<string, nothing>> {
    let extern = ($workspace | path join "extern" "qemu")
    let found = ([($extern | path join "bin" "qemu-system-riscv64") ($extern | path join "qemu-system-riscv64")] | where {|b| $b | path exists } | get -o 0)
    let binary = ($found | default "qemu-system-riscv64")
    { binary: $binary, version: (try { ^$binary --version | complete | get stdout | lines | get -o 0 } catch { null }) }
}

# The repository's commit and whether its tree held changes.
def repo-of [workspace: path]: nothing -> record<commit: string, dirty: bool> {
    let commit = (^git -C $workspace rev-parse --short HEAD | complete | get stdout | str trim)
    let status = (^git -C $workspace status --porcelain | complete | get stdout | str trim)
    { commit: $commit, dirty: ($status != "") }
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
# and wall seconds, and the machine it ran on.
def outcome [launched: record]: nothing -> record {
    {
        status: $launched.status,
        fault: ($launched.serial | lines | where {|l| $l starts-with "jab: " } | get -o 0),
        cpu_seconds: $launched.cpu_seconds,
        wall_seconds: $launched.wall_seconds,
        qemu_binary: $launched.qemu_binary,
        qemu: $launched.qemu,
        window: $launched.window,
        audio: $launched.audio,
    }
}

# A record's 32-bit word at a byte offset, or its 64-bit one.
def u32-at [r: binary, at: int]: nothing -> int { $r | bytes at $at..<($at + 4) | into int --endian little }
def u64-at [r: binary, at: int]: nothing -> int { $r | bytes at $at..<($at + 8) | into int --endian little }

# The frame and draw records and the end markers of a capture, kinds 7,
# 8, and 9, each field microseconds or a count, in the order sent.
export def clocks [api: binary]: nothing -> record<frames: list<any>, draws: list<any>, ends: list<int>> {
    mut frames = []
    mut draws = []
    mut ends = []
    for r in ($api | chunks $RECORD | where {|c| ($c | bytes length) == $RECORD }) {
        let kind = ($r | bytes at 0..<1 | into int)
        if $kind == $KIND_FRAME {
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
        } else if $kind == $KIND_END {
            $ends = ($ends | append (u32-at $r 4))
        }
    }
    { frames: $frames, draws: $draws, ends: $ends }
}

# A capture's state records in order, the n-th frame n's, with the
# placements the console answered before each, whether an R was
# answered before the first and whether one came later, and the game's
# events with the frame each fell in.
def states-of [api: binary]: nothing -> record<states: list<any>, seeded: bool, late_seed: bool, events: list<any>> {
    mut states = []
    mut events = []
    mut placed = 0
    mut seeded = false
    mut late_seed = false
    for r in ($api | chunks $RECORD | where {|c| ($c | bytes length) == $RECORD }) {
        let kind = ($r | bytes at 0..<1 | into int)
        if $kind == $KIND_CONSOLE {
            let command = ($r | bytes at 4..<5 | into int)
            if $command == $CONSOLE_P { $placed += 1 }
            if $command == $CONSOLE_R {
                if ($states | is-empty) { $seeded = true } else { $late_seed = true }
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
        }
    }
    { states: $states, seeded: $seeded, late_seed: $late_seed, events: $events }
}

# A capture measured: its window, every frame in it as a row with its
# leg, the leg's summaries, the outliers, and the outcomes. The window
# is complete when an end marker names the final frame and every frame
# from 0 to it has its state, its frame record, and its draw record,
# numbered in order with none twice, all at the schema; the frames past
# the marker lie outside it and count for nothing. A capture with no
# clock records is a build older than them: its rows are its state
# records' alone and it holds no window.
export def measure [api: binary, legs: list<any>]: nothing -> record {
    let s = (states-of $api)
    let c = (clocks $api)
    let clocked = (not ($c.frames | is-empty))
    let final = ($c.ends | get -o 0)
    let problems = (if not $clocked { [] } else { window-problems $s $c $final })
    let complete = ($clocked and ($problems | is-empty))
    let last = (if not $clocked { ($s.states | length) - 1 } else if $final == null { ($c.frames | length) - 1 } else { $final })
    let rows = (rows-of $s $c $legs $last)
    let names = ($legs | get name)
    let summaries = ($names | each {|n| leg-summary $n ($rows | where leg == $n) } | where frames > 0)
    {
        clocked: $clocked,
        complete: $complete,
        final: $final,
        problems: $problems,
        seeded: $s.seeded,
        late_seed: $s.late_seed,
        frames: ($rows | length),
        past_window: (if $final == null { 0 } else { ($s.states | length) - $final - 1 }),
        passes: (if $complete { ($rows | where {|r| $r.over } | is-empty) } else { false }),
        over: (if $clocked { $rows | where {|r| $r.over == true } | length } else { null }),
        whole: (leg-summary "whole" $rows),
        legs: $summaries,
        outliers: (if $clocked { outliers $rows } else { [] }),
        outcomes: (outcomes-of $s.events $rows $last),
        rows: $rows,
    }
}

# What keeps a window from being complete: no end marker, a record
# numbered out of order or twice, a frame short of a record, a schema
# other than this one.
def window-problems [s: record, c: record, final: oneof<int, nothing>]: nothing -> list<string> {
    mut problems = []
    if $final == null { $problems = ($problems | append "no end marker: the measurement never closed") }
    if ($c.ends | length) > 1 { $problems = ($problems | append $"($c.ends | length) end markers; the first closes the measurement") }
    let last = (if $final == null { ($c.frames | length) - 1 } else { $final })
    let frames = ($c.frames | where {|f| $f.frame <= $last })
    let draws = ($c.draws | where {|d| $d.frame <= $last })
    let frame_order = ($frames | enumerate | where {|e| $e.item.frame != $e.index } | length)
    let draw_order = ($draws | enumerate | where {|e| $e.item.frame != $e.index } | length)
    if $frame_order > 0 { $problems = ($problems | append $"($frame_order) frame records out of order or repeated") }
    if $draw_order > 0 { $problems = ($problems | append $"($draw_order) draw records out of order or repeated") }
    if ($frames | length) != ($last + 1) { $problems = ($problems | append $"($frames | length) frame records for ($last + 1) frames") }
    if ($draws | length) != ($last + 1) { $problems = ($problems | append $"($draws | length) draw records for ($last + 1) frames") }
    if ($s.states | length) < ($last + 1) { $problems = ($problems | append $"($s.states | length) state records for ($last + 1) frames") }
    let schemas = ($frames | get schema | append ($draws | get schema) | uniq)
    if ($schemas | any {|v| $v != $SCHEMA }) { $problems = ($problems | append $"a record at schema ($schemas | where {|v| $v != $SCHEMA } | first), this reader's being ($SCHEMA)") }
    $problems
}

# Every frame from 0 to `last` as one row: its leg (by the placements
# answered before it), whether a placement opened it, its state, and
# with the clock records its phases, the time it left unattributed, its
# flip's interval from the presented one before and its latency from
# its start, the drawing's parts, and the tile cache's counts; without
# them the clock's columns are null.
def rows-of [s: record, c: record, legs: list<any>, last: int]: nothing -> list<any> {
    let names = ($legs | get name)
    let reach = ($legs | enumerate | each {|e| $legs | first ($e.index + 1) | each {|l| $l.places | length } | math sum })
    mut rows = []
    mut previous_flip: any = null
    for e in ($s.states | first ($last + 1) | enumerate) {
        let st = $e.item
        let leg_at = ($reach | enumerate | where {|r| $r.item >= $st.placed } | get -o 0.index | default (($names | length) - 1))
        let entry = (if $e.index == 0 { true } else { ($s.states | get ($e.index - 1) | get placed) != $st.placed })
        let f = ($c.frames | get -o $st.frame)
        let d = ($c.draws | get -o $st.frame)
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
            $rows = ($rows | append ($base | merge {
                start_us: $f.start_us, critical_us: $f.critical_us, hud_us: $f.hud_us, mix_us: $f.mix_us,
                flip_us: $f.flip_us, report_us: $f.report_us, await_us: $f.await_us, flip_done_us: $f.flip_done_us,
                flip_status: $f.flip_status, flip_interval_us: $interval, latency_us: ($f.flip_done_us - $f.start_us),
                unattributed_us: ($f.critical_us - ($PHASES | each {|p| $f | get $p } | math sum)),
                clear_us: $d.clear_us, portals_us: $d.portals_us, planes_us: $d.planes_us, walls_us: $d.walls_us,
                sprites_us: $d.sprites_us, tiles_us: $d.tiles_us,
                parts_unattributed_us: ($f.draw_us - ($PARTS | each {|p| $d | get $p } | math sum)),
                tiles_built: $d.tiles_built, tile_resets: $d.tile_resets, tiled_pixels: $d.tiled_pixels,
                lit_pixels: $d.lit_pixels, fallback_pixels: ($d.lit_pixels - $d.tiled_pixels),
                tile_bytes: $d.tile_bytes, tile_peak: $d.tile_peak, spans: $d.spans, spans_over: ($d.spans > $SPAN_RECORDS),
                over: ($f.critical_us >= $CEILING_US),
                aligned: ($f.draw_us == $st.draw_us and $f.game_us == $st.game_us),
            }))
        }
    }
    $rows
}

# The clock's columns of a row with no clock records, all null.
def clockless []: nothing -> record {
    [start_us critical_us hud_us mix_us flip_us report_us await_us flip_done_us flip_status flip_interval_us latency_us unattributed_us clear_us portals_us planes_us walls_us sprites_us tiles_us parts_unattributed_us tiles_built tile_resets tiled_pixels lit_pixels fallback_pixels tile_bytes tile_peak spans spans_over over aligned]
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
# drawing's parts, and the tile cache; the drawing's and the game's
# times alone without them.
def leg-summary [name: string, rows: list<any>]: nothing -> record {
    let clocked = ($rows | where {|r| $r.critical_us != null })
    let base = { leg: $name, frames: ($rows | length), entries: ($rows | where entry | length), draw: (stats ($rows | get draw_us)), game: (stats ($rows | get game_us)) }
    if ($clocked | is-empty) { return $base }
    $base | merge {
        over: ($clocked | where {|r| $r.over } | length),
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
    }
}

# The unexplained phase outliers: in a frame no placement opened, a
# phase past OUTLIER_RATIO times its leg's median and OUTLIER_US over
# it, the frame's tile work within twice its leg's median. Kept in
# every statistic; a host stall is one explanation, not the finding.
def outliers [rows: list<any>]: nothing -> list<any> {
    let clocked = ($rows | where {|r| $r.critical_us != null })
    $clocked | get leg | uniq | each {|leg|
        let these = ($clocked | where leg == $leg)
        let medians = ($PHASES | append "tiles_us" | reduce --fold {} {|p, acc| $acc | insert $p ((stats ($these | get $p)).median | default 0) })
        $these | where {|r| not $r.entry } | each {|r|
            let phases = ($PHASES | where {|p| let v = ($r | get $p); let m = ($medians | get $p); $v > ($OUTLIER_RATIO * $m) and ($v - $m) > $OUTLIER_US })
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

# One line on a run: complete or not and why, passing or not, the
# critical path's spread, the seed, the outcome.
def run-line [label: string, n: int, m: record, ran: record]: nothing -> string {
    let name = (if $label == "" { "" } else { $"($label): " })
    let fault = (if ($ran.fault? | default null) == null { "" } else { $"; FAULT ($ran.fault)" })
    if not $m.clocked {
        return $"gauge: ($name)run ($n): ($m.frames) frames from the state records alone; draw (spread $m.whole.draw), game (spread $m.whole.game)($fault)"
    }
    let state = (if $m.complete { if $m.passes { "complete, passes" } else { $"complete, fails: ($m.over) of ($m.frames) frames at or over 15 ms" } } else { $"incomplete: ($m.problems | str join '; ')" })
    let seed = (if $m.seeded { "seeded" } else if $m.late_seed { "seeded late, no paired comparison" } else { "unseeded" })
    $"gauge: ($name)run ($n): ($state); ($m.frames) frames to frame ($m.final), critical (spread $m.whole.critical) ms; ($seed)($fault)"
}

# A spread in milliseconds: least, median, 95th, 99th, greatest.
def spread [s: record]: nothing -> string {
    [$s.min $s.median $s.p95 $s.p99 $s.max] | each {|v| ms $v } | str join " / "
}

# Microseconds as milliseconds to a tenth, or a dash for none.
def ms [us: any]: nothing -> string {
    if $us == null { "-" } else { $"(($us / 1000.0) | math round --precision 1)" }
}

# The report: every run's measurement and outcome under the identity,
# written as gauge.nuon in `out`, its legs and its outliers printed.
def report [label: string, id: record, runs: list<any>, out: path]: nothing -> nothing {
    let file = ($out | path join "gauge.nuon")
    let doc = {
        label: $label,
        identity: $id,
        ceiling_us: $CEILING_US,
        runs: ($runs | each {|r| { run: $r.run, seed: $r.seed, out: $r.out, ran: $r.ran, measured: ($r.measured | reject rows) } }),
        rows: ($runs | each {|r| $r.measured.rows | each {|row| $row | insert run $r.run } } | flatten),
    }
    $doc | to nuon | save --raw -f $file
    for r in $runs {
        for l in $r.measured.legs {
            if ($l.critical? | default null) == null {
                print $"gauge:   run ($r.run) ($l.leg): ($l.frames) frames; draw (spread $l.draw), game (spread $l.game)"
            } else {
                print $"gauge:   run ($r.run) ($l.leg): ($l.frames) frames, ($l.over) at or over; critical (spread $l.critical); draw (ms $l.draw.median), game (ms $l.game.median), flip (ms $l.flip.median), report (ms $l.report.median), await (ms $l.await.median), tiles (ms $l.tiles.median) median; ($l.tiles_built) cells built over ($l.building_frames) frames, ($l.tiled_pixels) tiled and ($l.fallback_pixels) fallback lit pixels; flips early ($l.flips_early); unattributed (ms $l.unattributed.max) at most"
            }
        }
        let o = $r.measured.outliers
        if not ($o | is-empty) { print $"gauge:   run ($r.run): ($o | length) unexplained phase outliers, the first at frame ($o | first | get frame)" }
    }
    print $"gauge: ($file)"
}
