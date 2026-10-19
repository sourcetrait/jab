use (path self ../../../../../../nu/mod/launch)
use (path self ../../console)
use (path self ../../pose)
use (path self ../../tree)
use std/assert
use (path self ../../console) [GRAIN_DEFAULT SPAWN_POSE]
use (path self ../../frame) [GFX_SLOTS]

# The harts the census fixtures run on
const CENSUS_HARTS = 8

# The bytes the Q frame shrinks a context line's chunk to
const CENSUS_SHRUNK = 96

# When a context line's chunk is shrunk and when restored
const CENSUS_SHRINK = { from: 1400ms, to: 2400ms }

# The census's lighting revisions: each one's time and lumels
const CENSUS_LIGHTS = [
    { at: 3000ms, bright: true, parity: false }
    { at: 5000ms, bright: false, parity: true }
    { at: 7000ms, bright: true, parity: false }
]

# When the census run's capture ends it
const CENSUS_END = 9000ms

# The census fixtures in one launch on eight harts, its log read apart
def census-holds [kernel: path, image: path, out: path, set: string, game: path]: nothing -> nothing {
    let dir = ($out | path join "census")
    mkdir $dir
    let still_tree = (tree variant (open ($game | path join "content" "map" "render_0.nuon")) "render_0_still" [android] ($dir | path join "still") $game)
    let still_disk = (tree romfs $still_tree ($dir | path join "still.romfs"))
    let lights = ($CENSUS_LIGHTS | each {|l| { at: $l.at, bytes: (console level $l.bright true --parity=$l.parity) } })
    let sends = ([
        { at: 1300ms, bytes: (console workers $GFX_SLOTS $GRAIN_DEFAULT) }
        { at: $CENSUS_SHRINK.from, bytes: (console census $CENSUS_SHRUNK) }
        { at: 1500ms, bytes: (pose pose-frame $SPAWN_POSE) }
        { at: $CENSUS_SHRINK.to, bytes: (console census 0) }
    ] | append $lights | sort-by at)
    let run = (launch --kernel $kernel --image $image --out ($dir | path join "run") --set $set --sound --api --disk $still_disk --serial "fps" --send $sends --capture $CENSUS_END --seconds 10 --harts $CENSUS_HARTS)
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest on the census run"
    let faults = ($run.serial | lines | where {|l| $l starts-with "jab: " })
    assert ($faults | is-empty) $"no fault on the census run: ($faults)"

    let holds = ($game | path join "nu" "mod" "census")
    let serial = ($dir | path join "run" "serial.log")
    let command = ("use '" + $holds + "' [census-fixture-holds]; print (census-fixture-holds (open --raw '" + $serial + "' | decode) " + ($CENSUS_SHRUNK | into string) + " " + ($GFX_SLOTS | into string) + ")")
    let read = (^nu -c $command | complete)
    print -n $read.stdout
    if $read.exit_code != 0 { print -e -n $read.stderr }
    assert equal $read.exit_code 0 "the census fixture's reading held in a nu of its own"
}

# A CENSUS build's own fixtures, run alone
export def holds [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
        census-holds $kernel $image $out $set $context.game
    {}
}
