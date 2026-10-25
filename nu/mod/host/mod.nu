# The roles a machine declares in jab/debug.toml, `unknown` the default
export const roles = [unknown container desktop metal]

# An executable's file name on this host, `<name>.exe` on Windows
export def exe-name [name: string]: nothing -> string {
    if $nu.os-info.name == "windows" { $name + ".exe" } else { $name }
}

# This machine's declared role: jab/debug.toml's, its file seeded if absent
export def role [ws: path]: nothing -> string {
    let file = (config-file "jab" "debug.toml")
    if ($file | path type) == null {
        let seed = ($ws | path join "asset" "default" "debug.toml")
        if not ($seed | path exists) { error make {msg: $"no ($seed) to seed ($file) from"} }
        cp $seed $file
    }
    let declared = (system-key $file "role")
    if $declared not-in $roles { error make {msg: $"($file)'s [system] role is ($declared | to nuon), where a machine declares one of ($roles | str join ', ')"} }
    $declared
}

# This system's alias: lowkick/config.toml's, `lowkick` written if absent
export def system-alias []: nothing -> string {
    let file = (config-file "lowkick" "config.toml")
    if ($file | path type) == null { $"[system](char nl)alias = 'lowkick'(char nl)" | save $file }
    let named = (system-key $file "alias")
    if ($named | describe) != "string" or ($named | str trim) == "" { error make {msg: $"($file) names no [system] alias, the system's nickname a run records"} }
    $named
}

# A file in `dir` under the XDG config home, the home checked and `dir` made
def config-file [dir: string, file: string]: nothing -> path {
    let given = ($env.XDG_CONFIG_HOME? | default "")
    let home = (if $given == "" { $nu.home-dir | path join ".config" } else { $given })
    if ($home | path type) != "dir" { error make {msg: $"the XDG config home ($home) is not there, where ($dir)/($file) is read"} }
    let at = ($home | path join $dir)
    mkdir $at
    $at | path join $file
}

# A TOML file's `[system]` value at `key`, null where it names none
def system-key [file: path, key: string]: nothing -> any {
    let cfg = (try { open --raw $file | into binary | decode | from toml } catch {|e| error make {msg: $"($file) is no TOML the tools read: ($e.msg)"} })
    $cfg | get -o system | get -o $key
}
