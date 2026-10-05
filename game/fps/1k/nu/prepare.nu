# prepare.nu: what the SDK runs before it builds, tests, or runs the game,
# the manifest's `prepare`: every map source under content/map compiled
# into the game's asset shard of the target, the trees the program's disk
# and its tests read, alike for every phase.
use ../../../../sdk/nu/jab.nu

def main [phase: string] {
    let game = ($env.FILE_PWD | path join ".." | path expand)
    let trees = (jab program-shard $game "asset")
    for src in (glob ($game | path join "content" "map" "*.nuon")) {
        ^nu ($env.FILE_PWD | path join "map.nu") compile $src $trees
    }
}
