# This file's directory, fierce's nu tree
const here = (path self | path dirname)

# The commands' usage; `just do` at the repository's root lists them
def main [] {
    print "nu do.nu <command> [args]; `just do` at the repository's root lists the commands"
}

# Every content asset rendered by nuance.nu's render
def "main render" [] {
    ^nu ($here | path join "bin" "nuance.nu") render
}

# Every map source compiled into the asset shard by nuance.nu's compile
def "main compile" [] {
    ^nu ($here | path join "bin" "nuance.nu") compile
}

# A run's screen capture as a PNG to look at by nuance.nu's shot
def "main shot" [ppm: path, png: path, --step: int = 4] {
    ^nu ($here | path join "bin" "nuance.nu") shot $ppm $png --step $step
}

# A map captured from placed poses by nuance.nu's pose
def "main pose" [map: string, poses: path, out: path, --set: string = "debug"] {
    ^nu ($here | path join "bin" "nuance.nu") pose $map $poses $out --set $set
}

# Seeded random players on the pad by nuance.nu's smoke
def "main smoke" [seeds: string = "1", seconds: int = 60] {
    ^nu ($here | path join "bin" "nuance.nu") smoke $seeds $seconds
}

# A debug build's map handed to robojab by nuance.nu's play
def "main play" [target: string = "mcp", map: string = "render_0", seconds: int = 600] {
    ^nu ($here | path join "bin" "nuance.nu") play $target $map $seconds
}

# The gauge's route on a fresh build by do.nu's build and nuance.nu's gauge run
def --wrapped "main gauge" [tree: string = "release", runs: int = 3, ...rest] {
    ^nu ($here | path join "bin" "do.nu") build --set (if $tree == "debug" { "debug" } else { "" })
    ^nu ($here | path join "bin" "nuance.nu") gauge run --tree $tree --runs $runs ...$rest
}

# Render Zero in the host's window on a fresh build by nuance.nu's gauge play
def --wrapped "main gauge-play" [seconds: int = 120, tree: string = "release", ...rest] {
    ^nu ($here | path join "bin" "do.nu") build --set (if $tree == "debug" { "debug" } else { "" })
    ^nu ($here | path join "bin" "nuance.nu") gauge play --tree $tree --seconds $seconds ...$rest
}

# A run's capture read by nuance.nu's gauge read
def --wrapped "main gauge-read" [api: path, ...rest] {
    ^nu ($here | path join "bin" "nuance.nu") gauge read ($api | path expand) ...$rest
}

# Builds' gauge.nuon files compared by nuance.nu's gauge compare
def --wrapped "main gauge-compare" [...rest] {
    ^nu ($here | path join "bin" "nuance.nu") gauge compare ...$rest
}
