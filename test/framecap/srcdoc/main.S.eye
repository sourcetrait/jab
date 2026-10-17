macro flip_whole kind imm > scratch t0-t6,a0-a7,s8-s9,ra,tp,ft0-ft11,fa0-fa7 [31:37] :a whole flip between two rdtime stamps, its receipt kept as that kind
macro flip_rect kind imm > scratch t0-t6,a0-a7,s8-s9,ra,tp,ft0-ft11,fa0-fa7 [39:45] :a flip of the rectangle in a0 to a3 between two rdtime stamps, its receipt kept as that kind
macro flip_rects kind imm,buffer reg,count reg > scratch t0-t6,a0-a7,s8-s9,ra,tp,ft0-ft11,fa0-fa7 [47:53] :a flip of a list of rectangles between two rdtime stamps, its receipt kept as that kind
 buffer :the rectangles, JAB_RECT_SIZE bytes each
 count :how many
j _start [57:88] :a flip before the open, kept; with no API on the machine the plain run, else SELECT_WAIT for a scenario's letter over the API and its scenario
j local no_scenario [89:91] :`framecap: no scenario` on the UART and exit 2
j local plain [93:147] :the burst, the awaited whole and rectangle flips, the bad rectangle, the lists, and a print between two flips, every receipt kept; then the receipts, `flags=NN`, and `paced` on the UART, exit 0
j local list [149:161] :the old frame flipped whole, the new one drawn, and a list of three rectangles flipped, its second transfer the knob's to refuse; the receipts, then idle for the capture
j local long [163:170] :a list of LIST_LONG rectangles flipped, a transfer of its first batch the knob's to refuse; the receipts, exit 0
j local transfer [172:182] :the old frame flipped whole, the new one drawn, and a whole flip whose transfer is the knob's to refuse; the receipts, then idle for the capture
j local flush [184:189] :a whole flip whose flush is the knob's to refuse; the receipts, exit 0
j local held [191:207] :under the GPU's held source, a whole flip, HELD_WAIT of awaits for the source's window to fail it, then a flip with a1 to a3 at SENTINEL; the receipts, exit 0
j local idle [209:213] :`framecap: scenario done`, then the display's tick awaited until the capture ends the run
j local no_display [215:217] :says so on the UART and exits with 1
j local flip_failed [219:221] :says a flip after await failed on the UART and exits with 2
call local keep status u64,stamp u64,tick u64,ordinal u64 > clobber t0-t4 [223:241] :a receipt into the next of RECEIPTS records, nothing once they are full
 status :a flip's a0, then its a1 to a3; the kind in t6, the rdtime stamps around the call in s8 and s9
call local report > clobber a0-a1,a7 [243:280] :every receipt kept as a `receipt` line on the UART, its seven fields in hex
call local put_hex value u64,at addr > text 0(at) u8 [282:298]
 text :the value's sixteen lowercase hex digits
call local fill colour u32 > framebuffer JAB_DISPLAY_BASE [300:310] :every pixel the colour
call local two_digits value u64,at addr > digits 0(at) u8 [312:320]
 value :under a hundred
 digits :the value's two decimal digits
