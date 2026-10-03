use crate::*;

/// A source directory as given, made absolute: it must exist and be a `src`.
pub(crate) fn checked_src_dir(given: &Path) -> EyeResult<PathBuf> {
    let src_dir = fs::canonicalize(given).map_err(EyeError::io(given))?;
    match src_dir.file_name() {
        Some(name) if name == "src" && src_dir.is_dir() => Ok(src_dir),
        _ => Err(EyeError::Path(format!("{} is not a src directory", given.display()))),
    }
}

/// The srcdoc directory beside a source directory.
pub(crate) fn srcdoc_dir(src_dir: &Path) -> PathBuf {
    src_dir.with_file_name("srcdoc")
}

/// The .eye of a source, by its path within the source directory.
pub(crate) fn eye_path(srcdoc: &Path, rel_file: &Path) -> PathBuf {
    appended(srcdoc.join(rel_file), ".eye")
}

/// The .eye.stub the generator writes for a source.
pub(crate) fn stub_path(srcdoc: &Path, rel_file: &Path) -> PathBuf {
    appended(srcdoc.join(rel_file), ".eye.stub")
}

/// The .eye.ignore naming a source's symbols its .eye never lists.
pub(crate) fn ignore_path(srcdoc: &Path, rel_file: &Path) -> PathBuf {
    appended(srcdoc.join(rel_file), ".eye.ignore")
}

fn appended(path: PathBuf, suffix: &str) -> PathBuf {
    let mut text = path.into_os_string();
    text.push(suffix);
    PathBuf::from(text)
}

/// True for a file the convention covers: assembly, an include, a linker
/// script.
pub(crate) fn is_source(path: &Path) -> bool {
    path.extension().is_some_and(|ext| ext == "S" || ext == "s" || ext == "inc" || ext == "ld")
}

/// True for a linker script.
pub(crate) fn is_linker(path: &Path) -> bool {
    path.extension().is_some_and(|ext| ext == "ld")
}

/// A directory's sources, by paths within the source directory.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct SourceDir {
    pub(crate) rel: PathBuf,
    pub(crate) files: Vec<PathBuf>,
}

/// A path within the source directory, refused when it would leave it.
pub(crate) fn within(rel: &Path) -> EyeResult<PathBuf> {
    let mut out = PathBuf::new();
    for component in rel.components() {
        match component {
            Component::Normal(part) => out.push(part),
            Component::CurDir => {}
            _ => return Err(EyeError::Path(format!("{} is not a path within the source directory", rel.display()))),
        }
    }
    Ok(out)
}

/// The sources at or under a path within the source directory, grouped by
/// directory, in order; hidden entries and build trees are passed over.
pub(crate) fn source_dirs(src_dir: &Path, rel: &Path) -> EyeResult<Vec<SourceDir>> {
    let rel = within(rel)?;
    let start = src_dir.join(&rel);
    if start.is_file() {
        let parent = rel.parent().map(Path::to_path_buf).unwrap_or_default();
        return Ok(vec![SourceDir { rel: parent, files: vec![rel] }]);
    }
    if !start.is_dir() {
        return Err(EyeError::Path(format!("{} is no file or directory", start.display())));
    }
    let mut out = Vec::new();
    walk(&start, &rel, &mut out)?;
    Ok(out)
}

fn walk(dir: &Path, rel: &Path, out: &mut Vec<SourceDir>) -> EyeResult<()> {
    let mut entries: Vec<PathBuf> =
        fs::read_dir(dir).map_err(EyeError::io(dir))?.filter_map(|entry| entry.ok().map(|entry| entry.path())).collect();
    entries.sort();
    let mut files = Vec::new();
    let mut dirs = Vec::new();
    for path in entries {
        let Some(name) = path.file_name().and_then(|name| name.to_str()) else { continue };
        if name.starts_with('.') || name == "target" {
            continue;
        }
        if path.is_dir() {
            dirs.push(path);
        } else if is_source(&path) {
            files.push(rel.join(name));
        }
    }
    if !files.is_empty() {
        out.push(SourceDir { rel: rel.to_path_buf(), files });
    }
    for path in dirs {
        let name = path.file_name().map(PathBuf::from).unwrap_or_default();
        walk(&path, &rel.join(name), out)?;
    }
    Ok(())
}
