use (path self ../../../../../nu/mod/build)
use (path self ../../../../../nu/mod/launch)
use (path self ../../../../../nu/mod/tool)

# The workspace's root, resolved from this file's own path
const WORKSPACE = path self ../../../../..

# A map's machine planned for robojab: its MCP config, or a socket served
export def serve [--kernel: path, --image: path, --out: path, --map: string = "render_0", --set: string = "DEBUG", --seconds: int = 600, --target: string = "mcp"] {
    let game = ($WORKSPACE | path join "kit" "fierce")
    let workspace = ($game | path join ".." ".." | path expand)
    let tree = (build program-shard $game "asset" | path join $map)
    if not ($tree | path join "map.nuon" | path exists) { error make { msg: $"no tree for ($map) at ($tree)" } }
    mkdir $out
    let disk = ($out | path join $"($map).romfs")
    let made = (^genromfs -d $tree -f $disk -V "fps" | complete)
    if $made.exit_code != 0 { error make { msg: $"genromfs on ($tree): ($made.stderr)" } }
    let machine = (launch plan --kernel $kernel --image $image --out $out --disk $disk --serial "fps" --set $set --api --gamepad --sound)
    let plan = ($out | path join "plan.json")
    $machine | to json | save --raw -f $plan
    let elf = ($image | path parse | update extension "elf" | path join)
    let flags = ($elf | path dirname | path join "flags")
    let prefix = (if ($flags | path exists) { open --raw $flags | decode | lines | get 0 | split row " " | last } else { "" })
    let robo = (tool robojab $workspace)
    let common = ["--plan" $plan "--elf" $elf "--prefix" $prefix "--seconds" ($seconds | into string)]
    if $target == "mcp" {
        print $"plan: ($plan)"
        print $"serve: ($robo) mcp (($common | str join ' '))"
        print ({ robojab: { command: $robo, args: (["mcp"] ++ $common) } } | to json)
    } else {
        ^$robo serve ...$common --sock $target
    }
}
