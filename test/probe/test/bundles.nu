use ../../../nu/mod/nonce
use ../../../nu/mod/sdl
use std/assert
use ./logs.nu [hex write-log]

# What a bundle's check made of a bundle: the stage that refused it, with
# its words, or stage 0 and its reading where it was admitted.
export def checked [bundle: path, guest: closure]: nothing -> record<stage: int, refused: string, result: any> {
    try {
        { stage: 0, refused: "", result: (sdl bundle-check $bundle --guest $guest) }
    } catch {|e|
        { stage: ($e.msg | parse --regex 'refused at stage (?P<n>\d+)' | get -o 0.n | default "-1" | into int), refused: $e.msg, result: null }
    }
}

# A bundle's manifest rewritten with each file it lists that lies there,
# its SHA-256 and size as they are now, and each object's table_sha256 its
# table's, so a negative past the inventory reaches its own stage.
export def rehash [bundle: path]: nothing -> nothing {
    let file = ($bundle | path join "bundle.nuon")
    let m = (open --raw $file | into binary | decode | from nuon)
    let files = ($m.files | where {|f| $bundle | path join $f.path | path exists } | each {|f|
        let p = ($bundle | path join $f.path)
        { path: $f.path, sha256: (open --raw $p | hash sha256), size: (ls -D $p | get 0.size | into int) }
    })
    let objects = ($m.objects | each {|o| if $o.table == null { $o } else { $o | update table_sha256 ($files | where path == $o.table | get -o 0.sha256) } })
    $m | update files $files | update objects $objects | to nuon --indent 1 | save --raw -f $file
}

# A text in a file replaced, held to occur there exactly once first, so a
# negative is the fault it names and no other.
def swap-once [file: path, find: string, put: string]: nothing -> nothing {
    let text = (open --raw $file | into binary | decode)
    let n = (($text | split row $find | length) - 1)
    assert equal $n 1 $"negative: ($find) occurs once in ($file | path basename), not ($n) times"
    $text | str replace $find $put | save --raw -f $file
}

# The one line of a file holding a text taken out.
def drop-line [file: path, holding: string]: nothing -> nothing {
    let lines = (open --raw $file | into binary | decode | lines)
    let kept = ($lines | where {|l| not ($l | str contains $holding) })
    assert equal (($lines | length) - ($kept | length)) 1 $"negative: one line of ($file | path basename) holds ($holding)"
    ($kept | str join "\n") + "\n" | save --raw -f $file
}

# A NUON file rewritten through `change`.
def nuon-edit [file: path, change: closure]: nothing -> nothing {
    let value = (open --raw $file | into binary | decode | from nuon)
    do $change $value | to nuon --indent 1 | save --raw -f $file
}

# A paired capture's maker, each capture bundled where it was taken
export def capture [bundles: path, shim_logs: record]: nothing -> closure {
    let exe = $shim_logs.exe
    let flip_chain = $shim_logs.flip_chain
    let registration_chain = $shim_logs.registration_chain
    let switch_chain = $shim_logs.switch_chain
    let render_chain = $shim_logs.render_chain
    let capture = {|name: string, run_nonce: int, pid: int|
        let probe = ($bundles | path join $"($name)_probe")
        mkdir $probe
        let sdl = ($probe | path join "sdl.log")
        write-log $sdl ($exe ++ [$"process ($pid)" $"nonce (nonce hex $run_nonce)" $flip_chain $registration_chain $switch_chain $render_chain "size"])
        let upload = (sdl log $sdl | get events | where name == "make_current" | first)
        let flushed = (($upload.ts - 0.002) * 1e9 | into int | into datetime | format date "%Y-%m-%dT%H:%M:%S%.6fZ")
        $"($flushed) virtio_gpu_cmd_res_flush res 0x1, x 0, y 0, w 1920, h 1080\n" | save --raw ($probe | path join "trace.log")
        $run_nonce | into binary --endian little | save --raw ($probe | path join "api.out")
        { profile: "paired", capture_nonce: $run_nonce, qemu_pid: $pid, sdl_log: $sdl, shim: "", window: "sdl,gl=on", api: true, sends: [] } | to nuon | save --raw ($probe | path join "identity.nuon")
        let bundle = ($bundles | path join $name)
        let manifest = (sdl bundle $probe $bundle)
        # the fixture object 0 is no QEMU, so its manifest names the one the
        # trace bracket rests on
        nuon-edit ($bundle | path join "bundle.nuon") {|m| $m | update host.qemu.version "QEMU emulator version 11.1.2" }
        { probe: $probe, bundle: $bundle, manifest: $manifest }
    }
    $capture
}

# The bundle's negatives, each a change to a copy and the stage refusing it
export def negatives [shim_logs: record, symbol: closure, second: record]: nothing -> list<any> {
    let inside = $shim_logs.inside
    let switch_frame = (do $inside 0 "displaychangelistener_gfx_switch")
    let moved_frame = $"0+(hex ((do $symbol 'displaychangelistener_gfx_switch').value + 8))"
    let registration_frame = (do $inside 0 "qemu_console_register_listener")
    let negatives = [
        { name: "bundle_log_byte", stage: 1, rehash: false, change: {|b| swap-once ($b | path join "sdl.log") "process 4242" "process 4243" } }
        { name: "bundle_file_added", stage: 1, rehash: false, change: {|b| "a file the manifest does not list\n" | save --raw ($b | path join "added.txt") } }
        { name: "bundle_hash_altered", stage: 1, rehash: false, change: {|b| nuon-edit ($b | path join "bundle.nuon") {|m| $m | update files ($m.files | each {|f| if $f.path == "classified.nuon" { $f | update sha256 ("0" | fill --character "0" --width 64) } else { $f } }) } } }
        { name: "bundle_inode", stage: 2, rehash: false, change: {|b| nuon-edit ($b | path join "bundle.nuon") {|m| $m | update objects ($m.objects | each {|o| if $o.index == 0 { $o | update inode ($o.inode + 1) } else { $o } }) } } }
        { name: "bundle_table_removed", stage: 2, rehash: true, change: {|b| rm ($b | path join "tables" "0.nm") } }
        { name: "bundle_event_altered", stage: 3, rehash: true, change: {|b| swap-once ($b | path join "sdl.log") $switch_frame $moved_frame } }
        { name: "bundle_event_removed", stage: 3, rehash: true, change: {|b| drop-line ($b | path join "sdl.log") $registration_frame } }
        { name: "bundle_classified_dropped", stage: 3, rehash: true, change: {|b| nuon-edit ($b | path join "classified.nuon") {|c| $c | update events ($c.events | drop 1) } } }
        { name: "bundle_kind_altered", stage: 4, rehash: true, change: {|b| nuon-edit ($b | path join "classified.nuon") {|c| $c | update events ($c.events | each {|e| if $e.kind == "upload" { $e | update kind "console" } else { $e } }) } } }
        { name: "bundle_table_renamed", stage: 4, rehash: true, change: {|b| swap-once ($b | path join "tables" "0.nm") "sdl2_gl_update " "sdl2_gl_updatf " } }
        { name: "bundle_evidence_altered", stage: 4, rehash: true, change: {|b| nuon-edit ($b | path join "classified.nuon") {|c| $c | update events ($c.events | each {|e| if $e.kind == "render" { $e | update evidence "timing" } else { $e } }) } } }
        { name: "bundle_pid_altered", stage: 5, rehash: true, change: {|b| swap-once ($b | path join "sdl.log") "process 4242" "process 4243" } }
        { name: "bundle_flush_removed", stage: 5, rehash: true, change: {|b| drop-line ($b | path join "trace.log") "virtio_gpu_cmd_res_flush" } }
        { name: "bundle_pid_unrecorded", stage: 5, rehash: true, change: {|b| nuon-edit ($b | path join "identity.nuon") {|i| $i | reject qemu_pid } } }
        { name: "bundle_guest_zero", stage: 5, rehash: true, change: {|b| 0 | into binary --endian little | save --raw -f ($b | path join "api.out") } }
        { name: "bundle_exchanged", stage: 5, rehash: true, change: {|b| cp -f ($second.bundle | path join "api.out") ($b | path join "api.out") } }
        { name: "bundle_qemu_unsupported", stage: 5, rehash: false, change: {|b| nuon-edit ($b | path join "bundle.nuon") {|m| $m | update host.qemu.version "QEMU emulator version 10.2.2" } } }
        { name: "bundle_flush_after", stage: 5, rehash: true, change: {|b| let up = (open --raw ($b | path join "classified.nuon") | decode | from nuon | get events | where kind == "upload" | first | get stamp | split row "."); let us = (($up.0 | into int) * 1000000 + ($up.1 | into int) + 1); $"((($us * 1000) | into datetime | format date "%Y-%m-%dT%H:%M:%S%.6fZ")) virtio_gpu_cmd_res_flush res 0x1, x 0, y 0, w 1920, h 1080\n" | save --raw -f ($b | path join "trace.log") } }
    ]
    $negatives
}
