# One unprobed run of walk's CADENCE build, the shape a bench step calls:
# one run of one condition on the image and the kernel its caller names,
# nothing built. The build's `flags` and its romfs, `walk.romfs`, sit
# beside the image, as the build leaves them and an export copies them.
# The run's capture nonce is minted here and sent as the WNON frame at
# 200 ms, a replay stream after it with `--replay`, and the launch is
# paired with the nonce on the named spec's machine, headless unless
# `--window`, the host's sound output with `--live-sound`. The run's
# directory keeps `api.out`, `identity.nuon` (the nonce, the image's, the
# kernel's, and the romfs's SHA-256, the build's CADENCE symbols, the
# target, the workload, and the replay), and `run.nuon`, the launch's
# outcome. The bound is 180 s, or for a replay twice the reference's
# window, its dt values summed, plus 60 s. A run that does not end with
# status 0 exits 1 once its records are written, its status named.
use ../../../sdk/nu/jab.nu
use ../../../nu/mod/nonce

const cadence_symbols = [CADENCE TIMING REPLAY PREPARE CADENCE_TEST]
const nonce_at = 200ms
const bound = 180
const replay_header = 64
const replay_magic = 0x4c505257
const replay_frames = 8192
const time_hz = 10_000_000

def main [
    image: path                # walk's image, built with CADENCE
    kernel: path               # the kernel's ELF the run boots
    --spec (-s): string = ""   # the target, a named spec; the configured default unless given
    --out: path                # the run's directory
    --label: string = ""       # the run's label, a bench step's
    --replay: path             # a replay stream (cadence.nu replay-of) sent after the nonce, for a REPLAY build
    --window                   # the window a run of the program opens, in place of none
    --live-sound               # the host's sound output, in place of no sound device
] {
    if $out == null { error make { msg: "walk's cadence run needs --out, the run's directory" } }
    let image = ($image | path expand)
    let kernel = ($kernel | path expand)
    let ws = ($env.FILE_PWD | path join ".." ".." ".." | path expand)
    let stamp = ($image | path dirname | path join "flags")
    if not ($stamp | path exists) { error make { msg: $"walk's image has no build flags beside it: ($stamp)" } }
    let flags = (open --raw $stamp | decode | lines | get 0)
    let symbols = ($flags | parse --regex '--defsym (?P<name>[A-Z0-9_]+)=1' | get name)
    if "CADENCE" not-in $symbols { error make { msg: $"walk's image is no CADENCE build: ($flags)" } }
    let replaying = ("REPLAY" in $symbols)
    if $replaying and $replay == null { error make { msg: "walk's image is a REPLAY build and no --replay stream was given" } }
    if (not $replaying) and $replay != null { error make { msg: "a --replay stream was given and walk's image is no REPLAY build" } }
    let romfs = ($image | path dirname | path join "walk.romfs")
    if not ($romfs | path exists) { error make { msg: $"walk's romfs is not beside its image: ($romfs)" } }
    let machine = (jab machine-for $ws $spec 0)
    let stream = (if $replaying { replay-of $replay } else { null })
    let seconds = (if $replaying { $stream.bound } else { $bound })
    let nonce = (nonce mint 0 true)
    let sends = ([{ at: $nonce_at, bytes: (jab nonce-frame $nonce) }]
        | append (if $replaying { [{ at: $nonce_at, bytes: $stream.bytes }] } else { [] }))
    let set = (if "DEBUG" in $symbols { "debug" } else { "" })
    let id = {
        written: (date now | format date "%Y-%m-%dT%H:%M:%S%z"),
        label: $label,
        workload: { program: "example/walk", order: (if "PREPARE" in $symbols { "prepare" } else { "await" }) },
        target: $machine.spec.name,
        machine: $machine,
        image: (file-of $image),
        kernel: (file-of $kernel),
        assets: (file-of $romfs),
        flags: $flags,
        cadence: ($cadence_symbols | where {|s| $s in $symbols }),
        replay: (if $replaying { $stream | reject bytes } else { null }),
        mode: { window: $window, sound: (if $live_sound { "host" } else { "none" }), seconds: $seconds },
        profile: "paired",
        capture_nonce: $nonce,
    }
    mkdir $out
    let id_file = ($out | path join "identity.nuon")
    $id | to nuon --indent 2 | save --raw -f $id_file
    let ran = (jab launch --kernel $kernel --image $image --out $out --set $set --disk $romfs --serial "walk" --api --send $sends --seconds $seconds --spec $machine.spec.name --window=$window --live-sound=$live_sound --capture-nonce $nonce --profile paired)
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

# A replay stream as the run sends it: its bytes, held to the header
# walk reads (the magic, then the frame count at 8, then that many u32
# dt values after the 64 bytes), its SHA-256, and the run's bound, twice
# the reference's window, the dt values summed, plus 60 s.
def replay-of [stream: path]: nothing -> record<file: string, sha256: string, frames: int, window_s: float, bound: int, bytes: binary> {
    let bytes = (open --raw $stream | into binary)
    let length = ($bytes | bytes length)
    if $length < $replay_header { error make { msg: $"the replay stream is shorter than its header: ($stream), ($length) bytes" } }
    let magic = ($bytes | bytes at 0..<4 | into int --endian little)
    if $magic != $replay_magic { error make { msg: $"the replay stream's magic is not WRPL: ($stream)" } }
    let frames = ($bytes | bytes at 8..<12 | into int --endian little)
    if $frames < 1 or $frames > $replay_frames { error make { msg: $"the replay stream's frames are 1 to ($replay_frames), not ($frames): ($stream)" } }
    if $length != ($replay_header + $frames * 4) { error make { msg: $"the replay stream holds ($length) bytes where its ($frames) frames need ($replay_header + $frames * 4): ($stream)" } }
    let ticks = (0..<$frames | each {|i| $bytes | bytes at ($replay_header + $i * 4)..<($replay_header + $i * 4 + 4) | into int --endian little } | math sum)
    let window_s = ($ticks / $time_hz)
    { file: ($stream | path expand), sha256: ($bytes | hash sha256), frames: $frames, window_s: $window_s, bound: ((2 * $window_s + 60) | math ceil), bytes: $bytes }
}
