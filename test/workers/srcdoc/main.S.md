# main.S

workers: the worker calls, one fixture a line on the UART for the test to
read line by line, each step's line naming what its calls answered. The
program runs on four harts. With no API port, the test's first two
launches, it opens the sound stream and goes through the steps in order,
ending with two workers still running when it exits. With the port, it
runs one scenario of jab.leavehold's, picked by a letter. Every worker
enters with a0 its job, a record of JOB_BYTES in bss, and ends by
jab.sys.worker.exit or by a stop.

## .set STACK_BYTES

`u64`: a worker's stack, 16 KiB; stacks holds three.

## .set JOB_N
## .set JOB_RESULT
## .set JOB_DONE
## .set JOB_GATE
## .set JOB_SPINNING
## .set JOB_ENTRY
## .set JOB_KEPT
## .set JOB_VL
## .set JOB_COUNT
## .set JOB_ANSWERS

`u64`: a job's fields: the worker's input; its result; the 32-bit word it
marks done; the 32-bit gate hart 0 opens and the 32-bit flag the registers'
worker raises as it starts spinning; the registers counted wrong at the
start and since; vl as the registers were set; the wakes that found hart 0
asleep; and the denied calls' answers, DENIED_CALLS of them and
jab.sys.harts's after.

## .set JOB_BYTES

`u64`: a job's record, two cache lines.

## .set DENIED_CALLS

`u64`: the calls the denied worker makes that hart 0 keeps.

## .set SUM_ONE
## .set SUM_TWO

`u64`: what the two summing workers count to.

## .set CHANNEL
## .set PROGRAM
## .set NOTE
## .set VELOCITY

`u8`: the note held through the join: channel 0, the square lead, the A at
440 Hz, full velocity, as test/midi plays it.

## .set HOLD

`u64`: how long the held worker spins, a second of the time counter.

## .set TAIL

`u64`: how long hart 0 spins after the note's release, half a second.

## .set SETTLE_TICKS

`u64`: the display ticks hart 0 lets pass before it opens the registers'
gate, so the worker is asleep at it.

## .set SPIN_CHUNK

`u64`: the registers' worker's spin between its polls for a stop, 20 ms.

## .set PESTER_WAKES

`u64`: the wakes the pester makes before it marks its job done.

## .set TICKS

`u64`: the display ticks hart 0 awaits while the pester runs.

## .set PATTERN_F
## .set PATTERN_V

`u64`: the registers' patterns, f n holding PATTERN_F plus n and v n
PATTERN_V plus n.

## .set FFLAGS_SET

`u64`: what regs_set writes to fcsr, two of its flags.

## .set VTYPE_E64_M1

`u64`: vtype for e64 m1 with tail and mask agnostic, as regs_set leaves it.

## .set VTYPE_ILL

`u64`: vtype's vill bit, as a start leaves it.

## .set REFUSAL_BYTES

`u64`: a row of refusals, five words.

## .set KERNEL

`u64`: the kernel's first address, an entry and a stack the start refuses.

## .set JOB_STOPPED

`u64`: a job's 32-bit word the restart's worker sets once its stop has come,
the last thing it writes.

## .set SELECT_WAIT

`u64`: how long the program waits for a scenario's letter over the API, two
seconds of the time counter.

## .set HELD_WAIT

`u64`: how long hart 0 polls the witness word for the exit's hold, half a
second.

## .set RETRY_WAIT

`u64`: how long the restart retries a start answered busy, 200 ms, the
hold's own bound.

## .set HOLD_WAIT

`u64`: how long the stop's scenario waits for a hold it returned inside to
end, 300 ms, the hold's bound and a margin.

## .set W_HELD
## .set W_EXPIRED
## .set W_SAW_WORKING
## .set W_SAW_IDLE
## .set W_STOP_SAW_WORKING
## .set W_STOP_SAW_IDLE

`u32`: the witness word as the kernel writes it (hart.inc's LEAVEHOLD_*):
held; expired with nothing having looked; a start's read of the hart
working, or idle; and a stop's.

## _start

The write of nothing answers 1 with no API port, so the same image runs the
fixtures in turn under the test's first two launches and a scenario under
the two that send its letter.

## join_with_sound

The worker spins HOLD in user mode while hart 0 sleeps in
jab.sys.worker.wait on its job's word, so the sound stream's refills come
through that wait's drain alone; the test hears the note whole. The stop
after the join answers the hart free whether the worker had already ended.

## refusal_codes

Hart 1 runs a sleeping worker throughout, which makes its own start busy
and its stack a running worker's to overlap. Every row's start is made from
registers with argument 0, so a start wrongly made shows in the line.

## registers

Twice on hart 1, so the second start follows a worker that left its
floating-point and vector registers set, and the entry's count shows the
start reset them. The wake reaches the worker asleep at its gate; the stop's
first wake lands while it spins in user mode, an interrupt the vector takes,
and its next poll sees the stop and ends it.

## pestered

Hart 0 waits once, not in a loop, so a wait that ended on a wake rather
than on the word would show the job not done. The awaits after it are on
the display's tick alone, which a worker's wake never reaches, and each
must end on its tick.

## hart_three

Under the jab.noack knob for hart 3, the first start answers 6 and the
second 1, hart 3 failed for the run.

## restart

Hart 0 starts once inside the hold and reads the witness word before any
other call, so no later look can change it; the word names what the start
read, and the start's answer has to agree. The retries then find the hart
idle once the hold is released and start the worker, which hart 0 joins on
its started word and stops; the stopped word, read after the stop returns,
is what the stop's completion acquired from the worker's exit. The line
reads `restart: held, start saw busy, then 0, stopped 1` when the start saw
the hart working inside the hold.

## stop_exit

The stop is made inside the hold and the word read at once after it, before
any other call, so no later look can overwrite or release the evidence. The
word decides the line: working, and only then a start on the hart, which
must answer 0; still held, the stop returned without looking at the hart,
and the program waits out the hold and starts nothing. The stop's elapsed
time is supporting evidence on a line of its own.

## sleep_worker

A wait that ends 0 here would be the word changing, which nothing does, so
the loop goes back to sleep; only the stop ends it.

## regs_worker

The poll for a stop is a wait with a value the gate does not hold, which
answers at once, 1 when a stop is pending.

## hold_exit

The witness word is hart 1's first worker's argument, so the kernel holds
that worker's exit at its gap and marks the word. The poll ends when the
word leaves 0, so a hold that expired before hart 0 looked is reported as
expired by the scenario rather than as never held.

## refusals

`16 * REFUSAL_BYTES u8`: each refused start's row: the label printed before
its group or 0, the hart, the entry, the stack, and its size.

## word_no_sound
## word_sound_join
## word_done
## word_stop
## word_space
## word_sums
## word_starts
## word_r_hart
## word_r_entry
## word_r_stack
## word_r_overlap
## word_r_busy
## word_stop_sleeping
## word_wait
## word_stop_spinning
## word_start
## word_denied
## word_worker_harts
## word_hart0_exit
## word_registers
## word_entry
## word_kept
## word_woke
## word_pestered
## word_woken
## word_awaits
## word_hart3
## word_then
## word_harts
## word_exiting
## word_no_scenario
## word_restart
## word_restart_never
## word_busy
## word_idle
## word_disagreed
## word_expired
## word_nothing
## word_other
## word_comma_then
## word_stopped
## word_stopexit
## word_stopexit_never
## word_saw_working
## word_saw_idle
## word_returned_held
## word_stop_took
## word_ticks

`u8`: the lines' words.

## msg_printed

`u8`: what a worker's print would put on the UART, were it let through.

## job_a
## job_b
## job_c
## job_d
## job_r
## job_p
## job_e

`JOB_BYTES u8`: the jobs, each on its own cache lines.

## stacks

`3 * STACK_BYTES u8`: the workers' stacks.

## line

`160 u8`: the line being built.

## digits

`32 u8`: put_dec's digits, built backward.

## selector

`8 u8`: the scenario's letter, and the write of nothing's buffer.

## witness

`u32`: the witness word, in its own 8 bytes, hart 1's first worker's
argument under jab.leavehold.
