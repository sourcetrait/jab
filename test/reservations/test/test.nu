# reservations's integration test: hart ownership by role (the kernel's
# HartReservations), one program printing a line a step, read on machines
# of three harts, of four, diagnostic, and of four with hart 2 failed by
# jab.late=2, a sparse grant; every expected line worked out from the
# machine's online secondaries S, the lowest L, the highest H and its bit
# h, and the floor F, one short of S's count:
# - harts: S, L, and H.
# - legacy: before a reservation jab.sys.harts leaves a3 as the caller had
#   it, every online secondary is unowned, a raw five-argument start with
#   a5 nonzero starts as ever, and the five-operand macro with a5 as its
#   size starts, the size read whole.
# - refused: a reservation past the secondaries refused short with nothing
#   reserved, one beside a running worker refused busy, and a claim before
#   any reservation refused unreserved.
# - reserve: the floor reserved, its grant every online secondary, none
#   left unowned, and a second reservation refused.
# - owner: after the reservation every start names its owner: a5's
#   sentinel raw and through the five-operand form, each refused, and the
#   reservation's own started.
# - claim refused: an empty mask, hart 0, a hart past the machine, a busy
#   hart, and the whole grant past the floor.
# - claim: the surplus, the highest secondary, claimed under id 2, its hart
#   the claim's and the rest the grant's; it claimed again refused, and the
#   lowest refused at the floor.
# - cross: each owner's start on the other's hart refused; a worker of each
#   at once, the claim's started through the macro's sixth operand from a
#   lower register; a start on the claim's busy hart under the reservation
#   refused for its owner ahead of its busy hart; and the claim's release
#   refused busy.
# - returned: the claim released, its hart back in the grant, its id then
#   refused by release and by a start.
# - reclaim: the same hart claimed again under a fresh id, 3, the old id
#   refused by a start and by release, and the hart claimed once more
#   refused, being the new claim's.
# - released: the new claim released; no owner and the reservation are no
#   claim's to release.
# - denied: a worker's four ownership calls each JAB_DENIED.
# The debug channel carries each change: the reservation with its grant,
# each claim and release with its hart. Under jab.claimids=1 one claim id
# is left: the claim takes 2^63 - 1, the reclaim is refused spent with the
# grant as it stood, and the claim after it refused spent again, so the
# counter never wrapped.
use ../../../sdk/nu/jab.nu
use std/assert

# The last claim id, 2^63 - 1, the one jab.claimids=1 leaves.
const LAST_ID = 9223372036854775807

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let debug = ($set | str contains "DEBUG")
    let machines = ([
        { name: "three", harts: 3, bootargs: "", online: [1 2], spent: false }
        { name: "four", harts: 4, bootargs: "", online: [1 2 3], spent: false }
    ] ++ (if $debug { [
        { name: "sparse", harts: 4, bootargs: "jab.late=2", online: [1 3], spent: false }
        { name: "spent", harts: 3, bootargs: "jab.claimids=1", online: [1 2], spent: true }
    ] } else { [] }))
    mut held = []
    for m in $machines {
        let run = (jab launch --kernel $kernel --image $image --out ($out | path join $m.name) --set $set --harts $m.harts --bootargs $m.bootargs --seconds 20)
        let want = (expected $m.online $m.spent)
        let got = ($run.serial | lines)
        for row in ($want | enumerate) {
            assert equal ($got | get -o $row.index) $row.item $"($m.name), line ($row.index + 1): ($run.serial)"
        }
        assert equal ($got | length) ($want | length) $"($m.name): nothing after the program's last line: ($run.serial)"
        assert equal $run.status 0 $"($m.name): exit status: ($run.serial)"
        assert equal (open --raw $run.qemu_log) "" $"($m.name): QEMU has no complaint about the guest"
        if $debug {
            if $m.bootargs != "" { assert ($run.debug | str contains $"jab: bootargs ($m.bootargs)") $"($m.name): the knob reached the kernel: ($run.debug)" }
            let changes = ($run.debug | lines | where {|l| ["jab: harts reserved " "jab: harts claimed " "jab: harts released "] | any {|p| $l | str starts-with $p } })
            assert equal $changes (changes $m.online $m.spent) $"($m.name): each change of ownership on the debug channel: ($changes)"
        }
        $held = ($held | append $"($m.name) ($got | get -o 6 | default '')")
    }
    print $"reservations: ($machines | length) machines, every line held; ($held | str join '; ')"
    print "reservations: ok"
}

# The program's lines on a machine whose online secondaries are `online`,
# and with one claim id left when `spent`.
def expected [online: list<int>, spent: bool]: nothing -> list<string> {
    let s = ($online | each {|h| 1 bit-shl $h } | math sum)
    let lowest = ($online | math min)
    let highest = ($online | math max)
    let h = (1 bit-shl $highest)
    let floor = (($online | length) - 1)
    let rest = ($s - $h)
    let id = (if $spent { $LAST_ID } else { 2 })
    [
        $"harts ($s) ($lowest) ($highest)"
        $"legacy a3 14906 owned ($s) start 0 size 0"
        "refused short 1 0 start 0 busy 3 unreserved 1"
        $"reserve ($floor) 0 ($s) owned ($s) 0 again 2"
        "owner sentinel 7 five 7 reserved 0"
        "claim refused empty 2 main 2 past 2 busy 3 floor 4 start 0"
        $"claim 0 id ($id) owned ($h) ($rest) again 2 second 4"
        "cross 7 7 both 0 0 order 7 release busy 2"
        $"returned 0 ($h) owned ($s) stale 1 7"
        (if $spent { $"reclaim 5 id 0 stale 7 1 owned ($s) again 5" } else { $"reclaim 0 id 3 stale 7 1 owned ($rest) again 2" })
        (if $spent { "released 1 none 1 reserved 1" } else { "released 0 none 1 reserved 1" })
        "denied start 0 answers -1 -1 -1 -1"
    ]
}

# The debug channel's line for each change of ownership, in order: the
# reservation with its grant, then each claim and its release with its
# hart.
def changes [online: list<int>, spent: bool]: nothing -> list<string> {
    let s = ($online | each {|h| 1 bit-shl $h } | math sum)
    let h = (1 bit-shl ($online | math max))
    let floor = (($online | length) - 1)
    let ids = (if $spent { [$LAST_ID] } else { [2 3] })
    [$"jab: harts reserved ($floor) grant (hex $s)"] ++ ($ids | each {|i| [$"jab: harts claimed ($i) (hex $h)" $"jab: harts released ($i) (hex $h)"] } | flatten)
}

# A mask as the debug channel writes it: 0x and sixteen lowercase digits.
def hex [mask: int]: nothing -> string {
    $"0x($mask | format number | get lowerhex | str replace '0x' '' | fill --alignment right --character '0' --width 16)"
}
