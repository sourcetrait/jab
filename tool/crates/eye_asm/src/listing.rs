use crate::*;

/// What eye-asm prints, and the sources it found no .eye for.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Listing {
    pub text: String,
    pub missing: Vec<PathBuf>,
}

/// The .eye of a source, or every .eye under a directory: a directory
/// line, then each source's name and its .eye.
pub fn listing(src_dir: &Path, rel: &Path) -> EyeResult<Listing> {
    let src_dir = &checked_src_dir(src_dir)?;
    let srcdoc = srcdoc_dir(src_dir);
    let mut listing = Listing::default();
    if src_dir.join(within(rel)?).is_file() {
        let rel = within(rel)?;
        append_eye(&mut listing, &srcdoc, &rel)?;
        return Ok(listing);
    }
    let mut previous: Option<PathBuf> = None;
    for dir in source_dirs(src_dir, rel)? {
        listing.text.push_str(&dir_line(previous.as_deref(), &dir.rel));
        listing.text.push('\n');
        for file in &dir.files {
            let name = file.file_name().map(|name| name.to_string_lossy().into_owned()).unwrap_or_default();
            listing.text.push_str(&name);
            listing.text.push('\n');
            append_eye(&mut listing, &srcdoc, file)?;
        }
        previous = Some(dir.rel);
    }
    Ok(listing)
}

/// A directory's line: relative to the directory listed before it when
/// it lies under that one, else from the source directory with `./`.
pub(crate) fn dir_line(previous: Option<&Path>, dir: &Path) -> String {
    let under = previous.and_then(|previous| dir.strip_prefix(previous).ok()).filter(|rest| !rest.as_os_str().is_empty());
    match under {
        Some(rest) => format!("{}/", rest.display()),
        None if dir.as_os_str().is_empty() => "./".to_owned(),
        None => format!("./{}/", dir.display()),
    }
}

fn append_eye(listing: &mut Listing, srcdoc: &Path, file: &Path) -> EyeResult<()> {
    let eye = eye_path(srcdoc, file);
    match fs::read_to_string(&eye) {
        Ok(text) => {
            listing.text.push_str(&text);
            if !text.is_empty() && !text.ends_with('\n') {
                listing.text.push('\n');
            }
        }
        Err(error) if error.kind() == io::ErrorKind::NotFound => listing.missing.push(file.to_path_buf()),
        Err(error) => return Err(EyeError::io(&eye)(error)),
    }
    Ok(())
}
