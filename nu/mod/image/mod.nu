use ../workspace

# Where a built image's program lives: its `home` file, else read from its path
export def home [image: path]: nothing -> string {
    let marker = ($image | path expand | path dirname | path join "home")
    if ($marker | path exists) { return (open --raw $marker | decode | str trim) }
    let parts = ($image | path expand | path split)
    let marks = ($parts | enumerate | where item == ".target" | get index)
    if ($marks | is-empty) { return ($image | path expand | path dirname) }
    let mark = ($marks | last)
    let base = ($parts | first $mark | path join)
    let relative = ($parts | skip ($mark + 2) | drop 1)
    if ($relative | is-empty) or not ($base | path join "workspace.jab.toml" | path exists) { return $base }
    let program = ($base | path join ...$relative)
    if (workspace member-of $program $base) { $program } else { $base }
}

# A launch's workspace: its image's program's, else the kernel's, else out's
export def workspace [kernel: path, image: path, out: path]: nothing -> oneof<string, nothing> {
    let home = (home $image)
    let manifest = ($home | path join "program.jab.toml")
    let found = (if ($manifest | path exists) { try { workspace workspace-of $home (open $manifest) } catch { null } } else { null })
    if $found != null { return $found }
    workspace workspace-dir ($kernel | path expand) | default (workspace workspace-dir $out)
}

# The manifest of the program an image was built from; an empty record if none
export def manifest [image: path]: nothing -> record {
    let manifest = (home $image | path join "program.jab.toml")
    if ($manifest | path exists) { open $manifest } else { {} }
}
