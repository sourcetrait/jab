use crate::*;

#[test]
fn names_resolve_to_abi_names() {
    assert_eq!(register("a0"), Some("a0"));
    assert_eq!(register("x10"), Some("a0"));
    assert_eq!(register("fp"), Some("s0"));
    assert_eq!(register("f10"), Some("fa0"));
    assert_eq!(register("ft11"), Some("ft11"));
    assert_eq!(register("JAB_X"), None);
}

#[test]
fn a_memory_form_names_its_base() {
    assert_eq!(operand_register("80(sp)"), Some("sp"));
    assert_eq!(operand_register("JAB_PAD_KEYS(a0)"), Some("a0"));
    assert_eq!(operand_register("0x10"), None);
}

#[test]
fn runs_become_ranges_in_class_order() {
    let regs: BTreeSet<&'static str> = ["a7", "t1", "ft0", "a2", "a3", "a4", "t0", "s1"].into_iter().collect();
    assert_eq!(reg_list(&regs), ["t0-t1", "a2-a4", "a7", "s1", "ft0"]);
}

#[test]
fn ranges_expand() {
    assert_eq!(expand_regs("a2-a5"), ["a2", "a3", "a4", "a5"]);
    assert_eq!(expand_regs("a7"), ["a7"]);
}

#[test]
fn argument_registers_have_positions() {
    assert_eq!(argument_index("a3"), Some(3));
    assert_eq!(argument_index("s3"), None);
    assert_eq!(argument_name(2), "a2");
    assert!(is_saved("s11"));
    assert!(!is_saved("sp"));
}
