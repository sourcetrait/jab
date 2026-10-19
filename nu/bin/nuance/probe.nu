#!/usr/bin/env nu
use ../../mod/probe

# One program probed under a window, one NUON record on how its flips reached it
def main [dir: path, kind: string, ...words: string, --seconds: int = 12, --set: string = "", --api, --send: string = "", --trace] {
    probe $dir $kind ...$words --seconds $seconds --set $set --api=$api --send $send --trace=$trace
}
