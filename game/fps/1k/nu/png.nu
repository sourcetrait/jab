# png.nu: PNG files written without a compressor, the image data as
# stored deflate blocks: `png write-rgb <path> <w> <h> <pixels>` and
# `png write-rgba <path> <w> <h> <pixels>`, the pixels the rows in order,
# three or four bytes each; the chunk, CRC, and Adler helpers exported
# for a writer of its own.

# An 8-bit RGB PNG of the pixels, w times h times three bytes.
export def write-rgb [path: path, width: int, height: int, pixels: binary]: nothing -> nothing {
    write-png $path $width $height $pixels 3 2
}

# An 8-bit RGBA PNG of the pixels, w times h times four bytes.
export def write-rgba [path: path, width: int, height: int, pixels: binary]: nothing -> nothing {
    write-png $path $width $height $pixels 4 6
}

def write-png [path: path, width: int, height: int, pixels: binary, channels: int, colour: int]: nothing -> nothing {
    let stride = ($width * $channels)
    if ($pixels | bytes length) != ($stride * $height) {
        error make { msg: $"($path): ($pixels | bytes length) bytes of pixels for ($width) by ($height) at ($channels) a pixel" }
    }
    let rows = (0..<$height | each {|r| [0x[00], ($pixels | bytes at ($r * $stride)..<(($r + 1) * $stride))] | bytes collect } | bytes collect)
    let ihdr = ([(be32 $width), (be32 $height), 0x[08], (be8 $colour), 0x[00 00 00]] | bytes collect)
    let file = ([0x[89 50 4E 47 0D 0A 1A 0A], (chunk "IHDR" $ihdr), (chunk "IDAT" (zlib $rows)), (chunk "IEND" 0x[])] | bytes collect)
    $file | save --raw -f $path
}

# A zlib stream of the bytes as stored deflate blocks of at most 65535.
export def zlib [raw: binary]: nothing -> binary {
    let len_all = ($raw | bytes length)
    mut blocks = []
    mut at = 0
    while $at < $len_all {
        let len = (if ($len_all - $at) > 65535 { 65535 } else { $len_all - $at })
        let last = (if ($at + $len) >= $len_all { 1 } else { 0 })
        let header = ([(be8 $last), (le16 $len), (le16 (65535 - $len))] | bytes collect)
        $blocks = ($blocks | append [($header ++ ($raw | bytes at $at..<($at + $len)))])
        $at = ($at + $len)
    }
    [0x[78 01], ($blocks | bytes collect), (be32 (adler32 $raw))] | bytes collect
}

# A chunk: its length, kind, data, and CRC.
export def chunk [kind: string, data: binary]: nothing -> binary {
    let body = ([($kind | into binary), $data] | bytes collect)
    [(be32 ($data | bytes length)), $body, (be32 (crc32 $body))] | bytes collect
}

export def be8 [v: int]: nothing -> binary { $v | into binary --endian little | bytes at 0..<1 }
export def le16 [v: int]: nothing -> binary { $v | into binary --endian little | bytes at 0..<2 }
export def be32 [v: int]: nothing -> binary { $v | into binary --endian big | bytes at 4..<8 }

def bytes-of [b: binary]: nothing -> list<int> {
    $b | encode hex | split chars | chunks 2 | each {|c| $c | str join "" | into int --radix 16 }
}

export def adler32 [b: binary]: nothing -> int {
    mut a = 1
    mut s = 0
    for v in (bytes-of $b) {
        $a = (($a + $v) mod 65521)
        $s = (($s + $a) mod 65521)
    }
    ($s * 65536) + $a
}

export def crc32 [b: binary]: nothing -> int {
    let table = (0..<256 | each {|n|
        mut c = $n
        for k in 0..<8 {
            if ($c bit-and 1) == 1 { $c = (0xEDB88320 bit-xor ($c bit-shr 1)) } else { $c = ($c bit-shr 1) }
        }
        $c
    })
    mut crc = 0xFFFFFFFF
    for v in (bytes-of $b) {
        $crc = (($table | get (($crc bit-xor $v) bit-and 255)) bit-xor ($crc bit-shr 8))
    }
    $crc bit-xor 0xFFFFFFFF
}
