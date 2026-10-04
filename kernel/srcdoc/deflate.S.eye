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
