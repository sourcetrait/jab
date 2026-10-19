# What a build was made from: its flags and every input path, sorted
export def id [flags: string, inputs: list<string>]: nothing -> string {
    $flags + (char nl) + ($inputs | sort | str join (char nl))
}

# Whether an output needs building: missing, older, or of other flags or inputs
export def stale [output: path, inputs: list<string>, flags: string, stamp: path]: nothing -> bool {
    if not ($output | path exists) { return true }
    if not ($stamp | path exists) { return true }
    if (open --raw $stamp) != $flags { return true }
    let newest = ($inputs | each {|p| ls -D $p | get 0.modified } | sort | last)
    (ls -D $output | get 0.modified) <= $newest
}
