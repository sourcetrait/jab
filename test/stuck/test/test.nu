# stuck's integration test: a device whose interrupt source stays
# asserted with no progress, held so by a debug kernel's knobs, is masked
# after three seconds, its device reset, its line on the UART once, and
# every wait on it ended with the failure, while the rest of the machine
# carries on. One program, a fresh launch a scenario, the scenario's
# letter sent over the API one second in:
# - rng: a draw outstanding when its source fails answers 1, and the
#   program's buffer is untouched past the device's next refill, which a
#   device left running would have written into it; the same run free
#   draws twice.
# - pad: a pad on the port fails with the serial device, so an await on
#   the pad alone ends, 0, and the next pad read answers 1.
# - api: a write the device never takes (the unsent knob) is abandoned
#   when the source fails and answers 2, the next 1.
# - sound: a held stream is taken back and never refilled, so the
#   source's window fires before the stream's own stall check; an await
#   on the sound alone ends, 0, through its teardown, and a second in
#   user mode after it shows no timer was left enabled.
# - disk: a disk whose reads complete five seconds late and one after it,
#   both on the generic disk's PCI line; the line fails with the slow
#   disk's read in flight and nothing in the generic disk's, both are reset
#   and the read drained, and the disk behind them on the failed line is
#   offered no request and its source stays masked.
# And with no letter the program says so and exits 2.
use ../../../sdk/nu/jab.nu
use std/assert

const VIRTIO0 = 0x10001000
const STRIDE = 0x1000
const PCIE_IRQ0 = 32
# the rng's quota: 64 bytes a six-second period, so the program's first
# draw takes it all and the second waits for the refill
const RNG_WORDS = ["-global" "virtio-rng-device.max-bytes=64" "-global" "virtio-rng-device.period=6000"]
# a disk whose every request completes five seconds late, at PCI slot 5,
# and one with none, at slot 9: both on INTA, so both on source 33 with
# the generic disk at slot 1. One line, since a virtio-blk reset drains
# every disk on the machine inside its status write: a failure on another
# line would complete the slow read before this one's window ran out
const DISK_WORDS = [
    "-blockdev" "node-name=slow,driver=null-co,read-zeroes=on,size=1048576,latency-ns=5000000000"
    "-device" "virtio-blk-pci,disable-legacy=on,vectors=0,drive=slow,serial=slow,addr=0x5"
    "-blockdev" "node-name=quick,driver=null-co,read-zeroes=on,size=1048576"
    "-device" "virtio-blk-pci,disable-legacy=on,vectors=0,drive=quick,serial=quick,addr=0x9"
]

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    assert ($set | str contains "DEBUG") $"the knobs are a debug kernel's, and the build is ($set)"

    let held = (scenario $kernel $image ($out | path join "rng_held") $set "r" --bootargs "jab.hold=4" --qemu $RNG_WORDS)
    assert equal $held.status 0 $"rng held: exit status ($held.status): ($held.serial)"
    let rng = (mmio-source $held.debug "jab: rng at 0x")
    assert equal ($held.serial | lines) ["stuck: scenario rng" $"jab: interrupt source ($rng) stalled" "stuck random 0 then 1, buffer intact, flip 0"] $"rng held: the source masked once, the outstanding draw answering 1, the buffer untouched past the refill, the display flipping: ($held.serial)"
    assert $held.machine.diagnostic $"a launch with QEMU words of its own is diagnostic: ($held.machine)"
    assert equal $held.overrides $RNG_WORDS $"the words come back apart: ($held.overrides)"

    let free = (scenario $kernel $image ($out | path join "rng_free") $set "r" --qemu $RNG_WORDS)
    assert equal $free.status 0 $"rng free: exit status ($free.status): ($free.serial)"
    assert equal ($free.serial | lines) ["stuck: scenario rng" "stuck random 0 then 0, buffer intact, flip 0"] $"rng free: the second draw waits for the refill and lands: ($free.serial)"

    let table = ($out | path join "no_events.nuon")
    "[]" | save -f $table
    let pad = (scenario $kernel $image ($out | path join "pad") $set "p" --bootargs "jab.hold=3" --pad $table --pad-port)
    assert equal $pad.status 0 $"pad: exit status ($pad.status): ($pad.serial)"
    let serial = (mmio-source $pad.debug "jab: serial at 0x")
    assert equal ($pad.serial | lines) ["stuck: scenario pad" $"jab: interrupt source ($serial) stalled" "stuck pad: read 0, await 0, read 1" "jab: exit 0"] $"pad: the serial device's source masked, the pad on its port failing with it, the await ending, and the debug channel's last line falling to the UART: ($pad.serial)"
    assert ($pad.debug | str contains "jab: pad on port") $"pad: the pad came up on the port: ($pad.debug)"

    let api = (scenario $kernel $image ($out | path join "api") $set "a" --bootargs "jab.hold=3 jab.unsent=3")
    assert equal $api.status 0 $"api: exit status ($api.status): ($api.serial)"
    let api_serial = (mmio-source $api.debug "jab: serial at 0x")
    assert equal ($api.serial | lines) ["stuck: scenario api" $"jab: interrupt source ($api_serial) stalled" "stuck api: write 2 then 1" "jab: exit 0"] $"api: the unsent write abandoned when the source failed, answering 2, the next 1: ($api.serial)"

    let sound = (scenario $kernel $image ($out | path join "sound") $set "s" --bootargs "jab.hold=25" --sound)
    assert equal $sound.status 0 $"sound: exit status ($sound.status): ($sound.serial)"
    let stream = (mmio-source $sound.debug "jab: sound at 0x")
    assert equal ($sound.serial | lines) ["stuck: scenario sound" $"jab: interrupt source ($stream) stalled" "stuck sound: write 0 took 8192, await 0"] $"sound: the source's window first, no sound stalled line, the await ending through its teardown and a second of user mode after it: ($sound.serial)"

    let disk = (scenario $kernel $image ($out | path join "disk") $set "d" --bootargs "jab.hold=2" --qemu $DISK_WORDS)
    assert equal $disk.status 0 $"disk: exit status ($disk.status): ($disk.serial)"
    let slots = ($disk.debug | lines | where {|l| $l starts-with "jab: disk on pci slot " } | each {|l| $l | str replace "jab: disk on pci slot " "" | into int })
    assert equal $slots [1 5 9] $"disk: the generic disk, the slow one, and the quick one, in slot order: ($disk.debug)"
    let lines = ($slots | each {|s| $PCIE_IRQ0 + ($s mod 4) } | uniq)
    assert equal $lines [33] $"disk: the three on one line: ($lines)"
    assert equal ($disk.serial | lines) ["stuck: scenario disk" $"jab: interrupt source ($lines.0) stalled" "stuck disks 3: 1 kind 0, 2 kind 0, 3 kind 0"] $"disk: the line masked once, every disk down: ($disk.serial)"
    let report = ($disk.debug | lines | where {|l| $l =~ '^jab: disk \d+ kind ' })
    assert equal $report [
        "jab: disk 1 kind 0 status 0 offered 2 outstanding 0 enabled 0"
        "jab: disk 2 kind 0 status 0 offered 2 outstanding 1 enabled 0"
        "jab: disk 3 kind 0 status 0 offered 0 outstanding 0 enabled 0"
    ] $"disk: the generic disk reset with nothing in flight, the slow one with its read in flight, the one behind them offered nothing, the source masked: ($disk.debug)"

    let none = (jab launch --kernel $kernel --image $image --out ($out | path join "none") --set $set --api --seconds 10)
    assert equal $none.status 2 $"no letter: exit status ($none.status): ($none.serial)"
    assert equal ($none.serial | lines) ["stuck: no scenario"] $"no letter, no scenario: ($none.serial)"

    print $"stuck: rng held ($rng), free; pad and api on the serial device's ($serial); sound's ($stream); disks on ($lines.0)"
    print "stuck: ok"
}

# One scenario's launch: the API on the machine and the scenario's letter
# sent into it one second in, with the knobs, the QEMU words, the pad, and
# the sound the scenario takes. Untyped because launch's record is wide.
def scenario [kernel: path, image: path, out: path, set: string, letter: string, --bootargs: string = "", --qemu: list<string> = [], --pad: path = "", --pad-port, --sound] {
    let send = [[at, bytes]; [1sec, ($letter | into binary)]]
    jab launch --kernel $kernel --image $image --out $out --set $set --send $send --bootargs $bootargs --qemu $qemu --pad $pad --pad-port=$pad_port --sound=$sound --seconds 30
}

# A virtio-mmio device's interrupt source from its debug line, `<head>` and
# its transport's address in hex: the transport's slot from the first
# plus one. Untyped because it ends in an error.
def mmio-source [debug: string, head: string] {
    let line = ($debug | lines | where {|l| $l starts-with $head } | get -o 0)
    if $line == null { error make {msg: $"no `($head)` line on the debug channel: ($debug)"} }
    let at = ($line | str replace $head "" | into int --radix 16)
    ($at - $VIRTIO0) // $STRIDE + 1
}
