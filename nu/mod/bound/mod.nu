# The GNU timeout a run's bounds take, resolved once, and its version line
export def timeout [] {
    let forced = ($env.JAB_TIMEOUT? | default "")
    if $forced != "" {
        let line = (timeout-version $forced)
        if not (gnu-timeout $line) { error make {msg: $"JAB_TIMEOUT names ($forced), whose --version reads ($line | to nuon), no GNU coreutils timeout, which every bound of a run takes"} }
        return { path: $forced, version: $line }
    }
    let msys = (if $nu.os-info.name == "windows" { try { [(^cygpath -w /usr/bin/timeout.exe | str trim)] } catch { [] } } else { [] })
    let listed = (which -a timeout | where type == "external" | get path)
    let candidates = ($msys ++ $listed | uniq)
    for c in $candidates {
        let line = (timeout-version $c)
        if (gnu-timeout $line) { return { path: $c, version: $line } }
    }
    error make {msg: $"no GNU coreutils timeout, which every bound of a run takes: tried (if ($candidates | is-empty) { 'none on PATH' } else { $candidates | str join ', ' }); install coreutils, or name one with JAB_TIMEOUT"}
}

# The first line a timeout prints for --version, "" when none
def timeout-version [path: string]: nothing -> string {
    try { ^$path --version | complete | get stdout | lines | get -o 0 | default "" } catch { "" }
}

# Whether a version line is GNU coreutils' timeout's
def gnu-timeout [line: string]: nothing -> bool {
    $line =~ '^timeout \(GNU coreutils\) '
}
