use (path self ../../../../../nu/mod/build)
use (path self ../../../../../nu/mod/launch)
use (path self ../map)
use (path self ../shot)

# The workspace's root, resolved from this file's own path
const WORKSPACE = path self ../../../../..

# An API record's size in bytes
const RECORD = 64

# What a trace's ray met, named, indexed as the program reports it
const TRACE_KINDS = [nothing plane piece android player]

# The API event records' names by record kind
const EVENT_KINDS = { 2: "round", 3: "android", 4: "hurt", 5: "pickup", 6: "trace" }

# What a round met, named, indexed as the program reports it
const MET = [nothing geometry android]

# The android events' names, indexed as the program reports them
const ANDROID_EVENTS = [none roused fired struck destroyed fallen waypoint]

# A map captured from placed poses, a launch and a PNG a pose, events printed
export def capture [map: string, poses: path, out: path, --kernel: path, --image: path, --set: string = "DEBUG"]: nothing -> nothing {
    let game = ($WORKSPACE | path join "kit" "fierce")
    let tree = (build program-shard $game "asset" | path join $map)
    let disk = ($out | path join $"($map).romfs")
    mkdir $out
    let made = (^genromfs -d $tree -f $disk -V "fps" | complete)
    if $made.exit_code != 0 { error make { msg: $"genromfs on ($tree): ($made.stderr)" } }
    for p in (open $poses) {
        let run_out = ($out | path join $"($map)_($p.name)")
        let sends = ([{ at: 2000ms, bytes: (pose-frame $p) }]
            | append (if (($p.report? | default 0) | into int) > 0 { [{ at: ((($p.report | into int)) * 1ms), bytes: (pose-frame $p) }] } else { [] })
            | append (if ($p.trace? | default false) { [{ at: 2500ms, bytes: (command-frame "T") }] } else { [] })
            | append (($p.sends? | default []) | each {|s| { at: (($s.at | into int) * 1ms), bytes: (command-frame $s.kind) } })
            | sort-by at)
        let capture = ((($p.capture? | default 3000) | into int) * 1ms)
        let seconds = (($p.seconds? | default 5) | into int)
        let pad = ($p.pad? | default "")
        let run = (if $pad == "" {
            launch --kernel $kernel --image $image --out $run_out --set $set --sound --api --disk $disk --serial "fps" --send $sends --capture $capture --seconds $seconds
        } else {
            launch --kernel $kernel --image $image --out $run_out --set $set --sound --api --pad $pad --disk $disk --serial "fps" --send $sends --capture $capture --seconds $seconds
        })
        let records = (0..<(($run.api | bytes length) // $RECORD) | each {|i|
            let r = ($run.api | bytes at ($i * $RECORD)..<(($i + 1) * $RECORD))
            {
                kind: ($r | bytes at 0..<4 | into int --endian little),
                sector: ($r | bytes at 4..<8 | into int --endian little --signed),
                fields: (0..<5 | each {|f| $r | bytes at (40 + $f * 4)..<(44 + $f * 4) | into int --endian little --signed }),
            }
        })
        let console = ($records | enumerate | where {|r| $r.item.kind == 11 })
        let landed = (if ($console | is-empty) { null } else { $records | slice ($console | get 0.index).. | where kind == 1 | get -o 0.sector })
        let lines = ($run.serial | lines | where {|l| ($l starts-with "fps: frame in") or ($l starts-with "fps: sectors") } | last 2)
        print $"pose ($p.name): sector ($landed); status ($run.status)"
        for l in $lines { print $"pose ($p.name): ($l)" }
        for e in ($records | enumerate | where {|r| $r.item.kind >= 2 and $r.item.kind <= 6 }) {
            let t = $e.item
            let f = $t.fields
            let said = (match $t.kind {
                2 => $"a round met ($MET | get $f.0), actor ($f.1), its health ($f.2)",
                3 => $"android ($f.1) ($ANDROID_EVENTS | get $f.0), row ($f.2)",
                4 => $"the frame struck for ($f.0), its health ($f.1)",
                5 => $"a pickup, ($f.0) rounds",
                6 => $"the eye's ray met ($TRACE_KINDS | get $f.0) at ($f.1 / 1000) m, the point ($f.2 / 1000), ($f.3 / 1000), ($f.4 / 1000)",
                _ => $"($f)",
            })
            print $"pose ($p.name): record ($e.index) ($EVENT_KINDS | get ($t.kind | into string)): ($said)"
        }
        if $run.screen != "" {
            shot $run.screen ($out | path join $"($map)_($p.name).png") --step 3
        } else {
            print $"pose ($p.name): no capture; ($run.serial | lines | last 2 | str join ' | ')"
        }
    }
}

# The console's P frame for a pose: the eye and its angles as singles
export def pose-frame [p: record]: nothing -> binary {
    let floats = [($p.x | into float), ($p.y | into float), ($p.z | into float), ($p.yaw | into float), ($p.pitch | into float), 0.0]
    [("P" | into binary), 0x[00 00 00], ($floats | each {|f| map float-bytes $f } | bytes collect), (0..<36 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# A console frame of a command with no fields: its kind byte, then zeros
export def command-frame [kind: string]: nothing -> binary {
    [($kind | into binary), (0..<63 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}
