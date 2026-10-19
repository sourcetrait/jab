# A wav QEMU recorded: its format and its samples as they lie
export def wave [path: path]: nothing -> record<rate: int, channels: int, bits: int, frames: int, samples: binary> {
    let bytes = (open --raw ($path | path expand) | into binary)
    let total = ($bytes | bytes length)
    if ($bytes | bytes at 0..<4 | decode) != "RIFF" or ($bytes | bytes at 8..<12 | decode) != "WAVE" { error make {msg: $"($path): not a wav"} }
    mut at = 12
    mut rate = 0
    mut channels = 0
    mut bits = 0
    mut samples = 0x[]
    while $at + 8 <= $total {
        let id = ($bytes | bytes at $at..<($at + 4) | decode)
        let size = ($bytes | bytes at ($at + 4)..<($at + 8) | into int --endian little)
        let body = ($at + 8)
        if $id == "fmt " {
            $channels = ($bytes | bytes at ($body + 2)..<($body + 4) | into int --endian little)
            $rate = ($bytes | bytes at ($body + 4)..<($body + 8) | into int --endian little)
            $bits = ($bytes | bytes at ($body + 14)..<($body + 16) | into int --endian little)
        } else if $id == "data" {
            let unwritten = ($size == 0 or ($body + $size) > $total)
            $samples = ($bytes | bytes at $body..<(if $unwritten { $total } else { $body + $size }))
            if $unwritten { break }
        }
        $at = ($body + $size + ($size mod 2))
    }
    if $rate == 0 or $channels == 0 { error make {msg: $"($path): no format chunk"} }
    { rate: $rate, channels: $channels, bits: $bits, frames: (($samples | bytes length) // ($channels * ($bits // 8))), samples: $samples }
}

# A screen a launch took: its size and its RGB pixels, row by row
export def screen [path: path]: nothing -> record<width: int, height: int, pixels: binary> {
    let bytes = (open --raw ($path | path expand) | into binary)
    let newlines = ($bytes | bytes index-of --all 0x[0a] | take 3)
    let header = ($bytes | bytes at 0..<($newlines.2) | decode | lines)
    let size = ($header.1 | split row " ")
    { width: ($size.0 | into int), height: ($size.1 | into int), pixels: ($bytes | bytes at ($newlines.2 + 1)..) }
}

# How many of a screen's pixels have a color, and their bounding box
export def ink [screen: record<width: int, height: int, pixels: binary>, color: string]: nothing -> record<count: int, left: int, top: int, right: int, bottom: int> {
    let pattern = ($color | decode hex)
    let hits = ($screen.pixels | bytes index-of --all $pattern | where {|i| $i mod 3 == 0 })
    if ($hits | is-empty) { return { count: 0, left: -1, top: -1, right: -1, bottom: -1 } }
    let xs = ($hits | each {|i| ($i // 3) mod $screen.width })
    let ys = ($hits | each {|i| ($i // 3) // $screen.width })
    { count: ($hits | length), left: ($xs | math min), top: ($ys | math min), right: ($xs | math max), bottom: ($ys | math max) }
}

# The color of a screen's pixel at x, y as RRGGBB
export def pixel [screen: record<width: int, height: int, pixels: binary>, x: int, y: int]: nothing -> string {
    let i = (($y * $screen.width + $x) * 3)
    $screen.pixels | bytes at $i..<($i + 3) | encode hex | str lowercase
}

# A screen as rough text, a character a block by its brightness
def thumbnail [screen: record<width: int, height: int, pixels: binary>, --columns: int = 96, --rows: int = 27]: nothing -> string {
    let block_w = ($screen.width // $columns)
    let block_h = ($screen.height // $rows)
    let row_bytes = ($screen.width * 3)
    0..<$rows | each {|r|
        let y = ($r * $block_h + ($block_h // 2))
        let row = ($screen.pixels | bytes at ($y * $row_bytes)..<(($y + 1) * $row_bytes))
        0..<$columns | each {|c|
            let x = ($c * $block_w + ($block_w // 2))
            let p = ($row | bytes at ($x * 3)..<($x * 3 + 3))
            let brightness = (($p | bytes at 0..<1 | into int) + ($p | bytes at 1..<2 | into int) + ($p | bytes at 2..<3 | into int))
            if $brightness < 48 { " " } else if $brightness < 256 { "." } else if $brightness < 512 { "o" } else { "#" }
        } | str join ""
    } | str join "\n"
}

# The strings in a binary starting with `prefix`, each to its terminator
export def strings [path: path, prefix: string]: nothing -> list<string> {
    let bytes = (open --raw ($path | path expand) | into binary)
    let total = ($bytes | bytes length)
    $bytes | bytes index-of --all ($prefix | into binary) | each {|at|
        let tail = ($bytes | bytes at $at..<([($at + 256) $total] | math min))
        let end = ($tail | bytes index-of 0x[00])
        (if $end < 0 { $tail } else { $tail | bytes at 0..<$end }) | decode
    }
}

# Named ELF functions' bounds, whether each lies in one page, and their ecalls
export def hot [elf: path, names: list<string>]: nothing -> table<name: string, start: int, end: int, paged: bool, ecalls: int> {
    let elf = ($elf | path expand)
    let built = ($elf | path dirname)
    let prefix = (open --raw ($built | path join "flags") | lines | first | split row " " | last)
    let symbols = (^$"($prefix)nm" -n $elf | lines | parse "{addr} {kind} {name}" | where {|s| $s.kind not-in ["a" "A"] } | each {|s| { addr: ($s.addr | into int --radix 16), name: $s.name } })
    let ecalls = (^$"($prefix)objdump" -d $elf | lines | parse --regex '^\s*(?P<addr>[0-9a-f]+):\s+[0-9a-f]+\s+ecall\b' | each {|d| $d.addr | into int --radix 16 })
    $names | each {|name|
        let at = ($symbols | enumerate | where {|s| $s.item.name == $name } | get -o 0.index)
        if $at == null { error make {msg: $"($name) is not among the symbols of ($elf)"} }
        let start = ($symbols | get $at | get addr)
        let next = ($symbols | get -o ($at + 1))
        if $next == null { error make {msg: $"($name) is the last symbol of ($elf), so its end is unknown"} }
        let end = $next.addr
        {
            name: $name,
            start: $start,
            end: $end,
            paged: (($start // 4096) == (($end - 1) // 4096)),
            ecalls: ($ecalls | where {|a| $a >= $start and $a < $end } | length),
        }
    }
}
