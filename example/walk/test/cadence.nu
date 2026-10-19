# One unprobed run of walk's CADENCE build, the shape a bench step calls:
# one run of one condition on the image and the kernel its caller names,
# nothing built. The build's `flags` and its romfs, `walk.romfs`, sit
# beside the image, as the build leaves them and an export copies them.
# The run's capture nonce is minted here and sent as the WNON frame at
# 200 ms, a replay stream after it with `--replay`, and the launch is
# paired with the nonce on the named spec's machine, headless unless
# `--window`, the host's sound output with `--live-sound`. The run's
# directory keeps `api.out`, `identity.nuon` (the build's fields as the
# probe's identity names them, the workload, the image's and the
# kernel's SHA-256, the flags, the CADENCE symbols, and the replay, with
# the romfs's SHA-256, the target, and the nonce), and `run.nuon`, the
# launch's outcome. The bound is 180 s, or for a replay twice the
# reference's window, its dt values summed, plus 60 s. A run that does
# not end with status 0 exits 1 once its records are written, its status
# named.
use ../../../nu/mod/nonce
use ../../../nu/mod/machine
use ../../../nu/mod/launch
use ../../../nu/mod/probe

const nonce_at = 200ms
const bound = 180

def main [
    image: path                # walk's image, built with CADENCE
    kernel: path               # the kernel's ELF the run boots
    --spec (-s): string = ""   # the target, a named spec; the configured default unless given
    --out: path                # the run's directory
    --label: string = ""       # the run's label, a bench step's
    --replay: path             # a replay stream, a reference run's dt values, sent after the nonce, for a REPLAY build
    --window                   # the window a run of the program opens, in place of none
    --live-sound               # the host's sound output, in place of no sound device
] {
    if $out == null { error make { msg: "walk's cadence run needs --out, the run's directory" } }
    let image = ($image | path expand)
    let kernel = ($kernel | path expand)
    let ws = ($env.FILE_PWD | path join ".." ".." ".." | path expand)
    let fields = (if $replay == null { probe build-fields "example/walk" $image $kernel } else { probe build-fields "example/walk" $image $kernel --replay $replay })
    if "CADENCE" not-in $fields.cadence { error make { msg: $"walk's image is no CADENCE build: ($fields.flags)" } }
    let romfs = ($image | path dirname | path join "walk.romfs")
    if not ($romfs | path exists) { error make { msg: $"walk's romfs is not beside its image: ($romfs)" } }
    let machine = (machine resolve $ws $spec 0)
    let stream = (if $fields.replay == null { null } else { probe replay-stream $replay })
    let seconds = (if $stream == null { $bound } else { $stream.bound })
    let nonce = (nonce mint 0 true)
    let sends = ([{ at: $nonce_at, bytes: (probe wnon-frame $nonce) }]
        | append (if $stream == null { [] } else { [{ at: $nonce_at, bytes: $stream.bytes }] }))
    let set = (if ($fields.flags | str contains "--defsym DEBUG=1") { "debug" } else { "" })
    let id = {
        written: (date now | format date "%Y-%m-%dT%H:%M:%S%z"),
        label: $label,
        workload: $fields.workload,
        target: $machine.spec.name,
        machine: $machine,
        image: $fields.image,
        kernel: $fields.kernel,
        assets: (file-of $romfs),
        flags: $fields.flags,
        cadence: $fields.cadence,
        replay: $fields.replay,
        mode: { window: $window, sound: (if $live_sound { "host" } else { "none" }), seconds: $seconds },
        profile: "paired",
        capture_nonce: $nonce,
    }
    mkdir $out
    let id_file = ($out | path join "identity.nuon")
    $id | to nuon --indent 2 | save --raw -f $id_file
    let ran = (launch --kernel $kernel --image $image --out $out --set $set --disk $romfs --serial "walk" --api --send $sends --seconds $seconds --spec $machine.spec.name --window=$window --live-sound=$live_sound --capture-nonce $nonce --profile paired)
    $id | upsert machine $ran.machine | upsert qemu_binary $ran.qemu_binary | merge $ran.capture | to nuon --indent 2 | save --raw -f $id_file
    $ran | reject api | insert api_bytes ($ran.api | bytes length) | to nuon --indent 2 | save --raw -f ($out | path join "run.nuon")
    let named = (if $label == "" { "" } else { $" ($label)" })
    print $"walk cadence($named): status ($ran.status), ($ran.api | bytes length) bytes over the API in ($ran.wall_seconds | math round -p 1) s, nonce (nonce hex $nonce), on ($machine.spec.name)"
    if $ran.status != 0 { print $"walk cadence($named): the run ended with status ($ran.status), not 0"; exit 1 }
}

# A file as the identity names it: its path and its SHA-256.
def file-of [file: path]: nothing -> record<file: string, sha256: string> {
    { file: $file, sha256: (open --raw $file | hash sha256) }
}
