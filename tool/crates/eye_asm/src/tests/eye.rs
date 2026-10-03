use crate::*;
use crate::generate::ignored_names;

const EYE: &str = "\
set TICK u64 [5] :a frame period in time ticks
set JAB_PAD_AXES 64 i16 :every axis at its JAB_ABS_* code
call frame_flipped > tick frame_tick u64,told frame_reported u64 [26:37] :a flip went through now
 tick :one period on
 told
ecall sys_await mask u64 > events a0 u64
macro jab.sys.exit status=0 imm > scratch a0,a7
macro jab.rng.byte dst reg,state address > byte dst u8,word 0(state) u64,scratch t0-t1 [9:20]
 byte :bits 24 to 31 of the new word
bss local frame_tick u64 [221:222] :the time of the next tick
";

#[test]
fn an_eye_round_trips() {
    let eye = Eye::parse(EYE, Path::new("test.eye")).expect("parses");
    assert_eq!(eye.to_string(), EYE);
}

#[test]
fn a_summary_ends_the_head_line() {
    let eye = Eye::parse(EYE, Path::new("test.eye")).expect("parses");
    assert_eq!(eye.entries[1].shape, Shape::Line { ty: Some("64 i16".to_owned()) });
    assert_eq!(eye.entries[1].summary.as_deref(), Some("every axis at its JAB_ABS_* code"));
    assert_eq!(eye.entries[0].range, Some((5, 5)));
    assert_eq!(eye.entries[2].summary.as_deref(), Some("a flip went through now"));
    assert_eq!(eye.entries[3].summary, None);
}

#[test]
fn a_note_is_a_name_and_maybe_a_summary() {
    let eye = Eye::parse(EYE, Path::new("test.eye")).expect("parses");
    assert_eq!(
        eye.entries[2].notes,
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
    let Shape::Signature { args, outs } = &eye.entries[4].shape else { panic!("no signature") };
    assert_eq!(args[0], Arg { name: "status".to_owned(), default: Some("0".to_owned()), location: None, ty: "imm".to_owned() });
    assert_eq!(outs, &[Out::Regs { word: "scratch".to_owned(), regs: vec!["a0".to_owned(), "a7".to_owned()] }]);
}

#[test]
fn an_argument_off_the_calling_convention_carries_its_location() {
    let text = "call feet_move ox fs0 f64,n u64 > x fs0 f64 [3:9]\nbss local actors MAX_ACTORS*ACTOR_SIZE u8 :the actors\n";
    let eye = Eye::parse(text, Path::new("test.eye")).expect("parses");
    let Shape::Signature { args, .. } = &eye.entries[0].shape else { panic!("no signature") };
    assert_eq!(args[0], Arg { name: "ox".to_owned(), default: None, location: Some("fs0".to_owned()), ty: "f64".to_owned() });
    assert_eq!(args[1].location, None);
    assert_eq!(eye.entries[1].shape, Shape::Line { ty: Some("MAX_ACTORS*ACTOR_SIZE u8".to_owned()) });
    assert_eq!(eye.to_string(), text);
}

#[test]
fn a_body_line_before_any_entry_is_refused() {
    assert!(Eye::parse(" stray\n", Path::new("test.eye")).is_err());
    assert!(Eye::parse("nope TICK\n", Path::new("test.eye")).is_err());
}

#[test]
fn an_ignore_file_names_one_symbol_a_line() {
    let names = ignored_names("set FOO\n\ncall local helper\nj loop\n", Path::new("test.eye.ignore")).expect("parses");
    assert_eq!(names, HashSet::from(["FOO".to_owned(), "helper".to_owned(), "loop".to_owned()]));
    assert!(ignored_names("FOO\n", Path::new("test.eye.ignore")).is_err());
}
