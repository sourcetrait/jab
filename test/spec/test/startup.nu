use ../../../nu/mod/target
use ../../../nu/mod/walk
use ../../../nu/mod/demand
use std/assert

# The startup check's refusals of machines off the spec they are named,
# each a custom machine whose command line names a spec, as a tree of a
# caller's own would, run on this program's image, with the status and the
# UART's one line: a spec the image does not list; 1KB1's seven cores on
# three harts; 1KA1 with hart 2 failed by the late check-in, three
# discovered and two online; 1KB1's 8 GiB on a machine of 4, and 1KA1's
# 4 GiB on one of 8; and a name in capitals, read as its lowercase entry,
# the program running
export const CHECKS = [
    { name: "unlisted", harts: 3, bootargs: "jab.spec=2ka1", qemu: [], status: 1, line: "jab: spec 2ka1 not listed" }
    { name: "cores", harts: 3, bootargs: "jab.spec=1kb1", qemu: [], status: 1, line: "jab: spec 1kb1 wants 7 harts: 3 discovered, 3 online" }
    { name: "offline", harts: 3, bootargs: "jab.spec=1ka1 jab.late=2", qemu: [], status: 1, line: "jab: spec 1ka1 wants 3 harts: 3 discovered, 2 online" }
    { name: "ram_short", harts: 7, bootargs: "jab.spec=1kb1", qemu: [], status: 1, line: "jab: spec 1kb1 wants 8 GiB of RAM: 0x0000000100000000 bytes installed" }
    { name: "ram_long", harts: 3, bootargs: "jab.spec=1ka1", qemu: ["-m" "8G"], status: 1, line: "jab: spec 1ka1 wants 4 GiB of RAM: 0x0000000200000000 bytes installed" }
    { name: "capitals", harts: 3, bootargs: "jab.spec=1KA1", qemu: [], status: 0, line: "spec: up" }
]
# The minimum's refusal of a program reserving two graphics harts on a
# machine of two, and the debug kernel's knob that skips it
export const SHORT = "jab: harts short of the program's demand: 2 for 3"
export const NOMINIMUM = "jab.nominimum=1"
# The link script every program had before the first page: its code at
# the window's base
const LEGACY_LD = "ENTRY(_start)

PHDRS
{
    code PT_LOAD FLAGS(5);
    data PT_LOAD FLAGS(6);
}

SECTIONS
{
    . = 0x80a00000;

    .text : { *(.text .text.*) } :code
    .rodata : { *(.rodata .rodata.*) } :code
    .data : { *(.data .data.*) } :data
    .bss : { *(.bss .bss.*) *(COMMON) } :data
}
"

# The malformed first pages, each its patches or count and the refusal it draws
export def malformed [crc: int]: nothing -> list<record> {
    [
        { name: "version", patches: [[8 2]], why: "version 2" }
        { name: "flag_bit", patches: [[12 3]], why: "flags 0x0000000000000003" }
        { name: "undeclared_length", patches: [[12 0]], why: "flags 0 with a length" }
        { name: "undeclared_offset", patches: [[12 0] [20 0]], why: "flags 0 with an offset" }
        { name: "undeclared_crc", patches: [[12 0] [20 0] [16 0]], why: "flags 0 with a CRC" }
        { name: "no_length", patches: [[20 0]], why: "flags 1 with length 0" }
        { name: "offset", patches: [[16 128]], why: "offset 128" }
        { name: "length_short", patches: [[20 20]], why: "length 20" }
        { name: "length_past", patches: [[20 4096]], why: "length 4096" }
        { name: "crc", patches: [[24 ($crc bit-xor 1)]], why: $"CRC (hex16 $crc) computed, the header's (hex16 ($crc bit-xor 1))" }
        { name: "count_none", count: 0, why: "spec count 0" }
        { name: "count_past", count: 17, why: "spec count 17" }
        { name: "count_off", count: 3, why: "length 68 for 3 specs" }
    ]
}

# A value as the kernel prints one in hex: 0x and sixteen digits.
def hex16 [v: int]: nothing -> string {
    $"0x($v | into binary --endian big | encode hex | str lowercase)"
}

# A copy of an image with its first page patched: each of `m.patches`, a
# word's offset and its value, written little-endian; or `m.count` as the
# declaration's count of specs, the CRC made again over the declaration so
# the count alone is wrong. Beside it a `home` naming the program, so a
# launch finds its workspace. Its path.
export def patched [bytes: binary, m: record, dir: path, home: path]: nothing -> string {
    target retire $dir
    mkdir $dir
    mut b = $bytes
    for p in ($m | get -o patches | default []) {
        $b = (put-word $b $p.0 $p.1)
    }
    let count = ($m | get -o count)
    if $count != null {
        let length = ($b | bytes at 20..<24 | into int --endian little)
        $b = (($b | bytes at 0..<66) ++ ($count | into binary --endian little | bytes at 0..<1) ++ ($b | bytes at 67..))
        $b = (put-word $b 24 (demand crc32 ($b | bytes at 64..<(64 + $length))))
    }
    let file = ($dir | path join "spec.jab")
    $b | save -f $file
    $home | save -f ($dir | path join "home")
    $file
}

# Bytes with the little-endian word at `at` made `value`.
def put-word [b: binary, at: int, value: int]: nothing -> binary {
    ($b | bytes at 0..<$at) ++ ($value | into binary --endian little | bytes at 0..<4) ++ ($b | bytes at ($at + 4)..)
}

# An image built as every program was before the first page: a fixture's
# source assembled and linked by the tools its flags stamp names under the
# link script of then, LEGACY_LD, its code at the window's base and no
# header; beside it a `home` naming the fixture, so a launch finds its
# workspace. Its path.
export def legacy-image [ws: path, fixture: path, built: path, dir: path]: nothing -> string {
    target retire $dir
    mkdir $dir
    let prefix = (open --raw ($built | path join "flags") | decode | lines | first | split row " " | last)
    let script = ($dir | path join "legacy.ld")
    $LEGACY_LD | save -f $script
    let obj = ($dir | path join "legacy.o")
    let elf = ($dir | path join "legacy.elf")
    let image = ($dir | path join "legacy.jab")
    ^$"($prefix)as" -march=rva23u64 -I ($ws | path join "sdk" "src") ($fixture | path join "src" "main.S") -o $obj
    ^$"($prefix)ld" -T $script -nostdlib $obj -o $elf
    ^$"($prefix)objcopy" -O binary $elf $image
    $fixture | save -f ($dir | path join "home")
    $image
}

# A kernel without the startup check, as every kernel before it entered an
# image: a copy of the kernel's sources with kernel.S's one call of
# start_check taken out, assembled and linked by the tools the test's
# kernel's flags stamp names, with the build's symbols. Its ELF.
export def unchecked-kernel [ws: path, kernel: path, set: string, dir: path]: nothing -> string {
    target retire $dir
    mkdir $dir
    cp -r ($ws | path join "kernel" "src") $dir
    let main = ($dir | path join "src" "kernel.S")
    let lines = (open --raw $main | decode | lines)
    let kept = ($lines | where {|l| not ($l | str starts-with "    call start_check") })
    assert equal (($lines | length) - ($kept | length)) 1 "the kernel's one call of the check taken out"
    ($kept | str join "\n") + "\n" | save -f $main
    let prefix = (open --raw ($kernel | path dirname | path join "flags") | decode | lines | first | split row " " | last)
    let symbols = ($set | split row "," | where {|s| $s != "" } | each {|s| ["--defsym" $"($s)=1"] } | flatten)
    let objects = (walk paths ($dir | path join "src" "*.S") | sort | each {|f|
        let o = ($dir | path join (($f | path parse | get stem) + ".o"))
        ^$"($prefix)as" -march=rva23s64 -I ($dir | path join "src" "include") -I ($ws | path join "sdk" "src") ...$symbols $f -o $o
        $o
    })
    let elf = ($dir | path join "jab.elf")
    ^$"($prefix)ld" -T ($dir | path join "src" "link.ld") -nostdlib ...$objects -o $elf
    $elf
}
