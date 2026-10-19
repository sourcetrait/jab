use (path self ../nonce)
use (path self ../spec)
use (path self ../target)
use (path self ../tool)

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

# A Windows machine's relays, one a pipe, each with the file its job ends in
export def relays-of [out: path, pipes: list<record<endpoint: string, pipe: any>>]: nothing -> list<record<endpoint: string, name: string, inward: string, outward: string, done: string>> {
    $pipes | where {|p| $p.pipe != null } | each {|p|
        { endpoint: $p.endpoint, name: $p.pipe.name, inward: $p.pipe.inward, outward: $p.pipe.outward, done: ($out | path join $"($p.endpoint).relay.nuon") }
    }
}

# The relay's binary for a machine with relays, "" for one with none
export def relay-build [relays: list<any>, ws: oneof<string, nothing>]: nothing -> string {
    if ($relays | is-empty) { return "" }
    if $ws == null { error make {msg: "a Windows run's pipes need their relay, which the workspace builds from shim/crates/pipe, and this run has no workspace"} }
    tool shim $ws "jabpipe" --bin
}

# The pipe the pad bridge writes: its in-file, or its name on Windows; "" none
export def bridge-pipe [pad: oneof<record<name: string, inward: string, outward: string>, nothing>]: nothing -> string {
    if $pad == null { "" } else if $nu.os-info.name == "windows" { $pad.name } else { $pad.inward }
}

# A Windows machine's relays started beside its QEMU, a job each
export def relays-start [relays: list<any>, binary: string, root: path]: nothing -> list<record<job: int, relay: record>> {
    mut started = []
    for r in $relays {
        target retire $r.done $root
        target retire $"($r.done).next" $root
        let id = (job spawn {
            let next = $"($r.done).next"
            ^$binary $r.name $r.inward $r.outward | complete | to nuon | save -f $next
            mv -f $next $r.done
        })
        $started = ($started | append { job: $id, relay: $r })
    }
    $started
}

# How each relay ended once its QEMU had: a second given, then any left stopped
export def relays-stop [started: list<record<job: int, relay: record>>]: nothing -> list<record<endpoint: string, name: string, exit: oneof<int, nothing>, said: string>> {
    if ($started | is-empty) { return [] }
    let deadline = ((date now) + 1sec)
    while ((date now) < $deadline) and ($started | any {|s| not ($s.relay.done | path exists) }) { sleep 50ms }
    $started | each {|s|
        let done = (if ($s.relay.done | path exists) { try { open --raw $s.relay.done | decode | from nuon } catch { null } } else { null })
        if $done == null { try { job kill $s.job } }
        { endpoint: $s.relay.endpoint, name: $s.relay.name, exit: (if $done == null { null } else { $done.exit_code }), said: (if $done == null { "" } else { $done.stderr }) }
    }
}

# Fails a launch for a relay that ended on its own in failure, naming its pipe
export def relays-held [relayed: list<any>, qemu: record] {
    let failed = ($relayed | where {|r| $r.exit != null and $r.exit != 0 })
    if ($failed | is-empty) { return }
    let told = ($failed | each {|r| $"the ($r.endpoint) pipe's relay, for ($r.name), ended with ($r.exit): ($r.said | str trim)" } | str join "; ")
    let said = ($qemu.stderr | str trim)
    error make {msg: $"($told); QEMU ended with ($qemu.exit_code)(if $said == '' { '' } else { $', saying: ($said)' })"}
}

# A named pipe at `path`: one there kept, anything else retired first
export def fifo-at [path: path, root: path]: nothing -> nothing {
    if ($path | path type) == "pipe" { return }
    target retire $path $root
    ^mkfifo $path
}

# A command into the QEMU monitor's pipe under the run's bound; true if it went in
export def monitor-send [monitor: path, command: string, bound: string]: nothing -> bool {
    pipe-write ($monitor + ".in") $"($command)\n" $bound
}

# Bytes into one of QEMU's pipes as the host takes them; true when they went in
export def pipe-write [inward: path, data: any, bound: string]: nothing -> bool {
    if $nu.os-info.name != "windows" { return (fifo-write $inward $data $bound) }
    $data | save --raw --append $inward
    true
}

# Bytes into a named pipe under a one-second bound; false when no reader came
export def fifo-write [fifo: path, data: any, bound: string]: nothing -> bool {
    let r = ($data | ^$bound 1 tee -a $fifo | complete)
    $r.exit_code == 0
}

# A word for the QEMU monitor's command line, double-quoted and escaped
export def hmp-quoted [text: string]: nothing -> string {
    let escaped = ($text | str replace --all '\' '\\' | str replace --all '"' '\"')
    $"\"($escaped)\""
}

# Whether a screen QEMU writes comes whole within five seconds
export def screen-whole [path: path]: nothing -> bool {
    let header = ($"P6\n($spec.display_size.width) ($spec.display_size.height)\n255\n" | into binary)
    let whole = (($header | bytes length) + $spec.display_size.width * $spec.display_size.height * 3)
    for _ in 0..100 {
        if ($path | path exists) {
            if (ls -D $path | get 0.size | into int) == $whole {
                return ((open --raw $path | into binary | bytes at 0..<($header | bytes length)) == $header)
            }
        }
        sleep 50ms
    }
    false
}
