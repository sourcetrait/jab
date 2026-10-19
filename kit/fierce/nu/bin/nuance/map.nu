#!/usr/bin/env nu
# The map module's path, bound at parse time
const MAP = path self ../../mod/map
# The map compiler's path, bound at parse time
const COMPILE = path self ../../mod/map/compile
use $MAP
use $COMPILE

# A source compiled to its tree under `out` by map/compile's main
def "main compile" [source: path, out: path, --content: path = ""] {
    compile $source $out --content $content
}

# A compiled map's counts and its spawn printed by map show
def "main show" [map: path] {
    map show $map
}

def main [] { help main }
