# An executable's file name on this host, `<name>.exe` on Windows
export def exe-name [name: string]: nothing -> string {
    if $nu.os-info.name == "windows" { $name + ".exe" } else { $name }
}
