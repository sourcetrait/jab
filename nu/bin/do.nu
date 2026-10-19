#!/usr/bin/env nu
# This file's directory, the root's do link resolved
const HERE = (path self | path expand | path dirname)
# The SDK's bench module's path, bound at parse time
const BENCH = ($HERE | path join ../mod/bench | path expand)
# The SDK's build module's path, bound at parse time
const BUILD = ($HERE | path join ../mod/build | path expand)
# The SDK's program module's path, bound at parse time
const PROGRAM = ($HERE | path join ../mod/program | path expand)
# The SDK's watcher module's path, bound at parse time
const WATCHER = ($HERE | path join ../mod/watcher | path expand)
use $BENCH
use $BUILD
use $PROGRAM
use $WATCHER

# The workspace's root, two directories above this file's
const WORKSPACE = ($HERE | path join ../.. | path expand)

# The kernel and every program, or those at or under a path, or one program
def "main build" [...words: string, --kernel, --set: string = ""] {
    build $WORKSPACE ...$words --kernel=$kernel --set $set
}

# Every program's test with DEBUG, or those at or under a path, or one
def "main test" [...words: string, --set: string = "", --spec (-s): string = ""] {
    program test $WORKSPACE ...$words --set $set --spec $spec
}

# One program built, then run in its window with the UART on stdio
def "main run" [...words: string, --set: string = "", --api, --kbm, --no-kbm, --pad, --no-pad, --no-sound, --spec (-s): string = "", --harts: int = 0] {
    program boot $WORKSPACE ...$words --set $set --api=$api --kbm=$kbm --no-kbm=$no_kbm --pad=$pad --no-pad=$no_pad --no-sound=$no_sound --spec $spec --harts $harts
}

# A program's bench run step by step, then its report and its tar; no name lists
def "main bench" [name?: string, --only: string = "", --package: string = ""] {
    bench $WORKSPACE $name --only $only --package $package
}

# The running Jab QEMU recorded per thread each second, reported when it ends
def "main watch" [--skip: float = 5.0] {
    watcher $WORKSPACE --skip $skip
}

def main [] { help main }
