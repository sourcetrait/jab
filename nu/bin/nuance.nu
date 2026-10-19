#!/usr/bin/env nu
use ../mod/build

# The whole target retired, or the outputs of the programs at or under a path
def --wrapped "main clean" [ws: path, ...words: string] {
    build clean $ws ...$words
}

# Everything retired deleted, the workspace checked first
def "main retire" [ws: path] {
    build retire $ws
}

def main [] { help main }
