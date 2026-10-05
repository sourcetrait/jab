# workerfault's integration test: a worker's fault ends the run, its line
# naming the hart, with status 1 and no hang, every other hart stopped
# at a safe point first. One program, a fresh launch a scenario, the
# scenario's letter sent over the API one second in; hart 0 then waits
# on what never comes, so only the shutdown's wake can end its wait:
# - store: a worker's store into the kernel's memory, while hart 0
#   awaits more bytes over the API and harts 2 and 3 idle.
# - two: two workers' stores at once, through one gate: a line each, the
#   owner's first, and one shutdown. A debug kernel's knob holds the
#   first claim 200 ms before its wakes (jab.claimhold=200), so the
#   second store lands even on a host that has its vCPU thread off a
#   core when the gate opens: otherwise the first owner's wake could
#   stop that worker before its store, and the scenario would see one
#   fault.
# - join: a worker's store a tenth of a second in, while hart 0 joins it
#   in jab.sys.worker.wait.
# - address: a worker's wait on a word outside the program's window,
#   the address line, as hart 0's own bad address prints it.
# - print: a worker's store while hart 0 prints a 32 KiB line with the
#   sound stream live, so the print's sound_tick drains under the line
#   lock: the whole line, then the whole fault line, and nothing of the
#   program's after it, hart 0 stopping at the boundary its print
#   returns through.
# A hart that did not stop within the shutdown's bound would be named
# after the fault lines (`jab: shutdown unanswered: hart N`); every
# scenario's lines are matched whole, so none may appear. And with no
# letter the program says so and exits 2.
use ../../../sdk/nu/jab.nu
use std/assert

const LONG_BYTES = 32768

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    assert ($set | str contains "DEBUG") $"two's knob is a debug kernel's, and the build is ($set)"

    let store = (scenario $kernel $image ($out | path join "store") $set "k")
    assert equal $store.status 1 $"store: exit status ($store.status): ($store.serial)"
    let lines = ($store.serial | lines)
    assert equal ($lines | length) 2 $"store: the scenario's line and the fault's, nothing more: ($store.serial)"
    assert equal $lines.0 "workerfault: scenario store" $"store: ($store.serial)"
    assert (fault-line $lines.1 1 0xa1 0x80000000) $"store: the worker's fault, its hart, argument, cause, and address: ($store.serial)"

    let two = (scenario $kernel $image ($out | path join "two") $set "t" --bootargs "jab.claimhold=200")
    assert equal $two.status 1 $"two: exit status ($two.status): ($two.serial)"
    assert ($two.debug | str contains "jab: bootargs jab.claimhold=200") $"two: the knob reached the kernel: ($two.debug)"
    let lines = ($two.serial | lines)
    assert equal ($lines | length) 3 $"two: the scenario's line and a fault line each, one shutdown: ($two.serial)"
    assert equal $lines.0 "workerfault: scenario two" $"two: ($two.serial)"
    let faults = ($lines | skip 1)
    assert ($faults | any {|l| fault-line $l 1 0xb1 0x80000008 }) $"two: hart 1's fault: ($two.serial)"
    assert ($faults | any {|l| fault-line $l 2 0xb2 0x80000010 }) $"two: hart 2's fault: ($two.serial)"

    let join = (scenario $kernel $image ($out | path join "join") $set "j")
    assert equal $join.status 1 $"join: exit status ($join.status): ($join.serial)"
    let lines = ($join.serial | lines)
    assert equal ($lines | length) 2 $"join: the scenario's line and the fault's, the join ended by the shutdown: ($join.serial)"
    assert equal $lines.0 "workerfault: scenario join" $"join: ($join.serial)"
    assert (fault-line $lines.1 1 0xc1 0x80000000) $"join: the worker's fault: ($join.serial)"

    let address = (scenario $kernel $image ($out | path join "address") $set "a")
    assert equal $address.status 1 $"address: exit status ($address.status): ($address.serial)"
    assert equal ($address.serial | lines) ["workerfault: scenario address" "jab: address outside the program"] $"address: the worker's wait refused as hart 0's would be: ($address.serial)"

    let print = (scenario $kernel $image ($out | path join "print") $set "p" --sound)
    assert equal $print.status 1 $"print: exit status ($print.status): ($print.serial | str substring 0..400)"
    let lines = ($print.serial | lines)
    assert equal ($lines | length) 3 $"print: the scenario's line, the long line, and the fault's, nothing after: ($lines | each {|l| $l | str substring 0..80 })"
    assert equal $lines.0 "workerfault: scenario print" "print: the scenario's line"
    assert equal ($lines.1 | str length) $LONG_BYTES $"print: the long line whole: ($lines.1 | str length) bytes"
    assert ($lines.1 =~ '^x+$') "print: the long line nothing but its own bytes"
    assert (fault-line $lines.2 1 0xd1 0x80000008) $"print: the fault line whole after it: ($lines.2)"

    let none = (jab launch --kernel $kernel --image $image --out ($out | path join "none") --set $set --api --seconds 10)
    assert equal $none.status 2 $"no letter: exit status ($none.status): ($none.serial)"
    assert equal ($none.serial | lines) ["workerfault: no scenario"] $"no letter, no scenario: ($none.serial)"

    print $"workerfault: store, two, join, address, and print each ended with the fault's line and status 1 in ($store.wall_seconds | math round -p 1), ($two.wall_seconds | math round -p 1), ($join.wall_seconds | math round -p 1), ($address.wall_seconds | math round -p 1), and ($print.wall_seconds | math round -p 1) s"
    print "workerfault: ok"
}

# One scenario's launch: the API on the machine and the scenario's letter
# sent into it one second in, with the knobs and the sound the scenario
# takes. Untyped because launch's record is wide.
def scenario [kernel: path, image: path, out: path, set: string, letter: string, --bootargs: string = "", --sound] {
    let send = [[at, bytes]; [1sec, ($letter | into binary)]]
    jab launch --kernel $kernel --image $image --out $out --set $set --send $send --bootargs $bootargs --sound=$sound --seconds 30
}

# Whether a line is a worker's store page fault: its hart, its argument,
# cause 15, an epc in the program's window, and the address it stored to.
def fault-line [line: string, hart: int, argument: int, address: int]: nothing -> bool {
    let parsed = ($line | parse --regex '^jab: worker fault: hart=(?P<hart>\d+) argument=0x(?P<argument>[0-9a-f]{16}) cause=0x(?P<cause>[0-9a-f]{16}) epc=0x(?P<epc>[0-9a-f]{16}) tval=0x(?P<tval>[0-9a-f]{16})$')
    if ($parsed | is-empty) { return false }
    let f = ($parsed | first)
    (($f.hart | into int) == $hart and ($f.argument | into int --radix 16) == $argument and ($f.cause | into int --radix 16) == 15 and ($f.epc | into int --radix 16) >= 0x80a00000 and ($f.tval | into int --radix 16) == $address)
}
