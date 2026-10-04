use crate::*;

/// Moves `path` out of the way whole in place of deleting it, as the
/// SDK's `retire` does, so nothing the harness clears away is lost: into
/// the target's own tmp, `<root>/tmp/retired/<stamp>/`, at its path in the
/// target, or under `outside/` at its absolute path when it lies outside
/// it; a second retirement of one path within a second takes a numbered
/// name. Nothing when nothing is there; a link, a fifo, or a socket is
/// moved as it is. Across filesystems a file is copied and then unlinked,
/// as `mv` moves one; anything else there is refused.
pub(crate) fn retire(path: &Path, root: &Path) -> RoboResult<()> {
    if fs::symlink_metadata(path).is_err() {
        return Ok(());
    }
    let from = std::path::absolute(path).map_err(RoboError::io(path.display().to_string()))?;
    let base = root.join("tmp").join("retired").join(stamp()?);
    let at = match from.strip_prefix(root) {
        Ok(rest) => base.join(rest),
        Err(_) => base.join("outside").join(from.strip_prefix("/").unwrap_or(&from)),
    };
    let mut dest = at.clone();
    let mut n = 1;
    while fs::symlink_metadata(&dest).is_ok() {
        dest = PathBuf::from(format!("{}.{n}", at.display()));
        n += 1;
    }
    if let Some(parent) = dest.parent() {
        fs::create_dir_all(parent).map_err(RoboError::io(parent.display().to_string()))?;
    }
    let what = format!("retiring {} to {}", from.display(), dest.display());
    match fs::rename(&from, &dest) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == io::ErrorKind::CrossesDevices && fs::symlink_metadata(&from).is_ok_and(|m| m.is_file()) => {
            fs::copy(&from, &dest).map_err(RoboError::io(what.clone()))?;
            fs::remove_file(&from).map_err(RoboError::io(what))
        }
        Err(error) => Err(RoboError::Io { what, source: error }),
    }
}

/// The target a path lies in, the nearest of its parents that is one, as
/// the SDK's target-root makes them: a `.target` directory, or a
/// checkout's under `jab/target` in the XDG cache.
pub(crate) fn target_of(path: &Path) -> Option<PathBuf> {
    let name = |p: Option<&Path>| p.and_then(Path::file_name).and_then(|n| n.to_str()).map(str::to_owned);
    let mut dir = path.parent();
    while let Some(d) = dir {
        let parent = d.parent();
        if name(Some(d)).as_deref() == Some(".target") || (name(parent).as_deref() == Some("target") && name(parent.and_then(Path::parent)).as_deref() == Some("jab")) {
            return Some(d.to_path_buf());
        }
        dir = parent;
    }
    None
}

/// The local time to the second, as the SDK stamps a retirement.
fn stamp() -> RoboResult<String> {
    let out = Command::new("date").arg("+%Y%m%d-%H%M%S").output().map_err(RoboError::io("date"))?;
    let text = String::from_utf8_lossy(&out.stdout).trim().to_owned();
    if !out.status.success() || text.is_empty() {
        return Err(RoboError::Retire("date gave no stamp".to_owned()));
    }
    Ok(text)
}
