use (path self ../nonce)
use (path self ../target)

# A machine's virtio-serial ports, debug, API, and pad, each its file or pipe
export def ports [names: list<string>, out: path, api: bool, pad_port: bool, root: path, nonce: int]: nothing -> record<args: list<string>, debug_log: string, api: oneof<record<name: string, inward: string, outward: string>, nothing>, pad: oneof<record<name: string, inward: string, outward: string>, nothing>> {
    mkdir $out
    let debug = (if "DEBUG" in $names {
        let log = ($out | path join "debug.log")
        target retire $log $root
        { args: ["-chardev" $"file,id=jabdebug,path=($log)" "-device" "virtserialport,chardev=jabdebug,nr=1,name=jab.debug"], log: $log }
    } else { { args: [], log: "" } })
    let port = (if $api { pipe-pair $out "api" $nonce $nu.os-info.name $root } else { null })
    let pad = (if $pad_port { pipe-pair $out "padport" $nonce $nu.os-info.name $root } else { null })
    let port_args = (if $port == null { [] } else { ["-chardev" $"pipe,id=jabapi,path=($port.name)" "-device" "virtserialport,chardev=jabapi,nr=2,name=jab.api"] })
    let pad_args = (if $pad == null { [] } else { ["-chardev" $"pipe,id=jabpad,path=($pad.name)" "-device" "virtserialport,chardev=jabpad,nr=3,name=jab.pad"] })
    let device = (if ($debug.args | is-empty) and ($port_args | is-empty) and ($pad_args | is-empty) { [] } else { ["-device" "virtio-serial-device"] })
    { args: ($device ++ $debug.args ++ $port_args ++ $pad_args), debug_log: $debug.log, api: $port, pad: $pad }
}

# QEMU's pipe chardev path for an endpoint: `<out>/<endpoint>`, a name on Windows
export def pipe-path [out: path, endpoint: string, nonce: int, os: string]: nothing -> string {
    if $os != "windows" { return ($out | path join $endpoint) }
    if $nonce < 1 { error make {msg: $"a Windows run's pipes are named by its nonce, 1 to 2^63 - 1, not ($nonce)"} }
    $"jab-(nonce hex $nonce)-($endpoint)"
}

# A pipe pair for QEMU's pipe chardev, its in-file and out-file made fresh
export def pipe-pair [out: path, endpoint: string, nonce: int, os: string, root: path]: nothing -> record<name: string, inward: string, outward: string> {
    let name = (pipe-path $out $endpoint $nonce $os)
    let inward = ($out | path join $"($endpoint).in")
    let outward = ($out | path join $"($endpoint).out")
    if $os == "windows" {
        target retire $inward $root
        "" | save $inward
    } else {
        fifo-at $inward $root
    }
    target retire $outward $root
    "" | save $outward
    { name: $name, inward: $inward, outward: $outward }
}

# A Windows machine's relays, one a pipe with no client of its own
export def relays-of [pipes: list<record<endpoint: string, pipe: any>>]: nothing -> list<record<endpoint: string, name: string, inward: string, outward: string>> {
    $pipes | where {|p| $p.pipe != null } | each {|p|
        { endpoint: $p.endpoint, name: $p.pipe.name, inward: $p.pipe.inward, outward: $p.pipe.outward }
    }
}

# The pipe the pad bridge writes: its in-file, or its name on Windows; "" none
export def bridge-pipe [pad: oneof<record<name: string, inward: string, outward: string>, nothing>]: nothing -> string {
    if $pad == null { "" } else if $nu.os-info.name == "windows" { $pad.name } else { $pad.inward }
}

# A named pipe at `path`: one there kept, anything else retired first
export def fifo-at [path: path, root: path]: nothing -> nothing {
    if ($path | path type) == "pipe" { return }
    target retire $path $root
    ^mkfifo $path
}

# A word for the QEMU monitor's command line, double-quoted and escaped
export def hmp-quoted [text: string]: nothing -> string {
    let escaped = ($text | str replace --all '\' '\\' | str replace --all '"' '\"')
    $"\"($escaped)\""
}
