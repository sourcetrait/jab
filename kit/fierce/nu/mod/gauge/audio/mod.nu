use (path self ../../../../../../nu/mod/capture)
use (path self ../../pose)

# The peak a window must reach to be heard, sound's own
export const SOUND_HEARD = 64

# The play's reports a second, the reference pad's rate
export const REPORT_HZ = 125

# The play's reports, ten seconds at the reference pad's rate
export const REPORTS = 1250

# The first report's time, the pad opened by the first frame's look by then
export const PLAY_FROM = 2000ms

# The E frame's time, half a second past the last report, closing the capture
export const MEASURED_TO = 12500ms

# The Z frame's time, a second past the last report so every event is taken
export const END_AT = 13000ms

# The run's bound, past the exit's flush of the sound
export const SECONDS = 20

# The recording's window, a coarse gap's length
export const WINDOW_SECONDS = 0.05

# The windows read from the ambient's first, to the play's end less a second
export const HEARD_TO = 11.0

# The axes each report moves: the left stick's two and the right stick's Z
export const AXES = [0 1 2]

# The QEMU trace event of a report virtio-input dropped for want of buffers
export const QUEUE_FULL = "virtio_input_queue_full"

# The frames apart a window's picks sit, a coarse read of each window
const PICK_FRAMES = 16

# The pad's table: three axes a report, sweeping, REPORT_HZ reports a second
export def play-table []: nothing -> table<at: duration, type: int, code: int, value: int> {
    0..<$REPORTS | each {|i|
        let at = ($PLAY_FROM + ($i * (1sec / $REPORT_HZ)))
        let t = ($i | into float)
        let x = (127 + 60 * (2 * 3.141592653589793 * $t / 250 | math sin) | math round | into int)
        let y = (87 + 30 * (2 * 3.141592653589793 * $t / 625 | math cos) | math round | into int)
        let z = (127 + 40 * (2 * 3.141592653589793 * $t / 375 | math sin) | math round | into int)
        [[at type code value]; [$at 3 ($AXES | get 0) $x] [$at 3 ($AXES | get 1) $y] [$at 3 ($AXES | get 2) $z]]
    } | flatten
}

# The play's console frames: the E closing the measurement, then the Z's exit
export def sends []: nothing -> list<any> {
    [{ at: $MEASURED_TO, bytes: (pose command-frame "E") }, { at: $END_AT, bytes: (pose command-frame "Z") }]
}

# A recording's 50 ms windows' peaks from its first frame, left channel, sampled
export def window-peaks [wav: path]: nothing -> list<int> {
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

# A recording's windows read for continuity
export def heard [peaks: list<int>]: nothing -> record {
    let first = ($peaks | enumerate | where {|w| $w.item >= $SOUND_HEARD } | get -o 0.index)
    let last = (($HEARD_TO / $WINDOW_SECONDS) | math floor | into int)
    let quiet = (if $first == null { [] } else { $peaks | enumerate | where {|w| $w.index >= $first and $w.index < $last and $w.item < $SOUND_HEARD } | each {|w| $w.index } })
    {
        windows: ($peaks | length),
        first: $first,
        heard_from: (if $first == null { null } else { $first * $WINDOW_SECONDS | math round --precision 3 }),
        reached: ($last < ($peaks | length)),
        read: (if $first == null { 0 } else { $last - $first }),
        quiet: $quiet,
        first_peaks: ($peaks | first 40),
    }
}

# The kernel's exit lines on the debug channel a prefix starts, each parsed
def counts [debug: list<string>, prefix: string, pattern: string]: nothing -> list<any> {
    $debug | where {|l| $l starts-with $prefix } | each {|l| $l | parse $pattern | get 0 | update cells {|c| $c | into int } }
}

# A launch of the play read: QEMU's log, the exit, the counts, the recording
export def reading [run: record, sent: int]: nothing -> record {
    let events = (^$run.qemu_binary -trace help | complete | get stdout | lines | each {|l| $l | str trim })
    let logged = (open --raw $run.qemu_log | decode | lines)
    let full = ($logged | where {|l| $l | str contains $QUEUE_FULL } | length)
    let complaints = ($logged | where {|l| not ($l | str contains $QUEUE_FULL) })
    let faults = ($run.serial | lines | where {|l| ($l starts-with "jab: ") and ($l =~ "fault") })
    let debug = ($run.debug | lines)
    let pads = (counts $debug "jab: pad accepted " "jab: pad accepted {accepted} taken {taken} dropped {dropped}")
    let sounds = (counts $debug "jab: sound submitted " "jab: sound submitted {submitted} returned {returned} failed {failed} exhausted {exhausted}")
    let pad = ($pads | get -o 0)
    let sound = ($sounds | get -o 0)
    let recorded = ($run.sound != "")
    let windows = (if $recorded { heard (window-peaks $run.sound) } else { null })
    let problems = [
        (if $QUEUE_FULL not-in $events { $"($run.qemu_binary) lists no trace event ($QUEUE_FULL), the device's dropped reports' count" })
        (if $full > 0 { $"QEMU dropped ($full) pad reports for want of buffers" })
        (if not ($complaints | is-empty) { $"QEMU complained of the guest: ($complaints | first 3 | str join '; ')" })
        (if $run.status != 0 { $"the run ended with status ($run.status), not the Z frame's 0" })
        (if not ($faults | is-empty) { $"a fault: ($faults | first)" })
        (if ($pads | length) != 1 { $"the exit's pad counts ($pads | length) times, where it writes them once" })
        (if $pad != null and $pad.dropped != 0 { $"the pad's ring lost ($pad.dropped) events" })
        (if $pad != null and $pad.accepted != $sent { $"the pad's ring took ($pad.accepted) events of the ($sent) the table sent" })
        (if $pad != null and $pad.taken != $pad.accepted { $"the program took ($pad.taken) of the ($pad.accepted) events the ring held" })
        (if ($sounds | length) != 1 { $"the exit's sound counts ($sounds | length) times, where it writes them once" })
        (if $sound != null and $sound.exhausted != 0 { $"($sound.exhausted) services found the sound's queue empty after their drain" })
        (if $sound != null and $sound.failed != 0 { $"($sound.failed) periods failed" })
        (if $windows != null and $windows.first == null { "the ambient never heard in the recording" })
        (if $windows != null and $windows.first != null and (not $windows.reached) { $"the recording ends at ($windows.windows) windows, short of ($HEARD_TO) s" })
        (if $windows != null and not ($windows.quiet | is-empty) { $"($windows.quiet | length) quiet 50 ms windows after the ambient's first, the first at ($windows.quiet | first | $in * $WINDOW_SECONDS | math round --precision 3) s" })
    ] | compact
    {
        sent: $sent,
        trace_listed: ($QUEUE_FULL in $events),
        queue_full: $full,
        complaints: $complaints,
        status: $run.status,
        faults: $faults,
        pads: ($pads | length),
        pad: $pad,
        sounds: ($sounds | length),
        sound: $sound,
        recorded: $recorded,
        windows: $windows,
        problems: $problems,
    }
}

# One line on a play's reading: held or broken, the counts, the continuity
export def line [r: record]: nothing -> string {
    let state = (if ($r.problems | is-empty) { "held" } else { $"broken: ($r.problems | str join '; ')" })
    let pad = (if $r.pad == null { "no pad counts" } else { $"pad accepted ($r.pad.accepted), taken ($r.pad.taken), dropped ($r.pad.dropped) of ($r.sent) sent" })
    let sound = (if $r.sound == null { "no sound counts" } else { $"sound submitted ($r.sound.submitted), returned ($r.sound.returned), failed ($r.sound.failed), exhausted ($r.sound.exhausted)" })
    let continuity = (if $r.windows == null {
        "played live, no recording, so its continuity unread"
    } else if $r.windows.first == null {
        "the ambient never heard"
    } else {
        $"($r.windows.read) windows of 50 ms read from ($r.windows.heard_from) s to ($HEARD_TO) s, ($r.windows.quiet | length) quiet"
    })
    $"gauge:   audio ($state); ($pad); ($sound); QEMU dropped ($r.queue_full) reports; ($continuity)"
}
