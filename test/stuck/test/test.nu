# stuck's integration test: a device's interrupt source held asserted
# with no progress, through a debug kernel's jab.hold knob naming the
# rng's virtio device id, is masked after three seconds, its line on the
# UART once, the rng refusing from then on while the display carries on;
# the same program with no knob draws twice.
use ../../../sdk/nu/jab.nu
use std/assert

const RNG_ID = 4
const VIRTIO0 = 0x10001000
const STRIDE = 0x1000

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    assert ($set | str contains "DEBUG") $"the knob is a debug kernel's, and the build is ($set)"
    let held = (jab launch --kernel $kernel --image $image --out ($out | path join "held") --set $set --bootargs $"jab.hold=($RNG_ID)" --seconds 30)
    assert equal $held.status 0 $"exit status with the rng held: ($held.serial)"
    let at = ($held.debug | lines | where {|l| $l starts-with "jab: rng at 0x" } | get 0 | str replace "jab: rng at 0x" "" | into int --radix 16)
    let source = (($at - $VIRTIO0) // $STRIDE + 1)
    let lines = ($held.serial | lines)
    assert equal $lines [$"jab: interrupt source ($source) stalled" "stuck random 0 then 1, flip 0"] $"the rng's source masked once, the rng refused, the display flipping: ($held.serial)"

    let free = (jab launch --kernel $kernel --image $image --out ($out | path join "free") --set $set --seconds 30)
    assert equal $free.status 0 $"exit status with nothing held: ($free.serial)"
    assert equal ($free.serial | lines) ["stuck random 0 then 0, flip 0"] $"with no knob the rng draws twice: ($free.serial)"

    print $"stuck: held, source ($source): ($lines | str join '; '); free: ($free.serial | str trim)"
    print "stuck: ok"
}
