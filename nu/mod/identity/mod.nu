# A reader's provenance: its checkouts' commits and states, its interpreters
export def reader [roots: list<path>, --launches, --executables: list<path> = []]: nothing -> record<repos: table<repo: string, commit: oneof<string, nothing>, dirty: oneof<bool, nothing>>, runtime: table<role: string, version: string, sha256: oneof<string, nothing>>, executables: table<name: string, sha256: string>> {
    let repos = ($roots | each {|r|
        let root = ($r | path expand)
        let source = ($root | path join "source.nuon")
        if ($source | path exists) {
            { repo: $root, commit: (open $source | get -o commit), dirty: null }
        } else {
            let head = (^git -C $root rev-parse HEAD | complete)
            if $head.exit_code != 0 { { repo: $root, commit: null, dirty: null } } else {
                let status = (^git -C $root status --porcelain | complete | get stdout | str trim)
                { repo: $root, commit: ($head.stdout | str trim), dirty: ($status != "") }
            }
        }
    })
    let sha256 = {|file: path| try { open --raw $file | hash sha256 } catch { null } }
    let running = { role: "nu", version: (version | get version), sha256: (do $sha256 $nu.current-exe) }
    let launched = (if $launches {
        let exe = (which nu | where type == external | get -o 0.path)
        if $exe == null { [{ role: "nu launched", version: "", sha256: null }] } else {
            [{ role: "nu launched", version: (^$exe --version | complete | get stdout | str trim), sha256: (do $sha256 $exe) }]
        }
    } else { [] })
    {
        repos: $repos,
        runtime: ([$running] ++ $launched),
        executables: ($executables | each {|e| { name: ($e | path basename), sha256: (open --raw $e | hash sha256) } }),
    }
}
