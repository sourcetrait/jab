export const branches = [beq bne blt bge bltu bgeu beqz bnez blez bgez bltz bgtz bgt ble bgtu bleu]

export def hex [n: int]: nothing -> string { $n | format number | get lowerhex }

# The address an operand list names before its symbol (`80000820
# <irq_serve>`), or the one its annotation names (`# 80049468
# <sound_base>`), or null
export def operand-address [args: string]: nothing -> oneof<int, nothing> {
    let p = ($args | parse --regex '(?:^|,)(?P<a>[0-9a-f]+) <[^>]+>$')
    if ($p | is-empty) { null } else { $"0x($p.0.a)" | into int }
}
export def annotated-address [args: string]: nothing -> oneof<int, nothing> {
    let p = ($args | parse --regex '# (?P<a>[0-9a-f]+) <[^>]+>$')
    if ($p | is-empty) { return null }
    # sixteen digits with the top bit set annotate a negative immediate,
    # never an address, and lie past what `into int` takes
    if ($p.0.a | str length) == 16 and ($p.0.a | str substring 0..0) in ["8" "9" "a" "b" "c" "d" "e" "f"] { return null }
    $"0x($p.0.a)" | into int
}

# An instruction's operands, before any comment
export def operands [args: string]: nothing -> list<string> {
    $args | split row "#" | first | str trim | split row "," | each {|o| $o | str trim } | where {|o| $o != "" }
}

# Whether an instruction is the op with these operands, "*" any one
export def shaped [i: record, op: string, want: list<string>]: nothing -> bool {
    let have = (operands $i.args)
    $i.op == $op and ($have | length) == ($want | length) and ($have | zip $want | all {|z| $z.1 == "*" or $z.0 == $z.1 })
}

# Whether an instruction loads the hart's id from its record
export def is-hart-load [i: record, hart_id: int]: nothing -> bool {
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
export def transfer-of [i: record, before: any]: nothing -> oneof<record<kind: string, to: oneof<int, nothing>>, nothing> {
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
export def transfers-of [funcs: list<any>]: nothing -> list<any> {
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
