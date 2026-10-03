use crate::*;
use crate::listing::dir_line;

#[test]
fn a_src_directory_has_its_srcdoc_beside_it() {
    assert_eq!(srcdoc_dir(Path::new("kernel/src")), PathBuf::from("kernel/srcdoc"));
    assert_eq!(eye_path(Path::new("kernel/srcdoc"), Path::new("include/riscv.inc")), PathBuf::from("kernel/srcdoc/include/riscv.inc.eye"));
}

#[test]
fn a_path_may_not_leave_the_source_directory() {
    assert!(within(Path::new("../kernel")).is_err());
    assert!(within(Path::new("/etc")).is_err());
    assert_eq!(within(Path::new("./include/riscv.inc")).expect("within"), PathBuf::from("include/riscv.inc"));
}

#[test]
fn a_directory_line_is_relative_to_the_one_before_it_when_under_it() {
    assert_eq!(dir_line(None, Path::new("")), "./");
    assert_eq!(dir_line(Some(Path::new("")), Path::new("include")), "include/");
    assert_eq!(dir_line(Some(Path::new("include")), Path::new("include/deep")), "deep/");
    assert_eq!(dir_line(Some(Path::new("include/deep")), Path::new("other")), "./other/");
    assert_eq!(dir_line(None, Path::new("include")), "./include/");
}
