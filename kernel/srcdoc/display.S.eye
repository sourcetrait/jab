ecall sys_display_open > status a0 u64 [26:31]
 status :display_open's
ecall sys_display_ready > ready a0 bool [32:37]
 ready :1 when a flip would go through now, 0 while the cap holds it back
ecall sys_display_flip > status a0 u64 [38:67] :shows the framebuffer without waiting
 status :0, 1 when early under the cap with nothing shown, 2 when not open, 3 when the device refused a command or its source stuck
ecall sys_display_flip_rect x u32,y u32,width u32,height u32 > status a0 u64 [68:112] :shows a rectangle of the framebuffer without waiting
 status :sys_display_flip's, or 4 when the rectangle is empty or reaches outside the screen
ecall sys_display_flip_rects buffer addr,count u64 > status a0 u64 [113:169] :shows that many rectangles, JAB_RECT_SIZE bytes each, as one flip
 buffer :ends the run unless the whole list lies inside the program's window
 status :sys_display_flip's, or 4 when the count is 0 or more than the window could hold, or a rectangle is empty or reaches outside the screen, nothing shown then
call display_present_rects rectangles addr,count u64 > failed a0 bool,clobber a1-a3 [170:263] :transfers the rectangles, JAB_RECT_SIZE bytes each, and flushes the one rectangle holding them all, a wait a batch
 failed :1 when a command fails
call local gpu_transfer_command x u32,y u32,width u32,height u32 > clobber a0-a1 [265:293] :adds the transfer of the rectangle to the pending batch, one chain
call local gpu_flush_command x u32,y u32,width u32,height u32 > clobber a0-a1 [295:318] :adds the flush of the rectangle to the pending batch, one chain
call local gpu_batch_command type u32 > command a0 addr [320:337]
 command :the pending chain's command buffer, zeroed, its type set
call local gpu_batch_add length u64 > pending GPUQ_PENDING(gpu_queue) u64 [339:374] :makes the pending chain's command and response buffers its two descriptors, offered in the available ring's next slot
 length :in a1, the bytes of the command
call local gpu_batch_run > failed a0 bool,last GPUQ_LAST_USED(gpu_queue) u64,pending GPUQ_PENDING(gpu_queue) u64 [376:420] :publishes the pending chains, notifies the device, and halts until it has used every one
 failed :0 when each answered VIRTIO_GPU_RESP_OK_NODATA, else 1, its source stuck included
 pending :0
call local gpu_wait_batch > stuck a0 bool [422:465] :halts until the GPU queue's used index has moved past what the kernel last saw by the pending count or its source is masked, draining and reporting before returning
 stuck :1 when its source stuck and no completion is coming
call local gpu_progress > progress a0 u64 [467:470] :the GPU queue's used index
call local gpu_fault > state display_state u64 [472:476] :its source stuck: 3, every call answering that the device refuses
call local gpu_queue_setup > refused a0 bool,clobber a2 [478:507] :gives the device's control queue the GPU queue record's rings, GPUQ_SIZE entries
 refused :1 when the device offers fewer
ecall sys_display_print message addr > status a0 u64 [508:529] :writes a NUL-terminated string to the screen console, opening the display if needed, stopping at the window's end
 message :ends the run unless it starts inside the program's window
 status :0, or display_open's code, 3 once its source stuck
ecall sys_print message addr > status a0 u64 [530:537] :sys_display_print while the display is open, else sys_uart_print, a stuck display's included
ecall sys_display_text message addr,x i64,y i64,color u32,style u64,scale u64 > width a0 u64,height a1 u64 [538:587] :draws a NUL-terminated string into the framebuffer with the console's font, its top left at x, y, clipped, nothing presented
 message :ends the run unless it starts inside the program's window
 color :0x00RRGGBB, the glyphs' own pixels only
 style :JAB_TEXT_BOLD striking each glyph twice a pixel apart
 scale :in 256ths sizing each cell, held to JAB_TEXT_SCALE_MAX
 width :the width drawn, one more for bold
 height :a cell's
call local text_glyph character u8,x i64,y i64,color u32,style u64,width u64,height u64 > clobber a5-a7 [589:646] :draws the glyph's set pixels in a cell that wide and high, each clipped to the screen
call local text_pixel color u32,column i64,row i64 > clobber a7 [648:665] :the colour at that pixel when it is on the screen
 color :in a3, column in a5, row in a6
call display_open > status a0 u64,state display_state u64,base gpu_base addr,clobber a1-a3 [666:743] :brings the GPU up and shows the framebuffer
 status :0, 1 with no virtio-gpu, 2 when the device refuses the features or its control queue is short, 3 when a command fails or its source stuck; 0 at once when open
call display_present_rect x u32,y u32,width u32,height u32 > failed a0 bool,clobber a1-a3 [744:792] :transfers the rectangle of the framebuffer to the host and flushes it to the screen
 failed :1 when a command fails
call local gpu_get_display_info > failed a0 bool,clobber a1-a3 [794:832] :asks what the display is
call local gpu_create_resource > failed a0 bool,clobber a1-a3 [834:853] :creates the one 2D resource, the framebuffer's size and format
call local gpu_attach_backing > failed a0 bool,clobber a1-a3 [855:874] :the framebuffer, one contiguous entry, backs the resource
call local gpu_set_scanout > failed a0 bool,clobber a1-a3 [876:893] :scanout 0 shows the whole resource
call local gpu_command type u32 > command gpu_cmd [895:906] :zeroes the request buffer and sets its type
call local gpu_submit length u32,expected u32 > failed a0 bool,response gpu_resp,clobber a1-a3 [908:988] :runs the request in gpu_cmd as a batch of one chain
 failed :0 when the device answered with the expected type, else 1, its source stuck included
call console_write bytes addr,end addr > column console_col u64,row console_row u64,clobber a0-a4 [989:1077] :draws the bytes up to the terminator or the end at the cursor, then shows the rows touched
call local console_glyph character u8,column u64,row u64 > clobber a3-a4 [1079:1117] :draws the glyph in that cell, white on black
call local console_scroll [1119:1133] :moves every line up by one and clears the last
