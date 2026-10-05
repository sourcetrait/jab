# dtb's integration test: the kernel's device tree reader, kernel/src/dtb.S,
# assembled into this program, over QEMU's own tree for a four-hart machine
# and trees the test breaks from it or builds itself, each held to the code
# the reader must answer: the tree whole, a bad magic, an unknown version
# and a last compatible one past the reader's, a total size past the bytes
# there, a block past the total size, a structure cut inside a property's
# header, a name running past the structure, a property's value past it, a
# property's name past the strings, an unknown token, and nesting at the
# bound and one past it. Then QEMU's tree through every lookup: a path, a
# unit address matched when given and a name alone when not, a property, a
# node's children, a phandle back to its node, paths that are not there,
# and a string list's entries in the supervisor IMSIC's compatible, each
# entry matched whole and neither a prefix of one nor a tail. Last, the
# debug kernel's own reading of the tree it booted on: its harts and its
# command line, given through -append.
use ../../../sdk/nu/jab.nu
use std/assert

# The reader's codes, kernel/src/include/dtb.inc's DTB_*
const OK = 0
const BAD_MAGIC = 1
const BAD_VERSION = 2
const BAD_SIZE = 3
const BAD_BLOCK = 4
const CUT = 5
const BAD_NAME = 6
const BAD_PROP = 7
const TOO_DEEP = 8
const BAD_TOKEN = 9
# The kernel's command line, in /chosen's bootargs
const BOOTARGS = "jab.test=1 other"
const TIMEBASE = 10000000

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let stage = ($out | path join "trees")
    jab retire $stage
    mkdir $stage
    let good = (jab dump-tree --kernel $kernel --image $image --out ($out | path join "virt4.dtb") --bootargs $BOOTARGS)
    let tree = (open --raw $good | into binary)
    let h = (header $tree)
    assert equal $h.totalsize ($tree | bytes length) "QEMU's tree is its total size"
    let walked = (tokens $tree $h)
    let first_prop = ($walked | where kind == 3 | first)
    let second_node = ($walked | where kind == 1 | get 1)
    let cases = [
        { name: "good.dtb", bytes: $tree, code: $OK }
        { name: "magic.dtb", bytes: (put32 $tree 0 0), code: $BAD_MAGIC }
        { name: "version.dtb", bytes: (put32 $tree 20 16), code: $BAD_VERSION }
        { name: "lastcomp.dtb", bytes: (put32 $tree 24 17), code: $BAD_VERSION }
        { name: "size.dtb", bytes: (put32 $tree 4 ($h.totalsize + 4096)), code: $BAD_SIZE }
        { name: "block.dtb", bytes: (put32 $tree 32 ($h.size_strings + 4096)), code: $BAD_BLOCK }
        { name: "cut.dtb", bytes: (put32 $tree 36 ($first_prop.at - $h.off_struct + 8)), code: $CUT }
        { name: "name.dtb", bytes: (put32 $tree 36 ($second_node.at - $h.off_struct + 7)), code: $BAD_NAME }
        { name: "prop.dtb", bytes: (put32 $tree ($first_prop.at + 4) 0x100000), code: $BAD_PROP }
        { name: "strings.dtb", bytes: (put32 $tree ($first_prop.at + 8) ($h.size_strings + 16)), code: $BAD_PROP }
        { name: "token.dtb", bytes: (put32 $tree $first_prop.at 7), code: $BAD_TOKEN }
        { name: "deep16.dtb", bytes: (nested 16), code: $OK }
        { name: "deep17.dtb", bytes: (nested 17), code: $TOO_DEEP }
    ]
    for c in $cases { $c.bytes | save --raw -f ($stage | path join $c.name) }
    let disk = ($out | path join "trees.romfs")
    let made = (^genromfs -d $stage -f $disk -V dtb | complete)
    assert equal $made.exit_code 0 $"genromfs: ($made.stderr)"
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --disk $disk --serial "dtb" --bootargs $BOOTARGS --seconds 30)
    assert equal $run.status 0 $"exit status, with the UART: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    let lines = ($run.serial | lines)

    # every tree's code
    let checks = ($lines | where {|l| $l starts-with "check " } | parse "check {name} {code}" | update code {|r| $r.code | into int })
    assert equal ($checks | get name) ($cases | get name) $"every tree checked, in order: ($checks)"
    for c in $cases {
        let got = ($checks | where name == $c.name | get 0.code)
        assert equal $got $c.code $"($c.name) answers ($c.code): ($got)"
    }

    # QEMU's tree through the lookups
    let intc = (prop-at $tree $h "/cpus/cpu@1/interrupt-controller" "phandle" | into int --endian big)
    let want = [
        "cells 1"
        "cpus 4"
        $"timebase ($TIMEBASE)"
        "reg /cpus/cpu@2 2"
        "reg /cpus/cpu 0"
        $"phandle ($intc) same interrupt-controller"
        $"bootargs ($BOOTARGS)"
        "found /cpus"
        "found /"
        "absent /nope"
        "absent /cpus/cpu@9"
        "found /cpus/"
        "listed riscv,imsics 1"
        "listed qemu,imsics 1"
        "listed riscv,imsic 0"
        "listed imsics 0"
    ]
    let looked = ($lines | where {|l| not ($l starts-with "check ") })
    assert equal $looked $want $"every lookup as the tree has it: ($looked)"
    assert equal (prop-at $tree $h "/cpus" "timebase-frequency" | into int --endian big) $TIMEBASE "the host reads the same timebase"

    # the debug kernel's own reading of its tree
    if ($set | str contains "DEBUG") {
        let debug = ($run.debug | lines)
        assert ($debug | any {|l| $l == "jab: harts discovered 0x000000000000000f online 0x0000000000000001 failed 0x0000000000000000" }) $"the kernel discovered four harts: ($run.debug)"
        assert ($debug | any {|l| $l == $"jab: bootargs ($BOOTARGS)" }) $"the kernel read its command line from /chosen: ($run.debug)"
    }
    print $"dtb: ($cases | length) trees, each answering its code; QEMU's ($h.totalsize)-byte tree read through every lookup"
    print "dtb: ok"
}

# A tree's header fields the cases move.
def header [b: binary]: nothing -> record<totalsize: int, off_struct: int, off_strings: int, size_strings: int, size_struct: int> {
    let w = {|o| $b | bytes at $o..<($o + 4) | into int --endian big }
    { totalsize: (do $w 4), off_struct: (do $w 8), off_strings: (do $w 12), size_strings: (do $w 32), size_struct: (do $w 36) }
}

# Every token of the structure with its offset in the tree, to END.
def tokens [b: binary, h: record]: nothing -> table<at: int, kind: int> {
    mut at = $h.off_struct
    let end = ($h.off_struct + $h.size_struct)
    mut out = []
    while $at < $end {
        let kind = ($b | bytes at $at..<($at + 4) | into int --endian big)
        $out = ($out | append { at: $at, kind: $kind })
        $at = $at + 4
        if $kind == 1 {
            let n = ($b | bytes at $at..<$end | bytes index-of 0x[00])
            $at = $at + ((($n + 4) // 4) * 4)
        } else if $kind == 3 {
            let len = ($b | bytes at $at..<($at + 4) | into int --endian big)
            $at = $at + 8 + ((($len + 3) // 4) * 4)
        } else if $kind == 9 {
            break
        }
    }
    $out
}

# A property's value at a node's whole path, read on the host.
def prop-at [b: binary, h: record, path: string, name: string]: nothing -> binary {
    let strings = ($b | bytes at $h.off_strings..<($h.off_strings + $h.size_strings))
    let end = ($h.off_struct + $h.size_struct)
    mut at = $h.off_struct
    mut nodes = []
    mut found: any = null
    while $at < $end and $found == null {
        let kind = ($b | bytes at $at..<($at + 4) | into int --endian big)
        $at = $at + 4
        if $kind == 1 {
            let n = ($b | bytes at $at..<$end | bytes index-of 0x[00])
            $nodes = ($nodes | append ($b | bytes at $at..<($at + $n) | decode))
            $at = $at + ((($n + 4) // 4) * 4)
        } else if $kind == 2 {
            $nodes = ($nodes | drop 1)
        } else if $kind == 3 {
            let len = ($b | bytes at $at..<($at + 4) | into int --endian big)
            let off = ($b | bytes at ($at + 4)..<($at + 8) | into int --endian big)
            let pname = ($strings | bytes at $off.. | bytes at 0..<($strings | bytes at $off.. | bytes index-of 0x[00]) | decode)
            let here = ("/" + ($nodes | skip 1 | str join "/"))
            if $here == $path and $pname == $name { $found = ($b | bytes at ($at + 8)..<($at + 8 + $len)) }
            $at = $at + 8 + ((($len + 3) // 4) * 4)
        } else if $kind == 9 {
            break
        }
    }
    if $found == null { error make { msg: $"no ($name) at ($path) in the tree" } }
    $found
}

# A 32-bit big-endian word written into the bytes at an offset.
def put32 [b: binary, at: int, v: int]: nothing -> binary {
    [($b | bytes at 0..<$at) (be32 $v) ($b | bytes at ($at + 4)..)] | bytes collect
}

def be32 [v: int]: nothing -> binary {
    $v | into binary --endian big | bytes at 4..<8
}

# Bytes padded with zeros to a multiple of four.
def padded [b: binary]: nothing -> binary {
    let pad = ((4 - (($b | bytes length) mod 4)) mod 4)
    if $pad == 0 { $b } else { [$b (0..<$pad | each {|i| 0x[00] } | bytes collect)] | bytes collect }
}

# A tree of nodes nested `depth` deep, the root the first, each holding one
# string property, laid out as the format puts it: the header, an empty
# reservation block, the structure, then the strings.
def nested [depth: int]: nothing -> binary {
    let strings = ("label" | into binary | bytes add 0x[00] --end)
    mut s = []
    for i in 0..<$depth {
        let name = (if $i == 0 { "" } else { $"n($i)" })
        $s = ($s | append (be32 1) | append (padded ($name | into binary | bytes add 0x[00] --end)))
        $s = ($s | append (be32 3) | append (be32 2) | append (be32 0) | append (padded 0x[78 00]))
    }
    for i in 0..<$depth { $s = ($s | append (be32 2)) }
    $s = ($s | append (be32 9))
    let structure = ($s | bytes collect)
    let off_struct = 56
    let off_strings = ($off_struct + ($structure | bytes length))
    let total = ($off_strings + ($strings | bytes length))
    let head = ([(be32 0xd00dfeed) (be32 $total) (be32 $off_struct) (be32 $off_strings) (be32 40) (be32 17) (be32 16) (be32 0) (be32 ($strings | bytes length)) (be32 ($structure | bytes length))] | bytes collect)
    [$head (0..<16 | each {|i| 0x[00] } | bytes collect) $structure $strings] | bytes collect
}
