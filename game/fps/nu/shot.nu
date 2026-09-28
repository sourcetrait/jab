# shot.nu: a screen capture as a PNG to look at. `nu shot.nu <ppm>
# <png> [--step N]` takes every Nth pixel of each Nth row of the PPM
# a run captured (P6, 8 bits) and writes an RGB PNG of the sampled
# size through png.nu, so no compressor is needed; the step is 4 by
# default, 1920 by 1080 becoming 480 by 270.
use ./png.nu

def main [ppm: path, png: path, --step: int = 4] {
    let bytes = (open --raw $ppm | into binary)
    let header = ($bytes | bytes at 0..<64 | decode | lines)
    if ($header | get 0) != "P6" { error make { msg: $"($ppm): not a P6 PPM" } }
    let size = ($header | get 1 | split row " " | each {|s| $s | into int })
    let width = ($size | get 0)
    let height = ($size | get 1)
    let head_len = (($header | first 3 | str join "\n" | str length) + 1)
    let pixels = ($bytes | bytes at $head_len..)
    let out_w = ($width // $step)
    let out_h = ($height // $step)
    let sampled = (0..<$out_h | each {|r|
        let y = ($r * $step)
        let row = ($pixels | bytes at ($y * $width * 3)..<(($y + 1) * $width * 3))
        0..<$out_w | each {|c| $row | bytes at ($c * $step * 3)..<($c * $step * 3 + 3) } | bytes collect
    } | bytes collect)
    png write-rgb $png $out_w $out_h $sampled
    print $"shot: ($png) ($out_w) by ($out_h) from ($ppm)"
}
