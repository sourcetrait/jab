use crate::*;

/// Replaces each source's .eye with its .eye.stub. Replaces nothing unless
/// every source has a stub, every stub parses, and every .eye replaced is a
/// plain file.
pub fn done(src_dir: &Path, rel: &Path) -> EyeResult<()> {
    let src_dir = &checked_src_dir(src_dir)?;
    let srcdoc = srcdoc_dir(src_dir);
    let pairs: Vec<(PathBuf, PathBuf)> = source_dirs(src_dir, rel)?
        .into_iter()
        .flat_map(|dir| dir.files)
        .map(|file| (stub_path(&srcdoc, &file), eye_path(&srcdoc, &file)))
        .collect();
    let missing: Vec<PathBuf> = pairs.iter().filter(|(stub, _)| !stub.is_file()).map(|(stub, _)| stub.clone()).collect();
    if !missing.is_empty() {
        return Err(EyeError::MissingStubs(missing));
    }
    for (stub, eye) in &pairs {
        let text = fs::read_to_string(stub).map_err(EyeError::io(stub))?;
        Eye::parse(&text, stub)?;
        match fs::symlink_metadata(eye) {
            Ok(meta) if !meta.is_file() => {
                return Err(EyeError::Path(format!("{} is not a plain file; no .eye was replaced", eye.display())));
            }
            Ok(_) => {}
            Err(error) if error.kind() == io::ErrorKind::NotFound => {}
            Err(error) => return Err(EyeError::io(eye)(error)),
        }
    }
    for (stub, eye) in pairs {
        fs::rename(&stub, &eye).map_err(EyeError::io(&stub))?;
    }
    Ok(())
}
