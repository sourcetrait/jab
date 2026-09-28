# pad's integration test: a gamepad shaped like the reference pad,
# played from table.nuon, is found by the kernel and read as the
# program expects: its name as the device reports it, the ranges it
# reports for three axes and none for a fourth, every event in evdev's
# terms and, after each, the state normalised, the keys as a mask, the
# left stick full scale at its ends, part way in between, 0 inside its
# flat band and at centre, the hat at full scale, the trigger
# one-sided, a scan code dropped, and the run ending on South's
# release. The pad comes in both ways the kernel takes one: on Linux
# as a device, through the evdev shim, and then over the pad port; on
# any other host over the port alone, since nothing preloads there.
# The same lines either way.
use ../../../sdk/nu/jab.nu
use std/assert

const expected = [
    "pad: ready"
    "name 8BitDo Ultimate"
    "axis 0 0 255 0 15 0"
    "axis 9 0 255 0 15 0"
    "axis 16 -1 1 0 0 0"
    "axis 3 none"
    "pad 3 0 255"
    "state 0 32767 0 0 0"
    "pad 3 1 0"
    "state 0 32767 -32767 0 0"
    "pad 3 0 200"
    "state 0 16818 -32767 0 0"
    "pad 3 0 135"
    "state 0 0 -32767 0 0"
    "pad 3 1 127"
    "state 0 0 0 0 0"
    "pad 3 16 -1"
    "state 0 0 0 -32767 0"
    "pad 3 16 0"
    "state 0 0 0 0 0"
    "pad 3 9 255"
    "state 0 0 0 0 32767"
    "pad 3 9 0"
    "state 0 0 0 0 0"
    "pad 1 304 1"
    "state 1 0 0 0 0"
    "pad 1 304 0"
    "state 0 0 0 0 0"
]

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let table = ($env.FILE_PWD | path join "table.nuon")
    let routes = (if $nu.os-info.name == "linux" { ["device" "port"] } else { ["port"] })
    for route in $routes {
        let run = (if $route == "port" {
            jab launch --kernel $kernel --image $image --out $out --set $set --pad $table --pad-port --seconds 8
        } else {
            jab launch --kernel $kernel --image $image --out $out --set $set --pad $table --seconds 8
        })
        assert equal $run.status 0 $"exit status over the ($route), with the UART: ($run.serial)"
        assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
        let found = (if $route == "port" { "jab: pad on port" } else { "jab: pad at " })
        assert ($run.debug | str contains $found) $"the kernel found the pad over the ($route): ($run.debug)"
        assert equal ($run.serial | lines) $expected $"the ranges, every event, and the state after each over the ($route): ($run.serial)"
        print $"pad: ($expected | length) lines as expected over the ($route); QEMU used ($run.cpu_seconds) CPU seconds over ($run.wall_seconds | math round -p 2) seconds"
        assert ($run.cpu_seconds < ($run.wall_seconds * 0.5)) "the hart halts while it waits for the pad"
    }
    print "pad: ok"
}
