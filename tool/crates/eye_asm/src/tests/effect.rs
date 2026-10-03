use crate::*;

fn facts(text: &str) -> MacroFacts {
    let source = scan_asm(text);
    let Def::Macro { params, body } = &source.symbols[0].def else { panic!("not a macro") };
    macro_facts(params, body, &HashMap::new())
}

#[test]
fn operand_kinds_follow_the_body() {
    let facts = facts(
        ".macro m dst, text, size, value\n    la a0, \\text\n    li a1, \\size\n    mv a2, \\value\n    srli \\dst, a2, 4\n.endm\n",
    );
    assert_eq!(facts.kinds, [Kind::Reg, Kind::Label, Kind::Imm, Kind::Value]);
    assert_eq!(facts.outputs, [true, false, false, false]);
    assert_eq!(facts.writes.iter().copied().collect::<Vec<_>>(), ["a0", "a1", "a2"]);
    assert!(facts.complete);
}

#[test]
fn a_base_register_is_a_value_and_an_offset_an_immediate() {
    let facts = facts(".macro m state, field\n    ld t0, \\field(\\state)\n.endm\n");
    assert_eq!(facts.kinds, [Kind::Value, Kind::Imm]);
}

#[test]
fn an_operand_read_before_it_is_written_is_a_value_changed_in_place() {
    let facts = facts(".macro m x, y\n    fmul.s \\x, \\x, \\y\n.endm\n");
    assert_eq!(facts.kinds, [Kind::Value, Kind::Value]);
    assert_eq!(facts.outputs, [true, false]);
}

#[test]
fn an_operand_in_a_data_directive_is_an_immediate() {
    let facts = facts(".macro m wave, note\n    .if \\note\n    .byte \\wave, 0\n    .endif\n.endm\n");
    assert_eq!(facts.kinds, [Kind::Imm, Kind::Unknown]);
}

#[test]
fn a_macro_inside_a_macro_passes_its_operands_through() {
    let source = scan_asm(
        ".macro inner dst, src\n    addi \\dst, \\src, 1\n.endm\n.macro outer out, base\n    inner \\out, \\base\n    inner t2, \\base\n.endm\n",
    );
    let tree = tree(&[&source]);
    let outer = &tree.macros["outer"];
    assert_eq!(outer.kinds, [Kind::Reg, Kind::Value]);
    assert_eq!(outer.outputs, [true, false]);
    assert_eq!(outer.writes.iter().copied().collect::<Vec<_>>(), ["t2"]);
}

#[test]
fn a_foreign_macro_leaves_the_facts_incomplete() {
    let facts = facts(".macro m\n    jab.sys.print hello\n.endm\n");
    assert!(!facts.complete);
}

#[test]
fn an_instruction_writes_its_first_operand() {
    let effect = effect(&parse_stmt("add a0, a1, a2", 1), &HashMap::new());
    assert_eq!((effect.reads, effect.writes), (vec!["a1", "a2"], vec!["a0"]));
    let store = effect_of("sd a0, 80(sp)");
    assert_eq!((store.reads, store.writes), (vec!["a0", "sp"], vec![]));
}

#[test]
fn a_call_changes_the_caller_saved_registers() {
    let call = effect_of("call frame_flipped");
    assert!(call.call);
    assert!(call.writes.contains(&"a0") && call.writes.contains(&"t6") && !call.writes.contains(&"s0"));
}

#[test]
fn a_foreign_macro_is_taken_for_a_call() {
    let foreign = effect_of("jab.sys.print a0");
    assert!(foreign.call);
    assert!(foreign.writes.contains(&"a0"));
}

#[test]
fn an_ecall_changes_nothing_itself() {
    let ecall = effect_of("ecall");
    assert!(ecall.writes.is_empty() && !ecall.call);
}

fn effect_of(text: &str) -> Effect {
    effect(&parse_stmt(text, 1), &HashMap::new())
}
