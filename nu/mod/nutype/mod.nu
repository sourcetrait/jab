# The scalar types a type may name
const spec_scalars = [string int float number bool filesize duration datetime binary nothing path directory]

# A type's text parsed into its parts; any form the checker cannot hold refused
export def model [text: string, file: string] {
    let body = ($text | lines | where {|l| not ($l | str trim | str starts-with "#") } | str join " ")
    let tokens = ($body | str replace --all --regex '([<>,:])' ' $1 ' | split row --regex '\s+' | where {|t| $t != "" })
    if ($tokens | is-empty) { error make {msg: $"($file): no type in it"} }
    let parsed = (type-parse $tokens 0 $file)
    if $parsed.next != ($tokens | length) { error make {msg: $"($file): more after the type: ($tokens | skip $parsed.next | first 3 | str join ' ')"} }
    $parsed.schema
}

# A value's problems against a type's text, a line each; none when it holds
export def problems [value: any, type_text: string, file: string]: nothing -> list<string> {
    value-problems $value (model $type_text $file) ""
}

# The type starting at word `at` of a type's words, and the word after it
def type-parse [tokens: list<string>, at: int, file: string] {
    let name = ($tokens | get -o $at)
    if $name == null or $name in ["<" ">" "," ":"] {
        error make {msg: $"($file): a type expected at word ($at + 1), (if $name == null { 'the end' } else { $name }) found"}
    }
    if ($tokens | get -o ($at + 1)) != "<" {
        if $name not-in $spec_scalars { error make {msg: $"($file): ($name) is no type the tools read; they read ($spec_scalars | str join ', '), oneof, list, record, and table"} }
        return { schema: { kind: "scalar", name: $name }, next: ($at + 1) }
    }
    match $name {
        "table" | "record" => {
            mut i = ($at + 2)
            mut fields = []
            while ($tokens | get -o $i) != ">" {
                let field = ($tokens | get -o $i)
                if $field == null or $field in ["<" ">" "," ":"] or ($tokens | get -o ($i + 1)) != ":" {
                    error make {msg: $"($file): a field and its type expected in ($name)<...>, (if $field == null { 'the end' } else { $tokens | skip $i | first 3 | str join ' ' }) found"}
                }
                if ($fields | any {|f| $f.name == $field }) { error make {msg: $"($file): ($field) named twice in ($name)<...>"} }
                let inner = (type-parse $tokens ($i + 2) $file)
                $fields = ($fields | append { name: $field, schema: $inner.schema })
                $i = $inner.next
                if ($tokens | get -o $i) == "," { $i += 1 }
            }
            { schema: { kind: $name, fields: $fields }, next: ($i + 1) }
        },
        "list" => {
            let inner = (type-parse $tokens ($at + 2) $file)
            if ($tokens | get -o $inner.next) != ">" { error make {msg: $"($file): list<...> holds one type"} }
            { schema: { kind: "list", of: $inner.schema }, next: ($inner.next + 1) }
        },
        "oneof" => {
            mut i = ($at + 2)
            mut members = []
            while ($tokens | get -o $i) != ">" {
                let inner = (type-parse $tokens $i $file)
                $members = ($members | append $inner.schema)
                $i = $inner.next
                if ($tokens | get -o $i) == "," { $i += 1 }
            }
            { schema: { kind: "oneof", members: $members }, next: ($i + 1) }
        },
        _ => { error make {msg: $"($file): ($name)<...> is no type the tools read; they read oneof, list, record, and table"} },
    }
}

# A type's part written as nushell writes it
export def type-name [schema: record]: nothing -> string {
    match $schema.kind {
        "scalar" => $schema.name,
        "oneof" => $"oneof<($schema.members | each {|m| type-name $m } | str join ', ')>",
        "list" => $"list<(type-name $schema.of)>",
        _ => $"($schema.kind)<($schema.fields | each {|f| $'($f.name): (type-name $f.schema)' } | str join ', ')>",
    }
}

# A field's path below `at`, "" being a row's own
def field-path [at: string, name: string]: nothing -> string {
    if $at == "" { $name } else { $"($at).($name)" }
}

# A record's problems against its fields, a line each, `at` its path
export def record-problems [value: any, fields: list<any>, at: string]: nothing -> list<string> {
    let got = ($value | describe)
    if not ($got | str starts-with "record") { return [$"(if $at == '' { 'the row' } else { $at }): a record expected, ($got) found"] }
    let named = ($fields | get name)
    let present = ($value | columns)
    let checked = ($fields | each {|f|
        let path = (field-path $at $f.name)
        if $f.name not-in $present { [$"($path): missing"] } else { value-problems ($value | get $f.name) $f.schema $path }
    } | flatten)
    let unknown = ($present | where {|c| $c not-in $named } | each {|c| $"(field-path $at $c): a field the type does not name" })
    $checked ++ $unknown
}

# A value's problems against its part of a type, a line each; none when it holds
def value-problems [value: any, schema: record, at: string]: nothing -> list<string> {
    let got = ($value | describe)
    match $schema.kind {
        "scalar" => {
            let holds = (match $schema.name {
                "number" => ($got in ["int" "float"]),
                "path" | "directory" => ($got == "string"),
                _ => ($got == $schema.name),
            })
            if $holds { [] } else { [$"($at): ($schema.name) expected, ($got) found"] }
        },
        "oneof" => {
            if ($schema.members | any {|m| value-problems $value $m $at | is-empty }) { [] } else { [$"($at): (type-name $schema) expected, ($got) found"] }
        },
        "record" => (record-problems $value $schema.fields $at),
        "list" => {
            if (not ($got | str starts-with "list")) and (not ($got | str starts-with "table")) { return [$"($at): (type-name $schema) expected, ($got) found"] }
            $value | enumerate | each {|e| value-problems $e.item $schema.of $"($at).($e.index)" } | flatten
        },
        _ => {
            if (not ($got | str starts-with "list")) and (not ($got | str starts-with "table")) { return [$"($at): (type-name $schema) expected, ($got) found"] }
            $value | enumerate | each {|e| record-problems $e.item $schema.fields $"($at).($e.index)" } | flatten
        },
    }
}
