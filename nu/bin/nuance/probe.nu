#!/usr/bin/env nu
# The SDK's probe module's path, bound at parse time
const PROBE = path self ../../mod/probe
use $PROBE

# The workspace's root, three directories above this file's
const WORKSPACE = path self ../../..

# One program probed under a window, one NUON record on how its flips reached it
def main [kind: string, ...words: string, --seconds: int = 12, --set: string = "", --api, --send: string = "", --trace] {
    probe $WORKSPACE $kind ...$words --seconds $seconds --set $set --api=$api --send $send --trace=$trace
}
