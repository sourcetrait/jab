# footprint's integration test, FootprintEstimate's fixtures: the
# candidate's row derivative (render.inc's row_derivative) run on its cases
# and each answer held to the exact arithmetic, the game's footprint
# crate's `derivative`, every case the value or the saturation it was laid
# for, and the program exiting 0 after the last.
use ../../../../../nu/mod/launch
use std/assert

# each case's purpose and whether it saturates, in the program's order
const CASES = [
    [name saturated];
    ["an ordinary floor's", false]
    ["both products past 64 bits, each shift fitting", false]
    ["the first product past 64 bits once shifted", true]
    ["the second product past 64 bits once shifted", true]
    ["the subtraction overflowing", true]
    ["the most negative value", true]
    ["a negative derivative", false]
    ["the clamp's, IZB zero", false]
    ["a negative product floored", false]
    ["a span's own numbers", false]
    ["the largest the narrowing keeps", false]
    ["one past it", true]
]

# the footprint crate built where cargo puts its targets, its binary's path
def footprint-tool []: nothing -> string {
    let manifest = ($env.FILE_PWD | path join ".." ".." ".." "rust" "Cargo.toml")
    let built = (^cargo build --release --quiet --manifest-path $manifest -p footprint | complete)
    if $built.exit_code != 0 { error make { msg: $"building the footprint crate: ($built.stderr)" } }
    let meta = (^cargo metadata --format-version 1 --no-deps --manifest-path $manifest | complete)
    if $meta.exit_code != 0 { error make { msg: $"reading the crate's metadata: ($meta.stderr)" } }
    $meta.stdout | from json | get target_directory | path join "release" "footprint"
}

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let run = (launch --kernel $kernel --image $image --out $out --set $set --seconds 10)
    assert equal $run.status 0 $"exit status, with the UART: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    let tool = (footprint-tool)
    let answers = ($run.serial | lines | where {|l| $l starts-with "footprint: derivative " } | parse "footprint: derivative {case} {coord} {izb} {uzb} {z} {answer}")
    assert equal ($answers | length) ($CASES | length) $"one answer a case, with the UART: ($run.serial)"
    for c in ($CASES | enumerate) {
        let a = ($answers | get $c.index)
        assert equal ($a.case | into int) $c.index $"the cases in order: ($a)"
        let exact = (^$tool derivative $a.coord $a.izb $a.uzb $a.z | complete)
        assert equal $exact.exit_code 0 $"the exact arithmetic of ($a): ($exact.stderr)"
        let oracle = ($exact.stdout | from nuon)
        assert equal $oracle.saturated $c.item.saturated $"case ($c.index), ($c.item.name), was laid to (if $c.item.saturated { 'saturate' } else { 'take its value' }): ($oracle)"
        let guest = (if $a.answer == "saturated" { null } else { $a.answer | into int })
        assert equal $guest $oracle.value $"case ($c.index), ($c.item.name): the guest answered ($a.answer) where the exact arithmetic gives ($oracle.value)"
    }
    print $"footprint: ($answers | length) cases held to the exact arithmetic"
    print "footprint: ok"
}
