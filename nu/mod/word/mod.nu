# A value as `width` little-endian bytes, two's complement
export def le [value: int, width: int]: nothing -> binary {
    $value | into binary --endian little | bytes at 0..<$width
}

# `n` zero bytes
export def zeros [n: int]: nothing -> binary {
    if $n <= 0 { 0x[] } else { 1..$n | each {|| 0x[00] } | bytes collect }
}
