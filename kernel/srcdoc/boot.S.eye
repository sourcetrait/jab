j _start > stack sp addr [6:36] :every hart's reset entry, hart 0 dropping into kmain as supervisor and every other parking
 stack :kernel_stack_top, the stack kmain runs on
j local park [38:42] :a hart other than 0 waits here for good
j local mtrap [43:44] :the machine-mode trap vector, where a trap not delegated stops
