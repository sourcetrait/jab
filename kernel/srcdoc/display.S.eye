set DISPLAY_RESOURCE u32 [6] :the one resource's id
set GPU_CMD_BYTES u64 [7] :bytes a command buffer holds
set GPU_RESP_BYTES u64 [8] :bytes a batch response buffer holds
set GPU_TRANSFERS_PER_BATCH u64 [9] :the transfers a batch holds, the last batch carrying the flush beside them
set FONT_WIDTH u64 [11] :a console cell's width in pixels
set FONT_HEIGHT u64 [12] :its height
set FONT_ROW_BYTES u64 [13] :bytes in a glyph's row
set FONT_GLYPH_BYTES u64 [14] :bytes in a glyph
set FONT_FIRST u8 [15] :the first character the font draws
set FONT_LAST u8 [16] :the last
set CONSOLE_COLUMNS u64 [17] :the cells across the screen
set CONSOLE_ROWS u64 [18] :the lines down it
set CONSOLE_LINE_BYTES u64 [19] :framebuffer bytes in a line of cells
set CONSOLE_FG u32 [20] :the console's text, white
set CONSOLE_BG u32 [21] :its ground, black
ecall sys_display_open > status a0 u64 [26:31]
 status :display_open's
ecall sys_display_ready > ready a0 bool [32:37]
 ready :1 when a flip would go through now, 0 while the cap holds it back
ecall sys_display_flip > status a0 u64 [38:64] :shows the framebuffer without waiting
 status :0, 1 when early under the cap with nothing shown, 2 when not open, 3 when the device refused a command
ecall sys_display_flip_rect x u32,y u32,width u32,height u32 > status a0 u64 [65:106] :shows a rectangle of the framebuffer without waiting
 status :sys_display_flip's, or 4 when the rectangle is empty or reaches outside the screen
ecall sys_display_flip_rects buffer addr,count u64 > status a0 u64 [107:160] :shows that many rectangles, JAB_RECT_SIZE bytes each, as one flip
 buffer :ends the run unless the whole list lies inside the program's window
 status :sys_display_flip's, or 4 when the count is 0 or more than the window could hold, or a rectangle is empty or reaches outside the screen, nothing shown then
call display_present_rects rectangles addr,count u64 > failed a0 bool,clobber a1-a3 [161:254] :transfers the rectangles, JAB_RECT_SIZE bytes each, and flushes the one rectangle holding them all, a wait a batch
 failed :1 when a command fails
call local gpu_transfer_command x u32,y u32,width u32,height u32 > clobber a0-a1 [256:284] :adds the transfer of the rectangle to the pending batch, one chain
call local gpu_flush_command x u32,y u32,width u32,height u32 > clobber a0-a1 [286:309] :adds the flush of the rectangle to the pending batch, one chain
call local gpu_batch_command type u32 > command a0 addr [311:328]
 command :the pending chain's command buffer, zeroed, its type set
call local gpu_batch_add length u64 > pending GPUQ_PENDING(gpu_queue) u64 [330:365] :makes the pending chain's command and response buffers its two descriptors, offered in the available ring's next slot
 length :in a1, the bytes of the command
call local gpu_batch_run > failed a0 bool,last GPUQ_LAST_USED(gpu_queue) u64,pending GPUQ_PENDING(gpu_queue) u64 [367:407] :publishes the pending chains, notifies the device, and halts until it has used every one
 failed :0 when each answered VIRTIO_GPU_RESP_OK_NODATA, else 1
 pending :0
call local gpu_wait_batch > clobber a0 [409:437] :halts until the GPU queue's used index has moved past what the kernel last saw by the pending count, the line serviced before returning
call local gpu_queue_setup > refused a0 bool,clobber a2 [439:468] :gives the device's control queue the GPU queue record's rings, GPUQ_SIZE entries
 refused :1 when the device offers fewer
ecall sys_display_print message addr > status a0 u64 [469:487] :writes a NUL-terminated string to the screen console, opening the display if needed, stopping at the window's end
 message :ends the run unless it starts inside the program's window
 status :0, or display_open's code
ecall sys_print message addr > status a0 u64 [488:494] :sys_display_print once the display is open, else sys_uart_print
ecall sys_display_text message addr,x i64,y i64,color u32,style u64,scale u64 > width a0 u64,height a1 u64 [495:544] :draws a NUL-terminated string into the framebuffer with the console's font, its top left at x, y, clipped, nothing presented
 message :ends the run unless it starts inside the program's window
 color :0x00RRGGBB, the glyphs' own pixels only
 style :JAB_TEXT_BOLD striking each glyph twice a pixel apart
 scale :in 256ths sizing each cell, held to JAB_TEXT_SCALE_MAX
 width :the width drawn, one more for bold
 height :a cell's
call local text_glyph character u8,x i64,y i64,color u32,style u64,width u64,height u64 > clobber a5-a7 [546:603] :draws the glyph's set pixels in a cell that wide and high, each clipped to the screen
call local text_pixel color u32,column i64,row i64 > clobber a7 [605:622] :the colour at that pixel when it is on the screen
 color :in a3, column in a5, row in a6
call display_open > status a0 u64,state display_state u64,base gpu_base addr,clobber a1-a3 [623:694] :brings the GPU up and shows the framebuffer
 status :0, 1 with no virtio-gpu, 2 when the device refuses the features or its control queue is short, 3 when a command fails; 0 at once when open
rodata local msg_gpu_at 13 u8 [648:649] :the debug line naming the GPU's transport, under DEBUG only
call display_present_rect x u32,y u32,width u32,height u32 > failed a0 bool,clobber a1-a3 [695:743] :transfers the rectangle of the framebuffer to the host and flushes it to the screen
 failed :1 when a command fails
call local gpu_get_display_info > failed a0 bool,clobber a1-a3 [745:783] :asks what the display is
rodata local msg_display 14 u8 [774:775] :the debug line on the display's first mode, under DEBUG only
rodata local msg_enabled 10 u8 [776:777] :that line's enabled field
call local gpu_create_resource > failed a0 bool,clobber a1-a3 [785:804] :creates the one 2D resource, the framebuffer's size and format
call local gpu_attach_backing > failed a0 bool,clobber a1-a3 [806:825] :the framebuffer, one contiguous entry, backs the resource
call local gpu_set_scanout > failed a0 bool,clobber a1-a3 [827:844] :scanout 0 shows the whole resource
call local gpu_command type u32 > command gpu_cmd [846:857] :zeroes the request buffer and sets its type
call local gpu_submit length u32,expected u32 > failed a0 bool,response gpu_resp,clobber a1-a3 [859:933] :runs the request in gpu_cmd as a batch of one chain
 failed :0 when the device answered with the expected type, else 1
rodata local msg_gpu_cmd 14 u8 [916:917] :the debug line on a command, under DEBUG only
rodata local msg_gpu_resp 7 u8 [918:919] :that line's response field
call console_write bytes addr,end addr > column console_col u64,row console_row u64,clobber a0-a4 [934:1022] :draws the bytes up to the terminator or the end at the cursor, then shows the rows touched
call local console_glyph character u8,column u64,row u64 > clobber a3-a4 [1024:1062] :draws the glyph in that cell, white on black
call local console_scroll [1064:1078] :moves every line up by one and clears the last
bss local gpu_queue [1082:1084] :the GPU's control queue record
bss local gpu_cmd 64 u8 [1085:1086] :the single command's buffer
bss local gpu_resp 408 u8 [1087:1089] :the single command's response
bss local gpu_batch_cmds 2048 u8 [1090:1091] :a batch's command buffers, GPU_CMD_BYTES each
bss local gpu_batch_resps 768 u8 [1092:1093] :a batch's response buffers, GPU_RESP_BYTES each
bss local gpu_base addr [1094:1095] :the GPU's transport
bss local display_state u64 [1096:1097] :1 once open
bss local console_col u64 [1098:1099] :the cursor's column
bss local console_row u64 [1100:1101] :the cursor's line
