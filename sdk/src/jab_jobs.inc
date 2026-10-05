.set JAB_JOB_BYTES, 128
.set JAB_JOB_GEN, 0
.set JAB_JOB_CANCEL, 4
.set JAB_JOB_FRAME, 8
.set JAB_JOB_PAYLOAD, 16
.set JAB_JOB_SIZE, 24
.set JAB_JOB_ARGS, 32
.set JAB_JOB_DONE, 64
.set JAB_JOB_STATUS, 68
.set JAB_JOB_COUNT, 72
.set JAB_JOB_OWN, 80

.set JAB_JOB_OK, 0
.set JAB_JOB_CANCELLED, 1

.macro jab.job.free mailbox, free
    lw t0, JAB_JOB_DONE(\mailbox)
    lw t1, JAB_JOB_GEN(\mailbox)
    fence r, rw                     # the last job's outputs after its completion
    sub t0, t0, t1
    seqz \free, t0
.endm

.macro jab.job.publish mailbox, frame, payload, size, gen
    sd \frame, JAB_JOB_FRAME(\mailbox)
    sd \payload, JAB_JOB_PAYLOAD(\mailbox)
    sd \size, JAB_JOB_SIZE(\mailbox)
    lw \gen, JAB_JOB_GEN(\mailbox)
    lw t0, JAB_JOB_CANCEL(\mailbox)
    addiw t0, t0, -1
    beq t0, \gen, .Ljab_job_publish_kept\@  # cancelled before its publish
    sw \gen, JAB_JOB_CANCEL(\mailbox)       # the last generation: no job to come carries it
.Ljab_job_publish_kept\@:
    addiw \gen, \gen, 1
    fence rw, w                     # the descriptor before the generation that publishes it
    sw \gen, JAB_JOB_GEN(\mailbox)
.endm

.macro jab.job.cancel mailbox, gen
    sw \gen, JAB_JOB_CANCEL(\mailbox)    # the job in flight, or the next once the mailbox is free
.endm

.macro jab.job.join mailbox
.Ljab_job_join_check\@:
    lw t0, JAB_JOB_DONE(\mailbox)
    lw t1, JAB_JOB_GEN(\mailbox)
    beq t0, t1, .Ljab_job_join_done\@
    addi a0, \mailbox, JAB_JOB_DONE
    mv a1, t0
    li a7, JAB_SYS_WORKER_WAIT
    ecall                           # asleep while the completion holds what it held
    j .Ljab_job_join_check\@
.Ljab_job_join_done\@:
    fence r, rw                     # the job's outputs after its completion
.endm

.macro jab.job.await mailbox, gen
.Ljab_job_await_check\@:
    lw \gen, JAB_JOB_GEN(\mailbox)
    lw t0, JAB_JOB_DONE(\mailbox)
    bne \gen, t0, .Ljab_job_await_taken\@
    addi a0, \mailbox, JAB_JOB_GEN
    mv a1, t0
    li a7, JAB_SYS_WORKER_WAIT
    ecall                           # asleep while no generation is newer than the last done
    beqz a0, .Ljab_job_await_check\@
    j .Ljab_job_await_out\@         # a stop asked: a0 1
.Ljab_job_await_taken\@:
    fence r, rw                     # the descriptor after the generation that published it
    li a0, 0
.Ljab_job_await_out\@:
.endm

.macro jab.job.cancelled mailbox, gen, cancelled
    lw t0, JAB_JOB_CANCEL(\mailbox)
    sub t0, t0, \gen
    seqz \cancelled, t0
.endm

.macro jab.job.complete mailbox, gen, status
    sw \status, JAB_JOB_STATUS(\mailbox)
    ld t0, JAB_JOB_COUNT(\mailbox)
    addi t0, t0, 1
    sd t0, JAB_JOB_COUNT(\mailbox)
    fence rw, w                     # every output, the status, and the count before the completion
    sw \gen, JAB_JOB_DONE(\mailbox)
.endm
