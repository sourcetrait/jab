use crate::*;

/// A fresh directory under the tool workspace's own target for one test.
fn scratch(name: &str) -> PathBuf {
    let nanos = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
    let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("..").join("..").join("target").join("test").join(format!("{name}-{}-{nanos}", std::process::id()));
    fs::create_dir_all(&dir).expect("the scratch directory");
    fs::canonicalize(dir).expect("the scratch directory's own path")
}

/// Every file under `dir` whose name is `name`, at any depth.
fn found(dir: &Path, name: &str) -> Vec<PathBuf> {
    let mut out = Vec::new();
    let Ok(entries) = fs::read_dir(dir) else { return out };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            out.extend(found(&path, name));
        } else if path.file_name().and_then(|n| n.to_str()) == Some(name) || path.file_name().and_then(|n| n.to_str()).is_some_and(|n| n.starts_with(&format!("{name}."))) {
            out.push(path);
        }
    }
    out
}

#[test]
fn a_target_is_a_dot_target_or_a_checkout_under_jab_target() {
    assert_eq!(target_of(Path::new("/w/.target/release/x/f")), Some(PathBuf::from("/w/.target")));
    assert_eq!(target_of(Path::new("/c/jab/target/jab-12345678/debug/f")), Some(PathBuf::from("/c/jab/target/jab-12345678")));
    assert_eq!(target_of(Path::new("/w/tool/target/release/f")), None, "a cargo target is no jab target");
    assert_eq!(target_of(Path::new("/c/jab/x/f")), None);
}

#[test]
fn a_retired_file_moves_whole_into_the_targets_tmp_at_its_path_there() {
    let root = scratch("inside").join(".target");
    let file = root.join("release").join("f");
    fs::create_dir_all(file.parent().expect("a parent")).expect("the release directory");
    fs::write(&file, b"one").expect("the file");
    retire(&file, &root).expect("retired");
    assert!(!file.exists(), "the file left its place");
    let kept = found(&root.join("tmp").join("retired"), "f");
    assert_eq!(kept.len(), 1, "one retired copy: {kept:?}");
    assert!(kept[0].ends_with(Path::new("release").join("f")), "kept at its path in the target: {}", kept[0].display());
    assert_eq!(fs::read(&kept[0]).expect("the retired file"), b"one");

    fs::write(&file, b"two").expect("the file again");
    retire(&file, &root).expect("retired again");
    let kept = found(&root.join("tmp").join("retired"), "f");
    assert_eq!(kept.len(), 2, "the second retirement kept beside the first: {kept:?}");
}

#[test]
fn a_path_outside_the_target_lands_under_outside_at_its_absolute_path() {
    let base = scratch("outside");
    let root = base.join(".target");
    let file = base.join("elsewhere").join("g");
    fs::create_dir_all(file.parent().expect("a parent")).expect("the directory");
    fs::create_dir_all(base.join("sub")).expect("a sibling");
    fs::write(&file, b"g").expect("the file");
    retire(&base.join("sub").join("..").join("elsewhere").join("g"), &root).expect("retired");
    let kept = found(&root.join("tmp").join("retired"), "g");
    assert_eq!(kept.len(), 1, "one retired copy: {kept:?}");
    let tail = Path::new("outside").join(file.strip_prefix("/").expect("an absolute path"));
    assert!(kept[0].ends_with(&tail), "{} ends with {}", kept[0].display(), tail.display());
    let beside = kept[0].parent().and_then(Path::parent).expect("the retired base").join("sub");
    assert!(!beside.exists(), "a `..` in the path made {} in the retired tree", beside.display());
}

#[test]
fn nothing_there_is_nothing_retired() {
    let root = scratch("absent").join(".target");
    retire(&root.join("none"), &root).expect("nothing to do");
    assert!(!root.join("tmp").exists());
}
