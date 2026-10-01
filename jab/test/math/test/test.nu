# math's integration test: the SDK's type libraries, jab_f32.inc,
# jab_f64.inc, and jab_rng.inc, through the program's lines, each a
# macro's result as a bit pattern, decoded here and held against
# nushell's own sine, cosine, arctangent, and arithmetic; each
# constant's expansion against the assembler's .float or .double of the
# same value, bit for bit; the generator against the same xorshift run
# here over two 32-bit halves; then the hot-code check through
# `jab hot`: expand_all, a page of its own holding every macro, lies
# within its page and traps nowhere, and trapped, the control beside
# it, is seen to make its one kernel call.
#
# Every tolerance is a measured number, the largest error the suite
# saw on this box rounded up to a round figure; the understanding
# records the measurement itself.
use ../../../sdk/nu/jab.nu
use std/assert

const PI = 3.141592653589793
# sin and cos within a half turn either way, the polynomial's own
# error (measured 1.3e-7 and 1.4e-7), and over the whole sweep, where
# the fold into a turn loses bits as the angle grows (5.3e-7, 5.4e-7)
const TRIG_TURN = 2.0e-7
const TRIG_SWEEP = 1.0e-6
# atan2 over every octant, in radians (measured 1.9e-6)
const ATAN2 = 3.0e-6
# rad and deg, relative (measured 3.0e-8, the round trip 6.4e-8)
const RAD_DEG = 1.0e-7
# the double-precision vector routines, relative (measured exact, 0,
# against the host's own doubles)
const F64 = 1.0e-15
# the single-precision dot product, relative (measured 1.8e-8)
const F32_DOT = 1.0e-7
# what jab.rng.seed puts in place of a zero seed
const RNG_DEFAULT = "2545f4914f6cdd1d"
const SWEEP_POINTS = 1601

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --seconds 20)
    assert equal $run.status 0 $"exit status, with the UART: ($run.serial | str substring 0..400)"
    assert equal (open --raw $run.qemu_log | into binary | bytes length) 0 "QEMU has no complaint about the guest"
    let lines = ($run.serial | lines | each {|l| $l | split row " " | where {|w| $w != "" } })
    let by = {|tag: string| $lines | where {|w| ($w | first) == $tag } }

    # sin and cos: the input decoded from its own pattern, so the
    # angle the guest saw is the angle compared against
    let sins = (do $by "sin" | each {|w| let x = (f32-of $w.1); { x: $x, err: (((f32-of $w.2) - ($x | math sin)) | math abs) } })
    let coss = (do $by "cos" | each {|w| let x = (f32-of $w.1); { x: $x, err: (((f32-of $w.2) - ($x | math cos)) | math abs) } })
    assert equal ($sins | length) $SWEEP_POINTS $"a sine for every angle of the sweep: ($sins | length)"
    assert equal ($coss | length) $SWEEP_POINTS $"a cosine for every angle of the sweep: ($coss | length)"
    let turn = {|rows| $rows | where {|r| ($r.x | math abs) <= $PI } | get err | math max }
    let whole = {|rows| $rows | get err | math max }
    let sin_turn = (do $turn $sins)
    let cos_turn = (do $turn $coss)
    let sin_sweep = (do $whole $sins)
    let cos_sweep = (do $whole $coss)
    assert ($sin_turn <= $TRIG_TURN) $"jab.f32.sin within a half turn: ($sin_turn) under ($TRIG_TURN)"
    assert ($cos_turn <= $TRIG_TURN) $"jab.f32.cos within a half turn: ($cos_turn) under ($TRIG_TURN)"
    assert ($sin_sweep <= $TRIG_SWEEP) $"jab.f32.sin over six turns either way: ($sin_sweep) under ($TRIG_SWEEP)"
    assert ($cos_sweep <= $TRIG_SWEEP) $"jab.f32.cos over six turns either way: ($cos_sweep) under ($TRIG_SWEEP)"

    # atan2 over every octant, the axes, and both zero
    let atans = (do $by "atan2" | each {|w|
        let y = (f32-of $w.1)
        let x = (f32-of $w.2)
        { y: $y, x: $x, got: (f32-of $w.3), err: (((f32-of $w.3) - (atan2 $y $x)) | math abs) }
    })
    assert equal ($atans | length) 24 $"an arctangent for every pair: ($atans | length)"
    let both_zero = ($atans | where {|r| $r.y == 0.0 and $r.x == 0.0 })
    assert equal ($both_zero | length) 1 "the pair of zeros is among the cases"
    assert equal ($both_zero | get 0.got) 0.0 "both zero gives zero"
    let atan_max = ($atans | get err | math max)
    assert ($atan_max <= $ATAN2) $"jab.f32.atan2 over every octant: ($atan_max) radians under ($ATAN2)"

    # rad and deg, and the round trip
    let rads = (do $by "rad" | each {|w| let x = (f32-of $w.1); { x: $x, err: (rel-err (f32-of $w.2) ($x * $PI / 180.0)) } })
    let degs = (do $by "deg" | each {|w| let x = (f32-of $w.1); { x: $x, err: (rel-err (f32-of $w.2) ($x * 180.0 / $PI)) } })
    let trips = (do $by "roundtrip" | each {|w| let x = (f32-of $w.1); { x: $x, err: (rel-err (f32-of $w.2) $x) } })
    assert equal ($rads | length) 11 "a rad for every angle"
    assert equal ($degs | length) 11 "a deg for every angle"
    assert equal ($trips | length) 11 "a round trip for every angle"
    let rad_max = ($rads | get err | math max)
    let deg_max = ($degs | get err | math max)
    let trip_max = ($trips | get err | math max)
    assert ($rad_max <= $RAD_DEG) $"jab.f32.rad: ($rad_max) relative under ($RAD_DEG)"
    assert ($deg_max <= $RAD_DEG) $"jab.f32.deg: ($deg_max) relative under ($RAD_DEG)"
    assert ($trip_max <= ($RAD_DEG * 2.0)) $"deg of rad gives the degrees back: ($trip_max) relative"

    # the constants: the macro's pattern is the assembler's, bit for bit
    let consts = (do $by "const")
    assert equal ($consts | each {|c| $c | get 1 } | sort) ([f32.PI f32.TAU f32.FRAC_PI_2 f64.PI f64.TAU f64.FRAC_PI_2] | sort) "every constant of the first cut reported"
    for c in $consts {
        assert equal $c.2 $c.3 $"($c.1): the macro's pattern ($c.2) is the assembler's ($c.3)"
    }
    let f32_pi = ($consts | where {|c| $c.1 == "f32.PI" } | get 0.2 | f32-of $in)
    let f64_pi = ($consts | where {|c| $c.1 == "f64.PI" } | get 0.2 | f64-of $in)
    assert ((rel-err $f32_pi $PI) < 1.0e-7) $"f32.PI decodes to pi: ($f32_pi)"
    assert ((rel-err $f64_pi $PI) < 1.0e-15) $"f64.PI decodes to pi: ($f64_pi)"

    # the double-precision vectors: every input decoded from the line
    let dots = (do $by "f64.vec3.dot" | each {|w|
        let v = ($w | slice 1..6 | each {|h| f64-of $h })
        let want = ($v.0 * $v.3 + $v.1 * $v.4 + $v.2 * $v.5)
        { want: $want, err: (rel-err (f64-of $w.7) $want) }
    })
    assert equal ($dots | length) 4 "a dot product for every pair"
    let lens = (do $by "f64.vec3.len" | each {|w|
        let v = ($w | slice 1..3 | each {|h| f64-of $h })
        { err: (rel-err (f64-of $w.4) (($v.0 * $v.0 + $v.1 * $v.1 + $v.2 * $v.2) | math sqrt)) }
    })
    let sqrlens = (do $by "f64.vec3.sqrlen" | each {|w|
        let v = ($w | slice 1..3 | each {|h| f64-of $h })
        { err: (rel-err (f64-of $w.4) ($v.0 * $v.0 + $v.1 * $v.1 + $v.2 * $v.2)) }
    })
    let norms = (do $by "f64.vec3.norm" | each {|w| norm-check $w })
    let aliased = (do $by "f64.vec3.norm.aliased" | each {|w| norm-check $w })
    assert equal ($lens | length) 4 "a length for every vector"
    assert equal ($sqrlens | length) 4 "a squared length for every vector"
    assert equal ($norms | length) 4 "a normal for every vector"
    assert equal ($aliased | length) 4 "an aliased normal for every vector"
    assert equal (do $by "f64.vec3.norm" | each {|w| $w | slice 4..6 }) (do $by "f64.vec3.norm.aliased" | each {|w| $w | slice 4..6 }) "the normal written in place is the normal written beside"
    let vec2_lens = (do $by "f64.vec2.len" | each {|w|
        let v = ($w | slice 1..2 | each {|h| f64-of $h })
        { err: (rel-err (f64-of $w.3) (($v.0 * $v.0 + $v.1 * $v.1) | math sqrt)) }
    })
    let vec2_sqrlens = (do $by "f64.vec2.sqrlen" | each {|w|
        let v = ($w | slice 1..2 | each {|h| f64-of $h })
        { err: (rel-err (f64-of $w.3) ($v.0 * $v.0 + $v.1 * $v.1)) }
    })
    assert equal ($vec2_lens | length) 4 "a length for every plan vector"
    assert equal ($vec2_sqrlens | length) 4 "a squared length for every plan vector"
    let f64_max = ((($dots ++ $lens ++ $sqrlens ++ $norms ++ $aliased ++ $vec2_lens ++ $vec2_sqrlens) | get err) | math max)
    assert ($f64_max <= $F64) $"the jab.f64 vector routines: ($f64_max) relative under ($F64)"

    # the single-precision dot product
    let f32_dots = (do $by "f32.vec3.dot" | each {|w|
        let v = ($w | slice 1..6 | each {|h| f32-of $h })
        let want = ($v.0 * $v.3 + $v.1 * $v.4 + $v.2 * $v.5)
        { err: (rel-err (f32-of $w.7) $want) }
    })
    assert equal ($f32_dots | length) 3 "a single dot product for every pair"
    let f32_max = ($f32_dots | get err | math max)
    assert ($f32_max <= $F32_DOT) $"jab.f32.vec3.dot: ($f32_max) relative under ($F32_DOT)"

    # the generator: a fixed seed gives the sequence run here, the zero
    # seed is replaced and does not stick, and the kernel's entropy
    # seeds a run that differs from the pinned one and is its own
    # state's sequence
    let rngs = (do $by "rng")
    assert equal ($rngs | length) 2 $"the fixed and the zero seed reported: ($rngs | length)"
    let fixed = ($rngs | get 0)
    assert equal $fixed.1 "0123456789abcdef" "the fixed seed as given"
    assert equal $fixed.2 $fixed.1 "a non-zero seed is the state"
    assert equal ($fixed | slice 3..18) (xorshift-bytes $fixed.2 16) "the fixed seed's sequence is the xorshift's"
    let zero = ($rngs | get 1)
    assert equal $zero.1 "0000000000000000" "the zero seed as given"
    assert equal $zero.2 $RNG_DEFAULT $"a zero seed becomes the default: ($zero.2)"
    assert equal ($zero | slice 3..18) (xorshift-bytes $RNG_DEFAULT 16) "the replaced seed's sequence is the xorshift's"
    let sys = (do $by "rngsys")
    assert equal ($sys | length) 1 "the entropy-seeded run reported"
    let drawn = ($sys | get 0)
    assert ($drawn.1 != "none") "the machine carries the rng device"
    assert equal $drawn.2 (if $drawn.1 == "0000000000000000" { $RNG_DEFAULT } else { $drawn.1 }) "the drawn word is the state, or the default when it was zero"
    assert ($drawn.2 != $fixed.2) "the entropy's seed differs from the pinned one"
    assert equal ($drawn | slice 3..18) (xorshift-bytes $drawn.2 16) "the entropy-seeded sequence is its own state's xorshift"
    assert (($drawn | slice 3..18) != ($fixed | slice 3..18)) "and differs from the pinned sequence"

    # the hot-code check
    let elf = ($image | path dirname | path join "math.elf")
    let hot = (jab hot $elf [expand_all trapped])
    let all = ($hot | where name == "expand_all" | get 0)
    assert $all.paged $"expand_all lies within one page of code: ($all)"
    assert equal $all.ecalls 0 $"expand_all, every macro of the first cut, traps nowhere: ($all)"
    let control = ($hot | where name == "trapped" | get 0)
    assert $control.paged $"trapped lies within one page of code: ($control)"
    assert equal $control.ecalls 1 $"the check sees the kernel call in trapped: ($control)"

    print $"math: sin within a half turn ($sin_turn), over the sweep ($sin_sweep); cos ($cos_turn) and ($cos_sweep); atan2 ($atan_max) rad; rad ($rad_max), deg ($deg_max), the round trip ($trip_max) relative; f64 vectors ($f64_max) relative; f32 dot ($f32_max) relative; ($consts | length) constants bit for bit; the rng pinned and the entropy's own; expand_all ($all.end - $all.start) bytes in its page with no trap"
    print "math: ok"
}

# A single from its eight hex digits.
def f32-of [hex: string]: nothing -> float {
    let b = ($hex | into int --radix 16)
    let sign = (if (($b bit-shr 31) bit-and 1) == 1 { -1.0 } else { 1.0 })
    let e = (($b bit-shr 23) bit-and 0xff)
    let m = ($b bit-and 0x7fffff)
    if $e == 255 { error make {msg: $"not a finite single: ($hex)"} }
    if $e == 0 { return ($sign * ($m | into float) * (2.0 ** (-149))) }
    $sign * (1.0 + (($m | into float) / 8388608.0)) * (2.0 ** ($e - 127))
}

# A double from its sixteen hex digits, read as two halves so the sign
# bit never makes a value past an int.
def f64-of [hex: string]: nothing -> float {
    let hi = ($hex | str substring 0..<8 | into int --radix 16)
    let lo = ($hex | str substring 8..<16 | into int --radix 16)
    let sign = (if (($hi bit-shr 31) bit-and 1) == 1 { -1.0 } else { 1.0 })
    let e = (($hi bit-shr 20) bit-and 0x7ff)
    let m = ((($hi bit-and 0xfffff) * 4294967296) + $lo)
    if $e == 2047 { error make {msg: $"not a finite double: ($hex)"} }
    if $e == 0 { return ($sign * ($m | into float) * (2.0 ** (-1074))) }
    $sign * (1.0 + (($m | into float) / 4503599627370496.0)) * (2.0 ** ($e - 1023))
}

# The relative error of got against want, absolute when want is zero.
def rel-err [got: float, want: float]: nothing -> float {
    if $want == 0.0 { ($got | math abs) } else { (($got - $want) / $want) | math abs }
}

# The arctangent of y over x by quadrant, Rust's `y.atan2(x)`.
def atan2 [y: float, x: float]: nothing -> float {
    if $x > 0.0 { return (($y / $x) | math arctan) }
    if $x < 0.0 {
        if $y >= 0.0 { return ((($y / $x) | math arctan) + $PI) }
        return ((($y / $x) | math arctan) - $PI)
    }
    if $y > 0.0 { return ($PI / 2.0) }
    if $y < 0.0 { return (0.0 - ($PI / 2.0)) }
    0.0
}

# A normal's line checked: the inputs decoded, the outputs at unit
# length along the input, or the input itself for the zero vector.
def norm-check [w: list<string>]: nothing -> record<err: float> {
    let v = ($w | slice 1..3 | each {|h| f64-of $h })
    let n = ($w | slice 4..6 | each {|h| f64-of $h })
    let len = (($v.0 * $v.0 + $v.1 * $v.1 + $v.2 * $v.2) | math sqrt)
    let want = (if $len == 0.0 { $v } else { $v | each {|c| $c / $len } })
    { err: ([(rel-err $n.0 $want.0) (rel-err $n.1 $want.1) (rel-err $n.2 $want.2)] | math max) }
}

# The xorshift jab.rng.byte runs, over the state as two 32-bit halves
# so every shift stays inside an int: x ^= x << 13, x ^= x >> 7,
# x ^= x << 17, the byte bits 24 to 31; n bytes as two hex digits each.
def xorshift-bytes [seed: string, n: int]: nothing -> list<string> {
    let mask = 0xffffffff
    mut hi = ($seed | str substring 0..<8 | into int --radix 16)
    mut lo = ($seed | str substring 8..<16 | into int --radix 16)
    mut out = []
    for _ in 0..<$n {
        let a_hi = ((($hi bit-shl 13) bit-or ($lo bit-shr 19)) bit-and $mask)
        let a_lo = (($lo bit-shl 13) bit-and $mask)
        $hi = ($hi bit-xor $a_hi)
        $lo = ($lo bit-xor $a_lo)
        let b_lo = ((($lo bit-shr 7) bit-or ($hi bit-shl 25)) bit-and $mask)
        let b_hi = ($hi bit-shr 7)
        $hi = ($hi bit-xor $b_hi)
        $lo = ($lo bit-xor $b_lo)
        let c_hi = ((($hi bit-shl 17) bit-or ($lo bit-shr 15)) bit-and $mask)
        let c_lo = (($lo bit-shl 17) bit-and $mask)
        $hi = ($hi bit-xor $c_hi)
        $lo = ($lo bit-xor $c_lo)
        let byte = (($lo bit-shr 24) bit-and 0xff)
        $out = ($out | append ($byte | format number | get lowerhex | str replace "0x" "" | fill -a right -c "0" -w 2))
    }
    $out
}
