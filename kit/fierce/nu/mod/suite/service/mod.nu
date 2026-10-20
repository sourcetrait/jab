use (path self ../../../../../../nu/mod/capture)
use (path self ../../../../../../nu/mod/launch)
use (path self ../../pose)
use std/assert

# The peak a window must reach to be heard, sound's own
const SOUND_HEARD = 64

# The play's reports a second, the reference pad's rate
const REPORT_HZ = 125

# The play's reports, ten seconds at the reference pad's rate
const REPORTS = 1250

# The first report's time, the pad opened by the first frame's look by then
const PLAY_FROM = 2000ms

# The Z frame's time, a second past the last report so every event is taken
const END_AT = 13000ms

# The run's bound, past the exit's flush of the sound
const SECONDS = 20

# The recording's window, a coarse gap's length
const WINDOW_SECONDS = 0.05

# The windows read from the ambient's first, to the play's end less a second
const HEARD_TO = 11.0

# The axes each report moves: the left stick's two and the right stick's Z
const AXES = [0 1 2]

# The QEMU trace event of a report virtio-input dropped for want of buffers
const QUEUE_FULL = "virtio_input_queue_full"

# The pad's table: three axes a report, sweeping, REPORT_HZ reports a second
def play-table []: nothing -> table<at: duration, type: int, code: int, value: int> {
    0..<$REPORTS | each {|i|
        let at = ($PLAY_FROM + ($i * (1sec / $REPORT_HZ)))
        let t = ($i | into float)
        let x = (127 + 60 * (2 * 3.141592653589793 * $t / 250 | math sin) | math round | into int)
        let y = (87 + 30 * (2 * 3.141592653589793 * $t / 625 | math cos) | math round | into int)
        let z = (127 + 40 * (2 * 3.141592653589793 * $t / 375 | math sin) | math round | into int)
        [[at type code value]; [$at 3 ($AXES | get 0) $x] [$at 3 ($AXES | get 1) $y] [$at 3 ($AXES | get 2) $z]]
    } | flatten
}

# The frames apart a window's picks sit, a coarse read of each window
const PICK_FRAMES = 16

# A recording's 50 ms windows' peaks from its first frame, left channel, sampled
def window-peaks [wav: path]: nothing -> list<int> {
    let w = (capture wave $wav)
    let frame_bytes = ($w.channels * ($w.bits // 8))
    let per = (($w.rate * $WINDOW_SECONDS) | math round | into int)
    let windows = ($w.frames // $per)
    0..<$windows | each {|i|
        seq ($i * $per) $PICK_FRAMES (($i + 1) * $per - 1) | each {|f|
            $w.samples | bytes at ($f * $frame_bytes)..<($f * $frame_bytes + 2) | into int --endian little --signed | math abs
        } | math max
    }
}

# The pad and the sound under the default workers through ten seconds of play
export def regression [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = ($context.out | path join "service")
    let set = $context.set
    let render_0_disk = $records."render_zero launched".render_0_disk
    mkdir $out
    let table = (play-table)
    let table_file = ($out | path join "table.nuon")
    $table | to nuon --indent 2 | save --raw -f $table_file
    let sent = ($table | length)
    let end = (pose command-frame "Z")
    let run = (launch --kernel $kernel --image $image --out ($out | path join "run") --set $set --sound --api --pad $table_file --disk $render_0_disk --serial "fps" --send [{ at: $END_AT, bytes: $end }] --seconds $SECONDS --qemu ["-trace" $QUEUE_FULL])
    let events = (^$run.qemu_binary -trace help | complete | get stdout | lines | each {|l| $l | str trim })
    assert ($QUEUE_FULL in $events) $"($run.qemu_binary) lists the trace event ($QUEUE_FULL), the device's dropped reports' count"
    let full = ($run.qemu_log | lines | where {|l| $l | str contains $QUEUE_FULL } | length)
    assert equal $full 0 $"QEMU dropped no pad report for want of buffers: ($full) times"
    assert equal ($run.qemu_log | lines | where {|l| not ($l | str contains $QUEUE_FULL) }) [] $"QEMU has no complaint about the guest: ($run.qemu_log)"
    assert equal $run.status 0 $"the Z frame ended the run with 0, the kernel's exit lines written: status ($run.status), ($run.serial)"
    assert (not ($run.serial | lines | any {|l| ($l starts-with "jab: ") and ($l =~ "fault") })) $"no fault: ($run.serial)"
    let debug = ($run.debug | lines)
    let pads = ($debug | where {|l| $l starts-with "jab: pad accepted " } | each {|l| $l | parse "jab: pad accepted {accepted} taken {taken} dropped {dropped}" | get 0 | update cells {|c| $c | into int } })
    assert equal ($pads | length) 1 $"the exit's pad counts once: ($debug | where {|l| $l starts-with 'jab: pad' })"
    let pad = ($pads | get 0)
    assert equal $pad.dropped 0 $"the pad's ring lost nothing: ($pad)"
    assert equal $pad.accepted $sent $"every event the table sent into the ring: ($pad.accepted) of ($sent)"
    assert equal $pad.taken $pad.accepted $"the program took every event the ring held: ($pad)"
    let sounds = ($debug | where {|l| $l starts-with "jab: sound submitted " } | each {|l| $l | parse "jab: sound submitted {submitted} returned {returned} failed {failed} exhausted {exhausted}" | get 0 | update cells {|c| $c | into int } })
    assert equal ($sounds | length) 1 $"the exit's sound counts once: ($debug | where {|l| $l starts-with 'jab: sound' })"
    let sound = ($sounds | get 0)
    assert equal $sound.exhausted 0 $"no service found the sound's queue empty after its drain: ($sound)"
    assert equal $sound.failed 0 $"no period failed: ($sound)"
    assert ($run.sound != "") "the run recorded its sound"
    let peaks = (window-peaks $run.sound)
    let first = ($peaks | enumerate | where {|w| $w.item >= $SOUND_HEARD } | get -o 0.index)
    assert ($first != null) $"the ambient heard: ($peaks | first 40)"
    let last = (($HEARD_TO / $WINDOW_SECONDS) | math floor | into int)
    assert ($last < ($peaks | length)) $"the recording reaches ($HEARD_TO) s: ($peaks | length) windows"
    let quiet = ($peaks | enumerate | where {|w| $w.index >= $first and $w.index < $last and $w.item < $SOUND_HEARD } | get index)
    assert equal $quiet [] $"every 50 ms window heard from the ambient's first at ($first * $WINDOW_SECONDS) s to ($HEARD_TO) s"
    { service: { sent: $sent, pad: $pad, sound: $sound, queue_full: $full, heard_from: ($first * $WINDOW_SECONDS), windows: ($last - $first) } }
}
