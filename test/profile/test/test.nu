# profile's integration test: the RVA23 user profile's instructions that
# need the kernel's leave run in a program. cbo.zero clears the whole
# 64-byte block its address falls in and nothing past it; cbo.clean,
# cbo.flush, and cbo.inval run and keep the block's bytes, cbo.inval
# acting as a flush; time, cycle, and instret read and rise over a spin;
# hpmcounter3 and hpmcounter18 read. Any of them refused is an illegal
# instruction, a program fault, and status 1.
use ../../../sdk/nu/jab.nu
use std/assert

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --seconds 8)
    assert equal $run.status 0 $"exit status, with the UART: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    let lines = ($run.serial | lines)
    assert equal ($lines | length) 4 $"four lines: ($run.serial)"
    assert equal $lines.0 "zero 64 untouched 64" "cbo.zero cleared its block and only its block"
    assert equal $lines.1 "kept 64" "cbo.clean, cbo.flush, and cbo.inval kept the block's bytes"
    assert equal $lines.2 "rising 1 1 1" "time, cycle, and instret rose over the spin"
    let hpm = ($lines.3 | parse "hpm3 {three} hpm18 {eighteen}")
    assert equal ($hpm | length) 1 $"the two performance counters read: ($lines.3)"
    let three = ($hpm.0.three | into int)
    let eighteen = ($hpm.0.eighteen | into int)
    print $"profile: cbo.zero, cbo.clean, cbo.flush, cbo.inval, and the counters from a program; hpmcounter3 ($three), hpmcounter18 ($eighteen)"
    print "profile: ok"
}
