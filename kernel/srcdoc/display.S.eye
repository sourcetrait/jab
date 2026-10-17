ecall sys_display_open > status a0 u64 [26:31]
 status :display_open's
ecall sys_display_ready > ready a0 bool [32:37]
 ready :1 when a flip would go through now, 0 while the cap holds it back
ecall sys_display_flip > status a0 u64,stamp a1 u64,tick a2 u64,ordinal a3 u64 [38:80] :shows the framebuffer without waiting
 status :0, 1 when early under the cap with nothing shown, 2 when not open, 3 when the device refused a command or its source stuck
 stamp :the rdtime its readiness check read; 0 when the call ended before the check, not open or failed already
 tick :the eligibility tick that check read; 0 when stamp is
 ordinal :present_ordinal as the call returns
ecall sys_display_flip_rect x u32,y u32,width u32,height u32 > status a0 u64,stamp a1 u64,tick a2 u64,ordinal a3 u64 [81:136] :shows a rectangle of the framebuffer without waiting
 status :sys_display_flip's, or 4 when the rectangle is empty or reaches outside the screen
 stamp :sys_display_flip's, 0 with 4
 tick :sys_display_flip's, 0 with 4
 ordinal :sys_display_flip's
ecall sys_display_flip_rects buffer addr,count u64 > status a0 u64,stamp a1 u64,tick a2 u64,ordinal a3 u64 [137:202] :shows that many rectangles, JAB_RECT_SIZE bytes each, as one flip
 buffer :ends the run unless the whole list lies inside the program's window
 status :sys_display_flip's, or 4 when the count is 0 or more than the window could hold, or a rectangle is empty or reaches outside the screen, nothing shown then
 stamp :sys_display_flip's, 0 with 4
 tick :sys_display_flip's, 0 with 4
 ordinal :sys_display_flip's
call display_present_rects rectangles addr,count u64 > failed a0 bool,ordinal present_ordinal u64,clobber a1-a3 [203:334] :transfers the rectangles, JAB_RECT_SIZE bytes each, and flushes the one rectangle holding them all, a wait a batch
 failed :1 when a command fails
 ordinal :one more when the last batch's flush answered OK, whatever its transfers answered
call local gpu_transfer_command x u32,y u32,width u32,height u32 > clobber a0-a1 [336:364] :adds the transfer of the rectangle to the pending batch, one chain
call local gpu_flush_command x u32,y u32,width u32,height u32 > clobber a0-a1 [366:389] :adds the flush of the rectangle to the pending batch, one chain
call local gpu_batch_command type u32 > command a0 addr [391:408]
 command :the pending chain's command buffer, zeroed, its type set
call local gpu_batch_add length u64 > pending GPUQ_PENDING(gpu_queue) u64 [410:445] :makes the pending chain's command and response buffers its two descriptors, offered in the available ring's next slot
 length :in a1, the bytes of the command
call local gpu_batch_run > failed a0 u64,last GPUQ_LAST_USED(gpu_queue) u64,pending GPUQ_PENDING(gpu_queue) u64 [447:493] :publishes the pending chains, notifies the device, and halts until it has used every one
 failed :0 when each answered VIRTIO_GPU_RESP_OK_NODATA, 1 when one did not, 2 when its source stuck and no answer was read
 pending :0
call local gpu_wait_batch > stuck a0 bool [495:537] :halts until the GPU queue's used index has moved past what the kernel last saw by the pending count or its source is masked, draining and reporting before returning
 stuck :1 when its source is masked, whatever the used index says, a completion in the last drain included
call local gpu_failed > failed a0 bool [539:551] :1 once the GPU's source is masked
call local gpu_progress > progress a0 u64 [553:556] :the GPU queue's used index
call local gpu_fault > state display_state u64 [558:562] :its source stuck: 3, every call answering that the device refuses, the device reset (virtio_reset)
call local gpu_queue_setup > refused a0 bool,clobber a2 [564:594] :gives the device's control queue the GPU queue record's rings, GPUQ_SIZE entries
 refused :1 when the device offers fewer
ecall sys_display_print message addr > status a0 u64 [595:616] :writes a NUL-terminated string to the screen console, opening the display if needed, stopping at the window's end
 message :ends the run unless it starts inside the program's window
 status :0, or display_open's code, 3 once its source stuck
ecall sys_print message addr > status a0 u64 [617:624] :sys_display_print while the display is open, else sys_uart_print, a stuck display's included
ecall sys_display_text message addr,x i64,y i64,color u32,style u64,scale u64 > width a0 u64,height a1 u64 [625:674] :draws a NUL-terminated string into the framebuffer with the console's font, its top left at x, y, clipped, nothing presented
 message :ends the run unless it starts inside the program's window
 color :0x00RRGGBB, the glyphs' own pixels only
 style :JAB_TEXT_BOLD striking each glyph twice a pixel apart
 scale :in 256ths sizing each cell, held to JAB_TEXT_SCALE_MAX
 width :the width drawn, one more for bold
 height :a cell's
call local text_glyph character u8,x i64,y i64,color u32,style u64,width u64,height u64 > clobber a5-a7 [676:733] :draws the glyph's set pixels in a cell that wide and high, each clipped to the screen
call local text_pixel color u32,column i64,row i64 > clobber a7 [735:752] :the colour at that pixel when it is on the screen
 color :in a3, column in a5, row in a6
call display_open > status a0 u64,state display_state u64,base gpu_base addr,clobber a1-a3 [753:833] :brings the GPU up and shows the framebuffer
 status :0, 1 with no virtio-gpu, 2 when the device refuses the features or its control queue is short, 3 when a command fails or its source stuck; 0 at once when open
call display_present_rect x u32,y u32,width u32,height u32 > failed a0 bool,ordinal present_ordinal u64,clobber a1-a3 [834:907] :transfers the rectangle of the framebuffer to the host and flushes it to the screen
 failed :1 when a command fails
 ordinal :one more when its flush answered OK
call local present_knobs > badxfer badxfer_call u64,at badxfer_at u64,badflush badflush_call u64,clobber a0 [908:928] :under DEBUG, the GPU knobs from the bootargs, read before the open's first frame
 badxfer :the present call whose transfer jab.badxfer refuses, all ones when absent
 at :which of its transfers, jab.badxferat, 1 when absent
 badflush :the present call whose flush jab.badflush refuses, all ones when absent
call local present_faults > faults a0 u64,calls present_calls u64 [938:958] :under DEBUG, the present call numbered from boot and the faults the knobs name for it
 faults :the refused transfer's number in the low half, 0 for none, and bit 32 the flush refused
call local gpu_get_display_info > failed a0 bool,clobber a1-a3 [960:998] :asks what the display is
call local gpu_create_resource > failed a0 bool,clobber a1-a3 [1000:1019] :creates the one 2D resource, the framebuffer's size and format
call local gpu_attach_backing > failed a0 bool,clobber a1-a3 [1021:1040] :the framebuffer, one contiguous entry, backs the resource
call local gpu_set_scanout > failed a0 bool,clobber a1-a3 [1042:1059] :scanout 0 shows the whole resource
call local gpu_command type u32 > command gpu_cmd [1061:1072] :zeroes the request buffer and sets its type
call local gpu_submit length u32,expected u32 > failed a0 bool,response gpu_resp,clobber a1-a3 [1074:1154] :runs the request in gpu_cmd as a batch of one chain
 failed :0 when the device answered with the expected type, else 1, its source stuck included
call console_write bytes addr,end addr > column console_col u64,row console_row u64,clobber a0-a4 [1155:1243] :draws the bytes up to the terminator or the end at the cursor, then shows the rows touched
call local console_glyph character u8,column u64,row u64 > clobber a3-a4 [1245:1283] :draws the glyph in that cell, white on black
call local console_scroll [1285:1299] :moves every line up by one and clears the last
