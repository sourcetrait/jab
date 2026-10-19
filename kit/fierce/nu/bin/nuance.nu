#!/usr/bin/env nu
use ../mod/gauge

# A route played and measured from the command line by gauge play route
def "main gauge run" [--tree: string = "release", --kernel: string = "", --image: string = "", --route: string = "", --map: string = "", --runs: int = 3, --seeds: string = "[]", --cadence: int = 1, --workers: int = -1, --grain: int = 32, --host, --out: string = "", --label: string = "", --spec (-s): string = "", --harts: int = 0, --qemu: string = "[]", --cpu, --sdl-probe, --trace] {
    gauge play route --tree $tree --kernel $kernel --image $image --route $route --map $map --runs $runs --seeds $seeds --cadence $cadence --workers $workers --grain $grain --host=$host --out $out --label $label --spec $spec --harts $harts --qemu $qemu --cpu=$cpu --sdl-probe=$sdl_probe --trace=$trace
}

# A host play from the command line by gauge play host
def "main gauge play" [--tree: string = "release", --kernel: string = "", --image: string = "", --seconds: int = 120, --seed: int = 1, --cadence: int = 1, --workers: int = -1, --grain: int = 32, --out: string = "", --label: string = "", --spec (-s): string = "", --harts: int = 0, --qemu: string = "[]"] {
    gauge play host --tree $tree --kernel $kernel --image $image --seconds $seconds --seed $seed --cadence $cadence --workers $workers --grain $grain --out $out --label $label --spec $spec --harts $harts --qemu $qemu
}

# A capture read from the command line by gauge read
def "main gauge read" [api: path, --route: string = "", --out: string = "", --label: string = ""] {
    gauge read $api --route $route --out $out --label $label
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
