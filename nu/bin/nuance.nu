#!/usr/bin/env nu
use ../mod/build
use ../mod/watcher

# The whole target retired, or the outputs of the programs at or under a path
def --wrapped "main clean" [ws: path, ...words: string] {
    build clean $ws ...$words
}

# Everything retired deleted, the workspace checked first
def "main retire" [ws: path] {
    build retire $ws
}

# Every QEMU of a bench's run recorded per step, reported and packed at its end
def "main watch bench" [...words: string, --skip: float = 5.0] {
    watcher bench ...$words --skip $skip
}

def main [] { help main }
