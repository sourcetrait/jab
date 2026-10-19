# The QEMU every machine runs on, by its binary's name
export const qemu_name = "qemu-system-riscv64"

# Whether a pid is in the process table; "" is no process
export def process-alive [pid: string]: nothing -> bool {
    if $pid == "" { return false }
    let id = (try { $pid | into int } catch { -1 })
    if $id < 0 { return false }
    ps | where pid == $id | is-not-empty
}

# A process's user and system CPU seconds from /proc, or null
export def cpu-seconds [pid: string]: nothing -> oneof<float, nothing> {
    let stat = (try { open --raw ("/proc" | path join $pid "stat") | decode } catch { "" })
    if $stat == "" { return null }
    # after the command's closing parenthesis: state, ppid, pgrp,
    # session, tty, tpgid, flags, minflt, cminflt, majflt, cmajflt,
    # utime, stime, in clock ticks of a hundredth
    let fields = ($stat | split row ") " | last | split row " ")
    (($fields | get 11 | into int) + ($fields | get 12 | into int)) / 100.0
}

# The pids of the Jab QEMU processes on this host, never their timeouts
export def jab-pids []: nothing -> list<int> {
    ps -l | where {|p| ((command-binary $p.command | path basename) == $qemu_name) and ($p.command | str contains "-name jab") } | get pid
}

# A command line's binary: everything before its first option
export def command-binary [command: string]: nothing -> string {
    $command | split row " -" | first
}

# A process's threads with their cumulative CPU seconds, on Linux and macOS
export def threads-of [pid: int]: nothing -> table<id: string, name: string, cpu: float> {
    match $nu.os-info.name {
        "linux" => {
            let tasks = (try { ls ("/proc" | path join ($pid | into string) "task") | get name } catch { [] })
            $tasks | each {|t|
                let stat = (try { open --raw ($t | path join "stat") | decode } catch { "" })
                if $stat == "" { null } else {
                    let fields = ($stat | split row ") " | last | split row " ")
                    let name = (try { open --raw ($t | path join "comm") | decode | str trim } catch { "" })
                    { id: ($t | path basename), name: $name, cpu: ((($fields | get 11 | into int) + ($fields | get 12 | into int)) / 100.0) }
                }
            } | compact
        },
        "macos" => {
            let out = (^ps -M -p ($pid | into string) | complete | get stdout)
            $out | lines | skip 1 | enumerate | each {|row|
                let times = ($row.item | parse --regex '(?P<stime>\d+:\d+(?::\d+)?\.\d+)\s+(?P<utime>\d+:\d+(?::\d+)?\.\d+)' | get -o 0)
                if $times == null { null } else {
                    { id: ($row.index | into string), name: (if $row.index == 0 { "main" } else { $"thread ($row.index)" }), cpu: ((clock-seconds $times.stime) + (clock-seconds $times.utime)) }
                }
            } | compact
        },
        _ => { error make {msg: $"no thread reading here for ($nu.os-info.name)"} },
    }
}

# Each thread's CPU delta and rate between two readings `span` seconds apart
export def threads-between [first: table<id: string, name: string, cpu: float>, second: table<id: string, name: string, cpu: float>, span: float]: nothing -> record<span: float, threads: list<record<name: string, delta: float, rate: float>>> {
    if $span <= 0.0 { error make {msg: $"a span of ($span) s holds no rate"} }
    let threads = ($second | each {|t|
        let before = ($first | where id == $t.id | get -o 0)
        if $before == null { null } else {
            let delta = ($t.cpu - $before.cpu)
            { name: $t.name, delta: $delta, rate: ($delta / $span) }
        }
    } | compact)
    { span: $span, threads: $threads }
}

# A process's resident memory in bytes as its host reports it, or null
export def memory-of [pid: int]: nothing -> any {
    match $nu.os-info.name {
        "linux" => {
            let status = (try { open --raw ("/proc" | path join ($pid | into string) "status") | decode } catch { "" })
            let kb = ($status | lines | parse --regex '^VmRSS:\s+(?P<kb>\d+) kB' | get -o 0.kb)
            if $kb == null { null } else { ($kb | into int) * 1024 }
        },
        "macos" => {
            let out = (try { ^ps -o rss= -p ($pid | into string) | complete | get stdout | str trim } catch { "" })
            if $out == "" { null } else { ($out | into int) * 1024 }
        },
        _ => null,
    }
}

# `ps` clock text, M:SS.hh or H:MM:SS.hh, as seconds
def clock-seconds [text: string]: nothing -> float {
    $text | split row ":" | each {|p| $p | into float } | reduce --fold 0.0 {|it, acc| $acc * 60.0 + $it }
}
