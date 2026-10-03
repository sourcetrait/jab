use crate::*;

/// The first word of an entry: how the item is entered, or what it is.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Syntax {
    Set,
    Bss,
    Data,
    Rodata,
    Ld,
    Call,
    Ecall,
    J,
    Macro,
}

impl Syntax {
    pub(crate) fn parse(word: &str) -> Option<Syntax> {
        Some(match word {
            "set" => Syntax::Set,
            "bss" => Syntax::Bss,
            "data" => Syntax::Data,
            "rodata" => Syntax::Rodata,
            "ld" => Syntax::Ld,
            "call" => Syntax::Call,
            "ecall" => Syntax::Ecall,
            "j" => Syntax::J,
            "macro" => Syntax::Macro,
            _ => return None,
        })
    }

    pub(crate) fn word(self) -> &'static str {
        match self {
            Syntax::Set => "set",
            Syntax::Bss => "bss",
            Syntax::Data => "data",
            Syntax::Rodata => "rodata",
            Syntax::Ld => "ld",
            Syntax::Call => "call",
            Syntax::Ecall => "ecall",
            Syntax::J => "j",
            Syntax::Macro => "macro",
        }
    }

    /// True for the entries that carry arguments and results.
    pub(crate) fn is_signature(self) -> bool {
        matches!(self, Syntax::Call | Syntax::Ecall | Syntax::J | Syntax::Macro)
    }

    /// True for a label of code.
    pub(crate) fn is_code(self) -> bool {
        matches!(self, Syntax::Call | Syntax::Ecall | Syntax::J)
    }
}

/// An argument: its name, the default the source declares, where it arrives
/// when the calling convention does not say, and its type.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct Arg {
    pub(crate) name: String,
    pub(crate) default: Option<String>,
    pub(crate) location: Option<String>,
    pub(crate) ty: String,
}

/// A result, or a list of registers changed beyond the results.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) enum Out {
    Result { name: String, location: String, ty: Option<String> },
    Regs { word: String, regs: Vec<String> },
}

/// What follows an entry's name on its head line, before its range.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) enum Shape {
    Line { ty: Option<String> },
    Signature { args: Vec<Arg>, outs: Vec<Out> },
}

/// A line under a head: an argument's or a result's name and what its name
/// and type leave unsaid.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct Note {
    pub(crate) name: String,
    pub(crate) summary: Option<String>,
}

/// One entry: its head line, ending in its range and its summary, and the
/// notes indented below it for its arguments and results.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct Entry {
    pub(crate) syntax: Syntax,
    pub(crate) local: bool,
    pub(crate) name: String,
    pub(crate) shape: Shape,
    pub(crate) range: Option<(usize, usize)>,
    pub(crate) summary: Option<String>,
    pub(crate) notes: Vec<Note>,
}

impl Entry {
    /// The names a note may carry: the arguments' and the results'.
    pub(crate) fn names(&self) -> HashSet<String> {
        match &self.shape {
            Shape::Line { .. } => HashSet::new(),
            Shape::Signature { args, outs } => args
                .iter()
                .map(|arg| arg.name.clone())
                .chain(outs.iter().filter_map(|out| match out {
                    Out::Result { name, .. } => Some(name.clone()),
                    Out::Regs { .. } => None,
                }))
                .collect(),
        }
    }
}

/// An .eye file: its entries in order.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub(crate) struct Eye {
    pub(crate) entries: Vec<Entry>,
}

impl Eye {
    /// The entries of an .eye file's text; what reads it names the source.
    pub(crate) fn parse(text: &str, what: &Path) -> EyeResult<Eye> {
        let mut entries: Vec<Entry> = Vec::new();
        for (index, line) in text.lines().enumerate() {
            let fail = |message: &str| EyeError::Parse { what: what.display().to_string(), line: index + 1, message: message.to_owned() };
            if line.trim().is_empty() {
                continue;
            }
            if let Some(note) = line.strip_prefix(' ') {
                let entry = entries.last_mut().ok_or_else(|| fail("a note before any entry"))?;
                let (name, summary) = match note.split_once(" :") {
                    Some((name, summary)) => (name, Some(summary.trim().to_owned()).filter(|summary| !summary.is_empty())),
                    None => (note.trim_end(), None),
                };
                if name.is_empty() || name.contains(' ') {
                    return Err(fail("a note is `<name> [:<summary>]`"));
                }
                entry.notes.push(Note { name: name.to_owned(), summary });
                continue;
            }
            entries.push(parse_head(line).map_err(|message| fail(&message))?);
        }
        Ok(Eye { entries })
    }
}

fn parse_head(line: &str) -> Result<Entry, String> {
    let (line, summary) = match line.split_once(" :") {
        Some((head, summary)) => (head, Some(summary.trim().to_owned()).filter(|summary| !summary.is_empty())),
        None => (line, None),
    };
    let (line, range) = split_range(line);
    let mut words = line.split(' ').filter(|word| !word.is_empty());
    let first = words.next().unwrap_or_default();
    let syntax = Syntax::parse(first).ok_or_else(|| format!("no such syntax word: {first}"))?;
    let mut name = words.next().ok_or("no name")?;
    let local = name == "local";
    if local {
        name = words.next().ok_or("no name after local")?;
    }
    let rest: Vec<&str> = words.collect();
    let rest = rest.join(" ");
    let shape = if syntax.is_signature() {
        parse_signature(&rest)
    } else {
        Shape::Line { ty: (!rest.is_empty()).then_some(rest) }
    };
    Ok(Entry { syntax, local, name: name.to_owned(), shape, range, summary, notes: Vec::new() })
}

/// A head line without its range, `[first:last]` or a one-liner's `[line]`.
fn split_range(line: &str) -> (&str, Option<(usize, usize)>) {
    let Some(open) = line.rfind(" [") else { return (line, None) };
    let parsed = line[open + 2..].strip_suffix(']').and_then(|inner| match inner.split_once(':') {
        Some((first, last)) => Some((first.parse().ok()?, last.parse().ok()?)),
        None => inner.parse().ok().map(|line| (line, line)),
    });
    match parsed {
        Some(range) => (&line[..open], Some(range)),
        None => (line, None),
    }
}

fn parse_signature(rest: &str) -> Shape {
    let rest = rest.trim();
    let (args_text, outs_text) = if let Some(after) = rest.strip_prefix('>') {
        ("", after.trim())
    } else if let Some((before, after)) = rest.split_once(" > ") {
        (before, after)
    } else {
        (rest, "")
    };
    let args = args_text
        .split(',')
        .filter(|item| !item.trim().is_empty())
        .map(|item| {
            let words: Vec<&str> = item.split(' ').filter(|word| !word.is_empty()).collect();
            let (head, location, ty) = match words.as_slice() {
                [head, location, ty @ ..] if !ty.is_empty() => (*head, Some((*location).to_owned()), ty.join(" ")),
                [head, ty] => (*head, None, (*ty).to_owned()),
                [head] => (*head, None, "?".to_owned()),
                _ => ("", None, "?".to_owned()),
            };
            let (name, default) = match head.split_once('=') {
                Some((name, default)) => (name.to_owned(), Some(default.to_owned())),
                None => (head.to_owned(), None),
            };
            Arg { name, default, location, ty }
        })
        .collect();
    let mut outs: Vec<Out> = Vec::new();
    for item in outs_text.split(',').map(str::trim).filter(|item| !item.is_empty()) {
        let words: Vec<&str> = item.split(' ').filter(|word| !word.is_empty()).collect();
        match words.as_slice() {
            [word, regs @ ..] if matches!(*word, "scratch" | "clobber") => {
                outs.push(Out::Regs { word: (*word).to_owned(), regs: regs.iter().map(|reg| (*reg).to_owned()).collect() });
            }
            [single] if matches!(outs.last(), Some(Out::Regs { .. })) => {
                if let Some(Out::Regs { regs, .. }) = outs.last_mut() {
                    regs.push((*single).to_owned());
                }
            }
            [name, location, ty @ ..] => outs.push(Out::Result {
                name: (*name).to_owned(),
                location: (*location).to_owned(),
                ty: (!ty.is_empty()).then(|| ty.join(" ")),
            }),
            [name] => outs.push(Out::Result { name: (*name).to_owned(), location: String::new(), ty: None }),
            [] => {}
        }
    }
    Shape::Signature { args, outs }
}

impl fmt::Display for Entry {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.syntax.word())?;
        if self.local {
            write!(f, " local")?;
        }
        write!(f, " {}", self.name)?;
        match &self.shape {
            Shape::Line { ty } => {
                if let Some(ty) = ty {
                    write!(f, " {ty}")?;
                }
            }
            Shape::Signature { args, outs } => {
                let args: Vec<String> = args
                    .iter()
                    .map(|arg| {
                        let head = match &arg.default {
                            Some(default) => format!("{}={}", arg.name, default),
                            None => arg.name.clone(),
                        };
                        match &arg.location {
                            Some(location) => format!("{head} {location} {}", arg.ty),
                            None => format!("{head} {}", arg.ty),
                        }
                    })
                    .collect();
                if !args.is_empty() {
                    write!(f, " {}", args.join(","))?;
                }
                if !outs.is_empty() {
                    let outs: Vec<String> = outs
                        .iter()
                        .map(|out| match out {
                            Out::Result { name, location, ty: Some(ty) } => format!("{name} {location} {ty}"),
                            Out::Result { name, location, ty: None } => format!("{name} {location}"),
                            Out::Regs { word, regs } => format!("{word} {}", regs.join(",")),
                        })
                        .collect();
                    write!(f, " > {}", outs.join(","))?;
                }
            }
        }
        match self.range {
            Some((first, last)) if first == last => write!(f, " [{first}]")?,
            Some((first, last)) => write!(f, " [{first}:{last}]")?,
            None => {}
        }
        if let Some(summary) = &self.summary {
            write!(f, " :{summary}")?;
        }
        writeln!(f)?;
        for note in &self.notes {
            match &note.summary {
                Some(summary) => writeln!(f, " {} :{summary}", note.name)?,
                None => writeln!(f, " {}", note.name)?,
            }
        }
        Ok(())
    }
}

impl fmt::Display for Eye {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        for entry in &self.entries {
            write!(f, "{entry}")?;
        }
        Ok(())
    }
}
