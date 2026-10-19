#!/usr/bin/env nu
# The tiles module's path, bound at parse time
const TILES = path self ../../mod/tiles
# The builder's oracle's path, bound at parse time
const BUILDER = path self ../../mod/tiles/builder
# The handoff's statistics' path, bound at parse time
const HANDOFF = path self ../../mod/tiles/handoff
# The lit steps' path, bound at parse time
const STEPS = path self ../../mod/tiles/steps
use $TILES
use $BUILDER
use $HANDOFF
use $STEPS

# A capture's whole tiles a dump and every problem saved by tiles dumps
def "main dumps" [api: path, out: path] {
    tiles dumps $api $out
}

# A capture's dumps keyed by tile header and texels' SHA-256 by tiles keys
def "main keys" [api: path, out: path] {
    tiles keys $api $out
}

# The builder's oracle over a capture by tiles/builder's main
def "main builder" [api: path, spec: string, out: path] {
    builder $api $spec $out
}

# The handoff pair at `index` compared by tiles/handoff's main
def "main handoff" [spec: path, index: int, out: path] {
    handoff $spec $index $out
}

# The lit loop's most step between side-by-side pixels by tiles/steps' main
def "main lit-steps" [capture: path, rect: string, crosshair: int, out: path] {
    steps $capture $rect $crosshair $out
}

def main [] { help main }
