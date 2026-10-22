use (path self ../target)
use (path self ../walk)

# The nearest parent of `dir` holding workspace.jab.toml, or null
export def workspace-dir [dir: path]: nothing -> oneof<string, nothing> {
    mut d = ($dir | path expand)
    loop {
        if ($d | path join "workspace.jab.toml" | path exists) { return $d }
        let parent = ($d | path dirname)
        if $parent == $d { return null }
        $d = $parent
    }
}

# The workspace a kernel or program builds against, a parent or its manifest's
export def workspace-of [here: path, manifest: record]: nothing -> oneof<string, nothing> {
    let above = (workspace-dir $here)
    if $above != null { return $above }
    let declared = ($manifest | get -o workspace | default "")
    if $declared == "" { return null }
    let ws = ($here | path join $declared | path expand)
    if not ($ws | path join "workspace.jab.toml" | path exists) {
        error make {msg: $"($manifest.name): workspace = '($declared)' names no workspace at ($ws), which would hold workspace.jab.toml"}
    }
    $ws
}

# Whether `dir` is the workspace's kernel or a program it lists
export def member-of [dir: path, ws: path]: nothing -> bool {
    if not (target under $dir $ws) { return false }
    let relative = ($dir | path relative-to $ws | str replace --all "\\" "/")
    let listed = (open ($ws | path join "workspace.jab.toml"))
    $relative == $listed.kernel or ($relative in $listed.programs)
}

# Whether `dir` is a workspace's root, holding workspace.jab.toml
export def is-workspace [dir: path]: nothing -> bool {
    $dir | path expand | path join "workspace.jab.toml" | path exists
}

# Every program of a workspace by its path: its members, then the unlisted
export def programs-of [ws: path]: nothing -> list<string> {
    let ws = ($ws | path expand)
    let listed = (open ($ws | path join "workspace.jab.toml") | get programs)
    let root = (target root $ws)
    let found = (walk paths ($ws | path join "**" "program.jab.toml")
        | where {|f| not ($f | path relative-to $ws | path split | any {|w| $w in [".git" ".target" "target" "extern"] }) }
        | each {|f| $f | path dirname }
        | where {|d| not (target under $d $root) }
        | each {|d| $d | path relative-to $ws | str replace --all "\\" "/" }
        | where {|p| $p not-in $listed }
        | sort)
    $listed ++ $found
}

# A path given as words, each split on its slashes; "" for none
export def path-words [words: list<string>]: nothing -> string {
    $words | each {|w| $w | split row "/" } | flatten | where {|w| $w != "" and $w != "." } | str join "/"
}

# A program's path from words, a shortcut standing for its path
export def program-path [ws: path, words: list<string>]: nothing -> string {
    let at = (path-words $words)
    let shortcuts = (open ($ws | path expand | path join "workspace.jab.toml") | get -o shortcuts | default {})
    $shortcuts | get -o $at | default $at
}

# The programs at or under a path, every program for none; no match refused
export def programs-under [ws: path, words: list<string>]: nothing -> list<string> {
    let at = (program-path $ws $words)
    let all = (programs-of $ws)
    let picked = (if $at == "" { $all } else { $all | where {|p| $p == $at or ($p | str starts-with $"($at)/") } })
    if ($picked | is-empty) { error make {msg: $"no program at or under ($at); the programs: ($all | str join ', ')"} }
    $picked
}

# The one program at a path in the workspace, its directory
export def program-at [ws: path, words: list<string>]: nothing -> string {
    let at = (program-path $ws $words)
    if $at == "" { error make {msg: "a program by its path from the workspace, or its shortcut: example/bounce, kit/fierce, fierce"} }
    let all = (programs-of $ws)
    if $at not-in $all { error make {msg: $"no program at ($at); the programs: ($all | str join ', ')"} }
    $ws | path expand | path join $at
}

# Whether a program's path lies under a `test` directory
def is-test [at: string]: nothing -> bool {
    "test" in ($at | split row "/")
}

# The one program a run takes at a path: any program but a test
export def run-target [ws: path, words: list<string>]: nothing -> string {
    let at = (program-path $ws $words)
    let all = (programs-of $ws)
    let runnable = ($all | where {|p| not (is-test $p) })
    if $at == "" { error make {msg: $"a program to run by its path from the workspace, or its shortcut: ($runnable | str join ', ')"} }
    if $at in $all and (is-test $at) { error make {msg: $"($at) is a test; `./do test ($at)` runs it"} }
    if $at not-in $runnable { error make {msg: $"no program to run at ($at); the programs: ($runnable | str join ', ')"} }
    $ws | path expand | path join $at
}

# A command's directory and words: an absolute first word's or the workspace's
export def subject [ws: path, words: list<string>]: nothing -> record<dir: string, words: list<string>> {
    let first = ($words | get -o 0 | default "")
    let root = ($first | path split | get -o 0 | default "")
    if not (($root | str ends-with "/") or ($root | str ends-with "\\")) { return { dir: $ws, words: $words } }
    let dir = ($first | path expand)
    let manifests = ["workspace.jab.toml" "kernel.jab.toml" "program.jab.toml"]
    if not ($manifests | any {|m| $dir | path join $m | path exists }) { error make {msg: $"($dir) holds no workspace's, kernel's, or program's manifest"} }
    { dir: $dir, words: ($words | skip 1) }
}
