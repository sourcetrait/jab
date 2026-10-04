# prepare.nu: what the SDK runs before it builds, tests, or runs the game,
# the manifest's `prepare`: every map source under content/map compiled
# into the game's asset shard of the target, the trees the program's disk
# and its tests read; and before a test, the sample trees the test puts on
# the machine itself, laid out there by the conversion tooling kept
# outside the repository, a missing one stopping with its path.
use ../../../../sdk/nu/jab.nu

def main [phase: string] {
    let game = ($env.FILE_PWD | path join ".." | path expand)
    let trees = (jab program-shard $game "asset")
    for src in (glob ($game | path join "content" "map" "*.nuon")) {
        ^nu ($env.FILE_PWD | path join "map.nu") compile $src $trees
    }
    if $phase == "test" {
        for m in [cage2 doortest] {
            let tree = ($trees | path join $m)
            if not ($tree | path join "map.nuon" | path exists) {
                error make { msg: $"no test tree at ($tree); lay it out with the conversion tooling kept outside the repository" }
            }
        }
    }
}
