j trap_vector [11:66] :the supervisor trap vector through stvec, a trap from the program framed below the hart's record, which sscratch holds, and tp set to that record: a system call sent to its handler by the number in a7 with the frame at sp, an external interrupt to the drain, anything else to a fault report
j local interrupt [68:71] :an external interrupt from the program, one bounded drain and its report, the program resumed where it was
j local bad_syscall [73:84] :a call number outside the table, reported on the UART and the run ended with 1
call message_bounds message addr > end a1 addr [85:92] :ends the run unless the message starts inside the program's window
 end :the window's end, JAB_STACK_TOP
ecall sys_uart_print message addr > status a0 u64 [93:115] :writes a NUL-terminated message to the UART, stopping at the window's end, the whole call under the line lock
 message :ends the run when outside the program's window
 status :always 0
call buffer_bounds buffer addr,size u64 [116:126] :ends the run unless the whole range lies inside the program's window
call copy_bytes destination addr,source addr,size u64 > clobber a0-a2 [127:139]
call zero_bytes buffer addr,size u64 > clobber a0-a1 [140:150]
j bad_address [151:156] :an address from the program outside its window, reported on the UART and the run ended with 1
ecall local sys_exit status u64 [158:174] :ends the run once the sound stream has played out, QEMU exiting with the status
j local program_fault [176:193] :a fault in the program, its cause, pc, and tval reported on the UART and the run ended with 1
j local kernel_trap [195:224] :a trap the kernel took itself, sp put back: the release's wake store faulting at its file's address resumes past the store with hart_wake_faulted set, and anything else goes to kernel_fault
j local kernel_fault [225:244] :a fault in the kernel, its cause, pc, and tval reported on the UART and the run ended with 1
j trap_return [245:248] :the end of every system call, the program resumed past its ecall with the frame at sp restored
j local interrupt_return [249:286] :the frame at sp restored and the program resumed at the instruction the interrupt came before
j qemu_exit status u64 [287:298] :ends QEMU through the test device, halting if the write does not end it
 status :0 passes, anything else fails with it as the exit code
j halt [299:301] :the hart waits for good
