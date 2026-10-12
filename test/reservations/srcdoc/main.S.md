# main.S

reservations: hart ownership by role, a line a step on the UART for the
test to hold against the machine's harts. It reads the online secondaries,
the lowest and the highest, then makes each step's calls before its
reservation and after it, every worker it starts on the hart's own stack
and stopped before the step's line, and exits 0. A worker enters with a0
its job, a record of JOB_BYTES in bss, or 0, and ends by
jab.sys.worker.exit or a stop. The kernel keeps every register a call does
not answer in, so the fixtures of the five-operand form set a5 themselves.

## .set STACK_BYTES

`u64`: a worker's stack, 16 KiB; stacks holds three, one a hart.

## .set JOB_WORD
## .set JOB_DONE
## .set JOB_RESERVE
## .set JOB_CLAIM
## .set JOB_RELEASE
## .set JOB_OWNED

`u64`: a job's fields: the 32-bit word a sleeping worker waits on, which
stays 0; the 32-bit word the denied worker marks done; and that worker's
four answers, reserve's, claim's, release's, and owned's.

## .set JOB_BYTES

`u64`: a job's record, one cache line.

## .set A3_SENTINEL

`u64`: a3 across jab.sys.harts, 14906, which the call leaves.

## .set A5_SENTINEL

`u64`: a5 in the starts that name no owner the kernel issues.

## .set PAST_HART

`u64`: hart 7's bit, past every machine the test runs.

## .set SHORT_COUNT

`u64`: a reservation's count past every machine's secondaries.

## word_harts
## word_space
## word_legacy
## word_owned
## word_start
## word_size
## word_unreserved
## word_refused
## word_busy
## word_reserve
## word_again
## word_owner
## word_five
## word_none
## word_reserved
## word_claim_refused
## word_main
## word_past
## word_floor
## word_claim
## word_id
## word_second
## word_cross
## word_both
## word_order
## word_release_busy
## word_returned
## word_stale
## word_reclaim
## word_released
## word_denied
## word_answers

`u8`: the lines' words.

## job
## job_denied

`JOB_BYTES u8`: the sleeping workers' job and the denied worker's.

## stacks

`3 * STACK_BYTES u8`: the workers' stacks, hart n's at n - 1.

## line

`160 u8`: the line being built.

## digits

`32 u8`: put_dec's digits, built backward.
