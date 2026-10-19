use (path self ../../../../../nu/mod/build)
use (path self ../../../../../nu/mod/walk)
use (path self ../ambient)
use (path self ../play)
use (path self ../pose)
use (path self ../smoke)
use (path self ../sound)

# The workspace's root, resolved from this file's own path
const WORKSPACE = path self ../../../../..

# The game's directory, the workspace's, and the SDK's tool
def places []: nothing -> record<game: string, workspace: string, tool: string> {
    let game = ($WORKSPACE | path join "kit" "fierce")
    let workspace = ($game | path join ".." ".." | path expand)
    { game: $game, workspace: $workspace, tool: ($workspace | path join "nu" "bin" "do.nu") }
}

# The game built through the SDK with the symbols `set` names, maps first
def build [set: string]: nothing -> nothing {
    let p = (places)
    ^nu $p.tool build $p.workspace "kit/fierce" --set $set
}

# Every asset under content/ rendered to the file beside it the engine reads
export def render [] {
    let p = (places)
    let tool = ($p.game | path join "rust" "target" "release" "svg2png")
    if not ($tool | path exists) { ^cargo build --release --manifest-path ($p.game | path join "rust" "Cargo.toml") }
    for svg in (walk paths ($p.game | path join "content" "**" "*.svg")) { ^$tool $svg ($svg | str replace --regex '\.svg$' '.png') }
    for list in (walk paths ($p.game | path join "content" "ambient" "*.nuon")) { ambient render $list ($list | str replace --regex '\.nuon$' '.mid') }
    for recipe in (walk paths ($p.game | path join "content" "sound" "*.nuon")) { sound render $recipe ($recipe | str replace --regex '\.nuon$' '.pcm') }
}

# A debug build's captures of a map from placed poses, PNGs under `out`
export def pose [map: string, poses: path, out: path, --set: string = "debug"] {
    build $set
    let p = (places)
    let built = (build program-out $p.game "debug")
    pose capture $map ($poses | path expand) ($out | path expand) --kernel (build program-kernel $p.game "debug") --image ($built | path join "fierce.jab") --set $set
}

# A debug build played by seeded random pads, each seed one run held
export def smoke [seeds: string = "1", seconds: int = 60] {
    let list = ($seeds | split row "," | each {|s| $s | str trim } | where {|s| $s != "" } | each {|s| $s | into int })
    build "debug"
    let p = (places)
    let built = (build program-out $p.game "debug")
    smoke seeds --kernel (build program-kernel $p.game "debug") --image ($built | path join "fierce.jab") --out ($built | path join "smoke") --seeds ($list | to nuon) --seconds $seconds
}

# A debug build's map handed to robojab: an MCP config or a socket served
export def play [target: string = "mcp", map: string = "render_0", seconds: int = 600] {
    build "debug"
    let p = (places)
    let built = (build program-out $p.game "debug")
    play serve --kernel (build program-kernel $p.game "debug") --image ($built | path join "fierce.jab") --out ($built | path join "play") --map $map --seconds $seconds --target $target
}
