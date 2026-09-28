# badstack's integration test: a program whose sp points into the
# kernel, at zero, and past the end of RAM makes a call from each, and
# every call goes through, since the kernel saves and runs on its own
# stack and never through the program's sp; the exit status comes back.
use ../../../sdk/nu/jab.nu
use std/assert

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set)
    assert equal $run.status 3 $"the exit's status, with the UART: ($run.serial)"
    assert equal $run.serial "badstack: sp inside the kernel\nbadstack: sp at zero\nbadstack: sp past the end of RAM\n" "every call printed, from every sp"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    print "badstack: three calls from three bad stacks, all served"
    print "badstack: ok"
}
