j trap_vector [12:64] :the supervisor trap vector through stvec, a trap from the program framed below the hart's record, which sscratch holds, and tp set to that record: a system call sent to its handler by the number in a7 with the frame at sp, an external interrupt to the drain, anything else to a fault report
j local call_table [65:70] :the handler syscall_table holds for the number in a7, entered with the frame at sp
j local worker_call [72:81] :a worker's system call: jab.sys.harts and the worker calls a worker may make on to call_table, every other to sys_denied
j sys_denied [82:85] :a call the hart may not make answered JAB_DENIED, all ones, nothing entered
j local interrupt [87:92] :an external interrupt from the program, one bounded drain and on hart 0 its report, then the boundary: the program resumed where it was, or the hart stopped there
j local bad_syscall [94:99] :a call number outside the table on hart 0: its line the hart's fault, the run ended with 1
call message_bounds message addr > end a1 addr [100:107] :ends the run unless the message starts inside the program's window
 end :the window's end, JAB_STACK_TOP
ecall sys_uart_print message addr > status a0 u64 [108:130] :writes a NUL-terminated message to the UART, stopping at the window's end, the whole call under the line lock
 message :ends the run when outside the program's window
 status :always 0
call buffer_bounds buffer addr,size u64 [131:141] :ends the run unless the whole range lies inside the program's window
call copy_bytes destination addr,source addr,size u64 > clobber a0-a2 [142:154]
call zero_bytes buffer addr,size u64 > clobber a0-a1 [155:165]
j bad_address [166:168] :an address from the program outside its window, on any hart: its line the hart's fault, the run ended with 1
ecall local sys_exit status u64 [170:187] :ends the run: every worker stopped where it is, the sound stream played out, then every fault another hart recorded printed, QEMU exiting with the status, or with 1 after such a fault
j local program_fault [189:197] :a fault in the program, hart 0's or a worker's: its cause, pc, and tval the hart's fault, the run ended with 1
j local kernel_trap [199:228] :a trap the kernel took itself, sp put back: the release's wake store faulting at its file's address resumes past the store with hart_wake_faulted set, and anything else goes to kernel_fault
j local kernel_fault [229:245] :a fault in the kernel on any hart: its cause, pc, and tval the hart's fault, the run ended with 1; a second fault on a hart already reporting one ends the run at once
j local timer_left_enabled [246:255] :under DEBUG, a return to user mode with the timer's enable set, which user mode would take as a fault: its line the hart's fault, the run ended with 1
j fatal_plain line addr [256:259] :a fault that is its line: the line kept in the hart's record as its fault, then the shutdown and the run ended with 1
j fatal_dec line addr,value u64 [260:263] :fatal_plain with the value in decimal after the line
j fatal_hex line addr,value u64 [264:268] :fatal_plain with the value in hex after the line
j local fault_recorded [269:274] :t0 a fault's kind, its fields already in the hart's record: the kind published after them, then the shutdown claimed, a hart behind another's claim parking and the owner going on to fatal_exit with 1
j fatal_exit status u64 [275:312] :the run's end by the shutdown's owner: under the line lock every recorded fault's line, the hart's own first, then each other hart's in order, a line for each hart that did not halt in the shutdown's bound, then QEMU ended with the status, or with 1 after another hart's fault
call local fault_line record addr > printed a0 bool [314:387] :the record's fault as its line on the UART, the line lock held by the caller
j trap_return [388:391] :the end of every system call, the program resumed past its ecall with the frame at sp restored
j local interrupt_return [392:452] :the boundary: under DEBUG the timer's enable checked clear (timer_left_enabled); another hart's shutdown parks the hart, a worker's forced stop ends it (worker_leave), and hart 0 keeps its external interrupts on while workers run; then the frame at sp restored and the program resumed at the instruction the interrupt came before
j qemu_exit status u64 [453:464] :ends QEMU through the test device, halting if the write does not end it
 status :0 passes, anything else fails with it as the exit code
j halt [465:467] :the hart waits for good
