# table.rs

The process table as the supervisor, the lock, and a forced end read it,
one `os` module a host family, each exporting the same functions.

## enum State

## fn is_running

A record's process still runs when its pid is live and started when the
record says: a pid reused by another process has another start.

## fn running_members

A group's members still running, an exited member awaiting its reap not
counted, so a group whose leader alone remains unreaped holds none.

## mod os

### fn fields

Linux: a `stat` file's fields read past the name's closing parenthesis,
the last `") "`, since a name can hold spaces and parentheses; field 0 is
then the state.

### fn stat

### fn ticks

### fn seconds

Fields 11 and 12 past the name, the user and system times, over the
clock's ticks a second.

### fn process_start

Linux: field 19 past the name, clock ticks since the boot. macOS: the
BSD record's start in microseconds since the epoch. Windows: the creation
time in 100 ns units since 1601.

### fn process_state

Linux: `Z` the zombie. macOS: the BSD record's `SZOMB`, a zombie's
record still read. Windows: an exit code still active as live, else gone,
no zombie being told apart.

### fn group_of

Windows names no group.

### fn group_members

Linux: every pid under `/proc` whose group is the group's. macOS:
`proc_listpgrppids`, its buffer grown until the list fits. Windows: none.

### fn cpu_seconds

macOS: the task record's user and system times in Mach ticks over the
timebase (`mach_timebase_info`), a zombie's task gone. Windows:
`GetProcessTimes`'s kernel and user times.

### fn process_threads

Linux: each task under `/proc/<pid>/task` with its `comm`, by id. macOS:
the rows `ps -M` lists, the first named main, each row's first two clock
fields its system and user times. Windows: none.

### fn info

### fn clock

### fn units

### fn times

A handle opened for limited information, closed after the reads.
