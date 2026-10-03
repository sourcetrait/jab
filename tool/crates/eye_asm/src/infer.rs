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
/// whether its syntax is certain, a data label's size, and a macro's facts.
#[derive(Clone, Debug)]
pub(crate) struct Gen {
    pub(crate) entry: Entry,
    pub(crate) certain: bool,
    pub(crate) size: Option<u64>,
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
            _ => continue,
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

/// The entries the code alone gives a source, in its order.
pub(crate) fn gens(source: &Source, tree: &Tree) -> Vec<Gen> {
    source.symbols.iter().map(|symbol| generated(symbol, tree)).collect()
}

fn line(syntax: Syntax, symbol: &Symbol, local: bool, ty: Option<String>) -> Entry {
    Entry {
        syntax,
        local,
        name: symbol.name.clone(),
        shape: Shape::Line { ty },
        range: Some((symbol.first, symbol.last)),
        summary: None,
        notes: Vec::new(),
    }
}

fn generated(symbol: &Symbol, tree: &Tree) -> Gen {
    let plain = |entry: Entry| Gen {
        entry,
        certain: true,
        size: None,
        kinds: Vec::new(),
        outputs: Vec::new(),
        writes: BTreeSet::new(),
        complete: true,
    };
    match &symbol.def {
        Def::Constant => plain(line(Syntax::Set, symbol, false, None)),
        Def::Linker => plain(line(Syntax::Ld, symbol, false, None)),
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
                shape: Shape::Signature { args, outs },
                range: Some((symbol.first, symbol.last)),
                summary: None,
                notes: Vec::new(),
            };
            Gen {
                entry,
                certain: true,
                size: None,
                kinds: facts.kinds,
                outputs: facts.outputs,
                writes: facts.writes,
                complete: facts.complete,
            }
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
                shape: Shape::Signature { args, outs },
                range: Some((symbol.first, symbol.last)),
                summary: None,
                notes: Vec::new(),
            };
            Gen { certain, ..plain(entry) }
        }
        Def::Label { section, global, stmts } => {
            let syntax = match section {
                Section::Bss => Syntax::Bss,
                Section::Rodata | Section::Text => Syntax::Rodata,
                Section::Data => Syntax::Data,
            };
            let (ty, size) = data_type(stmts);
            let mut made = plain(line(syntax, symbol, !global, ty));
            made.size = size;
            made
        }
    }
}

/// True for a label in text whose statements are all data directives: a
/// table, not code.
fn is_data(stmts: &[Stmt]) -> bool {
    let sized = |stmt: &Stmt| data_type(std::slice::from_ref(stmt)).1.is_some();
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

/// A data label's type and size in bytes, as far as its directives say.
pub(crate) fn data_type(stmts: &[Stmt]) -> (Option<String>, Option<u64>) {
    let mut width: Option<(&'static str, u64)> = None;
    let mut count: u64 = 0;
    let mut bytes: Option<u64> = Some(0);
    let mut mixed = false;
    for stmt in stmts {
        let element = match stmt.op.as_str() {
            ".byte" => Some(("u8", 1)),
            ".2byte" | ".half" | ".short" | ".hword" => Some(("u16", 2)),
            ".4byte" | ".word" | ".long" | ".int" => Some(("u32", 4)),
            ".8byte" | ".dword" | ".quad" => Some(("u64", 8)),
            ".float" | ".single" => Some(("f32", 4)),
            ".double" => Some(("f64", 8)),
            ".skip" | ".space" | ".zero" | ".asciz" | ".string" | ".ascii" => Some(("u8", 1)),
            ".balign" | ".align" | ".p2align" | ".type" | ".size" | ".global" | ".globl" => continue,
            _ => None,
        };
        let Some((word, size)) = element else {
            return (None, None);
        };
        let elements = match stmt.op.as_str() {
            ".skip" | ".space" | ".zero" => stmt.args.first().and_then(|arg| number(arg)),
            ".asciz" | ".string" => stmt.args.first().map(|arg| string_bytes(arg) + 1),
            ".ascii" => stmt.args.first().map(|arg| string_bytes(arg)),
            _ => Some(stmt.args.len() as u64),
        };
        match (elements, bytes) {
            (Some(n), Some(total)) => bytes = Some(total + n * size),
            _ => bytes = None,
        }
        match width {
            Some((seen, _)) if seen != word => mixed = true,
            _ => width = Some((word, size)),
        }
        count += elements.unwrap_or(0);
    }
    let ty = match (width, mixed, bytes) {
        (Some((word, _)), false, Some(_)) if count == 1 => Some(word.to_owned()),
        (Some((word, _)), false, Some(_)) => Some(format!("{count} {word}")),
        _ => None,
    };
    (ty, bytes.filter(|total| *total > 0))
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

/// How many bytes a type word or array type takes, when it says.
pub(crate) fn type_bytes(ty: &str) -> Option<u64> {
    let mut words = ty.split_whitespace();
    let first = words.next()?;
    let (count, word) = match first.parse::<u64>() {
        Ok(count) => (count, words.next()?),
        Err(_) => (1, first),
    };
    let width = match word {
        "u8" | "i8" => 1,
        "u16" | "i16" => 2,
        "u32" | "i32" | "f32" => 4,
        "u64" | "i64" | "f64" | "address" => 8,
        _ => return None,
    };
    Some(count * width)
}
