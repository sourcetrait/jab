# harts's integration test: jab.sys.harts on machines of one, two, and
# four harts, every hart of the device tree discovered, hart 0 alone
# online and none failed, the secondaries parked; the kernel's own line
# for the same masks on the debug channel; each launch's record of its
# machine, one and two harts diagnostic, the line carrying -smp and
# multithreaded TCG; and a count the machine does not take refused by
# the launcher before QEMU starts. Then the platform check's two classes
# on trees of the test's own through -dtb, QEMU's four-hart tree with one
# change each: a cpu whose id is past JAB_HARTS_MAX, a topology problem,
# named on the debug channel, the other harts discovered and failed and
# the kernel going on on hart 0; and a timebase other than QEMU's, which
# ends the boot with its line on the UART and status 1 before the
# program runs. The timebase as the device tree specification lets a
# tree write it: in two cells, read whole, the high cell 0 booting and a
# high cell of 1 ending the boot with the whole rate; and in the cpu
# nodes, each cpu's own read before /cpus's, every cpu's own with none
# at /cpus booting and cpu@2's own slow rate beside /cpus's ending the
# boot. Then the interrupt platform as the tree describes it, each a
# refusal with its code: the supervisor IMSIC gone, the ACLINT's timer
# gone, the supervisor APLIC domain gone, and the supervisor IMSIC at an
# address other than QEMU's, which the page tables map.
use ../../../sdk/nu/jab.nu
use std/assert

const PAST_MAX = 9
const SLOW_TIMEBASE = 1000000

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    mut seen = []
    for n in [1 2 4] {
        let run = (jab launch --kernel $kernel --image $image --out ($out | path join $"harts_($n)") --set $set --harts $n --seconds 20)
        assert equal $run.status 0 $"exit status on ($n) harts: ($run.serial)"
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on ($n) harts"
        let mask = ((1 bit-shl $n) - 1)
        assert equal ($run.serial | lines) [$"harts ($mask) 1 0"] $"on ($n) harts every one discovered, hart 0 online, none failed: ($run.serial)"
        assert equal $run.machine.harts $n $"the launch's record of its harts: ($run.machine)"
        assert equal $run.machine.diagnostic ($n != 4) $"a machine of ($n) harts diagnostic or not: ($run.machine)"
        assert equal $run.machine.accel "tcg,thread=multi" $"multithreaded TCG: ($run.machine)"
        assert ($run.qemu | window 2 | any {|w| $w.0 == "-smp" and $w.1 == ($n | into string) }) $"-smp ($n) on the line: ($run.qemu)"
        assert ($run.qemu | window 2 | any {|w| $w.0 == "-accel" and $w.1 == "tcg,thread=multi" }) $"-accel tcg,thread=multi on the line: ($run.qemu)"
        if ($set | str contains "DEBUG") {
            let line = $"jab: harts discovered (hex64 $mask) online (hex64 1) failed (hex64 0)"
            assert ($run.debug | lines | any {|l| $l == $line }) $"the kernel's line on ($n) harts, ($line): ($run.debug)"
        }
        $seen = ($seen | append { harts: $n, serial: ($run.serial | str trim) })
    }
    let refused = (try { jab launch --kernel $kernel --image $image --out ($out | path join "harts_3") --set $set --harts 3; "" } catch {|e| $e.msg })
    assert ($refused | str contains "--harts takes 1, 2, or 4") $"three harts refused before QEMU starts: ($refused)"

    # a cpu past JAB_HARTS_MAX: cpu@3's reg made 9, so harts 0 to 2 are
    # discovered, every one but the boot hart failed, and hart 0 runs on
    let tree = (open --raw (jab dump-tree --kernel $kernel --image $image --out ($out | path join "virt4.dtb")) | into binary)
    let past_file = ($out | path join "past_max.dtb")
    put32 $tree (prop-offset $tree "/cpus/cpu@3" "reg") $PAST_MAX | save --raw -f $past_file
    let past = (jab launch --kernel $kernel --image $image --out ($out | path join "past_max") --set $set --dtb $past_file --seconds 20)
    assert equal $past.status 0 $"the program runs on hart 0 past a topology problem: ($past.serial)"
    assert equal ($past.serial | lines) ["harts 7 1 6"] $"harts 0 to 2 discovered, hart 0 online, 1 and 2 failed: ($past.serial)"
    if ($set | str contains "DEBUG") {
        let debug = ($past.debug | lines)
        assert ($debug | any {|l| $l == $"jab: hart ($PAST_MAX) refused: past JAB_HARTS_MAX" }) $"the cpu past the bound named: ($past.debug)"
        assert ($debug | any {|l| $l == $"jab: harts discovered (hex64 7) online (hex64 1) failed (hex64 6)" }) $"the kernel's masks: ($past.debug)"
    }

    # a timebase not QEMU's: the boot ends with its line, status 1, and
    # the program never runs
    let slow_file = ($out | path join "slow_timebase.dtb")
    put32 $tree (prop-offset $tree "/cpus" "timebase-frequency") $SLOW_TIMEBASE | save --raw -f $slow_file
    let slow = (jab launch --kernel $kernel --image $image --out ($out | path join "slow_timebase") --set $set --dtb $slow_file --seconds 20)
    assert equal $slow.status 1 $"an unsupported timer ends the boot with status 1: ($slow.status), ($slow.serial)"
    assert equal ($slow.serial | lines) [$"jab: timer unsupported: timebase-frequency ($SLOW_TIMEBASE)"] $"its line, and nothing of the program's: ($slow.serial)"

    # the timebase in two cells, the high one first: 0 is QEMU's rate,
    # and 1 a rate past 2^32 that a read of the low cell alone would pass
    let at_cpus = (prop-offset $tree "/cpus" "timebase-frequency")
    let rate = ($tree | bytes at $at_cpus..<($at_cpus + 4) | into int --endian big)
    let wide = {|high: int| splice (put32 $tree ($at_cpus - 8) 8) $at_cpus (be32 $high) }
    # each cpu's own timebase, read before /cpus's: every cpu's own with
    # /cpus's made NOP, and cpu@2's own slow rate beside /cpus's, each read
    # wrong by a kernel that reads /cpus alone
    let name_offset = ($tree | bytes at ($at_cpus - 4)..<$at_cpus | into int --endian big)
    let own = {|b: binary, cpu: string, hz: int| splice $b (node-body $b $"/cpus/($cpu)") (prop-bytes $name_offset (be32 $hz)) }
    let every = (["cpu@0" "cpu@1" "cpu@2" "cpu@3"] | reduce --fold (nop-prop $tree $at_cpus) {|cpu, b| do $own $b $cpu $rate })
    let tried = ([
        { name: "wide_same", tree: (do $wide 0), status: 0, serial: ["harts 15 1 0"] }
        { name: "wide_high", tree: (do $wide 1), status: 1, serial: [$"jab: timer unsupported: timebase-frequency ((1 bit-shl 32) + $rate)"] }
        { name: "own_every", tree: $every, status: 0, serial: ["harts 15 1 0"] }
        { name: "own_slow", tree: (do $own $tree "cpu@2" $SLOW_TIMEBASE), status: 1, serial: [$"jab: timer unsupported: timebase-frequency ($SLOW_TIMEBASE)"] }
    ] | each {|t|
        let file = ($out | path join $"($t.name).dtb")
        $t.tree | save --raw -f $file
        let run = (jab launch --kernel $kernel --image $image --out ($out | path join $t.name) --set $set --dtb $file --seconds 20)
        assert equal $run.status $t.status $"($t.name): exit status ($run.status), ($run.serial)"
        assert equal ($run.serial | lines) $t.serial $"($t.name): its line: ($run.serial)"
        $"($t.name): ($run.serial | str trim)"
    })

    # the interrupt platform: aia.inc's AIA_NO_IMSIC_S, AIA_NO_TIMER,
    # AIA_NO_DOMAINS, and AIA_NOT_QEMU
    let s_imsic = "/soc/interrupt-controller@28000000"
    let refused = ([
        { name: "no_imsic", tree: (nop-node $tree $s_imsic), code: 1 }
        { name: "no_timer", tree: (nop-node $tree "/soc/mtimer@2007ff8"), code: 4 }
        { name: "no_domain", tree: (nop-node $tree "/soc/interrupt-controller@d000000"), code: 3 }
        { name: "moved_imsic", tree: (put32 $tree ((prop-offset $tree $s_imsic "reg") + 4) 0x29000000), code: 5 }
    ] | each {|t|
        let file = ($out | path join $"($t.name).dtb")
        $t.tree | save --raw -f $file
        let run = (jab launch --kernel $kernel --image $image --out ($out | path join $t.name) --set $set --dtb $file --seconds 20)
        assert equal $run.status 1 $"($t.name): exit status ($run.status), ($run.serial)"
        assert equal ($run.serial | lines) [$"jab: interrupt platform refused: code ($t.code)"] $"($t.name): its line: ($run.serial)"
        $"($t.name): ($run.serial | str trim)"
    })

    print $"harts: ($seen | each {|s| $'($s.harts) harts: ($s.serial)' } | str join '; '); a cpu past the bound: ($past.serial | str trim); a slow timebase: ($slow.serial | str trim); ($tried | str join '; '); ($refused | str join '; ')"
    print "harts: ok"
}

# A tree with a node, its properties and its children with it, made NOP
# tokens in place, by the node's whole path. Untyped because it can end
# in an error.
def nop-node [b: binary, path: string] {
    let w = {|o| $b | bytes at $o..<($o + 4) | into int --endian big }
    let off_struct = (do $w 8)
    let end = ($off_struct + (do $w 36))
    mut at = $off_struct
    mut nodes = []
    mut start = -1
    mut depth = 0
    while $at < $end {
        let token = $at
        let kind = (do $w $at)
        $at = $at + 4
        if $kind == 1 {
            let n = ($b | bytes at $at..<$end | bytes index-of 0x[00])
            $nodes = ($nodes | append ($b | bytes at $at..<($at + $n) | decode))
            $at = $at + ((($n + 4) // 4) * 4)
            if $start < 0 and ("/" + ($nodes | skip 1 | str join "/")) == $path {
                $start = $token
                $depth = ($nodes | length)
            }
        } else if $kind == 2 {
            if $start >= 0 and ($nodes | length) == $depth {
                let nops = (1..(($at - $start) // 4) | each { be32 4 } | bytes collect)
                return ([($b | bytes at 0..<$start) $nops ($b | bytes at $at..)] | bytes collect)
            }
            $nodes = ($nodes | drop 1)
        } else if $kind == 3 {
            let len = (do $w $at)
            $at = $at + 8 + ((($len + 3) // 4) * 4)
        } else if $kind == 9 {
            break
        }
    }
    error make { msg: $"no node ($path) in the tree" }
}

# The offset in a tree of a property's value at a node's whole path.
# Untyped because it can end in an error.
def prop-offset [b: binary, path: string, name: string] {
    let w = {|o| $b | bytes at $o..<($o + 4) | into int --endian big }
    let off_struct = (do $w 8)
    let off_strings = (do $w 12)
    let end = ($off_struct + (do $w 36))
    mut at = $off_struct
    mut nodes = []
    while $at < $end {
        let kind = (do $w $at)
        $at = $at + 4
        if $kind == 1 {
            let n = ($b | bytes at $at..<$end | bytes index-of 0x[00])
            $nodes = ($nodes | append ($b | bytes at $at..<($at + $n) | decode))
            $at = $at + ((($n + 4) // 4) * 4)
        } else if $kind == 2 {
            $nodes = ($nodes | drop 1)
        } else if $kind == 3 {
            let len = (do $w $at)
            let s = ($b | bytes at ($off_strings + (do $w ($at + 4)))..)
            let pname = ($s | bytes at 0..<($s | bytes index-of 0x[00]) | decode)
            if ("/" + ($nodes | skip 1 | str join "/")) == $path and $pname == $name { return ($at + 8) }
            $at = $at + 8 + ((($len + 3) // 4) * 4)
        } else if $kind == 9 {
            break
        }
    }
    error make { msg: $"no ($name) at ($path) in the tree" }
}

# The offset in a tree just past a node's name, where a property of its
# goes first, by the node's whole path. Untyped because it can end in an
# error.
def node-body [b: binary, path: string] {
    let w = {|o| $b | bytes at $o..<($o + 4) | into int --endian big }
    let off_struct = (do $w 8)
    let end = ($off_struct + (do $w 36))
    mut at = $off_struct
    mut nodes = []
    while $at < $end {
        let kind = (do $w $at)
        $at = $at + 4
        if $kind == 1 {
            let n = ($b | bytes at $at..<$end | bytes index-of 0x[00])
            $nodes = ($nodes | append ($b | bytes at $at..<($at + $n) | decode))
            $at = $at + ((($n + 4) // 4) * 4)
            if ("/" + ($nodes | skip 1 | str join "/")) == $path { return $at }
        } else if $kind == 2 {
            $nodes = ($nodes | drop 1)
        } else if $kind == 3 {
            let len = (do $w $at)
            $at = $at + 8 + ((($len + 3) // 4) * 4)
        } else if $kind == 9 {
            break
        }
    }
    error make { msg: $"no node ($path) in the tree" }
}

# A 32-bit big-endian word written into the bytes at an offset.
def put32 [b: binary, at: int, v: int]: nothing -> binary {
    [($b | bytes at 0..<$at) (be32 $v) ($b | bytes at ($at + 4)..)] | bytes collect
}

# A 32-bit big-endian word's bytes.
def be32 [v: int]: nothing -> binary {
    $v | into binary --endian big | bytes at 4..<8
}

# A tree with bytes put in at an offset inside its structure: the total
# size and the structure's size grown by them, and every block that
# starts past the offset moved on by them.
def splice [b: binary, at: int, add: binary]: nothing -> binary {
    let n = ($add | bytes length)
    let w = {|o| $b | bytes at $o..<($o + 4) | into int --endian big }
    let grown = ([($b | bytes at 0..<$at) $add ($b | bytes at $at..)] | bytes collect)
    let sized = (put32 (put32 $grown 4 ((do $w 4) + $n)) 36 ((do $w 36) + $n))
    [8 12 16] | reduce --fold $sized {|field, acc|
        let off = (do $w $field)
        if $off > $at { put32 $acc $field ($off + $n) } else { $acc }
    }
}

# A property as a tree's structure holds it: its token, its length, its
# name's offset in the strings, and its value padded to four bytes.
def prop-bytes [name_offset: int, value: binary]: nothing -> binary {
    let len = ($value | bytes length)
    let pad = ((4 - ($len mod 4)) mod 4)
    [(be32 3) (be32 $len) (be32 $name_offset) $value (0x[00 00 00] | bytes at 0..<$pad)] | bytes collect
}

# A tree with a one-cell property, by its value's offset, made four NOP
# tokens in place: its token, its length, its name's offset, its value.
def nop-prop [b: binary, at: int]: nothing -> binary {
    [($b | bytes at 0..<($at - 12)) (be32 4) (be32 4) (be32 4) (be32 4) ($b | bytes at ($at + 4)..)] | bytes collect
}

# A value as the kernel's debug_put_hex writes it: 0x and sixteen digits.
def hex64 [value: int]: nothing -> string {
    "0x" + ($value | into binary --endian big | encode hex | str lowercase)
}
