use ./elf.nu [data_sections data-words function-files functions-of index-at objects-of placed placement prefix-of sections-of symbols-of]
use ./instructions.nu [annotated-address hex transfer-of transfers-of]
use ./inventory.nu [class-of forbidden_classes inventory-problems]
use ./model.nu [dispatch_site dispatch_table drain drain_calls drain-cut guarded-regions hart-split service]

# The references into forbidden data a worker's path makes, one
# instruction a row, each bound to its condition: guarded, inside a region
# a test of HART_ID opens; masked, after the drain's mask on every path
const allowlist = [
    [function, symbol, kind, reason];
    [irq_drain, sound_base, masked, "the sound's identity, for the sound-first order: on a worker's hart its claim is the wake alone, so it decides nothing"]
    [sys_worker_wait, sound_live, guarded, "hart 0's branch, past its test of HART_ID: hart 0's external enable kept while the stream is live; a worker never runs it"]
]

# The entries besides the class's handlers
const entries = [trap_vector irq_drain]

const ends = [j jr ret sret mret]
const padding = [nop unimp]

# A model problem as a violation row
def model-row [detail: string]: nothing -> record {
    { kind: model, function: "", symbol: "", offset: 0, detail: $detail, path: "" }
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
export def owners-check [elf: path, values: record]: nothing -> record<entries: list<string>, class: list<int>, handlers: list<string>, reached: int, split: record, cut: record, cuts: list<int>, permitted: list<record<function: string, symbol: string, offset: int, kind: string>>, violations: list<record<kind: string, function: string, symbol: string, offset: int, detail: string, path: string>>> {
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
