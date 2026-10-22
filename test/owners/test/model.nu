use ./instructions.nu [annotated-address branches hex is-hart-load operand-address operands shaped transfer-of]

# The calls a worker's hart takes, by jab.inc's names, and the routine
# that admits them
export const worker_calls = [JAB_SYS_HARTS JAB_SYS_WORKER_WAIT JAB_SYS_WORKER_WAKE JAB_SYS_WORKER_EXIT]
export const class_site = "worker_call"

# The drain, its service, and how many calls between them the model cuts
export const drain = "irq_drain"
export const service = "irq_serve"
export const drain_calls = 2

# The one dispatch site and the table it reads
export const dispatch_site = "call_table"
export const dispatch_table = "syscall_table"

# The hart split's vector, hart 0's refusal of a bad call, the admissions'
# refusal, and where it returns
export const vector = "trap_vector"
const bad_call = "bad_syscall"
const denied = "sys_denied"
const denied_return = "trap_return"

# The instructions that write no register of their first operand
const nonwriting = [j jr ret sret mret fence wfi pause sb sh sw sd fsw fsd csrw csrs csrc ecall ebreak nop]

# The hart split (HartSplit): the vector's test of HART_ID branching to the
# admissions, the approach its fall-through runs, hart 0's bounds check,
# into the dispatch; the admissions (Admissions) and the dispatch (Dispatch)
# each exactly its pattern; and nothing entering the approach but the
# admissions' branches at the dispatch's first instruction, nothing
# entering the admissions but the test, and no address of either formed in
# the code or held in the data
export def hart-split [funcs: list<any>, direct: list<any>, words: list<int>, elf_symbols: table, values: record]: nothing -> record {
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
export def drain-cut [funcs: list<any>, transfers: list<any>, direct: list<any>, values: record]: nothing -> record {
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
export def guarded-regions [f: record, direct: list<any>, values: record]: nothing -> list<any> {
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
