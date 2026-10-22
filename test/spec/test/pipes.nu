use ../../../nu/mod/target

# A stand-in timeout in a directory of its own, its --version not GNU's
export def stand-in [out: path]: nothing -> record<stand: string, fake: string> {
    let stand = ($out | path join "timeout_stand")
    target retire $stand
    mkdir $stand
    let fake = ($stand | path join "timeout")
    "#!/bin/sh\necho 'timeout (not coreutils) 0.1'\n" | save -f $fake
    ^chmod +x $fake
    { stand: $stand, fake: $fake }
}

# GNU's timeout named by a path relative to another working directory
export def relative [out: path, real: record]: nothing -> string {
    let up = ($out | path split | skip 1 | each { ".." } | path join)
    let relative = ($up | path join ($real.path | path split | skip 1 | path join))
    $relative
}

# The pipes' directory under the run's out, a previous one retired
export def home [out: path]: nothing -> string {
    let pipes = ($out | path join "pipes")
    target retire $pipes
    mkdir $pipes
    $pipes
}

# A previous run's bytes left in Windows' pair, in its in-file and out-file
export def leftover [windows: record]: nothing -> nothing {
    "header" | save --raw --append $windows.inward
    "guest" | save --raw --append $windows.outward
}
