# launch

## program_base

The window's base (jab.inc): the kernel's 2 MiB and the framebuffer's
8 MiB come first, and the program has the rest of the machine's 4 GiB.

## plan

A headless machine prepared and not run: everything a launch sets up
before QEMU starts, handed back for whoever runs and drives it, the
SDK's own `launch` or a harness that plays interactively. `qemu_binary`
is the QEMU it runs on (qemu-binary, beside the program the image came
from and then in the workspace, as a run's), `qemu` the whole argument
vector after it, `env` what the process runs under (the evdev shim
preloaded when a gamepad rides the fifo), and the rest the paths: the
UART's log, QEMU's guest-error log, the screen a screendump lands in,
the pid file, the monitor's pipe pair (`<monitor>.in` and `.out`), the
debug channel's log under DEBUG, the API's `api_in` pipe and `api_out`
file with `--api`, and the pad: with `--gamepad`, on Linux the fifo
QEMU reads as the pad, which the driver writes 24-byte input_event
records into, else (and with `--pad-port`) the pad port's `pad_pipe_in`
pipe, whose header, `pad_header` as hex, the driver writes first, the
pipes made. On Windows, where QEMU makes each pipe chardev one named
pipe and waits for its client before it starts (chardev pipe-path), each pipe's
in-file is a plain file, and `relays` names the relay each pipe with no
client of its own takes, the monitor's, the API's, and a scripted pad's
port (chardev relays-of), the launch's supervisor holding each one's
connection; none elsewhere. `bridge_pipe` is the pipe the pad bridge
writes, "" with no pad port (bridge-pipe). The machine is headless unless `--window` puts it in the
window a run of the program would open (`window`, `none` without); the sound device
records to `sound` with `--sound`, or plays through the host's audio as
a run's does with `--live-sound` (`audio`, the backend); and
`--host-pad` attaches the host's own gamepad as a run does, on macOS
through the bridge `bridge` names, to be started beside QEMU. A
recording and the host's audio together are refused, as is the host's
pad beside a scripted one. A previous run's files in `out` are retired
into the retire home of `target`, the workspace's target or else the
program's, wherever `out` lies (retire), its pipes kept; `target` is
handed back for a harness that clears away files of its own. The
machine is the one `--spec` names, or with `--harts` a custom one of 1
to 8 harts, or with neither the configured default (machine resolve), and
`machine` is its record (machine of), `below_minimum` true beside it
where `bootargs` carries a debug kernel's jab.nominimum=1, which skips
the program's minimum (knob-of); a named spec the image's demand
does not list is refused before anything is made, a legacy image's run
taking the named machine. `bootargs` goes to the kernel through QEMU's
-append, into the device tree's /chosen, a named spec's
`jab.spec=<name>` after it (spec-bootargs), where a debug kernel reads its test
knobs, and the record's `bootargs` is the line as given; `dtb` hands the kernel that
tree through -dtb in place of the one QEMU builds, QEMU checking its
header before any hart runs. `demand` is the demand recorded with the
image at its build (demand image), null for a program on the legacy path
and for an image with no record; a record that does not hold is refused.
`send` is what a launch writes into the API at its times, kept as given
in `sends`, and anything to send puts the port on as `--api` does. With
`--sdl-probe`, a probing launch, Linux only: the window `sdl,gl=on`, the
sdl shim built and preloaded beside any other (`shim`), logging to that
file (`sdl_log`, a stale one retired), SDL's offscreen driver where no
display server is. `capture_nonce` is the caller's, never minted here,
1 to 2^63 - 1 or none, handed to the shim as `SDL_SHIM_NONCE` in its
sixteen hex digits (nonce hex); `profile` the capture's, `paired` only
with a nonce, `generic` for a probe that names none, "" for a run that
claims none; `capture` the run's capture identity as it stands before
QEMU starts (launch capture-identity). The workspace, which holds the
QEMU link, the shims, and the generic disk, is the image's program's
(image workspace) unless `--workspace` names it: a packaged image
carries no `home` marker, its program's source beside it, so the run
that takes it names the checkout it runs from.

- a debug kernel's jab.nominimum=1 skips a program's minimum, so the run
  is recorded below it, where a release kernel reads no knob and refuses
- a Windows run's pipes are named pipes, named by a nonce of its own
- Windows' relays, one a pipe with no client of its own: the monitor's,
  the API's, and a scripted pad's port, the host's pad's client being
  the bridge, a helper of the launch's (pad bridge-helpers)

## capture-identity

A run's capture identity, what its identity records of the capture
(CaptureBundle), from a machine as plan prepared it and the pid of the
QEMU that ran it, read while it lived (null before or without one): the
profile; `capture_nonce`; `qemu_pid`; the shim's log and library, ""
for a run unprobed; the window; `api`, whether the API's port was on the
machine; and `sends`, each entry to write into it by its time in
seconds, its bytes' length, and their SHA-256.

## main

Run a program on the kernel under QEMU with no window, the UART to
serial.log in `out`, for at most `seconds`, under the launch's supervisor
(supervise bounded): its schedule (schedule-of) carries QEMU's command
under the bound, every pipe's end, the pad port's header, the timed
actions in due order, the thread readings, Windows' relays, and the pad
bridge as a helper, and the supervisor owns QEMU from its spawn to its
reap, writing every action and taking every reading at its time on its
own monotonic clock, from the go. The status is what jab.sys.exit gave,
1 on a program fault, 124 when the bound ended the run, the child's
signal as 128 and its number (status-of). With `capture`, the screen is
taken into screen.ppm that long after the start and the run is then
ended with QEMU's `quit` (status 0); with `screen`, it is taken that long
after the start while the run goes on to its bound or its exit; with
`stop`, the run is ended with `quit` at that time, its screen never
taken, so the run's end is the caller's and never the bound's; with
`keys`, each key is pressed through the monitor that long after the
start. `set` names the symbols the kernel was built with: DEBUG puts the
kernel's debug channel on the machine, whose text comes back as `debug`.
With `api`, or with anything to `send`, the API's port is on the
machine: each entry of `send` is written into it that long after the
start, and every byte the program sent, landed in api.out, comes back as
`api`. QEMU's own complaints about the guest go to qemu.log and what it
wrote to its stderr comes back as `stderr`, so a backend's complaint
reaches a test. `cpu_seconds` is QEMU's process time as the supervisor
last sampled it, every 100 ms while QEMU ran, and `wall_seconds` the
run's end from the go, the child reaped once nothing it owns runs.

Each action goes in only while QEMU runs, the header first, then each
once due and whole before the next, so their order holds and a late
start drops none; a screen's line written, its file is looked at until
it is whole, the size and the header the display's (display_size), and a
screen that never comes whole, or comes under another header, holds
every action after it, the result's `screen` then "". `screen_started`
and `screen_completed` are the screen's asking and its file's
completion, `send_seconds` each entry of `send`'s write, and
`quit_seconds` the quit's, the capture's or the stop's, all seconds from
the go, null for what never happened; `unfinished` names every action
not complete, its state, `incomplete` or `unattempted`, and the bytes its
pipe accepted of its length. A payload is never written twice: a pipe
that breaks once some of it is in is never reopened, and the action stays
incomplete. The failure the receipt names, a relay never connected or
failed, a helper that could not start, a pipe broken while QEMU ran,
fails the launch with QEMU's exit and its stderr; a startup that did not
go fails it with nothing measured run. A run whose supervisor left no
receipt keeps `incomplete`, what ended it, its other fields null, and
`launch` is the run's record, `launch.nuon` in `out` (supervise bounded).

The workspace, whose generic disk rides along and whose shim plays a
pad, is the one above the kernel ELF, else the one above `out`.
`--window`, `--live-sound`, and `--host-pad` put the machine on the host
as a run puts it, the window, the host's audio, and the host's own
gamepad (plan), with the bridge run beside QEMU as the launch's helper
where the pad needs one; the screen and the timed actions go through the
monitor and the pipes as headless. The result carries the machine's
line, `qemu_binary` and `qemu`, with the `window` and the `audio`
backend it ran with, and `machine`, the record of the machine it had
(machine of); `--spec`, `--harts`, `--bootargs`, and `--dtb` are plan's.
With `--threads`, every QEMU thread's CPU is read that long after the
go and again a second on, each reading timed as the supervisor takes it:
`threads_span` is the seconds between the two, and `threads` carries
each thread's name, the CPU seconds it used in between, and those over
the span (process threads-between), the harts' threads named `CPU N/TCG`
on Linux; empty, its span null, when the run ended before the second
reading. With `--threads-at`, every QEMU thread's cumulative CPU seconds
are read at each time it lists, `thread_readings` keeping each reading
whole: the time asked, `requested`, and the time it was taken, `at`,
both seconds from the go; and every thread's id, name, and counter; a
time the run ended before keeps its request with `at` and `threads`
null, missing. `--qemu` appends words of its own to the line, unchanged,
after the launch's: a device or a property a test needs that no launch
flag gives. Such a run is diagnostic, its `machine` keeping the platform
asked for with the words in its `overrides`, and the words come back
apart as `overrides` too, so the requested platform and the custom
command stay distinct; `qemu` is the line as it ran. `declared` says
whether the demand recorded with the image at its build declares one
(demand image), and `diagnostic` is the run's standing: on a custom
machine, with QEMU words of its own, of an image built on the legacy
path or with no record beside it, undeclared and claiming no console, or
below its program's minimum (plan's `below_minimum`). `--sdl-probe`,
`--capture-nonce`, and `--profile` are plan's, the nonce the caller's,
minted here only for a probing launch given none (nonce mint); the
launch writes the API only what its caller sends, never for itself.
`qemu_pid` is QEMU's pid as the supervisor read it from the pid file
while QEMU lived, since QEMU removes its pid file as it exits, null
where it never came up; the result carries `sdl_log`, `shim`,
`capture_nonce`, and `profile` as planned, and `capture`, the run's
capture identity (launch capture-identity).

- `--kernel`: the kernel ELF
- `--image`: the program's .jab
- `--out`: where serial.log and the rest go
- `--seconds`: the bound
- `--capture`: when to take the screen and end the run; 0 never
- `--screen`: when to take the screen while the run goes on; 0 never
- `--stop`: when to end the run with QEMU's quit, no screen taken; 0 never
- `--keys`: keys to press that long after the start, QEMU's names, held for hold
  ms
- `--api`: put the API's port on the machine
- `--send`: bytes to write into the API that long after the start; puts the port
  on the machine
- `--disk`: a raw image to put on the machine as its first virtio-blk disk; the
  workspace's generic disk follows it
- `--serial`: the disk's serial, which the guest reads back as its own; 19
  characters at most
- `--set`: the symbols the kernel was built with, comma separated
- `--pad`: a NUON file of pad events, [[at, type, code, value]; ...], played as
  a gamepad: into a fifo attached through the evdev shim on Linux, else into the
  pad port
- `--pad-port`: play --pad into the pad port on Linux too, the route every other
  host takes
- `--kbm`: the keyboard and the tablet on the machine, which is the default
- `--no-kbm`: neither on the machine
- `--sound`: the sound device on the machine, its output recorded to sound.wav
  in `out`, handed back as `sound`
- `--window`: the window a run of the program opens, in place of none
- `--live-sound`: the sound device over the host's audio as a run discovers it,
  in place of the --sound recording
- `--host-pad`: the host's own gamepad as a run attaches it, in place of a --pad
  table
- `--spec (-s)`: the named spec the machine is, its cores, RAM, and display; the
  configured default unless given
- `--harts`: a custom machine of 1 to 8 harts in place of a named spec, the run
  then diagnostic
- `--bootargs`: the kernel's command line, its debug knobs, through -append
- `--dtb`: a device tree for the kernel in place of QEMU's, through -dtb
- `--threads`: when to read every QEMU thread's CPU and again a second on, the
  result's `threads` and `threads_span`; 0 never
- `--threads-at`: each time to read every QEMU thread's CPU, kept whole in the
  result's `thread_readings`; none unless given
- `--qemu`: words appended to the QEMU line unchanged, after the launch's own;
  the run is then diagnostic
- `--sdl-probe`: the sdl shim's log: QEMU under sdl,gl=on with the shim
  preloaded, Linux only
- `--capture-nonce`: the run's capture nonce from the caller making the request;
  minted here for a probe given none
- `--profile`: the capture's profile, paired or generic (plan)

- `--capture` and `--screen` together are refused, one screen a run, and
  so are `--capture` and `--stop`, each ending the run with its own quit
- every time the result carries is the supervisor's, sampled with its
  operation from the go, never a reading of this script's own clock
- the pad port's header goes in as soon as QEMU is up, before any
  event, since the kernel waits for the whole of it
- each thread's CPU over the held span: a reading at `threads`, another
  a second on, each timed as the supervisor takes it

## seconds-of

Nanoseconds from a receipt as seconds, a float; null stays null.

## status-of

A receipt's exit as the launch's status: the measured command's status,
else 128 and the signal that ended it; null with no receipt.

## ended-text

A receipt's exit as words for a failure's message: its status, its
signal, or no status.

## schedule-of

A launch's schedule as the supervisor runs it (Schedule.nutype), from a
machine as plan prepared it, the control token, the line, the bound,
the keys, and the pads: the command, `timeout --signal=TERM` with
`--kill-after` (supervise kill_after) and the seconds around QEMU and
the line; the environment plan made, the shims' preloads among it; QEMU's
stdout and stderr files in `out`; the pid file; every pipe an action
writes, by name, its end the fifo off Windows and the relay's endpoint
on Windows; the pad port's header when the pad rides the port; the
actions, the keys as the monitor's `sendkey` lines, the sends, the pad's
groups as reports or the port's frames, the screen with its file, its
header, and its whole size, a capture's quit at the screen's time, and a
stop's quit, all in due order, by time, a quit and a screen ahead of the
events of their time, then the order given; the held readings, `held` at
`threads` and a second on, and each of `threads-at` sorted; Windows'
relays; the helpers; and the bounds (supervise bounds). Every time is
nanoseconds from the go.

## due-order

The order a launch's poll takes its timed actions in, `elapsed` after
the start: every event due by then, its `at` at or before it, in the
order of their times and at one time in the order given; and the
screen, due at `screen` while it is still to take (null when none
is), once due after every event due before its time and ahead of
every event due at or after it, which wait on it, the poll writing
them only once the screen is whole. The events come back as given,
the screen as a row of kind `screen`, its `index` 0 and its `at` its
time. A pure function kept for the order's synthetic tests; the
supervisor takes the actions in the order schedule-of wrote them.
