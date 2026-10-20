use (path self ../../../../../../nu/mod/build)
use (path self ../../../../../../nu/mod/launch)
use (path self ../../../../../../nu/mod/machine)
use (path self ../../../../../../nu/mod/nonce)
use (path self ../../../../../../nu/mod/sdl/bundle)
use (path self ../../console)
use (path self ../audio)
use (path self ../cpu)
use (path self ../identity)
use (path self ../measure)
use (path self ../../pose)
use (path self ../report)
use (path self ../../console) [SEED_AT]
use (path self ../../frame) [GFX_SLOTS]
use (path self ../measure) [CADENCES CAP SCREEN_ROWS]
use (path self ../audio) [END_AT MEASURED_TO QUEUE_FULL SECONDS]

# The workspace's root, resolved from this file's own path
const WORKSPACE = path self ../../../../../..

# The time after the E for the final records and marker to land, before the stop
const DRAIN = 2sec

# How far a run's bound lies past its stop
const BOUND_PAST = 3sec

# How far before the E a run's service stops, its window's records inside the measurement
const SERVICE_STOP_BEFORE = 1ms

# A script flag's NUON list, refused unless every item is of the kind named
def nuon-list [text: string, flag: string, kind: string]: nothing -> list<any> {
    let v = (try { $text | from nuon } catch { null })
    let d = ($v | describe)
    if $v == null or not (($d == "list<any>" and ($v | is-empty)) or $d == $"list<($kind)>") {
        error make { msg: $"($flag) takes a NUON list of ($kind) values, such as \"[...]\", not ($text)" }
    }
    $v
}

# The route played `runs` times on the build, each run measured and reported
export def route [
    --tree: string = "release"
    --kernel: string = ""
    --image: string = ""
    --route: string = ""
    --map: string = ""
    --assets: string = ""
    --runs: int = 3
    --seeds: string = "[]"
    --cadence: int = 1
    --workers: int = -1
    --grain: int = 32
    --host
    --out: string = ""
    --label: string = ""
    --spec (-s): string = ""
    --harts: int = 0
    --qemu: string = "[]"
    --cpu
    --sdl-probe
    --trace
    --service: int = -1
] {
    let seeds = (nuon-list $seeds "--seeds" "int")
    let qemu = (nuon-list $qemu "--qemu" "string")
    if $cadence not-in $CADENCES { error make { msg: $"--cadence is one of ($CADENCES | str join ', '), not ($cadence)" } }
    let asked = (workers-asked $workers $grain)
    let at = (places $tree $kernel $image $out)
    let machine = (machine resolve $at.workspace $spec $harts)
    let flags = (identity image-flags $at.image)
    let contradiction = (identity contradiction $flags $at.tree)
    if $contradiction != null { error make { msg: $contradiction } }
    if $service >= 0 and not (($flags | default "") =~ '--defsym SERVICE=') { error make { msg: $"--service asks the synthetic service, and the image's build flags define no SERVICE: ($flags | default 'none recorded')" } }
    let route_file = (if $route == "" { $WORKSPACE | path join "kit" "fierce" "nu" "nuon" "route" "route_render_0.nuon" } else { $route | path expand })
    let route_bytes = (open --raw $route_file | into binary)
    let r = ($route_bytes | decode utf-8 | from nuon)
    let requests = (if $cpu { cpu requests $r.legs $r.end } else { [] })
    let map_name = (if $map == "" { $r.map } else { $map })
    let at = ($at | insert assets (assets-of $at.game $map_name $assets))
    let disk = (romfs-of $at.assets $map_name $at.out)
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
        let nonce = (nonce mint 0 true)
        let probe_log = (if $sdl_probe { $run_out | path join "sdl.log" } else { "" })
        let words = (if $trace { $qemu ++ ["-msg" "timestamp=on" "-trace" "virtio_gpu_cmd_res_flush" "-trace" "virtio_gpu_cmd_set_scanout" "-D" ($run_out | path join "trace.log")] } else { $qemu })
        let sends = (console run-sends $seed $cadence $nonce $asked
            | append (service-sends $service $r.end)
            | append ($r.legs | each {|l| $l.places | each {|p| { at: $p.at, bytes: (pose pose-frame $p) } } } | flatten)
            | append ($r.legs | each {|l| $l | get -o sends | default [] | each {|s| { at: $s.at, bytes: (pose command-frame $s.kind) } } } | flatten)
            | append [{ at: $r.end, bytes: (pose command-frame "E") }]
            | sort-by at)
        let mode = { window: $host, sound: (if $host { "host" } else { "recorded" }), pad: "route", seed: $seed, cadence: $cadence, workers: $asked.workers, grain: $asked.grain, end: $r.end, capture: $capture, service: (if $service < 0 { null } else { $service }) }
        let id = (identity new $at $set $map_name $route_file $mode $machine $words | merge { profile: "paired", capture_nonce: $nonce })
        $id | to nuon --indent 2 | save --raw -f ($run_out | path join "identity.nuon")
        let launched = (if $host {
            launch --kernel $at.kernel --image $at.image --out $run_out --set $set --live-sound --window --api --pad $pad --disk $disk --serial "fps" --send $sends --stop $capture --seconds $seconds --spec $spec --harts $harts --qemu $words --threads-at $requests --capture-nonce $nonce --profile paired --sdl-probe $probe_log --workspace $at.workspace
        } else {
            launch --kernel $at.kernel --image $at.image --out $run_out --set $set --sound --api --pad $pad --disk $disk --serial "fps" --send $sends --stop $capture --seconds $seconds --spec $spec --harts $harts --qemu $words --threads-at $requests --capture-nonce $nonce --profile paired --sdl-probe $probe_log --workspace $at.workspace
        })
        let ran = (cpu outcome $launched)
        $ran | to nuon --indent 2 | save --raw -f ($run_out | path join "run.nuon")
        let ran_id = (identity launched-identity $id $launched)
        let id_sha = (identity write $ran_id $run_out)
        let bundle = (if $sdl_probe { bundle $run_out ($run_out | path join "bundle") --profile paired | ignore; $run_out | path join "bundle" } else { null })
        let measured = (measure $launched.api $r.legs --cap ($id.cap | default $CAP))
        print (report run-line $label $n $measured $ran)
        print (report outcome-line $n $measured $ran)
        let served = (report service-line $n $measured)
        if $served != null { print $served }
        let windows = (if $cpu { cpu windows $ran.thread_readings $r.legs $r.end } else { null })
        { run: $n, seed: $seed, out: $run_out, ran: $ran, measured: $measured, identity: $ran_id, corrections: null, identity_sha256: $id_sha, cpu: $windows, bundle: $bundle }
    })
    report write $label (open ($at.out | path join "run_1" "identity.nuon")) $runs $at.out
}

# The build in the host's window for a person to play, measured over `seconds`
export def host [
    --tree: string = "release"
    --kernel: string = ""
    --image: string = ""
    --seconds: int = 120
    --seed: int = 1
    --cadence: int = 1
    --workers: int = -1
    --grain: int = 32
    --assets: string = ""
    --out: string = ""
    --label: string = ""
    --spec (-s): string = ""
    --harts: int = 0
    --qemu: string = "[]"
] {
    let qemu = (nuon-list $qemu "--qemu" "string")
    if $cadence not-in $CADENCES { error make { msg: $"--cadence is one of ($CADENCES | str join ', '), not ($cadence)" } }
    let asked = (workers-asked $workers $grain)
    let at = (places $tree $kernel $image $out)
    let machine = (machine resolve $at.workspace $spec $harts)
    let contradiction = (identity contradiction (identity image-flags $at.image) $at.tree)
    if $contradiction != null { error make { msg: $contradiction } }
    let at = ($at | insert assets (assets-of $at.game "render_0" $assets))
    let disk = (romfs-of $at.assets "render_0" $at.out)
    let set = (if $at.tree == "debug" { "debug" } else { "" })
    let end = ($seconds * 1sec)
    let capture = ($end + $DRAIN)
    let bound = ((($capture + $BOUND_PAST) / 1sec) | math ceil)
    let run_out = ($at.out | path join "run_1")
    mkdir $run_out
    let sends = ([{ at: $SEED_AT, bytes: (console seed $seed) }, { at: $SEED_AT, bytes: (console cadence $cadence) }]
        | append (console workers-sends $asked)
        | append [{ at: $end, bytes: (pose command-frame "E") }])
    let mode = { window: true, sound: "host", pad: "host", seed: $seed, cadence: $cadence, workers: $asked.workers, grain: $asked.grain, end: $end, capture: $capture }
    let id = (identity new $at $set "render_0" null $mode $machine $qemu)
    $id | to nuon --indent 2 | save --raw -f ($run_out | path join "identity.nuon")
    print $"gauge: play until the window closes, ($seconds) seconds measured from the start"
    let launched = (launch --kernel $at.kernel --image $at.image --out $run_out --set $set --live-sound --window --host-pad --api --disk $disk --serial "fps" --send $sends --stop $capture --seconds $bound --spec $spec --harts $harts --qemu $qemu --workspace $at.workspace)
    let ran = (cpu outcome $launched)
    $ran | to nuon --indent 2 | save --raw -f ($run_out | path join "run.nuon")
    let ran_id = (identity launched-identity $id $launched)
    let id_sha = (identity write $ran_id $run_out)
    let legs = [{ name: "play", places: [], pad: [] }]
    let measured = (measure $launched.api $legs --cap ($id.cap | default $CAP))
    print (report run-line $label 1 $measured $ran)
    print (report outcome-line 1 $measured $ran)
    report write $label $ran_id [{ run: 1, seed: $seed, out: $run_out, ran: $ran, measured: $measured, identity: $ran_id, corrections: null, identity_sha256: $id_sha, cpu: null }] $at.out
}

# RegressionSuite's fixture as a bench step, a debug build's: its pad table
# through the play, the sound live in the host's window or else recorded, the
# E closing the measurement and the Z's exit writing the kernel's counts, the
# reading kept as audio.nuon beside the run and in the report
export def audio [
    --tree: string = "debug"
    --kernel: string = ""
    --image: string = ""
    --assets: string = ""
    --host
    --out: string = ""
    --label: string = ""
    --spec (-s): string = ""
    --harts: int = 0
    --qemu: string = "[]"
] {
    let qemu = (nuon-list $qemu "--qemu" "string")
    if $tree != "debug" { error make { msg: $"--tree is debug: the kernel's pad and sound counts are a debug build's, not the ($tree) tree's" } }
    let at = (places $tree $kernel $image $out)
    let machine = (machine resolve $at.workspace $spec $harts)
    let contradiction = (identity contradiction (identity image-flags $at.image) $at.tree)
    if $contradiction != null { error make { msg: $contradiction } }
    let at = ($at | insert assets (assets-of $at.game "render_0" $assets))
    let disk = (romfs-of $at.assets "render_0" $at.out)
    let run_out = ($at.out | path join "run_1")
    mkdir $run_out
    let table = (audio play-table)
    let pad = ($run_out | path join "table.nuon")
    $table | to nuon --indent 2 | save --raw -f $pad
    let words = ($qemu ++ ["-trace" $QUEUE_FULL])
    let mode = { window: $host, sound: (if $host { "host" } else { "recorded" }), pad: "table", seed: null, cadence: null, workers: null, grain: null, end: $MEASURED_TO, capture: $END_AT, service: null }
    let id = (identity new $at "debug" "render_0" null $mode $machine $words)
    $id | to nuon --indent 2 | save --raw -f ($run_out | path join "identity.nuon")
    let launched = (if $host {
        launch --kernel $at.kernel --image $at.image --out $run_out --set "debug" --live-sound --window --api --pad $pad --disk $disk --serial "fps" --send (audio sends) --seconds $SECONDS --spec $spec --harts $harts --qemu $words --workspace $at.workspace
    } else {
        launch --kernel $at.kernel --image $at.image --out $run_out --set "debug" --sound --api --pad $pad --disk $disk --serial "fps" --send (audio sends) --seconds $SECONDS --spec $spec --harts $harts --qemu $words --workspace $at.workspace
    })
    let ran = (cpu outcome $launched)
    $ran | to nuon --indent 2 | save --raw -f ($run_out | path join "run.nuon")
    let ran_id = (identity launched-identity $id $launched)
    let id_sha = (identity write $ran_id $run_out)
    let reading = (audio reading $launched ($table | length))
    $reading | to nuon --indent 2 | save --raw -f ($run_out | path join "audio.nuon")
    let measured = (measure $launched.api [{ name: "play", places: [], pad: [] }] --cap ($id.cap | default $CAP))
    print (report run-line $label 1 $measured $ran)
    print (audio line $reading)
    report write $label $ran_id [{ run: 1, seed: null, out: $run_out, ran: $ran, measured: $measured, identity: $ran_id, corrections: null, identity_sha256: $id_sha, cpu: null, audio: $reading }] $at.out
}

# A run's V frames asking the service: its start, `quota` messages every
# frame, at SEED_AT, and its stop SERVICE_STOP_BEFORE the E; none for -1
def service-sends [quota: int, end: duration]: nothing -> list<any> {
    if $quota < 0 { return [] }
    [{ at: $SEED_AT, bytes: (console service true --total $quota) }, { at: ($end - $SERVICE_STOP_BEFORE), bytes: (console service false) }]
}

# A run's places: game, workspace, tree, kernel, image, and output dir, made
def places [tree: string, kernel: string, image: string, out: string]: nothing -> record<game: string, workspace: string, tree: string, kernel: string, image: string, out: string> {
    if $tree not-in [release debug] { error make { msg: $"--tree is release or debug, not ($tree)" } }
    let program = ($WORKSPACE | path join "kit" "fierce")
    let game = $program
    let workspace = ($game | path join ".." ".." | path expand)
    let stamp = (date now | format date "%Y%m%d-%H%M%S")
    let built = (build program-out $program $tree)
    let target = (if $out == "" { $built | path join "gauge" $stamp } else { $out | path expand })
    mkdir $target
    {
        game: $game,
        workspace: $workspace,
        tree: $tree,
        kernel: (if $kernel == "" { build program-kernel $program $tree } else { $kernel | path expand }),
        image: (if $image == "" { $built | path join "fierce.jab" } else { $image | path expand }),
        out: $target,
    }
}

# A map's compiled tree, `assets` or else the checkout's shard's, held to the map
def assets-of [game: path, map: string, assets: string]: nothing -> string {
    let tree = (if $assets == "" { build program-shard $game "asset" | path join $map } else { $assets | path expand })
    let named = ($tree | path join "map" "name")
    if not ($named | path exists) { error make { msg: $"no compiled map tree at ($tree): it holds no map/name" } }
    let name = (open --raw $named | decode | str trim)
    if $name != $map { error make { msg: $"the tree at ($tree) holds the map ($name), where the run plays ($map)" } }
    $tree
}

# A map's tree built in `out` as the romfs image the program reads
def romfs-of [tree: path, map: string, out: path]: nothing -> string {
    if not ($tree | path join "map.nuon" | path exists) { error make { msg: $"no tree for ($map) at ($tree)" } }
    let disk = ($out | path join $"($map).romfs")
    let made = (^genromfs -d $tree -f $disk -V "fps" | complete)
    if $made.exit_code != 0 { error make { msg: $"genromfs on ($tree): ($made.stderr)" } }
    $disk
}

# The workers and grain a run asks, null for none, refused out of range
def workers-asked [workers: int, grain: int]: nothing -> record<workers: oneof<int, nothing>, grain: oneof<int, nothing>> {
    if $workers < 0 { return { workers: null, grain: null } }
    if $workers > $GFX_SLOTS { error make { msg: $"--workers is 0 to ($GFX_SLOTS), not ($workers)" } }
    if $grain < 0 or $grain > $SCREEN_ROWS { error make { msg: $"--grain is 0 to ($SCREEN_ROWS), not ($grain)" } }
    { workers: $workers, grain: $grain }
}
