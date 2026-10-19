# jab.nu: what is left of the SDK's monolith, its definitions moved into
# the modules under nu/mod and its commands into the bins under nu/bin.
# It keeps `do`, the development commands the manifests' `do` scripts
# declare beside the SDK's probe and clean, and its help, which names
# the bins.

use ../../nu/mod/build
use ../../nu/mod/workspace

# This tool's own file, from which `do` finds the SDK's probe script.
const self = (path self)

# The development commands, `just do`: with no command the list, the
# SDK's own, probe and clean, then the kernel's and every program's, the
# `main <command>` definitions of the nushell script its manifest's `do`
# names; with one, the SDK's or the script's that defines it, run with
# the rest of the words as they came, from the directory the command was
# given in, so a relative path among them is the caller's.
def --wrapped "main do" [dir: path, ...words: string] {
    let ws = ($dir | path expand)
    if not (workspace is-workspace $ws) { error make {msg: $"($ws) is no workspace's root"} }
    let commands = (do-commands $ws)
    if ($words | is-empty) { print (do-list $commands); return }
    let name = ($words | first)
    let rest = ($words | skip 1)
    if $name == "probe" { ^nu ($self | path dirname | path dirname | path dirname | path join "nu" "bin" "nuance" "probe.nu") $ws ...$rest; return }
    if $name == "clean" { build clean $ws ...$rest; return }
    let hit = ($commands | where command == $name)
    if ($hit | is-empty) { error make {msg: $"no development command called ($name); `just do` lists them"} }
    ^nu ($hit | first | get script) $name ...$rest
}

# Every development command the kernel and the programs declare: the
# `main <command>` definitions of the script a manifest's `do` names,
# relative to it, each with the comment above it, the script, and its
# owner's path and directory.
def do-commands [ws: path]: nothing -> table<command: string, usage: string, owner: string, home: string, script: string, summary: string> {
    let m = (open ($ws | path join "workspace.jab.toml"))
    let owners = ([{ path: $m.kernel, manifest: "kernel.jab.toml" }] ++ (workspace programs-of $ws | each {|p| { path: $p, manifest: "program.jab.toml" } }))
    $owners | each {|o|
        let home = ($ws | path join $o.path)
        let declared = (open ($home | path join $o.manifest) | get -o "do" | default "")
        if $declared == "" { [] } else {
            let script = ($home | path join $declared)
            let lines = (open --raw $script | decode | lines)
            $lines | enumerate | each {|l|
                let hit = ($l.item | parse --regex '^def (?:--wrapped )?"main (?P<command>[^"]+)"\s*\[(?P<params>.*)\][^\]]*$' | get -o 0)
                if $hit == null { null } else {
                    let above = ($lines | first $l.index | reverse | take while {|x| $x | str starts-with "#" } | reverse | each {|x| $x | str replace --regex '^#\s?' '' } | str join " ")
                    { command: $hit.command, usage: (do-usage $hit.params), owner: $o.path, home: $home, script: $script, summary: $above }
                }
            } | compact
        }
    } | flatten
}

# A command's arguments as `just do` shows them, from its definition's
# parameters: a required one `<name>`, one with a default `[name]`, a
# flag `[--flag value]` or `[--flag]`, the rest `[args...]`.
def do-usage [params: string]: nothing -> string {
    $params | split row "," | each {|p| $p | str trim } | where {|p| $p != "" } | each {|p|
        let name = ($p | split row ":" | first | split row "=" | first | str trim)
        let default = (if ($p | str contains "=") { $p | split row "=" | skip 1 | str join "=" | str trim | str trim --char '"' } else { "" })
        if ($name | str starts-with "...") { "[args...]" } else if ($name | str starts-with "--") {
            if ($p | str contains ":") { $"[($name) ($default)]" } else { $"[($name)]" }
        } else if $default != "" { $"[($name)]" } else { $"<($name)>" }
    } | str join " "
}

# The list `just do` prints: each command with its arguments and its
# owner, and its description up to its first example or full stop.
def do-list [commands: table]: nothing -> string {
    let sdk = [
        { command: "probe", usage: "<kind> <program> [--seconds 12] [--set names] [--api] [--send <file>] [--trace]", owner: "sdk", summary: "Probe one program under a window and print one NUON record on how its flips reached it, `sdl` the one kind, Linux only" }
        { command: "clean", usage: "[path] [--tree release|debug]", owner: "sdk", summary: "Retire the build outputs of the programs at or under a path, or the kernel's with `kernel`, in both trees or the one --tree names; with no path the whole target, as `just clean` does" }
    ]
    let all = ($sdk ++ ($commands | select command usage owner summary))
    let shown = ($all | each {|c|
        let cut = ($c.summary | split row ": `" | first | split row ". " | first)
        let usage = (if $c.usage == "" { "" } else { $" ($c.usage)" })
        $"  just do ($c.command)($usage)  [($c.owner)]\n      ($cut)"
    })
    (["the commands for development, `just do <command> [args]`:"] ++ $shown) | str join "\n"
}

def main [] {
    print "nu jab.nu do <workspace> [command] [args]; build, test, run, bench, and watch: nu/bin/do.nu; watch bench, clean, and retire: nu/bin/nuance.nu; plan, probe, and the sdl bundle and report: nu/bin/nuance/plan.nu, probe.nu, and sdl.nu"
}
