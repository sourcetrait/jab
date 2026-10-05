# workers's integration test: the worker calls on a four-hart machine,
# one program printing a line a fixture, each line read on its own so a
# failure names its fixture:
# - CoordinatorWait: a worker held a second while hart 0 joins it in
#   jab.sys.worker.wait with a note playing; the recording holds the
#   note's length, level, and pitch through the join, as midi's does
#   through a spin, so the wait served the stream without a stall.
# - Sums: two workers summing at once, each sum right.
# - Refusals: every refusal of jab.sys.worker.start: hart 0, a hart past
#   JAB_HARTS_MAX and one the tree lacks; an entry in the kernel, odd,
#   and past the window; a stack empty, off 16 bytes, a size off 16
#   bytes, below the window, wrapping, and past its top; a stack reaching
#   into JAB_MAIN_STACK's reservation, inside it, and over a running
#   worker's; and the busy hart.
# - StopSleeping: a worker asleep in its wait stopped, the wait answering
#   1 and the worker leaving on its own, not interrupted.
# - StopSpinning: a worker that never calls stopped by interruption, and
#   its start answered 0 on the hart a stopped worker left.
# - Denied: the calls hart 0 keeps, made by a worker, each answering
#   JAB_DENIED with nothing printed and no exit; jab.sys.harts answered
#   to the worker; hart 0's own jab.sys.worker.exit denied.
# - Registers: twice on one hart, the floating-point and vector state as
#   a start leaves it, then set, and kept across a wait, the wake that
#   ends it, the stop's interrupt in a spin of user code, and the stop's
#   answer; the second start follows a worker that left them set.
# - Pestered: a worker waking hart 0 as fast as it can while hart 0
#   waits once on the worker's word, the wait ending only when the word
#   moves, then hart 0 awaiting display ticks, each await ending on its
#   tick, then the worker stopped by interruption.
# - HartThree: a start and a second start on the busy hart, its stop,
#   and the masks.
# - ExitRunning: jab.sys.exit with two workers spinning ends the run
#   with the program's status.
# On a debug kernel a second launch holds hart 3 from taking its start
# (jab.noack=3): the start answers 6, hart 3 is failed for the run, a
# second start answers 1, and the program goes on to its exit.
# Two more hold hart 1's first exit between its two publications
# (jab.leavehold=1), its worker's argument a word the kernel marks with
# what looked at the hart inside the hold, each running one scenario
# picked by a letter over the API:
# - Restart: a start inside the hold sees the hart working and answers
#   busy, then a retry starts it, and a stop's wait answers.
# - StopExit: a stop inside the hold sees the hart working and waits for
#   it, then a start on it answers 0.
# The word decides each line; an expired hold is evidence of neither.
use ../../../sdk/nu/jab.nu
use std/assert

const RATE = 48000
const TONE = 440
# Full velocity on the square lead after the mixer's scaling, as midi's
const PEAK = 6143
# A sample past this is the note and not silence
const HEARD = 500

const LINES = [
    [fixture, line];
    [CoordinatorWait, "join with sound: start 0, done 1, stop 2 0"]
    [Sums, "sums 500000500000 2000001000000, starts 0 0, stop 6 0"]
    [Refusals, "refused hart 1 1 1, entry 3 3 3, stack 4 4 4 4 4 4, overlap 5 5 5, busy 2"]
    [StopSleeping, "stop sleeping 2 0, wait 1"]
    [StopSpinning, "stop spinning 4 4, start 0"]
    [Denied, "denied -1 -1 -1 -1 -1 -1 -1, worker harts 15, hart 0 exit -1"]
    [Registers, "registers 1: entry 0, kept 0, woke 2, stop 2 0"]
    [Registers, "registers 2: entry 0, kept 0, woke 2, stop 2 0"]
    [Pestered, "pestered: done 1, woken 1, awaits 6, stop 4 4"]
    [HartThree, "hart 3 start 0 then 2, stop 8 0, harts 15 15 0"]
    [ExitRunning, "workers: exit with two running"]
]

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let run = (jab launch --kernel $kernel --image $image --out ($out | path join "workers") --set $set --sound --seconds 30)
    let got = ($run.serial | lines)
    for row in ($LINES | enumerate) {
        assert equal ($got | get -o $row.index) $row.item.line $"($row.item.fixture), line ($row.index + 1): ($run.serial)"
    }
    assert equal ($got | length) ($LINES | length) $"ExitRunning: nothing after the program's last line: ($run.serial)"
    assert equal $run.status 0 $"ExitRunning: the exit's status with two workers spinning: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"

    # the note held through the coordinator's join, as midi's through a spin
    assert ($run.sound != "") "CoordinatorWait: the host recorded the sound"
    let wave = (jab wave $run.sound)
    assert equal [$wave.rate $wave.channels $wave.bits] [$RATE 2 16] $"CoordinatorWait: the recording is in the one format: ($wave | reject samples)"
    let left = (0..<$wave.frames | each {|i| $wave.samples | bytes at ($i * 4)..<($i * 4 + 2) | into int --endian little --signed })
    let heard = ($left | enumerate | where {|s| ($s.item | math abs) > $HEARD } | get index)
    assert (($heard | length) > 0) "CoordinatorWait: the note is in the recording"
    let first = ($heard | first)
    let last = ($heard | last)
    let seconds = (($last - $first) / $RATE)
    assert ($seconds > 0.95 and $seconds < 1.2) $"CoordinatorWait: the note lasts the join's second and its release: ($seconds)"
    let tone = ($left | slice $first..$last)
    let peak = ($tone | each {|s| $s | math abs } | math max)
    assert ($peak >= ($PEAK - 300) and $peak <= ($PEAK + 300)) $"CoordinatorWait: at full velocity's level: ($peak)"
    let crossings = ($tone | window 2 | where {|w| ($w.0 < 0) != ($w.1 < 0) } | length)
    let frequency = ($crossings / 2.0 / $seconds)
    assert ($frequency > ($TONE - 2) and $frequency < ($TONE + 2)) $"CoordinatorWait: the zero crossings count out ($TONE) Hz, no gap in the join: ($frequency)"

    mut held = "not run: the knob is a debug kernel's"
    if ($set | str contains "DEBUG") {
        let noack = (jab launch --kernel $kernel --image $image --out ($out | path join "noack") --set $set --bootargs "jab.noack=3" --sound --seconds 30)
        let lines = ($noack.serial | lines)
        assert equal ($lines | get -o 9) "hart 3 start 6 then 1, stop 0 0, harts 15 7 8" $"NoAck: hart 3 held from its start, which answers 6, failed for the run, and a second start answering 1: ($noack.serial)"
        assert equal ($lines | last) "workers: exit with two running" $"NoAck: the program goes on to its exit: ($noack.serial)"
        assert equal $noack.status 0 $"NoAck: exit status: ($noack.serial)"
        assert ($noack.debug | str contains "jab: bootargs jab.noack=3") $"NoAck: the knob reached the kernel: ($noack.debug)"
        $held = ($lines | get 9)
    }

    mut witnessed = "not run: the knob is a debug kernel's"
    if ($set | str contains "DEBUG") {
        let restart = (jab launch --kernel $kernel --image $image --out ($out | path join "restart") --set $set --bootargs "jab.leavehold=1" --send [[at, bytes]; [1sec, 0x[72]]] --seconds 20)
        assert ($restart.debug | str contains "jab: bootargs jab.leavehold=1") $"Restart: the knob reached the kernel: ($restart.debug)"
        assert (not ($restart.serial | str contains "expired")) $"Restart: the hold expired before the start looked, evidence of neither order: ($restart.serial)"
        assert equal ($restart.serial | lines) ["restart: held, start saw busy, then 0, stopped 1"] $"Restart: a start while hart 1 holds at its exit's gap sees it working and answers busy, a retry starts it, and the stop's wait answers: ($restart.serial)"
        assert equal $restart.status 0 $"Restart: exit status: ($restart.serial)"

        let stopexit = (jab launch --kernel $kernel --image $image --out ($out | path join "stopexit") --set $set --bootargs "jab.leavehold=1" --send [[at, bytes]; [1sec, 0x[73]]] --seconds 20)
        let lines = ($stopexit.serial | lines)
        assert (not ($stopexit.serial | str contains "expired")) $"StopExit: the hold expired before the stop looked, evidence of neither order: ($stopexit.serial)"
        assert equal ($lines | get -o 0) "stopexit: held, stop saw working, then 0" $"StopExit: a stop while hart 1 holds at its exit's gap sees it working and waits for it, then a start on it answers 0: ($stopexit.serial)"
        let took = ($lines | get -o 1 | default "" | parse "stopexit: the stop took {ticks} ticks")
        assert (($took | length) == 1 and ($took.0.ticks | into int) > 0) $"StopExit: the stop's elapsed time, supporting evidence alone: ($stopexit.serial)"
        assert equal ($lines | length) 2 $"StopExit: nothing after the elapsed time: ($stopexit.serial)"
        assert equal $stopexit.status 0 $"StopExit: exit status: ($stopexit.serial)"
        $witnessed = $"($restart.serial | str trim); ($lines.0), ($took.0.ticks) ticks"
    }

    print $"workers: ($got | str join '; '); the join's note ($seconds | math round -p 2) s at ($peak), ($frequency | math round -p 1) Hz; held from its start: ($held); witnessed: ($witnessed)"
    print "workers: ok"
}
