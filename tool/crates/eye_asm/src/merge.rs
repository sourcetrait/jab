use crate::*;

/// The stub's entries: each generated entry with what the existing .eye
/// says of the same name.
pub(crate) fn merge(gens: Vec<Gen>, existing: &Eye) -> Vec<Entry> {
    let by_name: HashMap<&str, &Entry> = existing.entries.iter().map(|entry| (entry.name.as_str(), entry)).collect();
    gens.into_iter()
        .map(|made| match by_name.get(made.entry.name.as_str()) {
            Some(old) => merged(made, old),
            None => made.entry,
        })
        .collect()
}

fn merged(made: Gen, old: &Entry) -> Entry {
    let mut entry = made.entry.clone();
    if !made.certain && old.syntax.is_code() && entry.syntax.is_code() {
        entry.syntax = old.syntax;
    }
    entry.shape = match (&made.entry.shape, &old.shape) {
        (Shape::Line { ty }, Shape::Line { ty: old_ty }) => Shape::Line { ty: line_type(&made, ty.as_ref(), old_ty.as_ref()) },
        (Shape::Signature { .. }, Shape::Signature { .. }) if entry.syntax == Syntax::Macro => macro_shape(&made, old),
        (Shape::Signature { .. }, Shape::Signature { args, outs }) => Shape::Signature { args: args.clone(), outs: outs.clone() },
        (shape, _) => shape.clone(),
    };
    entry.summary = old.summary.clone();
    if matches!(entry.shape, Shape::Signature { .. }) {
        let old_names = old.names();
        let new_names = entry.names();
        entry.notes =
            old.notes.iter().filter(|note| !old_names.contains(&note.name) || new_names.contains(&note.name)).cloned().collect();
    }
    entry
}

/// A data label's type: the .eye's while it fits in what the code reserves,
/// a narrower type within padding being the .eye's to choose.
fn line_type(made: &Gen, ty: Option<&String>, old: Option<&String>) -> Option<String> {
    match (old, made.size) {
        (Some(old), Some(size)) => match type_bytes(old) {
            Some(bytes) if bytes > size => ty.cloned().or_else(|| Some("?".to_owned())),
            _ => Some(old.clone()),
        },
        (Some(old), None) => Some(old.clone()),
        (None, _) => ty.cloned(),
    }
}

/// An operand's type: what the code settles, else the .eye's; `?` where the
/// code reads a register the .eye calls an immediate or a label.
fn arg_type(kind: Kind, old: Option<&str>) -> String {
    match (kind.word(), old) {
        (Some(word), _) => word.to_owned(),
        (None, Some("imm" | "label")) if kind == Kind::Value => "?".to_owned(),
        (None, Some(old)) => old.to_owned(),
        (None, None) => "?".to_owned(),
    }
}

/// A macro's operands and results: its operands from the code, the inputs
/// the .eye places in registers or memory kept, the results the .eye names
/// kept while the code still writes them, and its scratch from the code.
fn macro_shape(made: &Gen, old: &Entry) -> Shape {
    let (Shape::Signature { args: gen_args, .. }, Shape::Signature { args: old_args, outs: old_outs }) =
        (&made.entry.shape, &old.shape)
    else {
        return made.entry.shape.clone();
    };
    let params: HashSet<&str> = gen_args.iter().map(|arg| arg.name.as_str()).collect();
    let mut args: Vec<Arg> = gen_args
        .iter()
        .enumerate()
        .map(|(index, arg)| {
            let kind = made.kinds.get(index).copied().unwrap_or(Kind::Unknown);
            let old_ty = old_args.iter().find(|old| old.name == arg.name).map(|old| old.ty.as_str());
            Arg { name: arg.name.clone(), default: arg.default.clone(), location: None, ty: arg_type(kind, old_ty) }
        })
        .collect();
    args.extend(old_args.iter().filter(|old| old.location.is_some() && !params.contains(old.name.as_str())).cloned());
    let written: HashSet<&str> =
        gen_args.iter().zip(&made.outputs).filter(|(_, written)| **written).map(|(arg, _)| arg.name.as_str()).collect();
    let old_params: HashSet<&str> = old_args.iter().filter(|arg| arg.location.is_none()).map(|arg| arg.name.as_str()).collect();
    let mut outs: Vec<Out> = old_outs
        .iter()
        .filter(|out| match out {
            Out::Result { location, .. } => !old_params.contains(location.as_str()) || written.contains(location.as_str()),
            Out::Regs { .. } => false,
        })
        .cloned()
        .collect();
    let old_items: BTreeSet<String> = old_outs
        .iter()
        .filter_map(|out| match out {
            Out::Regs { regs, .. } => Some(regs),
            Out::Result { .. } => None,
        })
        .flatten()
        .flat_map(|item| expand_regs(item))
        .collect();
    let kept_params: Vec<String> = gen_args
        .iter()
        .map(|arg| arg.name.clone())
        .filter(|param| old_items.contains(param) && written.contains(param.as_str()))
        .collect();
    for (arg, kind) in gen_args.iter().zip(&made.kinds) {
        let named = outs.iter().any(|out| matches!(out, Out::Result { location, .. } if *location == arg.name))
            || kept_params.contains(&arg.name);
        if *kind == Kind::Reg && !named {
            outs.push(Out::Result { name: arg.name.clone(), location: arg.name.clone(), ty: Some("?".to_owned()) });
        }
    }
    if !made.complete {
        outs.extend(old_outs.iter().filter(|out| matches!(out, Out::Regs { .. })).cloned());
        return Shape::Signature { args, outs };
    }
    let taken: HashSet<&str> = outs
        .iter()
        .filter_map(|out| match out {
            Out::Result { location, .. } => register(location),
            Out::Regs { .. } => None,
        })
        .collect();
    let literal: BTreeSet<&'static str> = made.writes.iter().copied().filter(|reg| !taken.contains(reg)).collect();
    let new_items: BTreeSet<String> = literal.iter().map(|reg| (*reg).to_owned()).chain(kept_params.iter().cloned()).collect();
    if new_items == old_items {
        outs.extend(old_outs.iter().filter(|out| matches!(out, Out::Regs { .. })).cloned());
    } else if !new_items.is_empty() {
        let mut items = reg_list(&literal);
        items.extend(kept_params);
        outs.push(Out::Regs { word: "scratch".to_owned(), regs: items });
    }
    Shape::Signature { args, outs }
}
