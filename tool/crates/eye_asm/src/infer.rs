use crate::*;

const FRAME_SLOT: usize = 80;

/// What the scanned tree says of how its labels are entered and what its
/// macros do.
#[derive(Debug, Default)]
pub(crate) struct Tree {
    pub(crate) macros: HashMap<String, MacroFacts>,
    pub(crate) called: HashSet<String>,
    pub(crate) tabled: HashSet<String>,
}

/// An entry the code alone produces, with what the merge must know of it:
/// whether its syntax is certain, and a macro's facts.
#[derive(Clone, Debug)]
pub(crate) struct Gen {
    pub(crate) entry: Entry,
    pub(crate) certain: bool,
    pub(crate) kinds: Vec<Kind>,
    pub(crate) outputs: Vec<bool>,
    pub(crate) writes: BTreeSet<&'static str>,
    pub(crate) complete: bool,
}

/// The tree's macro facts and label references, from every source in it.
pub(crate) fn tree(sources: &[&Source]) -> Tree {
    let mut tree = Tree::default();
    let macros: Vec<(&String, &Vec<Param>, &Vec<Stmt>)> = sources
        .iter()
        .flat_map(|source| source.symbols.iter())
        .filter_map(|symbol| match &symbol.def {
            Def::Macro { params, body } => Some((&symbol.name, params, body)),
            _ => None,
        })
        .collect();
    for _ in 0..4 {
        let next: HashMap<String, MacroFacts> =
            macros.iter().map(|(name, params, body)| ((*name).clone(), macro_facts(params, body, &tree.macros))).collect();
        tree.macros = next;
    }
    for symbol in sources.iter().flat_map(|source| source.symbols.iter()) {
        let stmts = match &symbol.def {
            Def::Macro { body, .. } => body,
            Def::Label { stmts, .. } => stmts,
        };
        for stmt in stmts {
            let target = || stmt.args.last().map(|arg| arg.trim().to_owned());
            if is_call(&stmt.op, &stmt.args) {
                tree.called.extend(target());
            } else if is_table(&stmt.op) {
                tree.tabled.extend(stmt.args.iter().map(|arg| arg.trim().to_owned()));
            }
        }
    }
    tree
}

/// The entries the code alone gives a source, in its order: its routines,
/// jump targets, and macros.
pub(crate) fn gens(source: &Source, tree: &Tree) -> Vec<Gen> {
    source.symbols.iter().filter_map(|symbol| generated(symbol, tree)).collect()
}

fn generated(symbol: &Symbol, tree: &Tree) -> Option<Gen> {
    match &symbol.def {
        Def::Macro { params, .. } => {
            let facts = tree.macros.get(&symbol.name).cloned().unwrap_or_default();
            let args = params
                .iter()
                .zip(&facts.kinds)
                .map(|(param, kind)| Arg {
                    name: param.name.clone(),
                    default: param.default.clone(),
                    location: None,
                    ty: kind.word().unwrap_or("?").to_owned(),
                })
                .collect();
            let mut outs: Vec<Out> = params
                .iter()
                .zip(&facts.outputs)
                .filter(|(_, written)| **written)
                .map(|(param, _)| Out::Result { name: param.name.clone(), location: param.name.clone(), ty: Some("?".to_owned()) })
                .collect();
            if !facts.writes.is_empty() {
                outs.push(Out::Regs { word: "scratch".to_owned(), regs: reg_list(&facts.writes) });
            }
            let entry = Entry {
                syntax: Syntax::Macro,
                local: false,
                name: symbol.name.clone(),
                args,
                outs,
                range: Some((symbol.first, symbol.last)),
                summary: None,
                notes: Vec::new(),
            };
            Some(Gen {
                entry,
                certain: true,
                kinds: facts.kinds,
                outputs: facts.outputs,
                writes: facts.writes,
                complete: facts.complete,
            })
        }
        Def::Label { section: Section::Text, global, stmts } if !is_data(stmts) => {
            let name = &symbol.name;
            let (syntax, certain) = if tree.called.contains(name) {
                (Syntax::Call, true)
            } else if stmts.iter().any(is_return) {
                (Syntax::Call, false)
            } else if tree.tabled.contains(name) {
                (Syntax::Ecall, false)
            } else {
                (Syntax::J, false)
            };
            let (args, outs) = routine(stmts, syntax == Syntax::Ecall, tree);
            let entry = Entry {
                syntax,
                local: !global,
                name: name.clone(),
                args,
                outs,
                range: Some((symbol.first, symbol.last)),
                summary: None,
                notes: Vec::new(),
            };
            Some(Gen { entry, certain, kinds: Vec::new(), outputs: Vec::new(), writes: BTreeSet::new(), complete: true })
        }
        Def::Label { .. } => None,
    }
}

/// True for a label in text whose statements are all data directives: a
/// table, not code.
fn is_data(stmts: &[Stmt]) -> bool {
    let sized = |stmt: &Stmt| data_bytes(std::slice::from_ref(stmt)).is_some();
    let aligns = |stmt: &Stmt| matches!(stmt.op.as_str(), ".balign" | ".align" | ".p2align");
    stmts.iter().any(sized) && stmts.iter().all(|stmt| sized(stmt) || aligns(stmt))
}

fn frame_slot(arg: Option<&String>) -> Option<usize> {
    let offset: usize = arg?.trim().strip_suffix("(sp)")?.trim().parse().ok()?;
    (offset >= FRAME_SLOT && (offset - FRAME_SLOT).is_multiple_of(8) && offset < FRAME_SLOT + 8 * 7).then(|| (offset - FRAME_SLOT) / 8)
}

/// A routine's argument registers, read before written, a register saved to
/// the stack and restored from the same slot not counting as read, and the
/// registers it leaves: a handler's frame slots, or what a routine writes
/// itself.
fn routine(stmts: &[Stmt], ecall: bool, tree: &Tree) -> (Vec<Arg>, Vec<Out>) {
    let slot = |stmt: &Stmt| Some((register(stmt.args.first()?)?, stmt.args.get(1)?.replace(' ', "")));
    let restored: HashSet<(&'static str, String)> =
        stmts.iter().filter(|stmt| matches!(stmt.op.as_str(), "ld" | "lw" | "lwu")).filter_map(slot).filter(|(_, at)| at.ends_with("(sp)")).collect();
    let mut written: HashSet<&'static str> = HashSet::new();
    let mut highest: Option<usize> = None;
    let mut results: BTreeSet<usize> = BTreeSet::new();
    let mut direct: BTreeSet<&'static str> = BTreeSet::new();
    for stmt in stmts {
        if !ecall && matches!(stmt.op.as_str(), "sd" | "sw") && slot(stmt).is_some_and(|saved| restored.contains(&saved)) {
            continue;
        }
        if ecall
            && matches!(stmt.op.as_str(), "ld" | "lw" | "lwu")
            && let Some(slot) = frame_slot(stmt.args.get(1))
        {
            highest = highest.max(Some(slot));
        }
        if ecall
            && stmt.op == "sd"
            && let Some(slot) = frame_slot(stmt.args.get(1))
        {
            results.insert(slot);
        }
        let effect = effect(stmt, &tree.macros);
        for read in &effect.reads {
            if let Some(index) = argument_index(read)
                && !written.contains(read)
            {
                highest = highest.max(Some(index));
            }
        }
        if !effect.call {
            direct.extend(effect.writes.iter().copied());
        }
        written.extend(effect.writes);
        if stmt.op == "ecall" {
            written.extend((0..8).map(argument_name));
        }
    }
    let args = (0..highest.map_or(0, |at| at + 1))
        .map(|index| Arg { name: argument_name(index).to_owned(), default: None, location: None, ty: "?".to_owned() })
        .collect();
    let mut outs: Vec<Out> = if ecall {
        results.iter().map(|&slot| result(argument_name(slot))).collect()
    } else {
        direct.iter().filter(|name| is_argument(name)).map(|name| result(name)).collect()
    };
    let saved: BTreeSet<&'static str> = direct.iter().copied().filter(|name| is_saved(name)).collect();
    if !ecall && !saved.is_empty() {
        outs.push(Out::Regs { word: "clobber".to_owned(), regs: reg_list(&saved) });
    }
    (args, outs)
}

fn result(register: &str) -> Out {
    Out::Result { name: register.to_owned(), location: register.to_owned(), ty: Some("?".to_owned()) }
}

/// The bytes a label's data directives reserve, when every one of them says.
pub(crate) fn data_bytes(stmts: &[Stmt]) -> Option<u64> {
    let mut bytes: u64 = 0;
    for stmt in stmts {
        let width = match stmt.op.as_str() {
            ".byte" | ".skip" | ".space" | ".zero" | ".asciz" | ".string" | ".ascii" => 1,
            ".2byte" | ".half" | ".short" | ".hword" => 2,
            ".4byte" | ".word" | ".long" | ".int" | ".float" | ".single" => 4,
            ".8byte" | ".dword" | ".quad" | ".double" => 8,
            ".balign" | ".align" | ".p2align" | ".type" | ".size" | ".global" | ".globl" => continue,
            _ => return None,
        };
        let elements = match stmt.op.as_str() {
            ".skip" | ".space" | ".zero" => number(stmt.args.first()?)?,
            ".asciz" | ".string" => string_bytes(stmt.args.first()?) + 1,
            ".ascii" => string_bytes(stmt.args.first()?),
            _ => stmt.args.len() as u64,
        };
        bytes += elements * width;
    }
    (bytes > 0).then_some(bytes)
}

fn number(text: &str) -> Option<u64> {
    let text = text.trim();
    match text.strip_prefix("0x").or_else(|| text.strip_prefix("0X")) {
        Some(hex) => u64::from_str_radix(hex, 16).ok(),
        None => text.parse().ok(),
    }
}

fn string_bytes(text: &str) -> u64 {
    let inner = text.trim().trim_start_matches('"').trim_end_matches('"');
    let mut count = 0;
    let mut chars = inner.chars();
    while let Some(c) = chars.next() {
        if c == '\\' {
            match chars.next() {
                Some('x') => {
                    let hex: String = chars.clone().take_while(|c| c.is_ascii_hexdigit()).collect();
                    for _ in 0..hex.len() {
                        chars.next();
                    }
                }
                Some(d) if d.is_digit(8) => {
                    for _ in 0..2 {
                        if chars.clone().next().is_some_and(|c| c.is_digit(8)) {
                            chars.next();
                        }
                    }
                }
                _ => {}
            }
        }
        count += c.len_utf8() as u64;
    }
    count
}
