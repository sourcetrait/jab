# prepare.nu: what the SDK runs before it builds, tests, or runs the game,
# the manifest's `prepare`: every map source under content/map compiled
# into the game's asset shard of the target, the trees the program's disk
# and its tests read, alike for every phase.
use ../../../nu/mod/walk
use ../../../nu/mod/build

def main [phase: string] {
    let game = ($env.FILE_PWD | path join ".." | path expand)
    let trees = (build program-shard $game "asset")
    for src in (walk paths ($game | path join "content" "map" "*.nuon")) {
        ^nu ($env.FILE_PWD | path join "map.nu") compile $src $trees
    }
}
