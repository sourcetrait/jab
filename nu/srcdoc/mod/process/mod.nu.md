# process

## qemu_name

The QEMU every machine runs on, by its binary's name.

## process-alive

Whether the process is in the process table, which nushell reads on
every host; "" is no process at all.

## jab-pids

The Jab QEMU processes on this host, by their command line, which
every Jab line marks with `-name jab`: the QEMU itself, wherever its
binary lives, never the `timeout` a test wraps it in, whose command
line carries the same words.

## command-binary

The binary a command line runs: everything before its first option, so
a binary whose path holds a space, an extern/qemu under such a
directory, stays whole.

## threads-of

The threads of a process with their cumulative CPU seconds: on Linux
from /proc, by thread id and name (the harts `CPU 0/TCG` and on, the
main loop under the process name); on macOS from `ps -M`, its rows
in order, the first the AppKit thread that draws the window, the
rest unnamed, so a thread is identified by its row.

## threads-between

Each thread's CPU between two readings of threads-of taken `span`
seconds apart: by thread id, its name, `delta` the CPU seconds it used
in between, and `rate` those over the span, its share of a core; a
thread in one reading alone is passed over. The span rides along, so a
rate never travels without the stretch it was measured over. A span
that is not past zero is refused.

## memory-of

A process's resident memory in bytes as its host reports it: VmRSS in
/proc/<pid>/status on Linux, `ps -o rss=` in KiB on macOS; null where
neither reads, the process gone or the host another.

## clock-seconds

`ps` clock text, M:SS.hh or H:MM:SS.hh, as seconds.
