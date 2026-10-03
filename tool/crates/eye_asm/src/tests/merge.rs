use crate::*;

const SOURCE: &str = "\
.set TICK, 5
.macro jab.rng.byte dst, state
    ld t0, 0(\\state)
    slli t1, t0, 13
    srli \\dst, t0, 24
.endm
.section .bss
frame_tick:
    .skip 8
";

const OLD: &str = "\
set TICK u64 :a frame period
set GONE u64 :a constant no longer there
macro jab.rng.byte dst reg,state addr,seed u64 > byte dst u8,word 0(state) u64,scratch t0 :the next byte
 byte :bits 24 to 31 of the new word
 seed :the note of an operand the macro no longer takes
bss local frame_tick u64 :the time of the next tick
";

fn stub(source: &str, old: &str) -> String {
    let source = scan_asm(source);
    let tree = tree(&[&source]);
    let old = Eye::parse(old, Path::new("old.eye")).expect("parses");
    Eye { entries: merge(gens(&source, &tree), &old) }.to_string()
}

#[test]
fn what_the_eye_says_carries_over_and_the_code_settles_the_rest() {
    assert_eq!(
        stub(SOURCE, OLD),
        "\
set TICK u64 [1] :a frame period
macro jab.rng.byte dst reg,state addr > byte dst u8,word 0(state) u64,scratch t0-t1 [2:6] :the next byte
 byte :bits 24 to 31 of the new word
bss local frame_tick u64 [8:9] :the time of the next tick
"
    );
}

#[test]
fn a_symbol_the_eye_lacks_comes_from_the_code_alone() {
    let stub = stub(SOURCE, "");
    assert!(stub.contains("macro jab.rng.byte dst reg,state ? > dst dst ?,scratch t0-t1 [2:6]\n"));
    assert!(stub.contains("bss local frame_tick 8 u8 [8:9]\n"));
}

#[test]
fn an_operand_changed_in_place_keeps_its_value_type() {
    let source = ".macro m x, y\n    fmul.s \\x, \\x, \\y\n    fmv.s ft0, \\x\n.endm\n";
    assert_eq!(
        stub(source, "macro m x f32,y f32 > scratch ft0 :x scaled by y\n"),
        "macro m x f32,y f32 > scratch ft0 [1:4] :x scaled by y\n"
    );
}

#[test]
fn an_operand_the_code_reads_is_no_immediate() {
    let source = ".macro m x\n    mv a0, \\x\n.endm\n";
    assert_eq!(stub(source, "macro m x imm > scratch a0\n"), "macro m x ? > scratch a0 [1:3]\n");
}

#[test]
fn an_operand_the_eye_lists_as_scratch_stays_scratch() {
    let source = ".macro m dst, tmp\n    li \\tmp, 255\n    and \\dst, \\dst, \\tmp\n.endm\n";
    let old = "macro m dst u64,tmp reg > dst dst u8,scratch tmp\n";
    assert_eq!(stub(source, old), "macro m dst u64,tmp reg > dst dst u8,scratch tmp [1:4]\n");
}

#[test]
fn inputs_the_eye_places_in_registers_stay_and_an_unchanged_list_keeps_its_order() {
    let source = ".macro m\n    add a2, a0, a7\n    mv t0, a2\n.endm\n";
    let old = "macro m left a0 u32,right a7 u32 > sum a2 u32,scratch t0\n left :the left texel\n";
    assert_eq!(stub(source, old), "macro m left a0 u32,right a7 u32 > sum a2 u32,scratch t0 [1:4]\n left :the left texel\n");
    let source = ".macro m\n    li a0, 1\n    li t3, 2\n.endm\n";
    assert_eq!(stub(source, "macro m > scratch a0,t3\n"), "macro m > scratch a0,t3 [1:4]\n");
}

#[test]
fn a_narrow_type_inside_its_reservation_stays() {
    let source = ".section .bss\nflag:\n    .skip 8\nwide:\n    .skip 4\n";
    assert_eq!(
        stub(source, "bss local flag u8 :the flag\nbss local wide u64 :the word\n"),
        "bss local flag u8 [2:3] :the flag\nbss local wide 4 u8 [4:5] :the word\n"
    );
}

#[test]
fn a_routine_keeps_the_signature_the_eye_gives_it() {
    let source = "f:\n    add a0, a0, a1\n    ret\n";
    assert_eq!(stub(source, "call local f x u64 > x a0 u64 :x and more\n"), "call local f x u64 > x a0 u64 [1:3] :x and more\n");
}
