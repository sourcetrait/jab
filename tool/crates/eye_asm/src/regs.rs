use crate::*;

const INT: [&str; 32] = [
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5", "a6",
    "a7", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6",
];

const FLOAT: [&str; 32] = [
    "ft0", "ft1", "ft2", "ft3", "ft4", "ft5", "ft6", "ft7", "fs0", "fs1", "fa0", "fa1", "fa2", "fa3", "fa4",
    "fa5", "fa6", "fa7", "fs2", "fs3", "fs4", "fs5", "fs6", "fs7", "fs8", "fs9", "fs10", "fs11", "ft8", "ft9",
    "ft10", "ft11",
];

const VECTOR: [&str; 32] = [
    "v0", "v1", "v2", "v3", "v4", "v5", "v6", "v7", "v8", "v9", "v10", "v11", "v12", "v13", "v14", "v15", "v16",
    "v17", "v18", "v19", "v20", "v21", "v22", "v23", "v24", "v25", "v26", "v27", "v28", "v29", "v30", "v31",
];

const CLASSES: [&str; 12] = ["t", "a", "s", "ra", "sp", "gp", "tp", "zero", "ft", "fa", "fs", "v"];

/// A register operand's ABI name; None for text that names no register.
pub(crate) fn register(text: &str) -> Option<&'static str> {
    let text = text.trim();
    if text == "fp" {
        return Some("s0");
    }
    for table in [&INT, &FLOAT, &VECTOR] {
        if let Some(name) = table.iter().find(|name| **name == text) {
            return Some(name);
        }
    }
    let number = |prefix: char| text.strip_prefix(prefix).and_then(|digits| digits.parse::<usize>().ok());
    if let Some(n) = number('x') {
        return INT.get(n).copied();
    }
    if let Some(n) = number('f') {
        return FLOAT.get(n).copied();
    }
    None
}

/// The register an operand names: itself, or the base of a memory form.
pub(crate) fn operand_register(operand: &str) -> Option<&'static str> {
    let operand = operand.trim();
    if operand.ends_with(')')
        && let Some(open) = operand.rfind('(')
    {
        return register(&operand[open + 1..operand.len() - 1]);
    }
    register(operand)
}

/// The registers any call may change: ra and the caller-saved sets.
pub(crate) fn caller_saved() -> Vec<&'static str> {
    let mut out = vec!["ra"];
    out.extend(INT.iter().copied().filter(|name| name.starts_with('t') || name.starts_with('a')));
    out.extend(FLOAT.iter().copied().filter(|name| name.starts_with("ft") || name.starts_with("fa")));
    out
}

/// True for a0 to a7.
pub(crate) fn is_argument(name: &str) -> bool {
    argument_index(name).is_some()
}

/// The position an argument register holds, a0 first.
pub(crate) fn argument_index(name: &str) -> Option<usize> {
    let (prefix, number) = split(name);
    match (prefix, number) {
        ("a", Some(n)) if n < 8 => Some(n as usize),
        _ => None,
    }
}

/// The argument register at a position.
pub(crate) fn argument_name(index: usize) -> &'static str {
    INT[10 + index]
}

/// True for s0 to s11.
pub(crate) fn is_saved(name: &str) -> bool {
    matches!(split(name), ("s", Some(_)))
}

fn split(name: &str) -> (&str, Option<u32>) {
    match name.find(|c: char| c.is_ascii_digit()) {
        Some(at) => (&name[..at], name[at..].parse().ok()),
        None => (name, None),
    }
}

fn sort_key(name: &str) -> (usize, u32) {
    let (prefix, number) = split(name);
    let class = CLASSES.iter().position(|class| *class == prefix).unwrap_or(CLASSES.len());
    (class, number.unwrap_or(0))
}

/// Registers in the .eye's order, each run of consecutive ones as a range.
pub(crate) fn reg_list(regs: &BTreeSet<&'static str>) -> Vec<String> {
    let mut sorted: Vec<&str> = regs.iter().copied().collect();
    sorted.sort_by_key(|name| sort_key(name));
    let mut out = Vec::new();
    let mut i = 0;
    while i < sorted.len() {
        let (prefix, start) = split(sorted[i]);
        let mut j = i;
        if let Some(start) = start {
            while let Some(next) = sorted.get(j + 1) {
                let (next_prefix, next_number) = split(next);
                if next_prefix == prefix && next_number == Some(start + (j + 1 - i) as u32) {
                    j += 1;
                } else {
                    break;
                }
            }
        }
        out.push(if j > i { format!("{}-{}", sorted[i], sorted[j]) } else { sorted[i].to_owned() });
        i = j + 1;
    }
    out
}

/// The registers a list item names, a range spelled out.
pub(crate) fn expand_regs(item: &str) -> Vec<String> {
    if let Some((first, last)) = item.split_once('-') {
        let (prefix, start) = split(first);
        let (last_prefix, end) = split(last);
        if let (Some(start), Some(end)) = (start, end)
            && prefix == last_prefix
            && start <= end
        {
            return (start..=end).map(|n| format!("{prefix}{n}")).collect();
        }
    }
    vec![item.to_owned()]
}
