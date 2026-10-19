# disk

## disks-args

The QEMU arguments that put raw images on the machine as virtio-blk
disks, in the order given, so the first is disk 1 to the kernel. Each
rides the PCI Express root rather than one of the eight mmio slots,
modern-only and on INTx (`disable-legacy=on,vectors=0`), which is how
the kernel drives it. A serial is what the guest reads back with
jab.sys.block.list, so it is how a program tells one disk from another.
An image built from assets, the program's own or the generic disk,
is attached read-only, so a program cannot change what the next run
reads: a write to it comes back to the program as the device's error
code, and the file on the host is never touched. The blank data disk
a run carries when a program ships no assets stays writable.

## machine-disks

The disks a machine carries: the program's own first, when there is
one, read-only when it is an asset image, then the generic assets
disk, always read-only, when the workspace has one, so a program's
disk is 1 and the generic disk 2, or 1 on its own.

## mix-image

The generic assets disk, disk 1 of every run and launch: `generic/`
in the workspace mirrored to the image's root, plus what
`generic/manifest.nuon` fetches, each entry an archive by URL and
sha256 with the members to take and where each lands, so the large
third-party assets, the soundfonts today, are never committed and
are verified on every build. Staged under the target's generic/ and
built into its mix.romfs whenever the tree or the manifest changes,
the archives kept under its fetch/, a stale stage retired. The path,
or "" with no workspace or no generic/ in it.

## fetched

An archive the manifest names, fetched into the target's fetch/ on
first use, which a run says once since it can take a while, and verified
by its sha256 then and on every later build; a mismatch stops with
both digests named.

## assets-image

A program's assets as a romfs image, built when the directory it names
has moved on: `assets` in its manifest, relative to the manifest, or
`target_assets`, a tree the program's content compiles to under its
asset shard of the target (program-shard), with the program's own name
as the volume's. The image is what `just run` puts on the machine, and
the program reads it with jab.sys.romfs.*.

## assets-names

A romfs name is at most 127 bytes of UTF-8, which is what a Linux
mount of the same image can read: its driver lists through a
128-byte buffer and works out where a file's data begins from a
length that stops there, so a longer name makes it read the wrong
bytes. The kernel reports such a name cut rather than wrong, but an
image Jab builds never has one. `str length` counts bytes, which is
the measure the record and the driver use.

## volume-name

A volume's name is bound the same way, and a disk's serial by virtio's
20-byte ID string, which carries a terminator only when it fits; each
is cut on a character, never inside one.

## cut-bytes

The longest prefix of `name` within `limit` bytes of UTF-8 that ends
on a whole character.
