use crate::*;

/// A statement: its mnemonic or directive and its operands.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct Stmt {
    pub(crate) op: String,
    pub(crate) args: Vec<String>,
    pub(crate) line: usize,
}

/// A macro's parameter: its name and the default the definition declares.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct Param {
    pub(crate) name: String,
    pub(crate) default: Option<String>,
}

/// The section a label sits in.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Section {
    Text,
    Data,
    Rodata,
    Bss,
}

/// What a symbol is, with the statements inference reads of it.
#[derive(Clone, Debug)]
pub(crate) enum Def {
    Macro { params: Vec<Param>, body: Vec<Stmt> },
    Label { section: Section, global: bool, stmts: Vec<Stmt> },
}

/// A symbol a source defines and the lines it spans.
#[derive(Clone, Debug)]
pub(crate) struct Symbol {
    pub(crate) name: String,
    pub(crate) def: Def,
    pub(crate) first: usize,
    pub(crate) last: usize,
}

/// A source's symbols in the order it defines them.
#[derive(Clone, Debug, Default)]
pub(crate) struct Source {
    pub(crate) symbols: Vec<Symbol>,
}

/// The labels and macros an assembly source defines, with the lines each spans.
pub(crate) fn scan_asm(text: &str) -> Source {
    let globals = globals(text);
    let mut symbols: Vec<Symbol> = Vec::new();
    let mut seen: HashSet<String> = HashSet::new();
    let mut section = String::from(".text");
    let mut stack: Vec<String> = Vec::new();
    let mut current: HashMap<String, usize> = HashMap::new();
    let mut in_macro: Option<usize> = None;
    let mut skipping = false;
    for (index, raw) in text.lines().enumerate() {
        let number = index + 1;
        for statement in statements(strip_comment(raw)) {
            let mut rest = statement.trim();
            while let Some((label, after)) = take_label(rest) {
                rest = after;
                if in_macro.is_some() || skipping || is_local_label(label) || !seen.insert(label.to_owned()) {
                    continue;
                }
                let def = Def::Label { section: section_of(&section), global: globals.contains(label), stmts: Vec::new() };
                symbols.push(Symbol { name: label.to_owned(), def, first: number, last: number });
                current.insert(section.clone(), symbols.len() - 1);
            }
            if rest.is_empty() {
                continue;
            }
            let stmt = parse_stmt(rest, number);
            if skipping {
                skipping = stmt.op != ".endm";
                continue;
            }
            if let Some(at) = in_macro {
                symbols[at].last = number;
                if stmt.op == ".endm" {
                    in_macro = None;
                } else if let Def::Macro { body, .. } = &mut symbols[at].def {
                    body.push(stmt);
                }
                continue;
            }
            match stmt.op.as_str() {
                ".macro" => {
                    let mut words = rest[".macro".len()..].split(|c: char| c == ',' || c.is_whitespace()).filter(|w| !w.is_empty());
                    let Some(name) = words.next() else { continue };
                    let params = words.map(param).collect();
                    if seen.insert(name.to_owned()) {
                        let def = Def::Macro { params, body: Vec::new() };
                        symbols.push(Symbol { name: name.to_owned(), def, first: number, last: number });
                        in_macro = Some(symbols.len() - 1);
                    } else {
                        skipping = true;
                    }
                }
                ".set" | ".equ" | ".equiv" => {}
                ".text" | ".data" | ".bss" => section = stmt.op.clone(),
                ".section" => section = section_name(&stmt),
                ".pushsection" => {
                    stack.push(section.clone());
                    section = section_name(&stmt);
                }
                ".popsection" => {
                    if let Some(previous) = stack.pop() {
                        section = previous;
                    }
                }
                _ => {
                    if assignment(rest).is_none()
                        && let Some(&at) = current.get(&section)
                    {
                        symbols[at].last = number;
                        if let Def::Label { stmts, .. } = &mut symbols[at].def {
                            stmts.push(stmt);
                        }
                    }
                }
            }
        }
    }
    Source { symbols }
}

fn param(word: &str) -> Param {
    let word = word.split(':').next().unwrap_or(word);
    match word.split_once('=') {
        Some((name, default)) => Param { name: name.to_owned(), default: Some(default.to_owned()) },
        None => Param { name: word.to_owned(), default: None },
    }
}

fn globals(text: &str) -> HashSet<String> {
    let mut out = HashSet::new();
    for line in text.lines() {
        for statement in statements(strip_comment(line)) {
            let stmt = parse_stmt(statement.trim(), 0);
            if stmt.op == ".global" || stmt.op == ".globl" {
                out.extend(stmt.args.iter().flat_map(|arg| arg.split_whitespace()).map(str::to_owned));
            }
        }
    }
    out
}

fn section_name(stmt: &Stmt) -> String {
    stmt.args.first().and_then(|arg| arg.split_whitespace().next()).unwrap_or(".text").to_owned()
}

fn section_of(name: &str) -> Section {
    if name.starts_with(".rodata") || name.starts_with(".srodata") {
        Section::Rodata
    } else if name.starts_with(".bss") || name.starts_with(".sbss") || name.starts_with(".tbss") {
        Section::Bss
    } else if name.starts_with(".data") || name.starts_with(".sdata") || name.starts_with(".tdata") {
        Section::Data
    } else {
        Section::Text
    }
}

fn is_ident_char(c: char) -> bool {
    c.is_ascii_alphanumeric() || matches!(c, '_' | '.' | '$')
}

fn is_label_char(c: char) -> bool {
    is_ident_char(c) || matches!(c, '\\' | '@')
}

fn is_local_label(name: &str) -> bool {
    name.starts_with(".L") || name.chars().all(|c| c.is_ascii_digit()) || name.contains('\\')
}

/// A label at the start of a statement, and what follows it.
pub(crate) fn take_label(text: &str) -> Option<(&str, &str)> {
    let end = text.find(|c: char| !is_label_char(c)).unwrap_or(text.len());
    if end > 0 && text[end..].starts_with(':') {
        Some((&text[..end], text[end + 1..].trim_start()))
    } else {
        None
    }
}

/// The name a `name = value` assignment defines.
fn assignment(text: &str) -> Option<&str> {
    let end = text.find(|c: char| !is_ident_char(c))?;
    let name = &text[..end];
    let rest = text[end..].trim_start();
    let defines = rest.starts_with('=') && !rest.starts_with("==");
    (defines && !name.is_empty() && !name.chars().next()?.is_ascii_digit()).then_some(name)
}

/// A line without its comment, quotes respected.
pub(crate) fn strip_comment(line: &str) -> &str {
    let mut quote: Option<char> = None;
    let mut escape = false;
    for (at, c) in line.char_indices() {
        if let Some(open) = quote {
            if escape {
                escape = false;
            } else if c == '\\' {
                escape = true;
            } else if c == open {
                quote = None;
            }
        } else if c == '"' || c == '\'' {
            quote = Some(c);
        } else if c == '#' {
            return &line[..at];
        }
    }
    line
}

/// A line's statements, split at semicolons outside quotes.
fn statements(line: &str) -> Vec<&str> {
    let mut out = Vec::new();
    let mut quote: Option<char> = None;
    let mut start = 0;
    for (at, c) in line.char_indices() {
        match quote {
            Some(open) if c == open => quote = None,
            Some(_) => {}
            None if c == '"' || c == '\'' => quote = Some(c),
            None if c == ';' => {
                out.push(&line[start..at]);
                start = at + 1;
            }
            None => {}
        }
    }
    out.push(&line[start..]);
    out
}

/// A statement's op, lowercased, and its operands split at top-level commas.
pub(crate) fn parse_stmt(text: &str, line: usize) -> Stmt {
    let text = text.trim();
    let end = text.find(char::is_whitespace).unwrap_or(text.len());
    let op = text[..end].to_ascii_lowercase();
    let mut args = Vec::new();
    let mut depth = 0usize;
    let mut quote: Option<char> = None;
    let mut current = String::new();
    for c in text[end..].chars() {
        match (quote, c) {
            (Some(open), _) if c == open => {
                quote = None;
                current.push(c);
            }
            (Some(_), _) => current.push(c),
            (None, '"' | '\'') => {
                quote = Some(c);
                current.push(c);
            }
            (None, '(') => {
                depth += 1;
                current.push(c);
            }
            (None, ')') => {
                depth = depth.saturating_sub(1);
                current.push(c);
            }
            (None, ',') if depth == 0 => args.push(std::mem::take(&mut current)),
            (None, _) => current.push(c),
        }
    }
    args.push(current);
    let args = args.into_iter().map(|arg| arg.trim().to_owned()).filter(|arg| !arg.is_empty()).collect();
    Stmt { op, args, line }
}
