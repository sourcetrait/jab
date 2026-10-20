use (path self ../chardev)
use (path self ../target)
use (path self ../tool)
use (path self ../word)

# The gamepad a machine carries when asked: the shim's fifo on Linux, or the port
export def pad-attach [wanted: bool, out: path, port: bool, ws: oneof<string, nothing>, root: path]: nothing -> record<args: list<string>, env: record, fifo: string, port: bool, header: binary> {
    let none = { args: [], env: {}, fifo: "", port: false, header: 0x[] }
    if not $wanted { return $none }
    if $port or $nu.os-info.name != "linux" {
        return ($none | merge { port: true, header: (pad-port-header) })
    }
    if $ws == null { error make {msg: "a gamepad needs a workspace, above the kernel or the output directory, which holds shim/crates/evdev"} }
    let shim = (tool shim $ws "jabshim_evdev")
    let fifo = ($out | path join "pad")
    chardev fifo-at $fifo $root
    {
        args: ["-device" $"virtio-input-host-device,evdev=($fifo)"],
        env: { LD_PRELOAD: $shim, EVDEV_SHIM_FIFO: $fifo },
        fifo: $fifo,
        port: false,
        header: 0x[],
    }
}

# A launch's pad table as the reports it plays, grouped by their time
export def pad-table [table: path]: nothing -> record<groups: list<any>> {
    if ($table | is-empty) { return { groups: [] } }
    let rows = (open ($table | path expand))
    if ($rows | is-empty) { return { groups: [] } }
    let wanted = [at type code value]
    if not ($wanted | all {|c| $c in ($rows | columns) }) {
        error make {msg: $"($table): a pad table has the columns at, type, code, value; this one has ($rows | columns | str join ', ')"}
    }
    { groups: ($rows | sort-by at | group-by --to-table {|r| $r.at | into int } | each {|g| { at: ($g.items | first | get at), items: $g.items } }) }
}

# One report of pad events as the device sends them, a SYN_REPORT closing it
export def pad-report [items: table<type: int, code: int, value: int>]: nothing -> binary {
    ($items | each {|e| input-event $e.type $e.code $e.value } | bytes collect) ++ (input-event 0 0 0)
}

# Pad events as the pad port takes them, eight bytes each, no SYN
export def pad-frames [items: table<type: int, code: int, value: int>]: nothing -> binary {
    $items | each {|e| (word le $e.type 2) ++ (word le $e.code 2) ++ (word le $e.value 4) } | bytes collect
}

# The pad port's header for the reference pad the evdev shim answers as
def pad-port-header []: nothing -> binary {
    let name = ("8BitDo Ultimate" | into binary)
    let axes = {
        0: [0 255 0 15 0], 1: [0 255 0 15 0], 2: [0 255 0 15 0], 5: [0 255 0 15 46],
        9: [0 255 0 15 0], 10: [0 255 0 15 0], 16: [-1 1 0 0 0], 17: [-1 1 0 0 0],
    }
    let axis_mask = ($axes | columns | each {|c| 1 bit-shl ($c | into int) } | math sum)
    let absinfo = (0..<64 | each {|code|
        let info = ($axes | get -o ($code | into string))
        if $info == null { word zeros 20 } else { $info | each {|f| word le $f 4 } | bytes collect }
    } | bytes collect)
    ("JPAD" | into binary) ++ (word le 1 4) ++ $name ++ (word zeros (128 - ($name | bytes length))) ++ (word le 0xffff 4) ++ (word le 0 4) ++ (word le $axis_mask 8) ++ $absinfo
}

# One input_event as an evdev device writes it, 24 bytes
def input-event [type: int, code: int, value: int]: nothing -> binary {
    let ns = (date now | into int)
    let sec = ($ns // 1_000_000_000)
    let usec = (($ns mod 1_000_000_000) // 1000)
    ($sec | into binary --endian little | bytes at 0..<8) ++ ($usec | into binary --endian little | bytes at 0..<8) ++ ($type | into binary --endian little | bytes at 0..<2) ++ ($code | into binary --endian little | bytes at 0..<2) ++ ($value | into binary --endian little | bytes at 0..<4)
}

# The gamepad on a run's line from jabdisco's record: passed through, or bridged
export def gamepad-plan [found: record]: nothing -> record<args: list<string>, port: bool, bridge: oneof<record<name: string, vendor: oneof<int, nothing>, product: oneof<int, nothing>>, nothing>> {
    let none = { args: [], port: false, bridge: null }
    let pad = ($found | get -o gamepad)
    match $nu.os-info.name {
        "linux" => {
            let forced = ($env.JAB_PAD? | default "")
            let path = (if $forced != "" { $forced } else if $pad == null { "" } else { $pad | get -o path | default "" })
            if $path == "" { $none } else { { args: ["-device" $"virtio-input-host-device,evdev=($path)"], port: false, bridge: null } }
        },
        "macos" | "windows" => {
            if $pad == null { $none } else { { args: [], port: true, bridge: { name: $pad.name, vendor: ($pad | get -o vendor), product: ($pad | get -o product) } } }
        },
        _ => $none,
    }
}

# The pad bridge as a supervised launch's helper; none without a bridge
export def bridge-helpers [bridge: oneof<record<name: string, vendor: oneof<int, nothing>, product: oneof<int, nothing>>, nothing>, pipe: string, ws: string, out: path, root: path]: nothing -> list<record<name: string, command: list<string>, stderr: string>> {
    if $bridge == null { return [] }
    let bin = (tool shim $ws "jabshim_pad" --bin)
    let vendor = (if $bridge.vendor == null { "" } else { $bridge.vendor | into string })
    let product = (if $bridge.product == null { "" } else { $bridge.product | into string })
    let said = ($out | path join "bridge.stderr")
    target retire $said $root
    [{ name: "pad bridge", command: [$bin $pipe $bridge.name $vendor $product], stderr: $said }]
}

# Whether the keyboard and the tablet go on the line; both flags refused
export def kbm-choice [kbm: bool, no_kbm: bool]: nothing -> bool {
    if $kbm and $no_kbm { error make {msg: "--kbm and --no-kbm together: one or the other"} }
    not $no_kbm
}

# Whether the gamepad goes on the line; both flags refused
export def pad-choice [pad: bool, no_pad: bool]: nothing -> bool {
    if $pad and $no_pad { error make {msg: "--pad and --no-pad together: one or the other"} }
    not $no_pad
}
