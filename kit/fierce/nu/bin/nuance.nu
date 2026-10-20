#!/usr/bin/env nu
# The game's commands' path, bound at parse time
const GAME = path self ../mod/game
# The gauge's aggregator's path, bound at parse time
const GAUGE = path self ../mod/gauge
# The asset trees' path, bound at parse time
const TREES = path self ../mod/map/trees
# The screen shot's path, bound at parse time
const SHOT = path self ../mod/shot
use $GAME
use $GAUGE
use $TREES
use $SHOT

# Every content asset rendered beside it by game render
def "main render" [] {
    game render
}

# Every map source compiled into the asset shard by trees
def "main compile" [] {
    trees
}

# A run's screen capture as a PNG to look at by shot
def "main shot" [ppm: path, png: path, --step: int = 4] {
    shot $ppm $png --step $step
}

# A map captured from placed poses on a debug build by game pose
def "main pose" [map: string, poses: path, out: path, --set: string = "debug"] {
    game pose $map $poses $out --set $set
}

# Seeded random players on the pad on a debug build by game smoke
def "main smoke" [seeds: string = "1", seconds: int = 60] {
    game smoke $seeds $seconds
}

# A debug build's map handed to robojab by game play
def "main play" [target: string = "mcp", map: string = "render_0", seconds: int = 600] {
    game play $target $map $seconds
}

# A route played and measured from the command line by gauge play route
def "main gauge run" [--tree: string = "release", --kernel: string = "", --image: string = "", --route: string = "", --map: string = "", --assets: string = "", --runs: int = 3, --seeds: string = "[]", --cadence: int = 1, --workers: int = -1, --grain: int = 32, --host, --out: string = "", --label: string = "", --spec (-s): string = "", --harts: int = 0, --qemu: string = "[]", --cpu, --sdl-probe, --trace, --service: int = -1, --eps: int = 10000] {
    gauge play route --tree $tree --kernel $kernel --image $image --route $route --map $map --assets $assets --runs $runs --seeds $seeds --cadence $cadence --workers $workers --grain $grain --host=$host --out $out --label $label --spec $spec --harts $harts --qemu $qemu --cpu=$cpu --sdl-probe=$sdl_probe --trace=$trace --service $service --eps $eps
}

# RegressionSuite's fixture as a bench step from the command line by gauge play audio
def "main gauge audio" [--tree: string = "debug", --kernel: string = "", --image: string = "", --assets: string = "", --host, --out: string = "", --label: string = "", --spec (-s): string = "", --harts: int = 0, --qemu: string = "[]"] {
    gauge play audio --tree $tree --kernel $kernel --image $image --assets $assets --host=$host --out $out --label $label --spec $spec --harts $harts --qemu $qemu
}

# A host play from the command line by gauge play host
def "main gauge play" [--tree: string = "release", --kernel: string = "", --image: string = "", --seconds: int = 120, --seed: int = 1, --cadence: int = 1, --workers: int = -1, --grain: int = 32, --assets: string = "", --out: string = "", --label: string = "", --spec (-s): string = "", --harts: int = 0, --qemu: string = "[]", --eps: int = 10000] {
    gauge play host --tree $tree --kernel $kernel --image $image --seconds $seconds --seed $seed --cadence $cadence --workers $workers --grain $grain --assets $assets --out $out --label $label --spec $spec --harts $harts --qemu $qemu --eps $eps
}

# A capture read from the command line by gauge read
def "main gauge read" [api: path, --route: string = "", --out: string = "", --label: string = "", --eps: int = 10000] {
    gauge read $api --route $route --out $out --label $label --eps $eps
}

# A kept bench step's report made again by gauge read batch
def "main gauge read batch" [step: path, --label: string = "", --out: string = "", --eps: int = 10000] {
    gauge read batch $step --label $label --out $out --eps $eps
}

# Builds compared from the command line by gauge compare report
def "main gauge compare" [...files: string, --field: string = "draw_us", --bin-cm: int = 50, --out: string = "", --diagnostic] {
    gauge compare report ...$files --field $field --bin-cm $bin_cm --out $out --diagnostic=$diagnostic
}

# A bench's report from the command line by gauge bench report
def "main gauge bench-report" [dir: path] {
    gauge bench report $dir
}

def main [] { help main }
