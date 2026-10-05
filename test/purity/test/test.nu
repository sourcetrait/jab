# purity's integration test: a release kernel carries none of the
# kernel's debug text, and a debug kernel carries all of it, so the scan
# is proved on the build it must find things in before it is trusted on
# the build it must find nothing in. Every `jab: ` string a release
# kernel does carry is a fault line, which stays in every build. The
# workspace's test build is a debug build, so the release kernel is
# built here through the tool, into its own tree. The program itself is
# run once as well, and its own debug line is the same proof for a
# program. First, read off the kernel's sources, the device ordering
# (OrderCheck): every virtio doorbell and every write that enables a queue
# or a device follows `fence ow, o`, or a fence ordering as much, with
# nothing between but value and address computation, so the fence lies on
# every path to the store in both builds. QEMU runs every fence as a full
# barrier, so no run could show one missing; this check is what keeps
# them.
use ../../../sdk/nu/jab.nu
use std/assert

# What only a debug kernel says
const debug_text = [
    "jab: kernel up on qemu virt"
    "jab: exit "
    "jab: keyboard at "
    "jab: no keyboard"
    "jab: pad at "
    "jab: rng at "
    "jab: no rng"
    "jab: sound at "
    "jab: no sound"
    "jab: sound refused"
    "jab: sound submitted "
    "jab: disk on pci slot "
    "jab: disk "
    "jab: serial at "
    "jab: timer left enabled"
    "jab: pad on port"
    "jab: pad port refused"
    "jab: no pad"
    "jab: gpu at "
    "jab: gpu cmd="
    "jab: display "
    "jab: harts discovered "
    "jab: hart "
    "jab: cpus refused: "
    "jab: cpu refused: "
    "jab: bootargs "
]

# What every kernel says, because a fault has to be reported whatever
# the build
const fault_text = [
    "jab: unknown system call "
    "jab: address outside the program"
    "jab: program fault: cause="
    "jab: worker fault: hart="
    "jab: kernel fault: hart="
    "jab: worker stop refused: hart "
    "jab: kernel stack overrun: hart "
    "jab: shutdown unanswered: hart "
    "jab: romfs: no disk "
    "jab: romfs: no romfs on disk "
    "jab: romfs: bad header at "
    "jab: romfs: wrong kind at "
    "jab: romfs: disk error"
    "jab: sound stalled"
    "jab: device tree refused: code "
    "jab: timer unsupported: timebase-frequency "
    "jab: machine trap: cause="
    "jab: interrupt platform refused: code "
    "jab: interrupt source "
    "jab: device reset refused: source "
]

# What may sit between a device store and its fence: value and address
# computation alone
const between = [la ld li lui addi slli add mv]

# The doorbells and enabling writes in one kernel source: each a record of
# the file, the line, and its kind. A doorbell is a store to a queue's
# notify register, or vpci_notify's store; an enabling write is a store
# to QUEUE_READY, the PCI queue enable, or a status register the value
# naming DRIVER_OK, loaded by the routine's last li of that register.
def order-sites [file: path] {
    let name = ($file | path basename)
    let lines = (open --raw $file | decode | lines)
    mut routine = ""
    mut loaded = {}
    mut sites = []
    for row in ($lines | enumerate) {
        let code = ($row.item | split row "#" | first | str trim)
        if ($code =~ '^[A-Za-z_][A-Za-z0-9_]*:$') {
            $routine = ($code | str trim --right --char ":")
            $loaded = {}
        }
        let li = ($code | parse --regex '^li\s+(?P<reg>\w+),\s*(?P<value>.+)$')
        if not ($li | is-empty) {
            $loaded = ($loaded | upsert $li.0.reg $li.0.value)
        }
        let store = ($code | parse --regex '^s[bhwd]\s+(?P<reg>\w+),\s*(?P<target>.+)$')
        if not ($store | is-empty) {
            let target = $store.0.target
            let value = ($loaded | get -o $store.0.reg | default "")
            let status = (($target | str contains "VIRTIO_MMIO_STATUS(") or ($target | str contains "VIRTIO_PCI_COMMON_STATUS("))
            let kind = (if ($target | str contains "VIRTIO_MMIO_QUEUE_NOTIFY(") or $routine == "vpci_notify" {
                "doorbell"
            } else if ($target | str contains "VIRTIO_MMIO_QUEUE_READY(") or ($target | str contains "VIRTIO_PCI_COMMON_QUEUE_ENABLE(") {
                "enabling"
            } else if $status and ($value | str contains "VIRTIO_STATUS_DRIVER_OK") {
                "enabling"
            } else {
                ""
            })
            if $kind != "" {
                $sites = ($sites | append { file: $name, line: ($row.index + 1), kind: $kind })
            }
        }
    }
    $sites
}

# The fence before the store at a line: "" when it orders earlier writes
# and device output before it with nothing but value and address
# computation between, else what is wrong, naming the file and line.
def fence-before [lines: list<string>, site: record] {
    mut i = ($site.line - 2)
    while $i >= 0 {
        let code = ($lines | get $i | split row "#" | first | str trim)
        if $code == "" {
            $i = ($i - 1)
            continue
        }
        let op = ($code | split row --regex '\s+' | first)
        if $op == "fence" {
            let sets = ($code | str replace "fence" "" | split row "," | each {|s| $s | str trim } | where {|s| $s != "" })
            let pred = (if ($sets | length) == 2 { $sets.0 } else { "iorw" })
            let succ = (if ($sets | length) == 2 { $sets.1 } else { "iorw" })
            if ($pred | str contains "o") and ($pred | str contains "w") and ($succ | str contains "o") {
                return ""
            }
            return $"($site.file):($site.line): its fence, `($code)`, orders too little"
        }
        if $op in $between {
            $i = ($i - 1)
            continue
        }
        return $"($site.file):($site.line): `($code)` between it and any fence"
    }
    $"($site.file):($site.line): no fence before it"
}

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let ws = ($env.FILE_PWD | path join ".." ".." ".." | path expand)
    let kernel_dir = ($ws | path join (open ($ws | path join "workspace.jab.toml") | get kernel))
    let tool = ($ws | path join "sdk" "nu" "jab.nu")

    # the device ordering, read off the sources before anything is built
    let sources = (glob ($kernel_dir | path join "src" "*.S") | sort)
    let sites = ($sources | each {|f| order-sites $f } | flatten)
    let doorbells = ($sites | where kind == "doorbell" | length)
    let enabling = ($sites | where kind == "enabling" | length)
    assert equal [$doorbells $enabling] [17 7] $"OrderCheck: the 17 doorbells and 7 enabling writes found, a driver added or a store missed if not: ($sites | each {|s| $'($s.file):($s.line) ($s.kind)' } | str join ', ')"
    let faults = ($sources | each {|f|
        let lines = (open --raw $f | decode | lines)
        $sites | where file == ($f | path basename) | each {|s| fence-before $lines $s }
    } | flatten | where {|m| $m != "" })
    assert equal $faults [] $"OrderCheck: every doorbell and enabling write after its fence: ($faults | str join '; ')"
    ^nu $tool build --kernel $kernel_dir
    let release = (jab target-root $ws | path join "release" "kernel" "jab.elf")
    assert ($release | path exists) $"the release kernel was built at ($release)"

    # the scan finds every debug line in the debug kernel
    let debug_found = (jab strings $kernel "jab: ")
    for text in $debug_text {
        assert ($debug_found | any {|s| $s | str starts-with $text }) $"the debug kernel carries '($text)'"
    }
    for text in $fault_text {
        assert ($debug_found | any {|s| $s | str starts-with $text }) $"the debug kernel carries the fault line '($text)'"
    }

    # and none of them in the release kernel, where every jab: line is a
    # fault line
    let release_found = (jab strings $release "jab: ")
    assert (($release_found | length) > 0) "the release kernel's fault lines are found, so the scan works there too"
    for text in $debug_text {
        assert (not ($release_found | any {|s| $s | str starts-with $text })) $"the release kernel carries no '($text)'"
    }
    for text in $fault_text {
        assert ($release_found | any {|s| $s | str starts-with $text }) $"the release kernel keeps the fault line '($text)'"
    }
    let strays = ($release_found | where {|s| not ($fault_text | any {|f| $s | str starts-with $f }) })
    assert equal $strays [] $"every jab: line in the release kernel is a fault line; not these: ($strays)"

    # the table of record and the SDK agree name for name: every call
    # in doc/syscalls.nuon has a macro of its name in sdk/src/jab.inc, the
    # JAB_SYS_ constant spelled from that name carries the table's
    # number, and jab.inc defines no call the table lacks
    let table = (open ($ws | path join "doc" "syscalls.nuon"))
    let inc = (open --raw ($ws | path join "sdk" "src" "jab.inc") | decode)
    let macros = ($inc | parse --regex '(?m)^\.macro (?P<name>jab\.[A-Za-z0-9_.]+)' | get name)
    let numbers = ($inc | parse --regex '(?m)^\.set (?P<sym>JAB_SYS_[A-Z0-9_]+), (?P<n>\d+)' | each {|r| { sym: $r.sym, n: ($r.n | into int) } })
    for row in $table {
        assert ($row.name in $macros) $"the table's ($row.name) has a macro of that name in jab.inc"
        let sym = ("JAB_" + ($row.name | str replace "jab." "" | str uppercase | str replace --all "." "_"))
        let n = ($numbers | where sym == $sym | get -o 0.n)
        assert ($n != null) $"jab.inc defines ($sym) for the table's ($row.name)"
        assert equal $n $row.number $"($row.name) is call ($row.number) in the table and ($sym) is ($n) in jab.inc"
    }
    assert equal ($numbers | length) ($table | length) $"every JAB_SYS_ constant in jab.inc has a row in the table: ($numbers | length) against ($table | length)"

    # the program: its debug line is there in this debug build, and it
    # runs on the debug kernel with the kernel's own lines on the debug
    # channel rather than the UART
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set)
    assert equal $run.status 0 $"exit status, with the UART: ($run.serial)"
    assert equal $run.serial "purity: debug build\npurity: done\n" "the program's debug line and its last line, and nothing of the kernel's"
    assert ($run.debug | str contains "jab: kernel up on qemu virt") $"the kernel's banner is on the debug channel: ($run.debug)"
    assert ($run.debug | str contains "jab: exit 0") $"and so is its exit line: ($run.debug)"
    print $"purity: ($doorbells) doorbells and ($enabling) enabling writes each after its fence; ($debug_text | length) debug lines absent from the release kernel and present in the debug one; ($fault_text | length) fault lines in both"
    print "purity: ok"
}
