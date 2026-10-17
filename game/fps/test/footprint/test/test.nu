# footprint's integration test, FootprintEstimate's fixtures: the
# candidate's row derivative (render.inc's row_derivative) run on its cases
# and each answer held to the exact arithmetic, the game's footprint
# crate's `derivative`, every case the value or the saturation it was laid
# for; and a pattern of LEVELS codes the program lays in the framebuffer,
# read back from the capture by the crate's `blocks` exactly as laid.
use ../../../../../sdk/nu/jab.nu
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

# the blocks the pattern lays, by span and start: span 9's run lies under
# the stamp's cells and is skipped, span 10's half under them, span 41
# covers the first four pixels of span 40's block
const BLOCKS = [
    [span row x0 level pixels end];
    [7 101 500 0 16 516]
    [7 101 516 1 4 520]
    [10 1 56 4 8 72]
    [40 102 700 5 12 716]
    [41 102 700 6 4 704]
    [300 100 200 2 16 216]
    [300 100 216 2 16 232]
    [300 100 232 3 16 248]
    [65535 1079 1904 9 16 1920]
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
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --seconds 10 --capture 2sec)
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
    assert ($run.screen != "") "a screen was taken"
    let read = (^$tool blocks $run.screen | complete)
    assert equal $read.exit_code 0 $"the pattern's capture reads: ($read.stderr)"
    let decoded = ($read.stdout | from nuon)
    assert equal [$decoded.width $decoded.height] [1920 1080] "a 1080p capture"
    assert equal $decoded.blocks $BLOCKS $"the pattern's blocks decode as laid: ($decoded.blocks | to nuon)"
    print $"footprint: ($answers | length) cases held to the exact arithmetic, ($decoded.blocks | length) blocks read back as laid"
    print "footprint: ok"
}
