use crate::*;

const STORES: &[&str] = &["sb", "sh", "sw", "sd", "fsh", "fsw", "fsd", "c.sw", "c.sd", "c.fsd"];

const BRANCHES: &[&str] = &[
    "beq", "bne", "blt", "bge", "bltu", "bgeu", "beqz", "bnez", "blez", "bgez", "bltz", "bgtz", "bgt", "ble", "bgtu",
    "bleu",
];

const QUIET: &[&str] =
    &["j", "ret", "fence", "fence.i", "fence.tso", "wfi", "mret", "sret", "ebreak", "nop", "unimp", "pause", "ecall"];

const IMMEDIATE_LAST: &[&str] =
    &["addi", "addiw", "andi", "ori", "xori", "slli", "srli", "srai", "slliw", "srliw", "sraiw", "slti", "sltiu"];

const TABLE: &[&str] = &[".quad", ".dword", ".8byte", ".word", ".4byte"];

const CONDITIONALS: &[&str] =
    &[".if", ".ifb", ".ifnb", ".ifc", ".ifnc", ".ifeq", ".ifne", ".ifdef", ".ifndef", ".else", ".elseif", ".endif"];

/// What a macro operand is, as the macro's body uses it.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub(crate) enum Kind {
    Unknown,
    Value,
    Imm,
    Label,
    Reg,
}

impl Kind {
    /// The type word the kind settles; None for a value of unknown type.
    pub(crate) fn word(self) -> Option<&'static str> {
        match self {
            Kind::Imm => Some("imm"),
            Kind::Label => Some("label"),
            Kind::Reg => Some("reg"),
            Kind::Value | Kind::Unknown => None,
        }
    }
}

/// What a macro does with registers, as its body shows it: each operand's
/// kind and whether the macro writes it, and the registers it writes itself.
#[derive(Clone, Debug, Default)]
pub(crate) struct MacroFacts {
    pub(crate) params: Vec<Param>,
    pub(crate) kinds: Vec<Kind>,
    pub(crate) outputs: Vec<bool>,
    pub(crate) writes: BTreeSet<&'static str>,
    pub(crate) complete: bool,
}

/// The registers a statement reads and writes, and whether it leaves for a
/// callee.
#[derive(Clone, Debug, Default)]
pub(crate) struct Effect {
    pub(crate) reads: Vec<&'static str>,
    pub(crate) writes: Vec<&'static str>,
    pub(crate) call: bool,
}

/// True for an op that leaves for a callee: call, tail, jal, jalr.
pub(crate) fn is_call(op: &str, args: &[String]) -> bool {
    matches!(op, "call" | "tail")
        || (op == "jal" && (args.len() == 1 || args.first().is_some_and(|rd| rd == "ra")))
        || (op == "jalr" && args.len() == 1)
}

/// True for a data directive whose operands may name code.
pub(crate) fn is_table(op: &str) -> bool {
    TABLE.contains(&op)
}

/// True for a statement that returns to the caller.
pub(crate) fn is_return(stmt: &Stmt) -> bool {
    stmt.op == "ret" || stmt.op == "tail" || (stmt.op == "jr" && stmt.args.first().is_some_and(|rs| rs == "ra"))
}

fn reads_only(op: &str) -> bool {
    STORES.contains(&op)
        || BRANCHES.contains(&op)
        || matches!(op, "jr" | "csrw" | "csrs" | "csrc" | "sfence.vma" | "sfence.vm")
        || op.starts_with("vse")
        || op.starts_with("vsse")
        || op.starts_with("vsoxei")
        || op.starts_with("vsuxei")
}

/// True for an op that is neither an instruction nor a directive: a macro
/// from outside the scanned tree.
fn foreign(op: &str) -> bool {
    const DOTTED: &[&str] = &["f", "amo", "lr.", "sc.", "fence", "sfence", "hfence", "v", "c.", "cbo.", "prefetch."];
    op.contains('.') && !op.starts_with('.') && !DOTTED.iter().any(|prefix| op.starts_with(prefix))
}

/// What a statement does to registers. A call, or a macro from outside the
/// scanned tree, changes every caller-saved register; a macro of the tree
/// does what its facts say; an ecall changes nothing the trap does not put
/// back, its results being its call's to declare.
pub(crate) fn effect(stmt: &Stmt, macros: &HashMap<String, MacroFacts>) -> Effect {
    let op = stmt.op.as_str();
    if op.starts_with('.') || QUIET.contains(&op) {
        return Effect::default();
    }
    if let Some(facts) = macros.get(op) {
        return macro_effect(stmt, facts);
    }
    if foreign(op) || is_call(op, &stmt.args) {
        let reads = if op == "jalr" { stmt.args.iter().filter_map(|arg| operand_register(arg)).collect() } else { Vec::new() };
        return Effect { reads, writes: caller_saved(), call: true };
    }
    let registers: Vec<Option<&'static str>> = stmt.args.iter().map(|arg| operand_register(arg)).collect();
    if reads_only(op) {
        return Effect { reads: registers.into_iter().flatten().collect(), ..Effect::default() };
    }
    match op {
        "csrwi" | "csrsi" | "csrci" => Effect::default(),
        "csrr" | "csrrwi" | "csrrsi" | "csrrci" => {
            Effect { writes: registers.into_iter().take(1).flatten().collect(), ..Effect::default() }
        }
        "csrrw" | "csrrs" | "csrrc" => {
            let writes = registers.first().copied().flatten().into_iter().collect();
            let reads = registers.get(2).copied().flatten().into_iter().collect();
            Effect { reads, writes, call: false }
        }
        _ => {
            let plain = stmt.args.first().is_some_and(|arg| register(arg).is_some());
            let writes = registers.first().copied().flatten().filter(|_| plain).into_iter().collect();
            let mut reads: Vec<&'static str> = registers.iter().skip(1).copied().flatten().collect();
            if !plain {
                reads.extend(registers.first().copied().flatten());
            }
            Effect { reads, writes, call: false }
        }
    }
}

fn macro_effect(stmt: &Stmt, facts: &MacroFacts) -> Effect {
    let mut reads = Vec::new();
    let mut writes: Vec<&'static str> = facts.writes.iter().copied().collect();
    for (index, param) in facts.params.iter().enumerate() {
        let operand = stmt.args.get(index).or(param.default.as_ref());
        let Some(register) = operand.and_then(|operand| operand_register(operand)) else { continue };
        let kind = facts.kinds.get(index).copied().unwrap_or(Kind::Unknown);
        if matches!(kind, Kind::Value | Kind::Unknown) {
            reads.push(register);
        }
        if facts.outputs.get(index).copied().unwrap_or(false) {
            writes.push(register);
        }
    }
    Effect { reads, writes, call: false }
}

/// How a statement uses an operand: what the use settles of its kind, and
/// whether it reads and whether it writes the register it names.
#[derive(Clone, Copy, Debug, Default)]
struct Use {
    kind: Option<Kind>,
    reads: bool,
    writes: bool,
}

/// What a macro does with registers, from its body and the macros it uses.
/// An operand read before the body writes it is a value, written in place
/// when the body also writes it; one the body writes first is a result.
pub(crate) fn macro_facts(params: &[Param], body: &[Stmt], macros: &HashMap<String, MacroFacts>) -> MacroFacts {
    let mut kinds = vec![Kind::Unknown; params.len()];
    let mut first_write: Vec<Option<bool>> = vec![None; params.len()];
    let mut outputs = vec![false; params.len()];
    let mut writes = BTreeSet::new();
    let mut complete = true;
    for stmt in body {
        let op = stmt.op.as_str();
        for (slot, param) in params.iter().enumerate() {
            let token = format!("\\{}", param.name);
            let mut used = Use::default();
            for (index, arg) in stmt.args.iter().enumerate() {
                if mentions(arg, &token) {
                    let one = use_of(stmt, index, arg, &token, macros);
                    used.reads |= one.reads;
                    used.writes |= one.writes;
                    if let Some(kind) = one.kind {
                        kinds[slot] = kinds[slot].max(kind);
                    }
                }
            }
            if used.reads || used.writes {
                first_write[slot].get_or_insert(!used.reads);
            }
            outputs[slot] |= used.writes;
        }
        if op.starts_with('.') {
            continue;
        }
        match macros.get(op) {
            Some(facts) => {
                writes.extend(facts.writes.iter().copied());
                for (index, written) in facts.outputs.iter().enumerate() {
                    if *written && let Some(register) = stmt.args.get(index).and_then(|arg| register(arg)) {
                        writes.insert(register);
                    }
                }
                complete &= facts.complete;
            }
            None if foreign(op) => complete = false,
            None => writes.extend(effect(stmt, &HashMap::new()).writes),
        }
    }
    for (slot, kind) in kinds.iter_mut().enumerate() {
        if matches!(kind, Kind::Unknown | Kind::Value)
            && let Some(written_first) = first_write[slot]
        {
            *kind = if written_first { Kind::Reg } else { Kind::Value };
        }
    }
    MacroFacts { params: params.to_vec(), kinds, outputs, writes, complete }
}

/// An operand's offset and its last parenthesised group when that group is
/// one word, `offset(base)`: the base of a memory form, or a relocation's
/// symbol.
fn memory_operand(arg: &str) -> Option<(&str, &str)> {
    let inner = arg.trim().strip_suffix(')')?;
    let mut depth = 0usize;
    for (at, c) in inner.char_indices().rev() {
        match c {
            ')' => depth += 1,
            '(' if depth == 0 => {
                let base = inner[at + 1..].trim();
                let word = !base.is_empty() && !base.contains(|c: char| c.is_whitespace() || "+-*/<>|&^~".contains(c));
                return word.then(|| (&arg.trim()[..at], base));
            }
            '(' => depth -= 1,
            _ => {}
        }
    }
    None
}

fn mentions(arg: &str, token: &str) -> bool {
    arg.match_indices(token).any(|(at, _)| {
        let next = arg[at + token.len()..].chars().next();
        !next.is_some_and(|c| c.is_ascii_alphanumeric() || c == '_')
    })
}

fn use_of(stmt: &Stmt, index: usize, arg: &str, token: &str, macros: &HashMap<String, MacroFacts>) -> Use {
    let op = stmt.op.as_str();
    let value = |kind: Kind| Use { kind: Some(kind), reads: false, writes: false };
    if op.starts_with('.') {
        return if CONDITIONALS.contains(&op) { Use::default() } else { value(Kind::Imm) };
    }
    if let Some(facts) = macros.get(op) {
        let kind = facts.kinds.get(index).copied().unwrap_or(Kind::Unknown);
        let writes = facts.outputs.get(index).copied().unwrap_or(false);
        return match kind {
            Kind::Imm | Kind::Label => value(kind),
            Kind::Reg => Use { kind: None, reads: false, writes: true },
            Kind::Value | Kind::Unknown => Use { kind: None, reads: true, writes },
        };
    }
    if let Some((offset, base)) = memory_operand(arg) {
        if offset.trim_end().rsplit(|c: char| !(c.is_ascii_alphanumeric() || c == '_' || c == '%')).next().is_some_and(|word| word.starts_with('%')) {
            return value(Kind::Label);
        }
        if mentions(base, token) {
            return Use { kind: None, reads: true, writes: false };
        }
        if mentions(offset, token) {
            return value(Kind::Imm);
        }
    }
    match (op, index) {
        ("la", 1) => value(Kind::Label),
        ("li", 1) => value(Kind::Imm),
        _ if IMMEDIATE_LAST.contains(&op) && index + 1 == stmt.args.len() && index > 0 => value(Kind::Imm),
        _ if reads_only(op) => Use { kind: None, reads: true, writes: false },
        (_, 0) => Use { kind: None, reads: false, writes: true },
        _ => Use { kind: None, reads: true, writes: false },
    }
}
