set DF_MAX_BITS u64 [4] :the longest code
set DF_LIT_SYMBOLS u64 [5] :the literal and length alphabet
set DF_DIST_SYMBOLS u64 [6] :the distance alphabet
set DF_CODE_SYMBOLS u64 [7] :the code-length alphabet
set DF_LENGTHS u64 [8] :the lengths a dynamic block carries at most
set DF_TICK_BYTES u64 [9] :output bytes between looks at the sound stream
set DF_OK u64 [11] :no failure
set DF_ERR_INPUT u64 [12] :the stream ended in the middle of something
set DF_ERR_OUTPUT u64 [13] :the buffer could not hold it
set DF_ERR_BLOCK u64 [14] :a block type that does not exist
set DF_ERR_STORED u64 [15] :a stored block's length disagrees with itself
set DF_ERR_CODES u64 [16] :a code table that is not a Huffman code
set DF_ERR_SYMBOL u64 [17] :a symbol no table can produce
set DF_ERR_DISTANCE u64 [18] :a distance reaching before the output
call deflate_inflate output addr,capacity u64,source addr,length u64 > written a0 u64,code a1 u64,clobber a2-a4 [23:33] :inflates a whole stream held in one segment
 code :a DF_* code
call deflate_begin output addr,capacity u64,source addr,length u64,hook addr > state df_in [34:60] :sets the decoder up afresh over the output and the first segment
 hook :called through df_refill when a segment runs out, 0 for none; the clobbers this file lists leave out a hook's own
 state :every df_* cursor, df_more the hook
call deflate_segment source addr,length u64 > input df_in addr,inlen df_inlen u64,inpos df_inpos u64 [61:70] :the next segment of compressed bytes, what a hook calls before it returns 1
call deflate_byte > byte a0 i64,inpos df_inpos u64 [71:96] :the next whole byte of the input, asking the hook for more when the segment has run out, the bit buffer left alone
 byte :-1 when there is none
call deflate_run > written a0 u64,code a1 u64,clobber a2-a3 [97:142] :the blocks, from where the input cursor stands to the one marked final
 code :a DF_* code
call local df_fail code u64 > error df_error u64 [144:150]
 code :in t0; the first failure is the one kept
call local df_refill > more a0 bool [152:159] :asks the hook for another segment
 more :1 with a new segment in place, 0 with none or no hook
call local df_bits count u64 > value a0 u64,bitbuf df_bitbuf u64,bitcnt df_bitcnt u64,inpos df_inpos u64 [161:224] :takes that many bits, at most 16, lowest first
 value :0 with DF_ERR_INPUT kept once the stream has run out
call local df_put byte u8 > outpos df_outpos u64,tick df_tick u64 [226:259] :writes the byte to the output, looking at the sound stream every DF_TICK_BYTES of it
 outpos :on by one, DF_ERR_OUTPUT kept instead when the output is full
call local df_stored > outpos df_outpos u64,clobber a0 [261:310] :a block held as it is, copied to the output
call local df_fixed > outpos df_outpos u64,clobber a0-a3 [312:362] :builds the tables every fixed block uses, then decodes the block
call local df_dynamic > outpos df_outpos u64,clobber a0-a3 [364:522] :reads the tables this block carries, themselves Huffman coded, then decodes the block
call local df_construct counts addr,symbols addr,lengths addr,count u64 > counts 0(counts) u16,symbols 0(symbols) u16,offsets df_offs u16 [524:607] :builds a canonical Huffman code from the lengths of that many symbols, DF_ERR_CODES kept for one that is over-subscribed
 counts :DF_MAX_BITS + 1 halfwords, the codes of each length
 symbols :halfwords, the symbols in code order
call local df_decode counts addr,symbols addr > symbol a0 u16 [609:667] :decodes one symbol, DF_ERR_SYMBOL kept and 0 for a code past the longest
call local df_codes > outpos df_outpos u64,clobber a0-a1 [669:759] :the block's symbols until the one that ends it, literals and copies written to the output
rodata local df_clorder 19 u8 [763:765] :the order a dynamic block writes its code-length lengths in
rodata local df_lenbase 29 u16 [766:768] :each length symbol's base
rodata local df_lenextra 29 u8 [769:772] :each length symbol's extra bits
rodata local df_distbase 30 u16 [773:776] :each distance symbol's base
rodata local df_distextra 30 u8 [777:779] :each distance symbol's extra bits
bss local df_in addr [783:784] :the segment being read
bss local df_inlen u64 [785:786] :its length
bss local df_inpos u64 [787:788] :the input cursor within it
bss local df_out addr [789:790] :the output, the program's buffer
bss local df_outcap u64 [791:792] :the bytes it holds
bss local df_outpos u64 [793:794] :the bytes written
bss local df_bitbuf u64 [795:796] :bits read and not yet taken
bss local df_bitcnt u64 [797:798] :how many
bss local df_error u64 [799:800] :the first failure, DF_OK until one
bss local df_last u64 [801:802] :the current block's final bit
bss local df_scratch u64 [803:804] :a count held across a call
bss local df_scratch2 u64 [805:806] :a repeated length held across a call
bss local df_more addr [807:808] :the hook, 0 for none
bss local df_want u64 [809:810] :the bits df_bits wants across a refill
bss local df_tick u64 [811:813] :output bytes until the next look at the sound stream
bss local df_lencnt 16 u16 [814:815] :the literal and length code's counts
bss local df_distcnt 16 u16 [816:817] :the distance code's counts
bss local df_codecnt 16 u16 [818:819] :the code-length code's counts
bss local df_offs 17 u16 [820:821] :where each length's symbols start
bss local df_lensym 288 u16 [822:823] :the literal and length code's symbols
bss local df_distsym 30 u16 [824:825] :the distance code's symbols
bss local df_codesym 19 u16 [826:827] :the code-length code's symbols
bss local df_lengths 318 u8 [828:829] :the lengths a table is built from
