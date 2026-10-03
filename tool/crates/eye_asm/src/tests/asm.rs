use crate::*;

const SOURCE: &str = "\
.include \"jab.inc\"
.set TICK, (TIMEBASE / 30)
.macro jab.demo.step dst, state, count=1
    ld t0, 0(\\state)
.Ldemo\\@:
    addi \\dst, t0, \\count
.endm

.section .text
.global step       # a side comment
step:
    li t0, 1
.pushsection .rodata
message:
    .asciz \"a # inside\"
.popsection
    ret

.section .bss
.balign 8
counter:
    .skip 8
LIMIT = 4
";

#[test]
fn every_kind_of_symbol_in_order_with_its_lines() {
    let source = scan_asm(SOURCE);
    let names: Vec<(&str, usize, usize)> =
        source.symbols.iter().map(|symbol| (symbol.name.as_str(), symbol.first, symbol.last)).collect();
    assert_eq!(
        names,
        [("TICK", 2, 2), ("jab.demo.step", 3, 7), ("step", 11, 17), ("message", 14, 15), ("counter", 21, 22), ("LIMIT", 23, 23)]
    );
}

#[test]
fn a_macro_keeps_its_parameters_and_body() {
    let source = scan_asm(SOURCE);
    let Def::Macro { params, body } = &source.symbols[1].def else { panic!("not a macro") };
    assert_eq!(params[2], Param { name: "count".to_owned(), default: Some("1".to_owned()) });
    assert_eq!(body.len(), 2);
}

#[test]
fn a_routine_keeps_its_statements_past_a_pushed_section() {
    let source = scan_asm(SOURCE);
    let Def::Label { section, global, stmts } = &source.symbols[2].def else { panic!("not a label") };
    assert_eq!((*section, *global), (Section::Text, true));
    let ops: Vec<&str> = stmts.iter().map(|stmt| stmt.op.as_str()).collect();
    assert_eq!(ops, ["li", "ret"]);
    let Def::Label { section, global, .. } = &source.symbols[3].def else { panic!("not a label") };
    assert_eq!((*section, *global), (Section::Rodata, false));
}

#[test]
fn comments_respect_quotes() {
    assert_eq!(strip_comment("li a0, '#' # the hash"), "li a0, '#' ");
    assert_eq!(strip_comment(".asciz \"#8F00FF\""), ".asciz \"#8F00FF\"");
}

#[test]
fn operands_split_at_top_level_commas() {
    let stmt = parse_stmt("sw a3, JAB_RECT_X(t0)", 1);
    assert_eq!(stmt.op, "sw");
    assert_eq!(stmt.args, ["a3", "JAB_RECT_X(t0)"]);
}

#[test]
fn a_linker_script_defines_what_it_assigns() {
    let source = scan_linker("/* the start\n   of RAM */\n. = 0x80000000;\n_bss_start = .;\nPROVIDE(_end = .);\n");
    let names: Vec<(&str, usize)> = source.symbols.iter().map(|symbol| (symbol.name.as_str(), symbol.first)).collect();
    assert_eq!(names, [("_bss_start", 4), ("_end", 5)]);
}
