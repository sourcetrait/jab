# owners' integration test (DriverInventory): every driver global is hart
# 0's, held on the built code. From every entry a worker's hart takes in
# the kernel, the trap vector's worker path, each call the worker class
# admits, and the drain, no transfer reaches a routine of a driver file or
# of the frame clock, no instruction refers to those files' data but the
# allowlist's one instruction a row, and every indirect transfer is a
# listed dispatch site whose targets are read from its table. The graph is
# read off the debug and release kernels' ELFs through the toolchain's
# objdump, each function a symbol's range and each address's file from
# where the objects beside the ELF were laid, so macros and tail
# transfers count as the assembler emitted them. A transfer through a
# register is direct only as the call and tail pseudos emit it, the auipc
# of that register just before; any other is indirect. The drain's calls
# into its service are cut on a worker's hart, the drain's path
# condition, which a debug kernel holds as it runs: a drain off hart 0
# that claims a device identity ends the run, and so does a secondary
# whose file enables one at its idle's entry. Then the program runs, its
# worker woken asleep in its wait, and no hart claims or enables a device
# identity.
use ../../../sdk/nu/jab.nu
use ../../../nu/mod/target
use ../../../nu/mod/walk
use std/assert

# The files whose routines and data a worker's hart never reaches: the
# drivers and the frame clock
const forbidden_files = [display keyboard pad sound synth smf soundfont block romfs serial random pci timer]

# The references into those files' data a worker's path makes, one
# instruction a row, each with its reason
const allowlist = [
    [function, symbol, reason];
    [irq_drain, sound_base, "the sound's identity, for the sound-first order: on a worker's hart its claim is the wake alone, so it decides nothing"]
    [sys_worker_wait, sound_live, "hart 0's branch, past its test of HART_ID: hart 0's external enable kept while the stream is live; a worker never runs it"]
]

# The calls a worker's hart takes, by jab.inc's names, and the routine
# that admits them
const worker_calls = [JAB_SYS_HARTS JAB_SYS_WORKER_WAIT JAB_SYS_WORKER_WAKE JAB_SYS_WORKER_EXIT]
const class_site = "worker_call"

# The entries besides the class's handlers
const entries = [trap_vector irq_drain]

# The drain, its service, and how many calls between them the model cuts
const drain = "irq_drain"
const service = "irq_serve"
const drain_calls = 2

# The one dispatch site and the table it reads
const dispatch_site = "call_table"
const dispatch_table = "syscall_table"

const code_sections = [".text" ".text.boot"]
const data_sections = [".rodata" ".data" ".bss" ".sdata" ".sbss"]
const branches = [beq bne blt bge bltu bgeu beqz bnez blez bgez bltz bgtz bgt ble bgtu bleu]
const ends = [j jr ret sret mret]
const padding = [nop unimp]

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    assert ($set | str contains "DEBUG") $"the run's checks are a debug kernel's, and the build is ($set)"
    let ws = ($env.FILE_PWD | path join ".." ".." ".." | path expand)
    let kernel_dir = ($ws | path join (open ($ws | path join "workspace.jab.toml") | get kernel))
    let tool = ($ws | path join "nu" "bin" "do.nu")
    let inc = (open --raw ($ws | path join "sdk" "src" "jab.inc") | decode)

    # the clean kernels: the debug kernel the test runs on, and the release
    # kernel, built here as purity builds it
    ^nu $tool build --kernel $kernel_dir
    let release = (target root $ws | path join "release" "kernel" "jab.elf")
    assert ($release | path exists) $"the release kernel was built at ($release)"
    let debug_reading = (owners-check $kernel $inc)
    assert equal $debug_reading.violations [] $"owners: the debug kernel's worker paths reach no driver: (violation-text $debug_reading.violations)"
    let release_reading = (owners-check $release $inc)
    assert equal $release_reading.violations [] $"owners: the release kernel's worker paths reach no driver: (violation-text $release_reading.violations)"

    # the run: the worker woken asleep in its wait, every drain off hart 0
    # claiming the wake alone, every secondary's file enabling it alone
    let run = (jab launch --kernel $kernel --image $image --out ($out | path join "run") --set $set --seconds 20)
    assert (not ($run.serial | str contains " claimed a device identity ")) $"owners: no hart but 0 claimed a device identity: ($run.serial)"
    assert (not ($run.serial | str contains " enabled a device identity ")) $"owners: no secondary's file enabled a device identity: ($run.serial)"
    assert equal $run.status 0 $"owners: exit status, with the UART: ($run.serial)"
    assert equal $run.serial "owners: woken asleep, then done\n" "owners: the worker slept in its wait, was woken there, and finished"

    for reading in [[name, r]; [debug, $debug_reading] [release, $release_reading]] {
        let r = $reading.r
        print $"owners: the ($reading.name) kernel: ($r.reached) functions reached from ($r.entries | str join ', ') and the calls ($r.class | str join ' ') through ($dispatch_site), ($r.handlers | str join ', '); the drain's calls into ($service) cut at ($r.cuts | each {|c| $'($drain)+(hex $c)' } | str join ' and '); permitted (($r.permitted | each {|p| $'($p.symbol) at ($p.function)+(hex $p.offset)' } | str join ', '))"
    }
    print "owners: the drain's cut assumes a worker's claim holds the wake alone: a secondary's file enables the wake alone (aia_file_open) and every device source targets hart 0's file (irq_enable); the debug kernel's claim and configuration checks hold it as it runs"
    print "owners: ok"
}

# Violations as one line each, their paths with them
def violation-text [vs: list<any>]: nothing -> string {
    if ($vs | is-empty) { return "none" }
    $vs | each {|v| $"($v.kind) ($v.function)(if $v.symbol == '' { '' } else { ' ' + $v.symbol }) at (hex $v.offset): ($v.detail); path ($v.path)" } | str join "; "
}

def hex [n: int]: nothing -> string { $n | format number | get lowerhex }

# The toolchain's prefix a kernel was built with, the last word of the
# flags beside it
def prefix-of [elf: path]: nothing -> string {
    open --raw ($elf | path dirname | path join "flags") | decode | lines | first | split row " " | last
}

# A file's symbols as objdump -t lists them, the section symbols and the
# file's name, the absolute, and the undefined left out
def symbols-of [prefix: string, file: path]: nothing -> table<value: int, section: string, name: string> {
    ^$"($prefix)objdump" -t $file | complete | get stdout | lines
    | parse --regex '^(?P<value>[0-9a-f]{16}) (?P<flags>.{7}) (?P<section>\S+)\t[0-9a-f]{16} (?P<name>.+)$'
    | where {|s| not ($s.flags | str contains "d") and $s.section not-in ["*ABS*" "*UND*"] }
    | each {|s| { value: ($s.value | into int --radix 16), section: $s.section, name: $s.name } }
}

# A file's sections as objdump -h lists them: each its size, its address,
# and its offset in the file
def sections-of [prefix: string, file: path]: nothing -> table<name: string, size: int, vma: int, off: int> {
    ^$"($prefix)objdump" -h $file | complete | get stdout | lines
    | parse --regex '^\s+\d+\s+(?P<name>\S+)\s+(?P<size>[0-9a-f]+)\s+(?P<vma>[0-9a-f]+)\s+[0-9a-f]+\s+(?P<off>[0-9a-f]+)\s+'
    | each {|s| { name: $s.name, size: ($s.size | into int --radix 16), vma: ($s.vma | into int --radix 16), off: ($s.off | into int --radix 16) } }
}

# The objects beside a kernel's ELF: each its file, its symbols, and its
# sections
def objects-of [prefix: string, elf: path] {
    walk paths ($elf | path dirname | path join "*.o") | sort | each {|o| { file: ($o | path parse | get stem), symbols: (symbols-of $prefix $o), sections: (sections-of $prefix $o) } }
}

# Where the objects' data lie in the ELF: a range a data section of an
# object, placed by a symbol of that section whose name no other symbol
# carries, in the objects or in the ELF. Data keep their offsets through
# the link; code does not, since the linker relaxes calls, so code is
# placed by name (function-files).
def placement [objects: list<any>, elf_symbols: table]: nothing -> table<file: string, section: string, start: int, end: int> {
    let all = ($objects | each {|o| $o.symbols | insert file $o.file } | flatten)
    let once_objects = ($all | get name | uniq --count | where count == 1 | get value | wrap name)
    let once_elf = ($elf_symbols | get name | uniq --count | where count == 1 | get value | wrap name)
    let anchors = ($all | join $once_objects name | join $once_elf name | join ($elf_symbols | select name value | rename name at) name)
    $objects | each {|o|
        $o.sections | where {|s| $s.name in $data_sections and $s.size > 0 } | each {|s|
            let anchor = ($anchors | where {|a| $a.file == $o.file and $a.section == $s.name } | get -o 0)
            if $anchor == null { error make {msg: $"($o.file).o's ($s.name) has no symbol of a name its own to place it by"} }
            let start = ($anchor.at - $anchor.value)
            { file: $o.file, section: $s.name, start: $start, end: ($start + $s.size) }
        }
    } | flatten
}

# Each function's file, in the functions' order: the one object defining a
# code symbol of its name, else, of those defining one, the file of the
# function before it, the link laying each object's code whole
def function-files [objects: list<any>, funcs: list<any>]: nothing -> list<string> {
    let code = ($objects | each {|o| $o.symbols | where {|s| $s.section in $code_sections } | each {|s| { name: $s.name, file: $o.file } } } | flatten)
    let owners = ($code | group-by name)
    mut current = ""
    mut files = []
    for f in $funcs {
        let c = ($owners | get -o $f.name | default [] | each {|r| $r.file } | uniq)
        let file = (if ($c | length) == 1 { $c | first } else if $current in $c { $current } else if ($c | is-empty) { "" } else { $c | first })
        $current = $file
        $files = ($files | append $file)
    }
    $files
}

# The range holding an address, or null
def placed [places: table, address: int] {
    $places | where {|p| $p.start <= $address and $address < $p.end } | get -o 0
}

# The ELF's functions in address order: each a symbol's block of objdump
# -d, its name, its start, and its instructions
def functions-of [prefix: string, elf: path] {
    ^$"($prefix)objdump" -d $elf | complete | get stdout | split row "\n\n"
    | where {|b| $b =~ '^[0-9a-f]+ <[^>]+>:' }
    | each {|b|
        let ls = ($b | lines)
        let head = ($ls | first | parse --regex '^(?P<addr>[0-9a-f]+) <(?P<name>[^>]+)>:$' | first)
        let instrs = ($ls | skip 1 | parse --regex '^\s+(?P<addr>[0-9a-f]+):\t[0-9a-f ]+\t(?P<op>\S+)\s*(?P<args>.*)$' | each {|i| { addr: ($i.addr | into int --radix 16), op: $i.op, args: $i.args } })
        { name: $head.name, start: ($head.addr | into int --radix 16), instrs: $instrs }
    }
    | sort-by start
}

# The index of the last value at or below an address in a sorted list,
# -1 when every value lies past it
def index-at [values: list<int>, address: int]: nothing -> int {
    if ($values | is-empty) or $address < ($values | first) { return (-1) }
    mut lo = 0
    mut hi = (($values | length) - 1)
    while $lo < $hi {
        let mid = (($lo + $hi + 1) // 2)
        if ($values | get $mid) <= $address { $lo = $mid } else { $hi = ($mid - 1) }
    }
    $lo
}

# The address an operand list names before its symbol (`80000820
# <irq_serve>`), or the one its annotation names (`# 80049468
# <sound_base>`), or null
def operand-address [args: string] {
    let p = ($args | parse --regex '(?:^|,)(?P<a>[0-9a-f]+) <[^>]+>$')
    if ($p | is-empty) { null } else { $p.0.a | into int --radix 16 }
}
def annotated-address [args: string] {
    let p = ($args | parse --regex '# (?P<a>[0-9a-f]+) <[^>]+>$')
    if ($p | is-empty) { null } else { $p.0.a | into int --radix 16 }
}

# The register a jalr or jr transfers through
def jump-register [op: string, args: string]: nothing -> string {
    let first = ($args | split row "#" | first | str trim | split row "," | first | str trim)
    if $op == "jr" { return $first }
    let parts = ($args | split row "#" | first | str trim | split row ",")
    if ($parts | length) == 1 {
        let m = ($first | parse --regex '\((?P<r>\w+)\)$')
        if ($m | is-empty) { $first } else { $m.0.r }
    } else {
        let second = ($parts | get 1 | str trim)
        let m = ($second | parse --regex '\((?P<r>\w+)\)$')
        if ($m | is-empty) { $second } else { $m.0.r }
    }
}

# An instruction's transfer, with the one before it: a kind and a target,
# or null for none. A jalr or jr is a direct call or jump only right after
# the auipc of the register it goes through, as the call and tail pseudos
# emit it; any other is indirect.
def transfer-of [i: record, before: any] {
    if $i.op in [ret sret mret] { return { kind: end, to: null } }
    if $i.op == "j" { return { kind: jump, to: (operand-address $i.args) } }
    if $i.op == "jal" { return { kind: call, to: (operand-address $i.args) } }
    if $i.op in $branches { return { kind: branch, to: (operand-address $i.args) } }
    if $i.op in [jr jalr] {
        let reg = (jump-register $i.op $i.args)
        let paired = ($before != null and $before.op == "auipc" and ($before.args | split row "," | first | str trim) == $reg)
        let to = (annotated-address $i.args)
        if $paired and $to != null { return { kind: (if $i.op == "jr" { "jump" } else { "call" }), to: $to } }
        return { kind: indirect, to: null }
    }
    null
}

# The step that reached a function, for a path
def step-text [funcs: list<any>, seen: record, k: int]: nothing -> string {
    let p = ($seen | get ($k | into string))
    let name = ($funcs | get $k | get name)
    if $p.from == null { return $name }
    let from = ($funcs | get $p.from)
    $"($name) \(($p.how) at ($from.name)+(hex ($p.at - $from.start))\)"
}

# The path from an entry to a function, each step how it was reached
def path-to [funcs: list<any>, seen: record, i: int]: nothing -> string {
    mut steps = []
    mut k = $i
    loop {
        $steps = ($steps | prepend (step-text $funcs $seen $k))
        let p = ($seen | get ($k | into string))
        if $p.from == null { break }
        $k = $p.from
    }
    $steps | str join " -> "
}

# The check over one kernel: the class read off its code and its table,
# every function its graph reaches from the entries, the drain's cut, the
# references permitted, and every violation with its path
def owners-check [elf: path, inc: string] {
    let prefix = (prefix-of $elf)
    let elf_symbols = (symbols-of $prefix $elf)
    let objects = (objects-of $prefix $elf)
    let places = (placement $objects $elf_symbols)
    let blocks = (functions-of $prefix $elf)
    let files = (function-files $objects $blocks)
    let funcs = ($blocks | zip $files | each {|z| $z.0 | insert file $z.1 })
    let starts = ($funcs | get start)
    let data_symbols = ($elf_symbols | where {|s| $s.section in $data_sections } | sort-by value)
    let data_values = ($data_symbols | get value)
    let index_of = {|n: string| $funcs | enumerate | where {|e| $e.item.name == $n } | get index }
    mut model = []

    # the class: the calls the admitting routine compares a7 with, against
    # jab.inc's numbers for the worker calls
    let class_at = (do $index_of $class_site)
    let class = (if ($class_at | length) == 1 {
        $funcs | get ($class_at | first) | get instrs | where op == "li" | each {|i| $i.args | split row "," | last | str trim | into int } | sort
    } else { [] })
    let named = ($worker_calls | each {|n| $inc | parse --regex ('(?m)^\.set ' + $n + ', (?P<v>\d+)') | get -o 0.v | default "-1" | into int } | sort)
    if $class != $named { $model = ($model | append { kind: model, function: $class_site, symbol: "", offset: 0, detail: $"its calls ($class | str join ' ') against jab.inc's worker calls ($named | str join ' ')", path: $class_site }) }

    # the dispatch table's entries for the class, read from the ELF's bytes
    let table = ($elf_symbols | where name == $dispatch_table)
    let rodata = (sections-of $prefix $elf | where name == ".rodata" | get -o 0)
    let bytes = (open --raw $elf | into binary)
    let handler_at = (if ($table | length) == 1 and $rodata != null {
        $class | each {|n|
            let at = (($table | first | get value) + 8 * $n)
            let off = ($rodata.off + $at - $rodata.vma)
            let target = ($bytes | bytes at $off..<($off + 8) | into int --endian little)
            $funcs | enumerate | where {|e| $e.item.start == $target } | get -o 0.index
        }
    } else { [] })
    if ($handler_at | is-empty) or ($handler_at | any {|h| $h == null }) { $model = ($model | append { kind: model, function: $dispatch_table, symbol: "", offset: 0, detail: "the class's handlers not read from the table", path: $dispatch_table }) }
    let handlers = ($handler_at | where {|h| $h != null })

    # the graph, from the entries and the class's handlers
    mut seen = {}
    mut queue = []
    for n in $entries {
        let at = (do $index_of $n)
        if ($at | length) != 1 { $model = ($model | append { kind: model, function: $n, symbol: "", offset: 0, detail: $"the entry is ($at | length) functions, not one", path: $n }); continue }
        let k = ($at | first)
        $seen = ($seen | upsert ($k | into string) { from: null, at: 0, how: entry })
        $queue = ($queue | append $k)
    }
    for k in $handlers {
        if not (($k | into string) in ($seen | columns)) {
            $seen = ($seen | upsert ($k | into string) { from: null, at: 0, how: entry })
            $queue = ($queue | append $k)
        }
    }
    mut violations = []
    mut cuts = []
    mut permitted = []
    mut used = []
    while not ($queue | is-empty) {
        let i = ($queue | first)
        $queue = ($queue | skip 1)
        let f = ($funcs | get $i)
        if $f.file in $forbidden_files {
            $violations = ($violations | append { kind: routine, function: $f.name, symbol: "", offset: 0, detail: $"a routine of ($f.file).S", path: (path-to $funcs $seen $i) })
            continue
        }
        mut before: any = null
        for ins in $f.instrs {
            let t = (transfer-of $ins $before)
            $before = $ins
            if $t != null {
                if $t.kind == "end" { continue }
                if $t.kind == "indirect" {
                    if $f.name == $dispatch_site {
                        for h in $handlers {
                            if not (($h | into string) in ($seen | columns)) {
                                $seen = ($seen | upsert ($h | into string) { from: $i, at: $ins.addr, how: dispatch })
                                $queue = ($queue | append $h)
                            }
                        }
                    } else {
                        $violations = ($violations | append { kind: indirect, function: $f.name, symbol: "", offset: ($ins.addr - $f.start), detail: $"($ins.op) ($ins.args), no listed dispatch site", path: (path-to $funcs $seen $i) })
                    }
                    continue
                }
                if $t.to == null { continue }
                let j = (index-at $starts $t.to)
                if $j < 0 or $j == $i { continue }
                if $f.name == $drain and ($funcs | get $j | get name) == $service {
                    $cuts = ($cuts | append ($ins.addr - $f.start))
                    continue
                }
                if not (($j | into string) in ($seen | columns)) {
                    $seen = ($seen | upsert ($j | into string) { from: $i, at: $ins.addr, how: $t.kind })
                    $queue = ($queue | append $j)
                }
                continue
            }
            let d = (annotated-address $ins.args)
            if $d == null { continue }
            let p = (placed $places $d)
            if $p == null or $p.section not-in $data_sections or $p.file not-in $forbidden_files { continue }
            let s = (index-at $data_values $d)
            let sym = (if $s < 0 { "" } else { $data_symbols | get $s | get name })
            let key = $"($f.name) ($sym)"
            let listed = ($allowlist | where {|a| $a.function == $f.name and $a.symbol == $sym } | is-not-empty)
            if $listed and $key not-in $used {
                $used = ($used | append $key)
                $permitted = ($permitted | append { function: $f.name, symbol: $sym, offset: ($ins.addr - $f.start) })
            } else {
                $violations = ($violations | append { kind: data, function: $f.name, symbol: $sym, offset: ($ins.addr - $f.start), detail: $"a reference into ($p.file).S's ($p.section)(if $listed { ', past its allowed one' } else { '' })", path: (path-to $funcs $seen $i) })
            }
        }
        let kept = ($f.instrs | where {|x| $x.op not-in $padding })
        let tail = (if ($kept | is-empty) { null } else { $kept | last })
        if $tail != null and $tail.op not-in $ends and ($i + 1) < ($funcs | length) {
            let j = ($i + 1)
            if not (($j | into string) in ($seen | columns)) {
                $seen = ($seen | upsert ($j | into string) { from: $i, at: $tail.addr, how: "falls into" })
                $queue = ($queue | append $j)
            }
        }
    }
    if ($cuts | length) != $drain_calls { $model = ($model | append { kind: model, function: $drain, symbol: "", offset: 0, detail: $"its calls into ($service): ($cuts | length), the model's ($drain_calls)", path: $drain }) }
    {
        entries: $entries
        class: $class
        handlers: ($handlers | each {|h| $funcs | get $h | get name })
        reached: ($seen | columns | length)
        cuts: $cuts
        permitted: $permitted
        violations: ($model ++ $violations)
    }
}
