# watcher

## watch-file

Where `watch` records: watch.nuonl in the workspace's target.

## watch-header

What a recording says first about the QEMU it records: the host, the
QEMU's version, the machine from its line (the harts, -machine, the
CPU, and the accelerator), the window, the kernel and the symbols it
was built with, read from its tree's flags stamp, its pid, and when the
recording started.

## main

Record the running Jab QEMU per thread, once a second, to the
workspace's target's watch.nuonl, a previous recording retired,
whatever shell this is run from: a first line describing the run
(watch-header), then a line per sample with every thread's cumulative
CPU seconds and the process's resident memory (memory-of), one short
line printed per sample with the rates since the last. When the run
ends, the report on the recording is printed to paste (watch-report-of),
the first `--skip` seconds dropped as the load. Interrupted, it ends
with no report. `watcher bench` records a bench's runs instead.

## watch-report-of

The report on a recording `watch` made, as one NUON record: the run
as recorded, the stretch reported on, and per thread the steady CPU
seconds a second over that stretch and the peak second, with the
process total; threads under 0.005 a second are left out. The stretch
drops the first `skip` seconds as the load, or nothing for a run too
short to spare them, `skipped` saying which. On macOS a thread is its
row, and QEMU's worker threads come and go, so a row can change
identity between samples: a row whose second-by-second rate is
impossible for one thread, negative or past one, is reported with
`stable: false` and no peak, its steady figure a mix. `tcg` names the
translator's mode from the threads' names: a lone `ALL CPUs/TCG` thread
runs every hart on one host thread, single-threaded and never evidence
of multicore performance, `CPU N/TCG` threads a thread a hart; null
where the names say neither, as on macOS. `memory` the process's
resident memory in bytes over the stretch, its median by nearest rank
and its peak with the samples holding it, null for a recording made
before the watch read it.

## memory-text

A watch report's memory in words, the resident median and peak in MiB,
empty where it holds none.

## watch-top

The busiest threads of a watch report as one short line.

## watch-rates

A recording's threads' rates over its last `span` samples, the
busiest first, as one short line; "" while it holds too few.

## bench

Record every QEMU of a bench's run, `just watch bench
<program>/<bench>` in a second terminal: it waits for the bench's next
run, or takes up one under way, then records each QEMU of the run per
thread once a second, under the step its own command line names as the
process table showed it, or `unknown` (bench-step-of), to
watch/<step>-<n>.nuonl in the run's directory, a
line printed as each
starts and ends and the rates every five seconds. When the bench has
finished and no QEMU of it is left, it prints the bench's report and
its own per QEMU, the steady CPU seconds a second after the first
`--skip` (watch-report-of), writes them together as watch.nuon in the
run's directory, then packs the run again, its recording included
(bench-tar), and names that tar last, the file to copy off the host.
Interrupted, it ends with no report.
