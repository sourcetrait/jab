# adv.nu: the game's commands for development, the manifest's `adv`,
# which the repository's `just adv <command>` runs and `just adv` lists:
# the content rendered and compiled, a capture of placed poses, the smoke
# test, robojab's play, and the gauge. A command that runs the program
# builds it first through the SDK, its maps compiled with it.
use ../../../sdk/nu/jab.nu

const here = (path self | path dirname)

def main [] {
    print "nu adv.nu <command> [args]; `just adv` at the repository's root lists the commands"
}

# The game's directory, the workspace's, and the SDK's tool.
def places []: nothing -> record<game: string, workspace: string, tool: string> {
    let game = ($here | path join ".." | path expand)
    let workspace = ($game | path join ".." ".." | path expand)
    { game: $game, workspace: $workspace, tool: ($workspace | path join "sdk" "nu" "jab.nu") }
}

# The game built through the SDK with the symbols `set` names, its maps
# compiled first.
def build [set: string]: nothing -> nothing {
    let p = (places)
    ^nu $p.tool build $p.workspace "game/fps" --set $set
}

# Every asset under content/ rendered to the file beside it the engine
# reads: an SVG to a PNG at its own size through rust/svg2png, built when
# it is not there; an ambient note list to a MIDI file through
# nu/ambient.nu; a sound recipe to PCM through nu/sound.nu
def "main render" [] {
    let p = (places)
    let tool = ($p.game | path join "rust" "target" "release" "svg2png")
    if not ($tool | path exists) { ^cargo build --release --manifest-path ($p.game | path join "rust" "Cargo.toml") }
    for svg in (glob ($p.game | path join "content" "**" "*.svg")) { ^$tool $svg ($svg | str replace --regex '\.svg$' '.png') }
    for list in (glob ($p.game | path join "content" "ambient" "*.nuon")) { ^nu ($here | path join "ambient.nu") render $list ($list | str replace --regex '\.nuon$' '.mid') }
    for recipe in (glob ($p.game | path join "content" "sound" "*.nuon")) { ^nu ($here | path join "sound.nu") render $recipe ($recipe | str replace --regex '\.nuon$' '.pcm') }
}

# Every map source under content/map compiled into the game's asset shard
# of the target, each a tree with its materials, ambients, counts, and
# plan views
def "main compile" [] {
    ^nu ($here | path join "prepare.nu") build
}

# A run's screen capture as a PNG to look at, every Nth pixel: `just adv
# shot <screen.ppm> frame.png`
def "main shot" [ppm: path, png: path, --step: int = 4] {
    ^nu ($here | path join "shot.nu") $ppm $png --step $step
}

# Build with the symbols given, then capture a map from placed camera
# poses, a NUON list of {name, x, y, z, yaw, pitch}, as PNGs under out:
# `just adv pose render_1 poses.nuon out`; `--set debug,owner` captures the
# surface each pixel belongs to
def "main pose" [map: string, poses: path, out: path, --set: string = "debug"] {
    build $set
    let p = (places)
    let built = (jab program-out $p.game "debug")
    ^nu ($p.game | path join "test" "pose.nu") $map ($poses | path expand) ($out | path expand) --kernel (jab program-kernel $p.game "debug") --image ($built | path join "fps.jab") --set $set
}

# Build with DEBUG set, then play Render Zero on the pad from seeded
# random tables for that many seconds a seed, the seeds separated by
# commas, a fault resolved to its routine: `just adv smoke 1,2,3 60`
def "main smoke" [seeds: string = "1", seconds: int = 60] {
    let list = ($seeds | split row "," | each {|s| $s | str trim } | where {|s| $s != "" } | each {|s| $s | into int })
    build "debug"
    let p = (places)
    let built = (jab program-out $p.game "debug")
    ^nu ($p.game | path join "test" "smoke.nu") --kernel (jab program-kernel $p.game "debug") --image ($built | path join "fps.jab") --out ($built | path join "smoke") --seeds ($list | to nuon) --seconds $seconds
}

# Build with DEBUG set, then hand a map to robojab for an agent or a
# script to play: `just adv play` prints the MCP server line and config
# record for a subagent; `just adv play <socket>` serves commands on that
# socket in the foreground; `just adv play mcp render_1 300` another map
# and bound
def "main play" [target: string = "mcp", map: string = "render_0", seconds: int = 600] {
    build "debug"
    let p = (places)
    let built = (jab program-out $p.game "debug")
    ^nu ($p.game | path join "test" "play.nu") --kernel (jab program-kernel $p.game "debug") --image ($built | path join "fps.jab") --out ($built | path join "play") --map $map --seconds $seconds --target $target
}

# Build, then play the gauge's route (test/route_render_0.nuon) on that
# build headless, every frame of each run read from the program's clock
# records, gauge.nuon written and the summary printed: `just adv gauge`,
# the release build three times at the program's own cadence, 1; `just
# adv gauge debug 1`; `--host` in the host's window and audio; `--cadence
# 0`, `1`, or `2`; `--out` and `--label` as gauge.nu takes them
def --wrapped "main gauge" [tree: string = "release", runs: int = 3, ...rest] {
    build (if $tree == "debug" { "debug" } else { "" })
    let p = (places)
    ^nu ($p.game | path join "test" "gauge.nu") run --tree $tree --runs $runs ...$rest
}

# Build, then put Render Zero in the host's window, with its audio and
# its own gamepad, for you to play; the measurement closes after that
# many seconds and the window with it: `just adv gauge-play 120`, or
# `just adv gauge-play 60 release --cadence 2`
def --wrapped "main gauge-play" [seconds: int = 120, tree: string = "release", ...rest] {
    build (if $tree == "debug" { "debug" } else { "" })
    let p = (places)
    ^nu ($p.game | path join "test" "gauge.nu") play --tree $tree --seconds $seconds ...$rest
}

# Read a run's capture as the gauge reads its own, the identity its
# launch wrote beside it taken up: `just adv gauge-read <run>/api.out`
def --wrapped "main gauge-read" [api: path, ...rest] {
    let p = (places)
    ^nu ($p.game | path join "test" "gauge.nu") read ($api | path expand) ...$rest
}

# Set builds' gauge.nuon files side by side, each walked leg per half
# metre of its path, the method and every bin kept: `just adv
# gauge-compare a/gauge.nuon b/gauge.nuon`; a run measured incomplete,
# invalid, or before validity was recorded is refused unless
# `--diagnostic` admits it, marked, and one with nothing to compare is
# refused even then
def --wrapped "main gauge-compare" [...rest] {
    let p = (places)
    ^nu ($p.game | path join "test" "gauge.nu") compare ...$rest
}
