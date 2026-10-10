# smoke.nu: the game played, not posed: a seeded random player on the pad
# for the run's length, walking and strafing, turning and looking, firing
# now and then, from the spawn, with the API's state records proving the
# body moved and the run survived; a program fault ends the run with its
# line on the UART, which is resolved to its routine from the ELF's
# symbols and printed, since a fixed pose never finds what ten seconds of
# play does. `nu smoke.nu --kernel <jab.elf> --image <fps.jab> --out <dir>
# --seeds "[1 2 3]" --seconds 60`; `just do smoke [seeds] [seconds]`,
# the seeds separated by commas, builds and runs it. Every seed is one
# launch of a debug build with Render Zero's tree; the table it played is
# kept beside the run as pad.nuon, so a seed that faults is replayed by
# its number.
use ../../../sdk/nu/jab.nu
use std/assert

const RECORD = 64
# A tick of play: the sticks move every so often, the trigger now and
# then, from after the load until just before the capture ends the run
const TICK = 400ms
const FIRST = 1500ms
const TRIGGER = 313
# The sticks' values on the reference pad, 0 to 255 about 127, up being
# 0 on the Y axes; the left stick leans forward, the right turns freely
# and looks a little
const LEFT_X = [0, 64, 127, 127, 190, 255]
const LEFT_Y = [0, 0, 0, 64, 127, 190, 255]
const RIGHT_X = [0, 64, 127, 127, 190, 255]
const RIGHT_Y = [64, 100, 127, 127, 127, 154, 190]
const FIRE_IN = 8
# What a run must show: states a second at least, metres walked at least
const STATES_A_SECOND = 10
const WALKED = 5.0

def main [--kernel: path, --image: path, --out: path, --seeds: string = "[1]", --seconds: int = 60, --set: string = "DEBUG"] {
    # A list from the command line arrives as its text, quoted when it
    # holds a space, so the seeds are NUON read here
    let seeds = (try { $seeds | from nuon } catch { null })
    if ($seeds | describe) != "list<int>" { error make { msg: $"--seeds takes a NUON list of whole numbers, \"[1 2 3]\": ($seeds | to nuon)" } }
    let game = ($env.FILE_PWD | path join ".." | path expand)
    let tree = (jab program-shard $game "asset" | path join "render_0")
    let elf = ($image | path dirname | path join "fps.elf")
    mkdir $out
    let disk = ($out | path join "render_0.romfs")
    let made = (^genromfs -d $tree -f $disk -V "fps" | complete)
    if $made.exit_code != 0 { error make { msg: $"genromfs on ($tree): ($made.stderr)" } }
    mut faults = []
    for seed in $seeds {
        let run_out = ($out | path join $"seed_($seed)")
        mkdir $run_out
        let table = (play-table $seed $seconds)
        let pad = ($run_out | path join "pad.nuon")
        $table | to nuon | save --raw -f $pad
        let capture = (($seconds * 1000 - 500) * 1ms)
        let run = (jab launch --kernel $kernel --image $image --out $run_out --set $set --sound --api --pad $pad --disk $disk --serial "fps" --capture $capture --seconds $seconds)
        let serial = ($run.serial | lines)
        let fault = ($serial | where {|l| $l starts-with "jab: " } | get -o 0)
        let states = (states $run.api)
        let walked = (if ($states | length) < 2 { 0.0 } else {
            $states | window 2 | each {|w| (($w.1.x - $w.0.x) ** 2 + ($w.1.y - $w.0.y) ** 2) | math sqrt } | math sum
        })
        let sectors = ($states | get sector | uniq)
        let ending = (if ($states | is-empty) { "no state read" } else {
            let last = ($states | last)
            $"ending at ($last.x | math round --precision 2), ($last.y | math round --precision 2) in ($last.sector)"
        })
        print $"smoke: seed ($seed): status ($run.status), ($states | length) states over ($run.wall_seconds | math round --precision 1) s, ($walked | math round --precision 1) m walked through ($sectors | length) sectors, ($ending); ($table | length) pad events"
        if $fault != null {
            let where = (resolve $elf $fault)
            print $"smoke: seed ($seed) FAULTED: ($fault)"
            print $"smoke: seed ($seed) in ($where)"
            $faults = ($faults | append { seed: $seed, fault: $fault, where: $where, pad: $pad })
            continue
        }
        assert equal $run.status 0 $"seed ($seed): the run ended on its capture, not a fault or the bound: ($run.status); ($serial | last 3 | str join ' | ')"
        assert (($states | length) >= ($seconds * $STATES_A_SECOND)) $"seed ($seed): states through the run: ($states | length)"
        assert ($walked >= $WALKED) $"seed ($seed): the body walked: ($walked) m"
    }
    assert equal $faults [] $"every seed survived; these faulted: ($faults)"
    print "smoke: ok"
}

# A seed's play: every tick the sticks take a value from their sets, the
# left stick leaning forward and the right turning, each axis sent on a
# change; the trigger pressed one tick in FIRE_IN and released a tenth
# later; from FIRST until a second before the run's end.
export def play-table [seed: int, seconds: int]: nothing -> table<at: duration, type: int, code: int, value: int> {
    mut state = (($seed * 2654435761 + 1) mod 2147483648)
    mut rows = []
    mut held = { 0: 127, 1: 127, 2: 127, 5: 127 }
    mut at = $FIRST
    let end = (($seconds * 1000 - 1000) * 1ms)
    while $at < $end {
        mut draws = []
        for i in 0..4 {
            $state = (($state * 1103515245 + 12345) mod 2147483648)
            $draws = ($draws | append $state)
        }
        let wanted = {
            0: ($LEFT_X | get (($draws.0 // 7) mod ($LEFT_X | length))),
            1: ($LEFT_Y | get (($draws.1 // 7) mod ($LEFT_Y | length))),
            2: ($RIGHT_X | get (($draws.2 // 7) mod ($RIGHT_X | length))),
            5: ($RIGHT_Y | get (($draws.3 // 7) mod ($RIGHT_Y | length))),
        }
        for code in [0, 1, 2, 5] {
            let key = ($code | into string)
            let value = ($wanted | get $key)
            if ($held | get $key) != $value {
                $rows = ($rows | append { at: $at, type: 3, code: $code, value: $value })
                $held = ($held | upsert $key $value)
            }
        }
        if (($draws.4 // 7) mod $FIRE_IN) == 0 {
            $rows = ($rows | append { at: $at, type: 1, code: $TRIGGER, value: 1 })
            $rows = ($rows | append { at: ($at + 100ms), type: 1, code: $TRIGGER, value: 0 })
        }
        $at = ($at + $TICK)
    }
    $rows | append { at: $end, type: 3, code: 0, value: 127 } | append { at: $end, type: 3, code: 1, value: 127 } | append { at: $end, type: 3, code: 2, value: 127 } | append { at: $end, type: 3, code: 5, value: 127 }
}

# The state records of an API capture: the sector and the eye.
def states [api: binary]: nothing -> table<sector: int, x: float, y: float, z: float> {
    0..<(($api | bytes length) // $RECORD) | each {|i|
        let r = ($api | bytes at ($i * $RECORD)..<(($i + 1) * $RECORD))
        if ($r | bytes at 0..<4 | into int --endian little) != 1 { null } else {
            {
                sector: ($r | bytes at 4..<8 | into int --endian little --signed),
                x: (float-at $r 8), y: (float-at $r 12), z: (float-at $r 16),
            }
        }
    } | where {|s| $s != null }
}

# A single at an offset of a record, little-endian.
def float-at [b: binary, off: int]: nothing -> float {
    let bits = ($b | bytes at $off..<($off + 4) | into int --endian little)
    let sign = (if ($bits bit-shr 31) == 1 { -1.0 } else { 1.0 })
    let exponent = (($bits bit-shr 23) bit-and 0xff)
    let mantissa = ($bits bit-and 0x7fffff)
    if $exponent == 0 { return ($sign * ($mantissa | into float) * (2.0 ** -149)) }
    $sign * (1.0 + ($mantissa | into float) / 8388608.0) * (2.0 ** ($exponent - 127))
}

# The routine a fault line's epc falls in, from the ELF's symbols through
# the toolchain the build's flags name.
def resolve [elf: path, fault: string]: nothing -> string {
    let epc = ($fault | parse --regex 'epc=(?P<epc>0x[0-9a-fA-F]+)' | get -o 0.epc)
    if $epc == null { return "no epc on the line" }
    let flags = ($elf | path dirname | path join "flags")
    if not ($flags | path exists) { return $"no flags beside ($elf)" }
    let prefix = (open --raw $flags | into binary | decode | lines | get 0 | split row " " | last)
    let symbols = (^$"($prefix)nm" -n $elf | lines | parse --regex '^(?P<addr>[0-9a-f]+) [tT] (?P<name>\S+)$' | each {|s| { addr: ($s.addr | into int --radix 16), name: $s.name } })
    let at = ($epc | str substring 2.. | into int --radix 16)
    let below = ($symbols | where addr <= $at | last)
    if $below == null { return $"($epc) before every symbol" }
    $"($below.name) + ($at - $below.addr)"
}
