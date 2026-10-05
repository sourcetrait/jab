macro jab.job.free mailbox addr,free reg > free free bool,scratch t0-t1 [16:22] :the producer's: 1 when the mailbox holds no job in flight, the last job's outputs then readable
macro jab.job.publish mailbox addr,frame u64,payload addr,size u64,gen reg > gen gen u32,generation JAB_JOB_GEN(mailbox) u32 [24:32] :the producer's, onto a free mailbox: the descriptor, then its generation one on, released after it
macro jab.job.cancel mailbox addr,gen u32 > cancel JAB_JOB_CANCEL(mailbox) u32 [34:36] :the producer's: the job of that generation cancelled at its next band
macro jab.job.join mailbox addr > scratch t0-t1,a0-a1,a7 [38:50] :the producer's: asleep until the job in flight is complete, its outputs then readable
macro jab.job.await mailbox addr,gen reg > stopped a0 bool,gen gen u32,scratch t0,a1,a7 [52:67] :the worker's: asleep until a job is published, its descriptor then readable
 stopped :1 when a stop is asked of the worker instead, gen then meaningless
macro jab.job.cancelled mailbox addr,gen u32,cancelled reg > cancelled cancelled bool,scratch t0 [69:73] :the worker's: whether the job of that generation is cancelled
macro jab.job.complete mailbox addr,gen u32,status u32 > done JAB_JOB_DONE(mailbox) u32,status JAB_JOB_STATUS(mailbox) u32,count JAB_JOB_COUNT(mailbox) u64,scratch t0 [75:82] :the worker's: the job's status and its count, then its completion, released after every output
