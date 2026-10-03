use crate::*;

/// Writes a .eye.stub beside each source's .eye: every symbol the source
/// defines but those its .eye.ignore names, generated from the code, with
/// what an existing .eye says merged.
pub fn generate(src_dir: &Path, rel: &Path) -> EyeResult<()> {
    let src_dir = &checked_src_dir(src_dir)?;
    let srcdoc = srcdoc_dir(src_dir);
    let mut scanned: Vec<(PathBuf, Source)> = Vec::new();
    for dir in source_dirs(src_dir, Path::new("."))? {
        for file in dir.files {
            let path = src_dir.join(&file);
            let text = fs::read_to_string(&path).map_err(EyeError::io(&path))?;
            let source = if is_linker(&file) { scan_linker(&text) } else { scan_asm(&text) };
            scanned.push((file, source));
        }
    }
    let tree = tree(&scanned.iter().map(|(_, source)| source).collect::<Vec<_>>());
    for dir in source_dirs(src_dir, rel)? {
        for file in dir.files {
            let Some((_, source)) = scanned.iter().find(|(scanned, _)| *scanned == file) else { continue };
            let eye = eye_path(&srcdoc, &file);
            let existing = match read_if_present(&eye)? {
                Some(text) => Eye::parse(&text, &eye)?,
                None => Eye::default(),
            };
            let ignore = ignore_path(&srcdoc, &file);
            let ignored = match read_if_present(&ignore)? {
                Some(text) => ignored_names(&text, &ignore)?,
                None => HashSet::new(),
            };
            let made: Vec<Gen> = gens(source, &tree).into_iter().filter(|made| !ignored.contains(&made.entry.name)).collect();
            let entries = merge(made, &existing);
            let stub = stub_path(&srcdoc, &file);
            if let Some(parent) = stub.parent() {
                fs::create_dir_all(parent).map_err(EyeError::io(parent))?;
            }
            fs::write(&stub, Eye { entries }.to_string()).map_err(EyeError::io(&stub))?;
        }
    }
    Ok(())
}

fn read_if_present(path: &Path) -> EyeResult<Option<String>> {
    match fs::read_to_string(path) {
        Ok(text) => Ok(Some(text)),
        Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(None),
        Err(error) => Err(EyeError::io(path)(error)),
    }
}

/// The names an .eye.ignore lists, one `<syntax> [local] <name>` a line.
pub(crate) fn ignored_names(text: &str, what: &Path) -> EyeResult<HashSet<String>> {
    let mut names = HashSet::new();
    for (index, line) in text.lines().enumerate() {
        let words: Vec<&str> = line.split_whitespace().collect();
        let name = match words.as_slice() {
            [] => continue,
            [syntax, "local", name] | [syntax, name] if Syntax::parse(syntax).is_some() => name,
            _ => {
                let message = "not a `<syntax> [local] <name>` line".to_owned();
                return Err(EyeError::Parse { what: what.display().to_string(), line: index + 1, message });
            }
        };
        names.insert((*name).to_owned());
    }
    Ok(names)
}
