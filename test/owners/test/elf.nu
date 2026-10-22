use ../../../nu/mod/walk

const code_sections = [".text" ".text.boot"]
export const data_sections = [".rodata" ".data" ".bss" ".sdata" ".sbss"]

# The toolchain's prefix a kernel was built with, the last word of the
# flags beside it
export def prefix-of [elf: path]: nothing -> string {
    open --raw ($elf | path dirname | path join "flags") | decode | lines | first | split row " " | last
}

# A file's symbols as objdump -t lists them, the section symbols and the
# file's name, the absolute, and the undefined left out
export def symbols-of [prefix: string, file: path]: nothing -> table<value: int, section: string, name: string> {
    ^$"($prefix)objdump" -t $file | complete | get stdout | lines
    | parse --regex '^(?P<value>[0-9a-f]{16}) (?P<flags>.{7}) (?P<section>\S+)\t[0-9a-f]{16} (?P<name>.+)$'
    | where {|s| not ($s.flags | str contains "d") and $s.section not-in ["*ABS*" "*UND*"] }
    | each {|s| { value: ($"0x($s.value)" | into int), section: $s.section, name: $s.name } }
}

# A file's sections as objdump -h lists them: each its size, its address,
# and its offset in the file
export def sections-of [prefix: string, file: path]: nothing -> table<name: string, size: int, vma: int, off: int> {
    ^$"($prefix)objdump" -h $file | complete | get stdout | lines
    | parse --regex '^\s+\d+\s+(?P<name>\S+)\s+(?P<size>[0-9a-f]+)\s+(?P<vma>[0-9a-f]+)\s+[0-9a-f]+\s+(?P<off>[0-9a-f]+)\s+'
    | each {|s| { name: $s.name, size: ($"0x($s.size)" | into int), vma: ($"0x($s.vma)" | into int), off: ($"0x($s.off)" | into int) } }
}

# The objects beside a kernel's ELF: each its file, its symbols, and its
# sections
export def objects-of [prefix: string, elf: path] {
    walk paths ($elf | path dirname | path join "*.o") | sort | each {|o| { file: ($o | path parse | get stem), symbols: (symbols-of $prefix $o), sections: (sections-of $prefix $o) } }
}

# Where the objects' data lie in the ELF: a range a data section of an
# object, placed by a symbol of that section whose name no other symbol
# carries, in the objects or in the ELF. Data keep their offsets through
# the link; code does not, since the linker relaxes calls, so code is
# placed by name (function-files).
export def placement [objects: list<any>, elf_symbols: table]: nothing -> table<file: string, section: string, start: int, end: int> {
    let all = ($objects | each {|o| $o.symbols | insert file $o.file } | flatten)
    let once_objects = ($all | get name | uniq --count | where count == 1 | get value | wrap name)
    let once_elf = ($elf_symbols | get name | uniq --count | where count == 1 | get value | wrap name)
    let anchors = ($all | join $once_objects name | join $once_elf name | join ($elf_symbols | select name value | rename name at) name)
    $objects | each {|o|
        $o.sections | where {|s| $s.name in $data_sections and $s.size > 0 } | each {|s|
            let anchor = ($anchors | where {|a| $a.file == $o.file and $a.section == $s.name } | get -o 0)
            if $anchor == null { error make {msg: $"($o.file).o's ($s.name) has no symbol of a name its own to place it by"} }
            let start = ($anchor.at - $anchor.value)
            { file: $o.file, section: $s.name, start: $start, end: ($start + $s.size) }
        }
    } | flatten
}

# Each function's file, in the functions' order: the one object defining a
# code symbol of its name, else, of those defining one, the file of the
# function before it, the link laying each object's code whole; a name no
# object defines, or several the order does not decide, a problem
export def function-files [objects: list<any>, funcs: list<any>]: nothing -> list<any> {
    let code = ($objects | each {|o| $o.symbols | where {|s| $s.section in $code_sections } | each {|s| { name: $s.name, file: $o.file } } } | flatten)
    let owners = ($code | group-by name)
    mut current = ""
    mut files = []
    for f in $funcs {
        let c = ($owners | get -o $f.name | default [] | each {|r| $r.file } | uniq)
        let row = (if ($c | length) == 1 {
            { name: $f.name, file: ($c | first), problem: null }
        } else if $current in $c {
            { name: $f.name, file: $current, problem: null }
        } else if ($c | is-empty) {
            { name: $f.name, file: "", problem: "no object defines it" }
        } else {
            { name: $f.name, file: "", problem: $"the link order does not decide among ($c | str join ', ')" }
        })
        $current = $row.file
        $files = ($files | append $row)
    }
    $files
}

# The range holding an address, or null
export def placed [places: table, address: int] {
    $places | where {|p| $p.start <= $address and $address < $p.end } | get -o 0
}

# The ELF's functions in address order: each a symbol's block of objdump
# -d, its name, its start, and its instructions
export def functions-of [prefix: string, elf: path] {
    ^$"($prefix)objdump" -d $elf | complete | get stdout | split row "\n\n"
    | where {|b| $b =~ '^[0-9a-f]+ <[^>]+>:' }
    | each {|b|
        let ls = ($b | lines)
        let head = ($ls | first | parse --regex '^(?P<addr>[0-9a-f]+) <(?P<name>[^>]+)>:$' | first)
        let instrs = ($ls | skip 1 | parse --regex '^\s+(?P<addr>[0-9a-f]+):\t[0-9a-f ]+\t(?P<op>\S+)\s*(?P<args>.*)$' | each {|i| { addr: ($"0x($i.addr)" | into int), op: $i.op, args: $i.args } })
        { name: $head.name, start: ($"0x($head.addr)" | into int), instrs: $instrs }
    }
    | sort-by start
}

# The 64-bit words of the kernel's initialized data on their own
# boundaries, for any code address one holds
export def data-words [sections: table, bytes: binary]: nothing -> list<int> {
    $sections | where {|s| $s.name in [".rodata" ".data"] and $s.size >= 8 } | each {|s|
        let first = (($s.vma + 7) // 8 * 8)
        let count = (($s.size - ($first - $s.vma)) // 8)
        if $count <= 0 { [] } else {
            let off = ($s.off + $first - $s.vma)
            $bytes | bytes at $off..<($off + $count * 8) | chunks 8 | each {|w| $w | into int --endian little --signed }
        }
    } | flatten
}

# The index of the last value at or below an address in a sorted list,
# -1 when every value lies past it
export def index-at [values: list<int>, address: int]: nothing -> int {
    if ($values | is-empty) or $address < ($values | first) { return (-1) }
    mut lo = 0
    mut hi = (($values | length) - 1)
    while $lo < $hi {
        let mid = (($lo + $hi + 1) // 2)
        if ($values | get $mid) <= $address { $lo = $mid } else { $hi = ($mid - 1) }
    }
    $lo
}
