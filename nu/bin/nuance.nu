#!/usr/bin/env nu
# The SDK's build module's path, bound at parse time
const BUILD = path self ../mod/build
# The SDK's watcher module's path, bound at parse time
const WATCHER = path self ../mod/watcher
use $BUILD
use $WATCHER

# The workspace's root, two directories above this file's
const WORKSPACE = path self ../..

# The whole target retired, or the outputs of the programs at or under a path
def --wrapped "main clean" [...words: string] {
    build clean $WORKSPACE ...$words
}

# Everything retired deleted, the workspace checked first
def "main retire" [] {
    build retire $WORKSPACE
}

# Every QEMU of a bench's run recorded per step, reported and packed at its end
def "main watch bench" [name?: string, --skip: float = 5.0] {
    watcher bench $WORKSPACE $name --skip $skip
}

def main [] { help main }
