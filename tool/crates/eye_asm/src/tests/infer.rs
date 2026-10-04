use crate::*;

const SOURCE: &str = "\
.section .text
.global sys_demo
sys_demo:
    ld s2, 88(sp)
    mv s0, a0
    call helper
    sd a0, 80(sp)
    j trap_return
helper:
    add a0, a0, a1
    li s1, 0
    ret
table:
    .quad sys_demo
.section .bss
words:
    .8byte 0, 0, 0
";

fn generated() -> Vec<Gen> {
    let source = scan_asm(SOURCE);
    let tree = tree(&[&source]);
    gens(&source, &tree)
}

#[test]
fn how_a_label_is_entered_decides_its_syntax_and_data_gives_none() {
    let gens = generated();
    let syntax: Vec<(&str, Syntax, bool)> = gens.iter().map(|made| (made.entry.name.as_str(), made.entry.syntax, made.entry.local)).collect();
    assert_eq!(syntax, [("sys_demo", Syntax::Ecall, false), ("helper", Syntax::Call, true)]);
}

#[test]
fn a_handler_takes_its_frame_slots_and_live_registers() {
    let gens = generated();
    let entry = &gens[0].entry;
    assert_eq!(entry.args.iter().map(|arg| arg.name.as_str()).collect::<Vec<_>>(), ["a0", "a1"]);
    assert_eq!(entry.outs, [Out::Result { name: "a0".to_owned(), location: "a0".to_owned(), ty: Some("?".to_owned()) }]);
}

#[test]
fn a_routine_names_what_it_writes_and_the_saved_registers_it_changes() {
    let gens = generated();
    let entry = &gens[1].entry;
    assert_eq!(entry.args.len(), 2);
    assert_eq!(
        entry.outs,
        [
            Out::Result { name: "a0".to_owned(), location: "a0".to_owned(), ty: Some("?".to_owned()) },
            Out::Regs { word: "clobber".to_owned(), regs: vec!["s1".to_owned()] },
        ]
    );
}

#[test]
fn a_label_that_returns_is_a_routine_however_it_is_reached() {
    let source = scan_asm(".global front\nfront:\n    li a0, 1\n    j back\nback:\n    addi a0, a0, 1\n    ret\nloop:\n    j loop\n");
    let tree = tree(&[&source]);
    let gens = gens(&source, &tree);
    let syntax: Vec<(&str, Syntax, bool)> = gens.iter().map(|made| (made.entry.name.as_str(), made.entry.syntax, made.certain)).collect();
    assert_eq!(syntax, [("front", Syntax::J, false), ("back", Syntax::Call, false), ("loop", Syntax::J, false)]);
}

#[test]
fn a_saved_register_and_a_system_call_result_are_no_arguments() {
    let source = scan_asm(
        "f:\n    addi sp, sp, -16\n    sd a1, 8(sp)\n    mv a0, t0\n    li a7, 3\n    ecall\n    mv t1, a2\n    ld a1, 8(sp)\n    addi sp, sp, 16\n    ret\n",
    );
    let tree = tree(&[&source]);
    assert!(gens(&source, &tree)[0].entry.args.is_empty());
}

#[test]
fn an_operand_in_an_offset_is_an_immediate() {
    let source = scan_asm(".macro m kind, reg\n    la \\reg, table\n    ld \\reg, (BASE + 8 * (\\kind - 1))(\\reg)\n.endm\n");
    let tree = tree(&[&source]);
    assert_eq!(tree.macros["m"].kinds, [Kind::Imm, Kind::Reg]);
}

#[test]
fn data_directives_say_their_bytes_when_every_one_does() {
    assert_eq!(data_bytes(&[parse_stmt(".8byte 0, 0, 0", 1)]), Some(24));
    assert_eq!(data_bytes(&[parse_stmt(".balign 8", 1), parse_stmt(".asciz \"ab\"", 2)]), Some(3));
    assert_eq!(data_bytes(&[parse_stmt(".skip MAX_ACTORS", 1)]), None);
    assert_eq!(data_bytes(&[parse_stmt("ret", 1)]), None);
}
