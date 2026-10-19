#!/usr/bin/env nu
use ../mod/build

# The kernel and every program, or those at or under a path, or one program
def "main build" [dir: path, ...words: string, --kernel, --set: string = ""] {
    build $dir ...$words --kernel=$kernel --set $set
}

def main [] { help main }
