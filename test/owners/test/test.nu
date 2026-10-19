# owners' integration test (DriverInventory): every driver global is hart
# 0's, held on the built code. Every kernel source file is classified, a
# file no class names refused, and the drivers, the frame clock, the
# decoders, and hart 0's storage are forbidden to a worker's paths,
# routines and data alike. From every entry a worker's hart takes in the
# kernel, the trap vector's worker path, each call the worker class admits,
# and the drain, no transfer reaches a forbidden routine and no instruction
# refers to forbidden data but the allowlist's one instruction a row, each
# under its condition. The model the walk rests on is checked as bounded
# patterns, any other form refused by name: the hart split and the approach
# it protects, the admissions, the dispatch, and the drain's cut, a worker's
# claim holding the wake alone, which a debug kernel holds as it runs. The
# graph is read off the debug and release kernels' ELFs through the
# toolchain's objdump, each function a symbol's range and each address's
# file from where the objects beside the ELF were laid, so macros and tail
# transfers count as the assembler emitted them. A transfer through a
# register is direct only as the call and tail pseudos emit it, the auipc
# of that register just before; any other is indirect, and a transfer
# whose target does not parse and a function whose file the link order
# does not resolve are refused. The data scan covers the pc-relative
# addresses objdump annotates; an address held in a register and
# dereferenced is outside it, carried by the hart-0-only calls. Then the
# program runs, its worker woken asleep in its wait, and no hart claims or
# enables a device identity or disables its wake.
use ../../../nu/mod/target
use ../../../nu/mod/walk
use ../../../nu/mod/launch
use std/assert

# Every kernel source file by its class (DecoderInventory): the drivers and
# the frame clock, the decoders, and hart 0's storage, written by hart 0's
# calls or at boot, forbidden to a worker's paths, routines and data; the
# drain, the worker machinery, and the shared lock reachable, their state
# their own; and the files the objects hold to no mutable storage
const classes = [
    [class, files];
    [driver, [display keyboard pad sound synth smf soundfont block romfs serial random pci timer]]
    [decoder, [png deflate gz tar sha3 xxh3 sprite]]
    [hart0, [start page ram owners]]
    [drain, [aia]]
    [machinery, [workers harts]]
    [lock, [uart]]
    [stateless, [boot dtb font kernel trap virtio virtio_pci]]
]
const forbidden_classes = [driver decoder hart0]
const storage_sections = [".data" ".bss" ".sdata" ".sbss"]

# The references into forbidden data a worker's path makes, one
# instruction a row, each bound to its condition: guarded, inside a region
# a test of HART_ID opens; masked, after the drain's mask on every path
const allowlist = [
    [function, symbol, kind, reason];
    [irq_drain, sound_base, masked, "the sound's identity, for the sound-first order: on a worker's hart its claim is the wake alone, so it decides nothing"]
    [sys_worker_wait, sound_live, guarded, "hart 0's branch, past its test of HART_ID: hart 0's external enable kept while the stream is live; a worker never runs it"]
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

# The hart split's vector, hart 0's refusal of a bad call, the admissions'
# refusal, and where it returns
const vector = "trap_vector"
const bad_call = "bad_syscall"
const denied = "sys_denied"
const denied_return = "trap_return"

const code_sections = [".text" ".text.boot"]
const data_sections = [".rodata" ".data" ".bss" ".sdata" ".sbss"]
const branches = [beq bne blt bge bltu bgeu beqz bnez blez bgez bltz bgtz bgt ble bgtu bleu]
const ends = [j jr ret sret mret]
const padding = [nop unimp]

# The instructions that write no register of their first operand
const nonwriting = [j jr ret sret mret fence wfi pause sb sh sw sd fsw fsd csrw csrs csrc ecall ebreak nop]

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    assert ($set | str contains "DEBUG") $"the run's checks are a debug kernel's, and the build is ($set)"
    let ws = ($env.FILE_PWD | path join ".." ".." ".." | path expand)
    let kernel_dir = ($ws | path join (open ($ws | path join "workspace.jab.toml") | get kernel))
    let tool = ($ws | path join "nu" "bin" "do.nu")
    let values = (model-values $ws $kernel_dir)

    # the clean kernels: the debug kernel the test runs on, and the release
    # kernel, built here as purity builds it
    ^nu $tool build --kernel $kernel_dir
    let release = (target root $ws | path join "release" "kernel" "jab.elf")
    assert ($release | path exists) $"the release kernel was built at ($release)"
    let debug_reading = (owners-check $kernel $values)
    assert equal $debug_reading.violations [] $"owners: the debug kernel's worker paths reach no driver: (violation-text $debug_reading.violations)"
    let release_reading = (owners-check $release $values)
    assert equal $release_reading.violations [] $"owners: the release kernel's worker paths reach no driver: (violation-text $release_reading.violations)"

    # the run: the worker woken asleep in its wait, every drain off hart 0
    # claiming the wake alone, every secondary's file enabling it alone
    let run = (launch --kernel $kernel --image $image --out ($out | path join "run") --set $set --seconds 20)
    assert (not ($run.serial | str contains " claimed a device identity ")) $"owners: no hart but 0 claimed a device identity: ($run.serial)"
    assert (not ($run.serial | str contains " enabled a device identity ")) $"owners: no secondary's file enabled a device identity: ($run.serial)"
    assert (not ($run.serial | str contains " disabled the wake identity ")) $"owners: no secondary's file disabled its wake: ($run.serial)"
    assert equal $run.status 0 $"owners: exit status, with the UART: ($run.serial)"
    assert equal $run.serial "owners: woken asleep, then done\n" "owners: the worker slept in its wait, was woken there, and finished"

    for reading in [[name, r]; [debug, $debug_reading] [release, $release_reading]] {
        let r = $reading.r
        print $"owners: the ($reading.name) kernel: ($r.reached) functions reached from ($r.entries | str join ', ') and the calls ($r.class | str join ' ') through ($dispatch_site), ($r.handlers | str join ', ')"
        print $"owners:   the hart split at ($vector)+(hex $r.split.test), its approach entered by its own fall-through alone and ($dispatch_site) by ($class_site)'s ($r.class | length) admissions alone, no address of either formed in the code or held in the data; the dispatch ($dispatch_table) indexed by a7 times 8"
        print $"owners:   the drain's mask at ($drain)+(hex $r.cut.mask) on every path to its calls into ($service) at ($r.cut.cuts | each {|c| $'($drain)+(hex $c)' } | str join ' and '), each reached from the mask only through an xor of s0 \(($r.cut.forms | str join ', ')\), the only writes of s0 there"
        print $"owners:   permitted ($r.permitted | each {|p| $'($p.symbol) at ($p.function)+(hex $p.offset), ($p.kind)' } | str join '; ')"
    }
    print $"owners: the inventory: ($classes | each {|c| $'($c.class) ($c.files | length)' } | str join ', '); the ($forbidden_classes | str join ', ') classes forbidden to a worker's paths"
    print "owners: the data scan covers the pc-relative addresses objdump annotates, la and lla and the loads and stores through them; an address held in a register and dereferenced is outside it, carried by the hart-0-only calls"
    print "owners: the drain's cut assumes a worker's claim holds the wake alone: a secondary's file enables the wake alone (aia_file_open) and every device source targets hart 0's file (irq_enable); the debug kernel's claim and configuration checks hold it as it runs"
    print "owners: ok"
}

# The numbers the model reads from the includes: HART_ID's offset in a
# hart's record, the wake's identity, JAB_DENIED, and the worker calls
def model-values [ws: path, kernel_dir: path]: nothing -> record {
    let jab = (open --raw ($ws | path join "sdk" "src" "jab.inc") | decode)
    let hart = (open --raw ($kernel_dir | path join "src" "include" "hart.inc") | decode)
    let aia = (open --raw ($kernel_dir | path join "src" "include" "aia.inc") | decode)
    {
        hart_id: (set-value $hart HART_ID)
        wake: (set-value $aia AIA_WAKE)
        denied: (set-value $jab JAB_DENIED)
        calls: ($worker_calls | each {|n| set-value $jab $n } | sort)
    }
}

# A `.set` constant's value where an include writes it as a literal
def set-value [text: string, name: string]: nothing -> int {
    let v = ($text | parse --regex ('(?m)^\.set ' + $name + ', (?P<v>-?\d+)\b') | get -o 0.v)
    if $v == null { error make {msg: $"no literal .set of ($name)"} }
    $v | into int
}

# Violations as one line each, their paths with them
def violation-text [vs: list<any>]: nothing -> string {
    if ($vs | is-empty) { return "none" }
    $vs | each {|v|
        if $v.kind == "model" { $"model: ($v.detail)" } else {
            $"($v.kind) ($v.function)(if $v.symbol == '' { '' } else { ' ' + $v.symbol }) at (hex $v.offset): ($v.detail); path ($v.path)"
        }
    } | str join "; "
}

# A model problem as a violation row
def model-row [detail: string]: nothing -> record {
    { kind: model, function: "", symbol: "", offset: 0, detail: $detail, path: "" }
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

# A file's class, or none
def class-of [file: string]: nothing -> string {
    $classes | where {|c| $file in $c.files } | get -o 0.class | default ""
}

# The inventory against the objects: every object's file in one class,
# every classified file linked, and the stateless holding no mutable
# storage
def inventory-problems [objects: list<any>]: nothing -> list<string> {
    let named = ($classes | each {|c| $c.files } | flatten)
    let linked = ($objects | get file)
    let twice = ($named | uniq --count | where count > 1 | get value | each {|f| $"($f).S is in more than one class" })
    let unclassified = ($linked | where {|f| $f not-in $named } | each {|f| $"($f).S is in no class, and a new file is placed on purpose" })
    let unlinked = ($named | where {|f| $f not-in $linked } | each {|f| $"($f).S is classified and not linked" })
    let stateless = ($classes | where class == "stateless" | get 0.files)
    let holding = ($objects | where {|o| $o.file in $stateless } | each {|o|
        let held = ($o.sections | where {|s| $s.name in $storage_sections and $s.size > 0 })
        if ($held | is-empty) { null } else { $"($o.file).S is classed stateless and holds ($held | each {|s| $'($s.size) bytes of ($s.name)' } | str join ', ')" }
    } | compact)
    $twice ++ $unclassified ++ $unlinked ++ $holding
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
# function before it, the link laying each object's code whole; a name no
# object defines, or several the order does not decide, a problem
def function-files [objects: list<any>, funcs: list<any>]: nothing -> list<any> {
    let code = ($objects | each {|o| $o.symbols | where {|s| $s.section in $code_sections } | each {|s| { name: $s.name, file: $o.file } } } | flatten)
    let owners = ($code | group-by name)
    mut current = ""
    mut files = []
    for f in $funcs {
        let c = ($owners | get -o $f.name | default [] | each {|r| $r.file } | uniq)
        let row = (if ($c | length) == 1 {
            { name: $f.name, file: ($c | first), problem: null }
        } else if $current in $c {
            { name: $f.name, file: $current, problem: null }
        } else if ($c | is-empty) {
            { name: $f.name, file: "", problem: "no object defines it" }
        } else {
            { name: $f.name, file: "", problem: $"the link order does not decide among ($c | str join ', ')" }
        })
        $current = $row.file
        $files = ($files | append $row)
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

# The 64-bit words of the kernel's initialized data on their own
# boundaries, for any code address one holds
def data-words [sections: table, bytes: binary]: nothing -> list<int> {
    $sections | where {|s| $s.name in [".rodata" ".data"] and $s.size >= 8 } | each {|s|
        let first = (($s.vma + 7) // 8 * 8)
        let count = (($s.size - ($first - $s.vma)) // 8)
        if $count <= 0 { [] } else {
            let off = ($s.off + $first - $s.vma)
            $bytes | bytes at $off..<($off + $count * 8) | chunks 8 | each {|w| $w | into int --endian little --signed }
        }
    } | flatten
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
    if ($p | is-empty) { return null }
    # sixteen digits with the top bit set annotate a negative immediate,
    # never an address, and lie past what `into int` takes
    if ($p.0.a | str length) == 16 and ($p.0.a | str substring 0..0) in ["8" "9" "a" "b" "c" "d" "e" "f"] { return null }
    $p.0.a | into int --radix 16
}

# An instruction's operands, before any comment
def operands [args: string]: nothing -> list<string> {
    $args | split row "#" | first | str trim | split row "," | each {|o| $o | str trim } | where {|o| $o != "" }
}

# Whether an instruction is the op with these operands, "*" any one
def shaped [i: record, op: string, want: list<string>]: nothing -> bool {
    let have = (operands $i.args)
    $i.op == $op and ($have | length) == ($want | length) and ($have | zip $want | all {|z| $z.1 == "*" or $z.0 == $z.1 })
}

# Whether an instruction loads the hart's id from its record
def is-hart-load [i: record, hart_id: int]: nothing -> bool {
    let o = (operands $i.args)
    $i.op == "ld" and ($o | length) == 2 and $o.1 == $"($hart_id)\(tp\)"
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

# Every transfer in the kernel, each with its function, its address and
# offset, its kind, and its target
def transfers-of [funcs: list<any>]: nothing -> list<any> {
    $funcs | each {|f|
        let befores = ([null] ++ ($f.instrs | drop 1))
        $f.instrs | zip $befores | each {|z|
            let t = (transfer-of $z.0 $z.1)
            if $t == null or $t.kind == "end" { null } else {
                { function: $f.name, at: $z.0.addr, offset: ($z.0.addr - $f.start), kind: $t.kind, to: $t.to, op: $z.0.op, args: $z.0.args }
            }
        } | compact
    } | flatten
}

# The hart split (HartSplit): the vector's test of HART_ID branching to the
# admissions, the approach its fall-through runs, hart 0's bounds check,
# into the dispatch; the admissions (Admissions) and the dispatch (Dispatch)
# each exactly its pattern; and nothing entering the approach but the
# admissions' branches at the dispatch's first instruction, nothing
# entering the admissions but the test, and no address of either formed in
# the code or held in the data
def hart-split [funcs: list<any>, direct: list<any>, words: list<int>, elf_symbols: table, values: record]: nothing -> record {
    let names = [$vector $class_site $dispatch_site $denied $bad_call $denied_return]
    let found = ($names | each {|n| $funcs | enumerate | where {|e| $e.item.name == $n } })
    let lone = ($names | zip $found | where {|z| ($z.1 | length) != 1 } | each {|z| $"($z.0) is ($z.1 | length) functions, not one" })
    if not ($lone | is-empty) { return { problems: $lone, dispatch: false, admitted: [], test: 0 } }
    let at = ($found | each {|e| $e.0.index })
    let v = ($found.0.0.item)
    let w = ($found.1.0.item)
    let a = ($found.2.0.item)
    let d = ($found.3.0.item)
    let bad = ($found.4.0.item.start)
    let back = ($found.5.0.item.start)
    let vi = $v.instrs
    mut problems = []

    # the test of HART_ID branching to the admissions, then the approach to
    # the vector's end, laid out before the dispatch, the admissions, and
    # their refusal in that order
    let tests = ($vi | enumerate | where {|e|
        let nx = ($vi | get -o ($e.index + 1))
        (is-hart-load $e.item $values.hart_id) and $nx != null and (shaped $nx "bnez" [(operands $e.item.args | first) "*"]) and (operand-address $nx.args) == $w.start
    } | get index)
    if ($tests | length) != 1 { return { problems: [$"($vector) holds ($tests | length) tests of HART_ID branching to ($class_site), not one"], dispatch: false, admitted: [], test: 0 } }
    let k = ($tests | first)
    let approach = ($vi | skip ($k + 1))
    let test = ($approach | first)
    let shape_ok = (($approach | length) == 4
        and (shaped ($approach | get 1) "beqz" ["a7" "*"]) and (operand-address ($approach | get 1).args) == $bad
        and (shaped ($approach | get 2) "li" ["t0" "*"])
        and (shaped ($approach | get 3) "bltu" ["t0" "a7" "*"]) and (operand-address ($approach | get 3).args) == $bad)
    if not $shape_ok { $problems = ($problems | append $"($vector)'s approach past its test is not hart 0's bounds check alone, beqz a7, li t0, bltu t0, a7 to ($bad_call), at the vector's end") }
    if $at != [($at.0) ($at.0 + 2) ($at.0 + 1) ($at.0 + 3) ($at.4) ($at.5)] { $problems = ($problems | append $"($vector), ($dispatch_site), ($class_site), and ($denied) are not laid out one after another") }

    # the dispatch: the table's address, a7 scaled by 8, the entry loaded,
    # the jump through it
    let ai = $a.instrs
    let table_at = ($elf_symbols | where name == $dispatch_table | get -o 0.value)
    let dispatch = (($ai | length) == 6
        and (shaped ($ai | get 0) "auipc" ["t0" "*"])
        and (shaped ($ai | get 1) "addi" ["t0" "t0" "*"]) and $table_at != null and (annotated-address ($ai | get 1).args) == $table_at
        and (shaped ($ai | get 2) "slli" ["t1" "a7" "0x3"])
        and (shaped ($ai | get 3) "add" ["t0" "t0" "t1"])
        and (shaped ($ai | get 4) "ld" ["t0" "0(t0)"])
        and (shaped ($ai | get 5) "jr" ["t0"]))
    if not $dispatch { $problems = ($problems | append $"($dispatch_site) is not the dispatch's pattern: ($dispatch_table)'s address, a7 shifted by 3, the entry loaded, the jump through it") }

    # the admissions: pairs of the call loaded and compared with a7 to the
    # dispatch, then the refusal and nothing else
    let wi = $w.instrs
    let pairs = ($wi | chunks 2)
    let admitted = ($pairs | each {|p|
        if ($p | length) == 2 and (shaped ($p | get 0) "li" ["t0" "*"]) and (shaped ($p | get 1) "beq" ["a7" "t0" "*"]) and (operand-address ($p | get 1).args) == $a.start {
            try { operands ($p | get 0).args | get 1 | into int } catch { null }
        } else { null }
    })
    if ($admitted | any {|x| $x == null }) { $problems = ($problems | append $"($class_site) is not pairs of li t0 and beq a7, t0 to ($dispatch_site) alone") }
    let calls = ($admitted | compact | sort)
    if $calls != $values.calls { $problems = ($problems | append $"($class_site) admits ($calls | str join ' '), where jab.inc's worker calls are ($values.calls | str join ' ')") }
    let di = $d.instrs
    let refusal = (($di | length) == 3
        and (shaped ($di | get 0) "li" ["t0" $"($values.denied)"])
        and (shaped ($di | get 1) "sd" ["t0" "80(sp)"])
        and (shaped ($di | get 2) "j" ["*"]) and (operand-address ($di | get 2).args) == $back)
    if not $refusal { $problems = ($problems | append $"($denied) is not JAB_DENIED stored to a0's slot and the jump to ($denied_return) alone") }

    # nothing enters the approach but at the dispatch's first instruction
    # from an admission, nothing the admissions but the test at their first
    let protected = (($approach | each {|i| $i.addr }) ++ ($ai | skip 1 | each {|i| $i.addr }))
    let head = (if ($ai | is-empty) { -1 } else { $ai | first | get addr })
    let admissions = ($wi | where op == "beq" | each {|i| $i.addr })
    let held = ($wi | each {|i| $i.addr })
    let entering = ($direct | each {|t|
        if $t.to in $protected {
            $"($t.function)+(hex $t.offset) enters the hart split's approach at (hex $t.to)"
        } else if $t.to == $head and $t.at not-in $admissions {
            $"($t.function)+(hex $t.offset) reaches ($dispatch_site) and is no admission"
        } else if $t.to in $held and not ($t.at == $test.addr and $t.to == $w.start) {
            $"($t.function)+(hex $t.offset) enters ($class_site) at (hex $t.to)"
        }
    } | compact)
    let watched = ($protected ++ [$head] ++ $held)
    let formed = ($funcs | each {|f| $f.instrs | each {|i|
        let x = (annotated-address $i.args)
        if $x != null and $x in $watched { $"($f.name)+(hex ($i.addr - $f.start)) forms the address (hex $x), inside the hart split" }
    } | compact } | flatten)
    let stored = ($words | where {|x| $x in $watched } | each {|x| $"the data hold the address (hex $x), inside the hart split" })
    { problems: ($problems ++ $entering ++ $formed ++ $stored), dispatch: $dispatch, admitted: $calls, test: ($test.addr - $v.start) }
}

# The instructions a function's graph reaches from its starts, never
# through the blocked
def reach [succ: list<any>, starts: list<int>, blocked: list<int>]: nothing -> list<int> {
    mut seen = []
    mut queue = ($starts | where {|s| $s not-in $blocked })
    while not ($queue | is-empty) {
        let k = ($queue | first)
        $queue = ($queue | skip 1)
        if $k in $seen { continue }
        $seen = ($seen | append $k)
        for j in ($succ | get $k) {
            if $j not-in $blocked and $j not-in $seen { $queue = ($queue | append $j) }
        }
    }
    $seen
}

# Each instruction's predecessors in a function's graph
def preds-of [succ: list<any>]: nothing -> list<any> {
    let n = ($succ | length)
    0..<$n | each {|k| $succ | enumerate | where {|e| $k in $e.item } | get index }
}

# The bounded form an xor of s0 closes: tested, the and of s0 with the bit
# its branch tests on zero; lowest, the lowest set bit counted from s0 past
# its branch on zero; else none
def form-at [ins: list<any>, x: int]: nothing -> record {
    let xo = (operands ($ins | get $x).args)
    let m = ($xo | get -o 2 | default "")
    if $x >= 2 and $m not-in ["" "s0"] {
        let a = ($ins | get ($x - 2))
        let b = ($ins | get ($x - 1))
        let ao = (operands $a.args)
        let bo = (operands $b.args)
        if $a.op == "and" and ($ao | length) == 3 and $ao.1 == "s0" and $ao.2 == $m and $ao.0 not-in ["s0" $m] and $b.op == "beqz" and ($bo | length) == 2 and $bo.0 == $ao.0 {
            return { at: $x, kind: tested, head: ($x - 2), body: [($x - 1) $x] }
        }
    }
    if $x >= 4 and $m not-in ["" "s0"] {
        let c = (operands ($ins | get ($x - 3)).args)
        if (shaped ($ins | get ($x - 4)) "beqz" ["s0" "*"]) and ($ins | get ($x - 3) | get op) == "ctz" and ($c | length) == 2 and $c.1 == "s0" and $c.0 not-in ["s0" $m] and (shaped ($ins | get ($x - 2)) "li" [$m "1"]) and (shaped ($ins | get ($x - 1)) "sll" [$m $m $c.0]) {
            return { at: $x, kind: lowest, head: ($x - 4), body: [($x - 3) ($x - 2) ($x - 1) $x] }
        }
    }
    { at: $x, kind: null, head: null, body: [] }
}

# The drain's cut (DrainCut): the mask of the wake on every path from the
# drain's entry to each call into its service, nothing entering the drain
# but at its head, and each call reached from the mask only through an xor
# of s0 of one of the two bounded forms, each entered only at its head, the
# forms' xors the only writes of s0 on those paths: a zero claim stays zero
# to each form's test, so on a worker's hart, whose claim is the wake
# alone, the calls are unreached
def drain-cut [funcs: list<any>, transfers: list<any>, direct: list<any>, values: record]: nothing -> record {
    let fs = ($funcs | where name == $drain)
    let ss = ($funcs | where name == $service)
    if ($fs | length) != 1 or ($ss | length) != 1 { return { ok: false, problems: [$"($drain) and ($service) are ($fs | length) and ($ss | length) functions, not one each"], mask: 0, cuts: [], forms: [], dominated: [] } }
    let f = ($fs | first)
    let target = ($ss | first | get start)
    let ins = $f.instrs
    let n = ($ins | length)
    let addrs = ($ins | get addr)
    let befores = ([null] ++ ($ins | drop 1))
    let succ = ($ins | zip $befores | enumerate | each {|e|
        let t = (transfer-of $e.item.0 $e.item.1)
        let next = (if ($e.index + 1) < $n { [($e.index + 1)] } else { [] })
        if $t == null { $next } else if $t.kind == "end" or $t.kind == "indirect" { [] } else if $t.kind == "call" { $next } else {
            let j = (if $t.to == null { null } else { $addrs | enumerate | where item == $t.to | get -o 0.index })
            let jumped = (if $j == null { [] } else { [$j] })
            if $t.kind == "branch" { $next ++ $jumped } else { $jumped }
        }
    })
    mut problems = ($transfers | where {|t| $t.function == $drain and $t.kind == "indirect" } | each {|t| $"($drain)+(hex $t.offset) transfers through a register" })
    $problems = ($problems ++ ($direct | where {|t| $t.function != $drain and $t.to in $addrs and $t.to != $f.start } | each {|t| $"($t.function)+(hex $t.offset) enters ($drain) at (hex $t.to), past its head" }))

    # the mask: the wake's complement loaded, then and-ed into s0
    let notwake = (-1 - (1 bit-shl $values.wake))
    let masks = ($ins | enumerate | skip 1 | where {|e|
        let p = ($ins | get ($e.index - 1))
        let po = (operands $p.args)
        $p.op == "li" and ($po | length) == 2 and (try { ($po.1 | into int) == $notwake } catch { false }) and (shaped $e.item "and" ["s0" "s0" $po.0])
    } | get index)
    if ($masks | length) != 1 { return { ok: false, problems: ($problems | append $"($drain) holds ($masks | length) masks of the wake, not one"), mask: 0, cuts: [], forms: [], dominated: [] } }
    let m = ($masks | first)
    let calls = ($ins | zip $befores | enumerate | where {|e|
        let t = (transfer-of $e.item.0 $e.item.1)
        $t != null and $t.kind == "call" and $t.to == $target
    } | get index)
    if ($calls | length) != $drain_calls { $problems = ($problems | append $"($drain) calls ($service) ($calls | length) times, the model's ($drain_calls)") }

    # the mask on every path from the entry: past it unreached when it is
    # blocked
    let unmasked = (reach $succ [0] [$m])
    for c in $calls {
        if $c in $unmasked { $problems = ($problems | append $"($drain)+(hex (($addrs | get $c) - $f.start)) is reached from the entry past no mask") }
    }

    # the forms, each entered only at its head
    let forms = ($ins | enumerate | where {|e| shaped $e.item "xor" ["s0" "s0" "*"] } | get index | each {|x| form-at $ins $x })
    for x in ($forms | where kind == null) {
        $problems = ($problems | append $"($drain)+(hex (($addrs | get $x.at) - $f.start)) is an xor of s0 of no bounded form")
    }
    let bounded = ($forms | where kind != null)
    for x in $bounded {
        let body = ($x.body | each {|i| $addrs | get $i })
        for t in ($direct | where {|t| $t.to in $body }) {
            $problems = ($problems | append $"($t.function)+(hex $t.offset) enters the ($x.kind) form at (hex ($t.to - $f.start)) past its head")
        }
    }

    # each call reached from the mask only through a form's xor, and s0
    # written on the way by those xors alone
    let xors = ($bounded | each {|x| $x.at })
    let after = ($succ | get $m)
    let unguarded = (reach $succ $after $xors)
    let preds = (preds-of $succ)
    let onward = (reach $succ $after [])
    for c in $calls {
        if $c in $unguarded { $problems = ($problems | append $"($drain)+(hex (($addrs | get $c) - $f.start)) is reached from the mask through no xor of s0") }
        let on = ((reach $preds [$c] []) | where {|i| $i in $onward and $i != $c })
        for i in $on {
            let o = (operands ($ins | get $i).args)
            let op = ($ins | get $i | get op)
            if $op not-in $nonwriting and $op not-in $branches and ($o | get -o 0) == "s0" and $i not-in $xors {
                $problems = ($problems | append $"($drain)+(hex (($addrs | get $i) - $f.start)) writes s0 between the mask and a call")
            }
        }
    }
    let dominated = (0..<$n | each {|i| if $i not-in $unmasked and $i != $m { $addrs | get $i } } | compact)
    { ok: ($problems | is-empty), problems: $problems, mask: (($addrs | get $m) - $f.start), cuts: ($calls | each {|c| ($addrs | get $c) - $f.start }), forms: ($bounded | each {|x| $x.kind }), dominated: $dominated }
}

# The regions a test of HART_ID opens in a function, hart 0's alone: past
# `ld <r>, HART_ID(tp)` and `bnez <r>, L` up to L, each with the transfers
# from outside it into it
def guarded-regions [f: record, direct: list<any>, values: record]: nothing -> list<any> {
    let ins = $f.instrs
    let last = ($ins | last | get addr)
    $ins | enumerate | where {|e| ($e.index + 2) < ($ins | length) and (is-hart-load $e.item $values.hart_id) } | each {|e|
        let b = ($ins | get ($e.index + 1))
        let to = (operand-address $b.args)
        if not (shaped $b "bnez" [(operands $e.item.args | first) "*"]) or $to == null or $to <= $b.addr or $to > $last { null } else {
            let from = ($ins | get ($e.index + 2) | get addr)
            let entered = ($direct | where {|t| $t.to >= $from and $t.to < $to and not ($t.function == $f.name and $t.at >= $from and $t.at < $to) } | each {|t| $"($t.function)+(hex $t.offset)" })
            { from: $from, to: $to, entered: $entered }
        }
    } | compact
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

# The check over one kernel: the inventory, the model's patterns, the class
# read off its code and its table, every function its graph reaches from
# the entries, the drain's cut, the references permitted under their
# conditions, and every violation with its path
def owners-check [elf: path, values: record] {
    let prefix = (prefix-of $elf)
    let elf_symbols = (symbols-of $prefix $elf)
    let objects = (objects-of $prefix $elf)
    let places = (placement $objects $elf_symbols)
    let blocks = (functions-of $prefix $elf)
    let resolved = (function-files $objects $blocks)
    let funcs = ($blocks | zip $resolved | each {|z| $z.0 | insert file $z.1.file })
    let starts = ($funcs | get start)
    let data_symbols = ($elf_symbols | where {|s| $s.section in $data_sections } | sort-by value)
    let data_values = ($data_symbols | get value)
    let sections = (sections-of $prefix $elf)
    let bytes = (open --raw $elf | into binary)
    let transfers = (transfers-of $funcs)
    let direct = ($transfers | where {|t| $t.kind in [branch jump call] and $t.to != null })

    # the model: the inventory, every file and target resolved, the hart
    # split with the admissions and the dispatch, and the drain's cut
    let split = (hart-split $funcs $direct (data-words $sections $bytes) $elf_symbols $values)
    let cut = (drain-cut $funcs $transfers $direct $values)
    let unresolved = ($resolved | where {|r| $r.problem != null } | each {|r| $"($r.name)'s file: ($r.problem)" })
    let unparsed = ($transfers | where {|t| $t.kind in [branch jump call] and $t.to == null } | each {|t| $"($t.function)+(hex $t.offset) ($t.op) ($t.args): its target does not parse" })
    mut model = ((inventory-problems $objects) ++ $unresolved ++ $unparsed ++ $split.problems ++ $cut.problems | each {|p| model-row $p })

    # the dispatch table's entries for the admitted calls, read from the
    # ELF's bytes
    let table = ($elf_symbols | where name == $dispatch_table)
    let rodata = ($sections | where name == ".rodata" | get -o 0)
    let handler_at = (if $split.dispatch and ($table | length) == 1 and $rodata != null {
        $split.admitted | each {|n|
            let at = (($table | first | get value) + 8 * $n)
            let off = ($rodata.off + $at - $rodata.vma)
            let target = ($bytes | bytes at $off..<($off + 8) | into int --endian little)
            $funcs | enumerate | where {|e| $e.item.start == $target } | get -o 0.index
        }
    } else { [] })
    if ($handler_at | is-empty) or ($handler_at | any {|h| $h == null }) { $model = ($model | append (model-row "the class's handlers not read from the table")) }
    let handlers = ($handler_at | where {|h| $h != null })

    # the graph, from the entries and the class's handlers
    mut seen = {}
    mut queue = []
    for n in $entries {
        let at = ($funcs | enumerate | where {|e| $e.item.name == $n } | get index)
        if ($at | length) != 1 { $model = ($model | append (model-row $"the entry ($n) is ($at | length) functions, not one")); continue }
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
        let class = (class-of $f.file)
        if $class in $forbidden_classes {
            $violations = ($violations | append { kind: routine, function: $f.name, symbol: "", offset: 0, detail: $"a routine of ($f.file).S, of the ($class) class", path: (path-to $funcs $seen $i) })
            continue
        }
        mut before: any = null
        for ins in $f.instrs {
            let t = (transfer-of $ins $before)
            $before = $ins
            if $t != null {
                if $t.kind == "end" { continue }
                if $t.kind == "indirect" {
                    if $f.name == $dispatch_site and $split.dispatch {
                        for h in $handlers {
                            if not (($h | into string) in ($seen | columns)) {
                                $seen = ($seen | upsert ($h | into string) { from: $i, at: $ins.addr, how: dispatch })
                                $queue = ($queue | append $h)
                            }
                        }
                    } else {
                        $violations = ($violations | append { kind: indirect, function: $f.name, symbol: "", offset: ($ins.addr - $f.start), detail: $"($ins.op) ($ins.args), no checked dispatch site", path: (path-to $funcs $seen $i) })
                    }
                    continue
                }
                if $t.to == null { continue }
                let j = (index-at $starts $t.to)
                if $j < 0 or $j == $i { continue }
                if $cut.ok and $f.name == $drain and ($funcs | get $j | get name) == $service {
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
            if $p == null or $p.section not-in $data_sections or (class-of $p.file) not-in $forbidden_classes { continue }
            let s = (index-at $data_values $d)
            let sym = (if $s < 0 { "" } else { $data_symbols | get $s | get name })
            let key = $"($f.name) ($sym)"
            let row = ($allowlist | where {|a| $a.function == $f.name and $a.symbol == $sym } | get -o 0)
            let held = (if $row == null { false } else if $row.kind == "guarded" {
                guarded-regions $f $direct $values | any {|g| $ins.addr >= $g.from and $ins.addr < $g.to and ($g.entered | is-empty) }
            } else if $row.kind == "masked" {
                $cut.ok and $f.name == $drain and $ins.addr in $cut.dominated
            } else { false })
            if $held and $key not-in $used {
                $used = ($used | append $key)
                $permitted = ($permitted | append { function: $f.name, symbol: $sym, offset: ($ins.addr - $f.start), kind: $row.kind })
            } else {
                let why = (if $row == null { "" } else if not $held { ", past its guard" } else { ", past its allowed one" })
                $violations = ($violations | append { kind: data, function: $f.name, symbol: $sym, offset: ($ins.addr - $f.start), detail: $"a reference into ($p.file).S's ($p.section)($why)", path: (path-to $funcs $seen $i) })
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
    if ($cuts | length) != $drain_calls { $model = ($model | append (model-row $"($drain)'s calls into ($service) cut: ($cuts | length), the model's ($drain_calls)")) }
    for a in ($allowlist | where {|a| $"($a.function) ($a.symbol)" not-in $used }) {
        $model = ($model | append (model-row $"the allowlist's ($a.symbol) in ($a.function) names no reference the walk met under its condition"))
    }
    {
        entries: $entries
        class: $split.admitted
        handlers: ($handlers | each {|h| $funcs | get $h | get name })
        reached: ($seen | columns | length)
        split: $split
        cut: $cut
        cuts: $cuts
        permitted: $permitted
        violations: ($model ++ $violations)
    }
}
