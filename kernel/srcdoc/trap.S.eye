j trap_vector [11:65] :the supervisor trap vector through stvec, a system call sent to its handler by the number in a7 with the frame at sp, an external interrupt to the drain, anything else to a fault report
j local interrupt [67:70] :an external interrupt from the program, one bounded drain and its report, the program resumed where it was
j local bad_syscall [72:82] :a call number outside the table, reported on the UART and the run ended with 1
call message_bounds message addr > end a1 addr [83:90] :ends the run unless the message starts inside the program's window
 end :the window's end, JAB_STACK_TOP
ecall sys_uart_print message addr > status a0 u64 [91:111] :writes a NUL-terminated message to the UART, stopping at the window's end
 message :ends the run when outside the program's window
 status :always 0
call buffer_bounds buffer addr,size u64 [112:122] :ends the run unless the whole range lies inside the program's window
call copy_bytes destination addr,source addr,size u64 > clobber a0-a2 [123:135]
call zero_bytes buffer addr,size u64 > clobber a0-a1 [136:146]
j bad_address [147:151] :an address from the program outside its window, reported on the UART and the run ended with 1
ecall local sys_exit status u64 [153:169] :ends the run once the sound stream has played out, QEMU exiting with the status
j local program_fault [171:187] :a fault in the program, its cause, pc, and tval reported on the UART and the run ended with 1
j local kernel_trap [189:190] :a trap the kernel took itself, sp put back before kernel_fault reports it
j local kernel_fault [191:208] :a fault in the kernel, its cause, pc, and tval reported on the UART and the hart halted
j trap_return [209:212] :the end of every system call, the program resumed past its ecall with the frame at sp restored
j local interrupt_return [213:250] :the frame at sp restored and the program resumed at the instruction the interrupt came before
j qemu_exit status u64 [251:262] :ends QEMU through the test device, halting if the write does not end it
 status :0 passes, anything else fails with it as the exit code
j halt [263:265] :the hart waits for good
