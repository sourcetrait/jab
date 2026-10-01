# blocklist's integration test: the SDK built this program's own assets
# directory into a romfs image, and the machine carries it as its first
# disk, with the workspace's generic assets disk, serial mix, second.
# The kernel must find both on the PCI Express root, name each by the
# serial QEMU was given, read its capacity from the device, and know a
# romfs when it sees one. Both are attached read-only: the program's
# write to its disk comes back as the device's error, and the image on
# the host is the same bytes after the run as before it.
use ../../../sdk/nu/jab.nu
use std/assert

def main [--kernel: path, --image: path, --out: path, --assets: path, --set: string = ""] {
    assert (($assets | path exists)) "the sdk built the assets image"
    let bytes = (ls -D $assets | get 0.size | into int)
    let sectors = ($bytes // 512)
    let before = (open --raw $assets | hash sha256)
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --disk $assets --serial "blocklist")
    assert equal $run.status 0 $"exit status, with the UART: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    let lines = ($run.serial | lines)
    assert equal ($lines | length) 4 $"two disks, the count, and the write: ($run.serial)"
    assert equal $lines.0 $"disk 1 kind 2 sectors ($sectors) serial blocklist" "the program's disk as the kernel sees it"
    assert ($lines.1 =~ '^disk 2 kind 2 sectors [1-9][0-9]* serial mix$') $"the generic disk second, a romfs with the serial mix: ($lines.1)"
    assert equal $lines.2 "count 2 next 0" "two records written and no page after them"
    assert equal $lines.3 "write 3" "the write to the read-only disk came back as the device's error"
    assert equal (open --raw $assets | hash sha256) $before "the image on the host is untouched"
    let mix_sectors = ($lines.1 | parse "disk 2 kind 2 sectors {sectors} serial mix" | get 0.sectors | into int)
    print $"blocklist: one romfs disk of ($sectors) sectors, serial blocklist, and the generic disk of ($mix_sectors) sectors, serial mix; a write refused and the image unchanged"
    print "blocklist: ok"
}
