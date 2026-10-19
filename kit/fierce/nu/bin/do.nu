#!/usr/bin/env nu
# The SDK's bench module's path, bound at parse time
const BENCH = path self ../../../../nu/mod/bench
# The SDK's build module's path, bound at parse time
const BUILD = path self ../../../../nu/mod/build
# The SDK's program module's path, bound at parse time
const PROGRAM = path self ../../../../nu/mod/program
use $BENCH
use $BUILD
use $PROGRAM

# The workspace's root, resolved from this file's own path
const WORKSPACE = path self ../../../..

# The kernel and fierce built with the symbols given
def "main build" [--set: string = ""] {
    build $WORKSPACE kit/fierce --set $set
}

# Fierce's test with DEBUG, its suite and its programs' fixtures
def "main test" [--set: string = "", --spec (-s): string = ""] {
    program test $WORKSPACE kit/fierce --set $set --spec $spec
}

# Fierce built, then run in its window with the UART on stdio
def "main run" [--set: string = "", --api, --kbm, --no-kbm, --pad, --no-pad, --no-sound, --spec (-s): string = "", --harts: int = 0] {
    program boot $WORKSPACE kit/fierce --set $set --api=$api --kbm=$kbm --no-kbm=$no_kbm --pad=$pad --no-pad=$no_pad --no-sound=$no_sound --spec $spec --harts $harts
}

# A bench of fierce's run step by step, then its report and its tar
def "main bench" [name: string, --only: string = "", --package: string = ""] {
    bench $WORKSPACE $"kit/fierce/($name)" --only $only --package $package
}

def main [] { help main }
