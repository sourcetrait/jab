use crate::*;
use crate::generate::ignored_names;

const EYE: &str = "\
call frame_flipped > tick frame_tick u64,told frame_reported u64 [26:37] :a flip went through now
 tick :one period on
 told
ecall sys_await mask u64 > events a0 u64
macro jab.sys.exit status=0 imm > scratch a0,a7
macro jab.rng.byte dst reg,state addr > byte dst u8,word 0(state) u64,scratch t0-t1 [9:20]
 byte :bits 24 to 31 of the new word
j local frame [134:223]
";

#[test]
fn an_eye_round_trips() {
    let eye = Eye::parse(EYE, Path::new("test.eye")).expect("parses");
    assert_eq!(eye.to_string(), EYE);
}

#[test]
fn a_summary_ends_the_head_line() {
    let eye = Eye::parse(EYE, Path::new("test.eye")).expect("parses");
    assert_eq!(eye.entries[0].summary.as_deref(), Some("a flip went through now"));
    assert_eq!(eye.entries[0].range, Some((26, 37)));
    assert_eq!(eye.entries[1].summary, None);
    assert_eq!(eye.entries[4].range, Some((134, 223)));
    assert!(eye.entries[4].args.is_empty() && eye.entries[4].outs.is_empty());
}

#[test]
fn a_note_is_a_name_and_maybe_a_summary() {
    let eye = Eye::parse(EYE, Path::new("test.eye")).expect("parses");
    assert_eq!(
        eye.entries[0].notes,
        [
            Note { name: "tick".to_owned(), summary: Some("one period on".to_owned()) },
            Note { name: "told".to_owned(), summary: None },
        ]
    );
    assert!(Eye::parse("call f x u64\n x the first\n", Path::new("test.eye")).is_err());
}

#[test]
fn a_one_word_item_continues_the_list_before_it() {
    let eye = Eye::parse(EYE, Path::new("test.eye")).expect("parses");
    let entry = &eye.entries[2];
    assert_eq!(entry.args[0], Arg { name: "status".to_owned(), default: Some("0".to_owned()), location: None, ty: "imm".to_owned() });
    assert_eq!(entry.outs, [Out::Regs { word: "scratch".to_owned(), regs: vec!["a0".to_owned(), "a7".to_owned()] }]);
}

#[test]
fn an_argument_off_the_calling_convention_carries_its_location() {
    let text = "call feet_move ox fs0 f64,n u64 > x fs0 f64 [3:9]\n";
    let eye = Eye::parse(text, Path::new("test.eye")).expect("parses");
    let args = &eye.entries[0].args;
    assert_eq!(args[0], Arg { name: "ox".to_owned(), default: None, location: Some("fs0".to_owned()), ty: "f64".to_owned() });
    assert_eq!(args[1].location, None);
    assert_eq!(eye.to_string(), text);
}

#[test]
fn a_body_line_before_any_entry_is_refused() {
    assert!(Eye::parse(" stray\n", Path::new("test.eye")).is_err());
    assert!(Eye::parse("nope TICK\n", Path::new("test.eye")).is_err());
}

#[test]
fn constants_and_data_are_no_entries() {
    assert!(Eye::parse("set TICK u64 [5] :a frame period\n", Path::new("test.eye")).is_err());
    assert!(Eye::parse("bss local frame_tick u64 [221:222]\n", Path::new("test.eye")).is_err());
    assert!(Eye::parse("rodata local k_one f32 [13:14]\n", Path::new("test.eye")).is_err());
    assert!(Eye::parse("data counter u32\n", Path::new("test.eye")).is_err());
    assert!(Eye::parse("ld _bss_start [4]\n", Path::new("test.eye")).is_err());
}

#[test]
fn an_ignore_file_names_one_symbol_a_line() {
    let names = ignored_names("macro jab.demo\n\ncall local helper\nj loop\n", Path::new("test.eye.ignore")).expect("parses");
    assert_eq!(names, HashSet::from(["jab.demo".to_owned(), "helper".to_owned(), "loop".to_owned()]));
    assert!(ignored_names("FOO\n", Path::new("test.eye.ignore")).is_err());
    assert!(ignored_names("set FOO\n", Path::new("test.eye.ignore")).is_err());
}
