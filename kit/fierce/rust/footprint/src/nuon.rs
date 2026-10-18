use crate::*;

/// A value as the tool writes it, NUON being the user-visible wire format.
#[derive(Clone, Debug, PartialEq)]
pub(crate) enum Nuon {
    Null,
    Bool(bool),
    Int(i64),
    Float(f64),
    Str(String),
    List(Vec<Nuon>),
    Record(Vec<(String, Nuon)>),
}

/// A record's key, bare where NUON takes it bare.
fn key(name: &str) -> String {
    let bare = name.chars().next().is_some_and(|c| c.is_ascii_alphabetic() || c == '_') && name.chars().all(|c| c.is_ascii_alphanumeric() || c == '_');
    if bare { name.to_string() } else { quoted(name) }
}

/// A string in double quotes, its quotes, backslashes, and controls escaped.
fn quoted(text: &str) -> String {
    let mut out = String::with_capacity(text.len() + 2);
    out.push('"');
    for c in text.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\t' => out.push_str("\\t"),
            '\r' => out.push_str("\\r"),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

impl fmt::Display for Nuon {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Nuon::Null => write!(f, "null"),
            Nuon::Bool(b) => write!(f, "{b}"),
            Nuon::Int(i) => write!(f, "{i}"),
            Nuon::Float(x) if x.is_finite() => write!(f, "{x:?}"),
            Nuon::Float(_) => write!(f, "null"),
            Nuon::Str(s) => write!(f, "{}", quoted(s)),
            Nuon::List(items) => {
                write!(f, "[")?;
                for (i, item) in items.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{item}")?;
                }
                write!(f, "]")
            }
            Nuon::Record(fields) => {
                write!(f, "{{")?;
                for (i, (name, value)) in fields.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{}: {value}", key(name))?;
                }
                write!(f, "}}")
            }
        }
    }
}

/// A record from its fields, each name a static string.
pub(crate) fn record(fields: Vec<(&str, Nuon)>) -> Nuon {
    Nuon::Record(fields.into_iter().map(|(name, value)| (name.to_string(), value)).collect())
}

/// A count as NUON's integer.
pub(crate) fn count(n: u64) -> Nuon {
    Nuon::Int(n as i64)
}
