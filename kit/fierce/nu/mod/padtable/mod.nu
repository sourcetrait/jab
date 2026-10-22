use (path self ../../../../../nu/mod/nutype)

# A pad table's model, nu/type/table/PadTable.nutype
const MODEL = path self ../../type/table/PadTable.nutype

# A pad table file held to its model, its path returned; refused by problem
export def held [file: path]: nothing -> string {
    let rows = (open --raw $file | decode utf-8 | from nuon)
    let problems = (nutype problems $rows (open --raw $MODEL | decode utf-8) $MODEL)
    if ($problems | is-not-empty) {
        error make { msg: $"the pad table ($file) breaks its model: ($problems | str join '; ')" }
    }
    $file
}
