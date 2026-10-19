#!/usr/bin/env nu
use ../mod/bench
use ../mod/build
use ../mod/program
use ../mod/watcher

# The kernel and every program, or those at or under a path, or one program
def "main build" [dir: path, ...words: string, --kernel, --set: string = ""] {
    build $dir ...$words --kernel=$kernel --set $set
}

# Every program's test with DEBUG, or those at or under a path, or one
def "main test" [dir: path, ...words: string, --set: string = "", --spec (-s): string = ""] {
    program test $dir ...$words --set $set --spec $spec
}

# One program built, then run in its window with the UART on stdio
def "main run" [dir: path, ...words: string, --set: string = "", --api, --kbm, --no-kbm, --pad, --no-pad, --no-sound, --spec (-s): string = "", --harts: int = 0] {
    program boot $dir ...$words --set $set --api=$api --kbm=$kbm --no-kbm=$no_kbm --pad=$pad --no-pad=$no_pad --no-sound=$no_sound --spec $spec --harts $harts
}

# A program's bench run step by step, then its report and its tar; no name lists
def "main bench" [ws: path, name?: string, --only: string = ""] {
    bench $ws $name --only $only
}

# The running Jab QEMU recorded per thread each second, reported when it ends
def "main watch" [ws: path, --skip: float = 5.0] {
    watcher $ws --skip $skip
}

def main [] { help main }
