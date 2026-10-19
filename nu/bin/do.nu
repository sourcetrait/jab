#!/usr/bin/env nu
use ../mod/bench
use ../mod/build

# The kernel and every program, or those at or under a path, or one program
def "main build" [dir: path, ...words: string, --kernel, --set: string = ""] {
    build $dir ...$words --kernel=$kernel --set $set
}

# A program's bench run step by step, then its report and its tar; no name lists
def "main bench" [ws: path, name?: string, --only: string = ""] {
    bench $ws $name --only $only
}

def main [] { help main }
