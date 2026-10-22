# The one target a workspace builds into, under the XDG cache when it is set
export def root [anchor: path]: nothing -> string {
    let anchor = ($anchor | path expand)
    let cache = ($env.XDG_CACHE_HOME? | default "")
    if $cache == "" { return ($anchor | path join ".target") }
    let checkout = $"($anchor | path basename)-($anchor | hash sha256 | str substring 0..<8)"
    $cache | path expand | path join "jab" "target" $checkout
}

# Whether a directory is a target this tool makes
def is-target [dir: path]: nothing -> bool {
    let name = ($dir | path basename)
    ($name == ".target") or ($name != "tmp" and ($dir | path dirname | path basename) == "target" and ($dir | path dirname | path dirname | path basename) == "jab")
}

# The nearest target a path lies in, or null
def target-of [path: path]: nothing -> oneof<string, nothing> {
    mut d = ($path | path expand --no-symlink | path dirname)
    loop {
        if (is-target $d) { return $d }
        let up = ($d | path dirname)
        if $up == $d { return null }
        $d = $up
    }
}

# Where a target's retirements go, and the base a retired path keeps under
export def retire-home [target: path]: nothing -> record<tmp: string, base: string> {
    let target = ($target | path expand)
    let base = (if ($target | path basename) == ".target" { $target } else { $target | path dirname })
    { tmp: ($base | path join "tmp"), base: $base }
}

# A path moved aside whole into the retire home in place of deleting it
export def retire [path: path, root?: path, --stamp: string = ""]: nothing -> nothing {
    let from = ($path | path expand --no-symlink)
    if ($from | path type) == null { return }
    let target = (if $root != null { $root | path expand } else { target-of $from })
    if $target == null { error make {msg: $"($from) lies in no target, so there is nowhere to retire it to; it is left as it is"} }
    let home = (retire-home $target)
    if (under $from $home.tmp) { error make {msg: $"($from) is already retired; it is left as it is"} }
    let stamp = (if $stamp == "" { date now | format date "%Y%m%d-%H%M%S" } else { $stamp })
    let rest = (if (under $from $home.base) { $from | path relative-to $home.base | path split } else { ["outside"] ++ ($from | path split | skip 1) })
    let at = ($home.tmp | path join "retired" $stamp ...$rest)
    mut dest = $at
    mut n = 1
    while ($dest | path type) != null {
        $dest = $"($at).($n)"
        $n += 1
    }
    mkdir ($dest | path dirname)
    mv $from $dest
}

# Where a kernel's or a program's output lives in a target
export def shard-of [here: path, workspace: oneof<string, nothing>, root: path, name: string]: nothing -> record<relative: string, inside: bool> {
    if (under $here $root) { return { relative: "", inside: true } }
    if $workspace == null { return { relative: $name, inside: false } }
    if (under $here $workspace) { return { relative: ($here | path relative-to $workspace | str replace --all "\\" "/"), inside: false } }
    { relative: (["external" $"($name)-($here | hash sha256 | str substring 0..<8)"] | path join), inside: false }
}

# A build context's purpose shard, beside its source when inside the target
export def shard-dir [c: record<here: path, manifest: record, manifest_path: path, workspace: oneof<path, nothing>, toolchain: oneof<path, nothing>, prefix: string, symbols: list<string>, profile: string, root: path, shard: string, inside: bool, target: path, out: path>, purpose: string]: nothing -> string {
    if $c.inside { $c.here | path join $purpose } else { $c.root | path join $purpose $c.shard }
}

# The symbols that put a build in a tree: DEBUG for debug, none for release
export def tree-symbols [tree: string]: nothing -> list<string> {
    match $tree {
        "debug" => ["DEBUG"],
        "release" => [],
        _ => { error make {msg: $"a tree is release or debug, not ($tree)"} },
    }
}

# Whether `dir` is `root` or lies under it
export def under [dir: path, root: path]: nothing -> bool {
    try { $dir | path relative-to $root | ignore; true } catch { false }
}

# The workspace's whole target retired under one stamp
export def clean [ws: path]: nothing -> nothing {
    let target = (root $ws)
    if ($target | path type) != "dir" { print $"jab: no target at ($target)"; return }
    if not (is-target $target) { error make {msg: $"($target) is not a target this tool makes; leaving it"} }
    let home = (retire-home $target)
    let stamp = (date now | format date "%Y%m%d-%H%M%S")
    let entries = (if $home.base == $target { ls -a $target | get name | where {|e| ($e | path basename) != "tmp" } } else { [$target] })
    for e in $entries { retire $e $target --stamp $stamp }
    print $"jab: retired ($target) to ($home.tmp | path join 'retired' $stamp); `nu/bin/nuance.nu retire` deletes everything retired"
}

# The retire home's tmp deleted, the one deletion this tool makes
export def retire-all [ws: path]: nothing -> nothing {
    let home = (retire-home (root $ws))
    let tmp = $home.tmp
    if ($tmp | path type) == null { print $"jab: nothing retired at ($tmp)"; return }
    let kind = (ls -D $tmp | get 0.type)
    let base = ($home.base | path basename)
    let placed = (($tmp | path basename) == "tmp") and ($base == ".target" or ($base == "target" and ($home.base | path dirname | path basename) == "jab"))
    if $kind != "dir" or not $placed { error make {msg: $"($tmp) is not the retire home this tool keeps; leaving it"} }
    let size = (du $tmp | get -o 0.apparent | default 0b)
    rm --recursive --permanent $tmp
    print $"jab: deleted ($tmp), ($size) retired"
}
