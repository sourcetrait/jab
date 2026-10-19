# dtb's integration test: the kernel's device tree reader, kernel/src/dtb.S,
# assembled into this program, over QEMU's own tree for a three-hart machine
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
# entry matched whole and neither a prefix of one nor a tail. Then the
# kernel's RAM reader, kernel/src/ram.S, over QEMU's own trees at 4 GiB
# and 8 GiB and trees the test builds: each tree's code and its banks
# sorted by base, whether the program's window is backed, and the free
# view, the banks less the protected prefix and the window, one bank, two
# in one node and in two, 32-bit cells, a bank ending at Sv39's reach,
# and the window's last page unbacked read whole; overlapping banks, an
# end past 2^64, a bank of 0, one below RAM's base, one past 256 GiB, 3
# cells, a memory node with no reg, no memory node, and 17 banks each
# refused by its code. The kernel's own refusals through -dtb, QEMU's tree
# with its bank made 0 and made a page short of the window, each ending
# the boot with 1 and its line. Last, the debug kernel's own reading of
# the tree it booted on: its harts and its command line, given through
# -append, a named spec's `jab.spec` after it.
use ../../../sdk/nu/jab.nu
use ../../../nu/mod/target
use ../../../nu/mod/spec
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
    target retire $stage
    mkdir $stage
    let ws = ($env.FILE_PWD | path join ".." ".." ".." | path expand)
    # the line a launch on the configured spec hands the kernel: the test's
    # own words, then the spec's name
    let line = $"($BOOTARGS) jab.spec=(spec configured $ws)"
    let good = (jab dump-tree --kernel $kernel --image $image --out ($out | path join "virt3.dtb") --bootargs $BOOTARGS)
    jab dump-tree --kernel $kernel --image $image --out ($stage | path join "virt8.dtb") --spec 1kb1 | ignore
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
    let gib = 1073741824
    let ram_trees = [
        { name: "ram1.dtb", nodes: [[{ base: 0x80000000, size: (4 * $gib) }]] }
        { name: "ram2.dtb", nodes: [[{ base: 0x200000000, size: (2 * $gib) } { base: 0x80000000, size: (4 * $gib) }]] }
        { name: "ramnodes.dtb", nodes: [[{ base: 0x80000000, size: (4 * $gib) }] [{ base: 0x180000000, size: (4 * $gib) }]] }
        { name: "ram32.dtb", nodes: [[{ base: 0x80000000, size: 0x7fffffff }]], cells: 1 }
        { name: "ramedge.dtb", nodes: [[{ base: 0x80000000, size: (4 * $gib) } { base: 0x3f80000000, size: 0x80000000 }]] }
        { name: "ramwindow.dtb", nodes: [[{ base: 0x80000000, size: 0xfffff000 }]] }
        { name: "ramoverlap.dtb", nodes: [[{ base: 0x80000000, size: (4 * $gib) } { base: 0x100000000, size: (4 * $gib) }]] }
        { name: "ramoverflow.dtb", nodes: [[{ base: (0 - 0x100000000), size: 0x200000000 }]] }
        { name: "ramempty.dtb", nodes: [[{ base: 0x80000000, size: 0 }]] }
        { name: "ramlow.dtb", nodes: [[{ base: 0x40000000, size: (4 * $gib) }]] }
        { name: "ramhigh.dtb", nodes: [[{ base: 0x3f80000000, size: 0x100000000 }]] }
        { name: "ramcells.dtb", nodes: [[{ base: 0x80000000, size: (4 * $gib) }]], cells: 3 }
        { name: "ramnoreg.dtb", nodes: [[]] }
        { name: "ramnone.dtb", nodes: [] }
        { name: "rammany.dtb", nodes: [(0..<17 | each {|i| { base: (0x80000000 + $i * 0x10000000), size: 0x1000000 } })] }
    ]
    for t in $ram_trees { ram-tree $t.nodes --cells ($t | get -o cells | default 2) | save --raw -f ($stage | path join $t.name) }
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
        "cpus 3"
        $"timebase ($TIMEBASE)"
        "reg /cpus/cpu@2 2"
        "reg /cpus/cpu 0"
        $"phandle ($intc) same interrupt-controller"
        $"bootargs ($line)"
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
    let looked = ($lines | where {|l| not ($l starts-with "check ") and not ($l starts-with "ram ") })
    assert equal $looked $want $"every lookup as the tree has it: ($looked)"

    # the RAM reader: each tree's code and banks, sorted by base, then for
    # a tree read whole whether the program's window is backed and the free
    # view, the banks less the protected prefix and the window
    let at = {|base: int, end: int| $"($base) ($end)" }
    let whole = {|name: string, banks: list<string>, window: int, free: list<string>|
        [$"ram ($name) 0 ($banks | length)"] ++ ($banks | each {|b| $"ram ($name) bank ($b)" }) ++ [$"ram ($name) window ($window)" $"ram ($name) free ($free | length)"] ++ ($free | each {|f| $"ram ($name) range ($f)" })
    }
    let low4 = (do $at 0x80000000 0x180000000)
    let ram_want = ([
        (do $whole "good.dtb" [$low4] 1 [])
        (do $whole "virt8.dtb" [(do $at 0x80000000 0x280000000)] 1 [(do $at 0x180000000 0x280000000)])
        (do $whole "ram1.dtb" [$low4] 1 [])
        (do $whole "ram2.dtb" [$low4 (do $at 0x200000000 0x280000000)] 1 [(do $at 0x200000000 0x280000000)])
        (do $whole "ramnodes.dtb" [$low4 (do $at 0x180000000 0x280000000)] 1 [(do $at 0x180000000 0x280000000)])
        (do $whole "ram32.dtb" [(do $at 0x80000000 0xffffffff)] 0 [])
        (do $whole "ramedge.dtb" [$low4 (do $at 0x3f80000000 0x4000000000)] 1 [(do $at 0x3f80000000 0x4000000000)])
        (do $whole "ramwindow.dtb" [(do $at 0x80000000 0x17ffff000)] 0 [])
        ["ram ramoverlap.dtb 6 2" "ram ramoverflow.dtb 5 0" "ram ramempty.dtb 4 0" "ram ramlow.dtb 7 0" "ram ramhigh.dtb 8 0" "ram ramcells.dtb 2 0" "ram ramnoreg.dtb 3 0" "ram ramnone.dtb 1 0" "ram rammany.dtb 9 16"]
    ] | reduce --fold [] {|x, acc| $acc ++ $x })
    let ram_read = ($lines | where {|l| $l starts-with "ram " })
    assert equal $ram_read $ram_want $"every RAM tree read as the rules give it: ($ram_read)"

    # the kernel's own refusals, QEMU's tree handed it through -dtb with its
    # memory node's size changed: a bank of 0, and one ending a page short of
    # the program's window
    let reg = 0x[00 00 00 00 80 00 00 00 00 00 00 01 00 00 00 00]
    let reg_at = ($tree | bytes index-of --all $reg)
    assert equal ($reg_at | length) 1 $"QEMU's tree holds its memory node's reg once: ($reg_at)"
    let refusals = [
        { name: "ram_empty", size: 0x[00 00 00 00 00 00 00 00], line: "jab: ram refused: code 4" }
        { name: "ram_short", size: 0x[00 00 00 00 ff ff f0 00], line: "jab: ram missing for the program's window: 0x0000000080a00000-0x0000000180000000" }
    ]
    for r in $refusals {
        let at = ($reg_at | first)
        let patched = ([($tree | bytes at 0..<($at + 8)) $r.size ($tree | bytes at ($at + 16)..)] | bytes collect)
        let file = ($out | path join $"($r.name).dtb")
        $patched | save --raw -f $file
        let refused = (jab launch --kernel $kernel --image $image --out ($out | path join $r.name) --set $set --dtb $file --seconds 20)
        assert equal $refused.status 1 $"($r.name): the boot ends with 1: ($refused.serial)"
        assert ($refused.serial | lines | any {|l| $l == $r.line }) $"($r.name): its line, ($r.line): ($refused.serial)"
    }
    assert equal (prop-at $tree $h "/cpus" "timebase-frequency" | into int --endian big) $TIMEBASE "the host reads the same timebase"

    # the debug kernel's own reading of its tree
    if ($set | str contains "DEBUG") {
        let debug = ($run.debug | lines)
        assert ($debug | any {|l| $l == "jab: harts discovered 0x0000000000000007 online 0x0000000000000007 failed 0x0000000000000000" }) $"the kernel discovered three harts, every one online: ($run.debug)"
        assert ($debug | any {|l| $l == $"jab: bootargs ($line)" }) $"the kernel read its command line from /chosen: ($run.debug)"
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

# A value in `cells` big-endian 32-bit cells, its high cells first; a
# value past 64 bits never asked.
def in-cells [v: int, cells: int]: nothing -> binary {
    let words = (if $cells == 1 { [$v] } else { (0..<($cells - 2) | each {|_| 0 }) ++ [($v bit-shr 32) ($v bit-and 0xffffffff)] })
    $words | each {|w| be32 $w } | bytes collect
}

# A tree of a root and its memory nodes, laid out as the format puts it:
# the root's #address-cells and #size-cells, both `cells`, then each
# node, named for its first bank, its device_type memory and its reg, the
# banks' bases and sizes in those cells; a node with no banks has no reg.
def ram-tree [nodes: list<list<record<base: int, size: int>>>, --cells: int = 2]: nothing -> binary {
    let names = ["#address-cells" "#size-cells" "device_type" "reg"]
    let strings = ($names | each {|n| $n | into binary | bytes add 0x[00] --end } | bytes collect)
    let offsets = [0 15 27 39]
    let prop = {|name: int, value: binary| [(be32 3) (be32 ($value | bytes length)) (be32 ($offsets | get $name)) (padded $value)] | bytes collect }
    mut s = [(be32 1) (padded 0x[00]) (do $prop 0 (be32 $cells)) (do $prop 1 (be32 $cells))]
    for n in $nodes {
        let unit = (if ($n | is-empty) { "0" } else { $n | first | get base | format number | get lowerhex | str replace "0x" "" })
        $s = ($s | append (be32 1) | append (padded ($"memory@($unit)" | into binary | bytes add 0x[00] --end)))
        $s = ($s | append (do $prop 2 ("memory" | into binary | bytes add 0x[00] --end)))
        if not ($n | is-empty) { $s = ($s | append (do $prop 3 ($n | each {|b| (in-cells $b.base $cells) ++ (in-cells $b.size $cells) } | bytes collect))) }
        $s = ($s | append (be32 2))
    }
    $s = ($s | append (be32 2) | append (be32 9))
    let structure = ($s | bytes collect)
    let off_struct = 56
    let off_strings = ($off_struct + ($structure | bytes length))
    let total = ($off_strings + ($strings | bytes length))
    let head = ([(be32 0xd00dfeed) (be32 $total) (be32 $off_struct) (be32 $off_strings) (be32 40) (be32 17) (be32 16) (be32 0) (be32 ($strings | bytes length)) (be32 ($structure | bytes length))] | bytes collect)
    [$head (0..<16 | each {|i| 0x[00] } | bytes collect) $structure $strings] | bytes collect
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
