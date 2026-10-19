# The paths a glob pattern names, through `ls`, a drive letter allowed
export def paths [pattern: string, --no-dir]: nothing -> list<string> {
    let found = (try { ls -a ($pattern | into glob) } catch {|e|
        if ($e.msg | str starts-with "No matches found") { [] } else { error make {msg: $e.msg} }
    })
    let kept = (if $no_dir { $found | where type != "dir" } else { $found })
    let parts = ($pattern | path split)
    let root = (if ($parts | length) > 2 and ($parts | last 2) == ["**" "*"] { $parts | drop 2 | path join } else { "" })
    let rooted = (if $root != "" and (not $no_dir) and ($root | path type) == "dir" { [$root] } else { [] })
    $rooted ++ ($kept | get name) | each {|p| $env.PWD | path join $p }
}

# Every file under the directories, for the staleness check
export def files [dirs: list<string>]: nothing -> list<string> {
    $dirs | each {|d| paths ($d | path join "**" "*") } | flatten | where {|p| ($p | path type) == "file" }
}

# Every file and directory under the directories
export def tree [dirs: list<string>]: nothing -> list<string> {
    $dirs | each {|d| [$d] ++ (paths ($d | path join "**" "*")) } | flatten | where {|p| ($p | path type) in ["file" "dir"] }
}
