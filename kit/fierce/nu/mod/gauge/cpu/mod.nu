# When the CPU readings' whole window opens, past the load
const CPU_FROM = 5sec

# What a launch came to: status, fault, CPU and wall time, threads, machine
export def outcome [launched: record]: nothing -> record {
    {
        status: $launched.status,
        fault: ($launched.serial | lines | where {|l| $l starts-with "jab: " } | get -o 0),
        cpu_seconds: $launched.cpu_seconds,
        wall_seconds: $launched.wall_seconds,
        threads: ($launched | get -o threads | default []),
        threads_span: ($launched | get -o threads_span),
        thread_readings: ($launched | get -o thread_readings | default []),
        qemu_binary: $launched.qemu_binary,
        qemu: $launched.qemu,
        machine: $launched.machine,
        window: $launched.window,
        audio: $launched.audio,
    }
}

# The times a run's CPU is read: CPU_FROM, each placement, the route's end
export def requests [legs: list<any>, end: duration]: nothing -> list<duration> {
    [$CPU_FROM] | append ($legs | each {|l| $l.places | each {|p| $p.at } } | flatten) | append $end | uniq | sort
}

# A run's CPU readings as host-time windows: the whole, each leg, subwindows
export def windows [readings: list<any>, legs: list<any>, end: duration]: nothing -> record {
    let reading = {|at: duration|
        let s = ($at / 1sec)
        $readings | where {|r| (($r.requested - $s) | math abs) < 0.000001 } | get -o 0
    }
    let between = {|name: string, from: duration, to: duration| cpu-window $name (do $reading $from) (do $reading $to) $from $to }
    let starts = ($legs | where {|l| not ($l.places | is-empty) } | each {|l| { leg: $l.name, places: ($l.places | each {|p| $p.at }) } })
    let leg_windows = ($starts | enumerate | each {|e|
        let from = ($e.item.places | first)
        let to = (if ($e.index + 1) < ($starts | length) { $starts | get ($e.index + 1) | get places | first } else { $end })
        let marks = ($e.item.places | append $to)
        let subs = (if ($e.item.places | length) < 2 { [] } else {
            $marks | window 2 | enumerate | each {|w| do $between $"($e.item.leg) ($w.index + 1)" ($w.item | get 0) ($w.item | get 1) }
        })
        do $between $e.item.leg $from $to | insert subwindows $subs
    })
    { whole: (do $between "whole" $CPU_FROM $end), legs: $leg_windows }
}

# One CPU window between two readings, missing when either is absent
def cpu-window [name: string, first: any, second: any, from: duration, to: duration]: nothing -> record {
    let base = { window: $name, requested_from: ($from / 1sec), requested_to: ($to / 1sec) }
    let taken = ($first != null and $second != null and ($first | get -o at) != null and ($second | get -o at) != null)
    if not $taken {
        return ($base | merge { missing: true, from: ($first | get -o at), to: ($second | get -o at), interval: null, threads: [] })
    }
    let interval = ($second.at - $first.at)
    let ids = ($first.threads | each {|t| $t.id } | append ($second.threads | each {|t| $t.id }) | uniq)
    let threads = ($ids | each {|id|
        let a = ($first.threads | where id == $id | get -o 0)
        let b = ($second.threads | where id == $id | get -o 0)
        let name = (if $b != null { $b.name } else { $a.name })
        if $a == null or $b == null { { id: $id, name: $name, cpu_seconds: null, utilization: null } } else {
            let seconds = ($b.cpu - $a.cpu)
            { id: $id, name: $name, cpu_seconds: $seconds, utilization: (if $interval > 0 { $seconds / $interval } else { null }) }
        }
    })
    $base | merge { missing: false, from: $first.at, to: $second.at, interval: $interval, threads: $threads }
}
