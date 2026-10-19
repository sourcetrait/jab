use (path self ../../../../../../nu/mod/build)
use (path self ../../../../../../nu/mod/walk)

# The game's directory, from the module's own file
const GAME = path self ../../../..

# The map compiler's bin, a source compiled in a nu of its own
const COMPILER = path self ../../../bin/nuance/map.nu

# Every map source under content/map compiled into the game's asset shard
export def main [] {
    let trees = (build program-shard $GAME "asset")
    for src in (walk paths ($GAME | path join "content" "map" "*.nuon")) {
        ^nu $COMPILER compile $src $trees
    }
}
