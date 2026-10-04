# play.nu: the game handed to a player that is not a hand on a pad: a
# machine planned for a map on the debug kernel, with the API's port,
# the pad, and the sound device, served through robojab, the harness
# that takes commands and gives frames back. `--target mcp` prints the
# MCP server line and the config record a subagent template takes, so
# an agent plays the game as a tool; any other `--target` is a socket
# path to serve on in the foreground, for a script. The plan and
# everything the run writes land in `out`; a fault on the UART is
# resolved to its routine from the ELF beside the image through the
# toolchain the build's flags name. `just play` builds and runs it.
use ../../../../sdk/nu/jab.nu

def main [--kernel: path, --image: path, --out: path, --map: string = "factory", --set: string = "DEBUG", --seconds: int = 600, --target: string = "mcp"] {
    let game = ($env.FILE_PWD | path join ".." | path expand)
    let workspace = ($game | path join ".." ".." ".." | path expand)
    let tree = (jab program-shard $game "asset" | path join $map)
    if not ($tree | path join "map.nuon" | path exists) { error make { msg: $"no tree for ($map) at ($tree)" } }
    mkdir $out
    let disk = ($out | path join $"($map).romfs")
    let made = (^genromfs -d $tree -f $disk -V "fps" | complete)
    if $made.exit_code != 0 { error make { msg: $"genromfs on ($tree): ($made.stderr)" } }
    let machine = (jab plan --kernel $kernel --image $image --out $out --disk $disk --serial "fps" --set $set --api --gamepad --sound)
    let plan = ($out | path join "plan.json")
    $machine | to json | save --raw -f $plan
    let elf = ($image | path dirname | path join "fps.elf")
    let flags = ($elf | path dirname | path join "flags")
    let prefix = (if ($flags | path exists) { open --raw $flags | decode | lines | get 0 | split row " " | last } else { "" })
    let robo = (jab robo-build $workspace)
    let common = ["--plan" $plan "--elf" $elf "--prefix" $prefix "--seconds" ($seconds | into string)]
    if $target == "mcp" {
        print $"plan: ($plan)"
        print $"serve: ($robo) mcp (($common | str join ' '))"
        print ({ robojab: { command: $robo, args: (["mcp"] ++ $common) } } | to json)
    } else {
        ^$robo serve ...$common --sock $target
    }
}
