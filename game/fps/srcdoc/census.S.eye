call local census_init > surfaces census_surfaces LUMAP_COUNT*CS_SIZE u8,used census_used CENSUS_SIZES u64,maps census_maps u64,slots CTX_CENSUS_NEXT(contexts) 4 u64,clobber a0-a1,a7 [51:228] :on a CENSUS build, every lumel map's directory grid at each level of its material's chain and each tile side, the contexts' census slots, and the directory's line on the UART; a directory past CENSUS_ENTRIES exits 14 with its line
call local census_context index u64 > context a0 addr [230:240] :a raster context by its census index, 0 hart 0's, 1 on the workers'
call local census_frame frame u64 > totals census_totals CENSUS_SIZES*CT_SIZE u8,window census_ring CENSUS_SIZES*CENSUS_WINDOW u64,entries census_entries CENSUS_ENTRIES u64,clobber a0-a7 [242:326] :the frame's census: every context's block records taken into the directory at each tile side, the slots emptied for the next frame, the lines on the UART
call local census_block record s3 addr,context s2 u64,stamp s0 u64,slot s1 u64 > clobber s5-s11,a0-a7 [328:375] :one block record at every tile side; a record no lumel map or level of the directory holds counted as dropped
call local census_tiles record s3 addr,size s11 u64 > totals census_totals CT_SIZE u8,clobber a0-a7 [377:484] :the block's tiles at one side: one tile inside the grid eligible, a pixel past the depth test its request; a block across tiles straddling, each tile its walk meets sampled
call local census_request entry u64,totals addr,tx u64,ty u64 > entry census_entries 1 u64,clobber a0-a7 [486:547] :an eligible block's request for its tile: its first demand of the frame, its class's, its context's, and its sampling
 entry :the tile's index in census_entries
call local census_first_demand entry addr,totals addr,tx u64,ty u64 > entry 0(entry) u64,clobber a0,a2-a7 [549:631] :a tile's first demand of the frame: into the window, its stamp, its contexts and classes cleared, its uniformity once a tile, its surface's first demand
call local census_uniform tx u64,ty u64 > uniform a0 bool,clobber a4-a7 [633:697] :1 when every lumel node over the tile's cells, the far node and the map's clamp included, holds one value
 tx :in a2, ty in a3, the record in s9, the level in s6, the size in s11
call local census_context_surface totals addr [699:732] :the context's distinct request of the frame, counted on its surface, the surface listed at its first
 totals :in a1, the context in s2, the surface in s5, the size in s11
call local census_working frame u64,size u64,frames u64 > tiles a0 u64 [734:755] :the distinct tiles demanded over that many frames to this one
call local census_print frame u64 > clobber a0-a7 [757:953] :the frame's census lines on the UART: the blocks, then for each tile side its totals and each context's requests
call local census_line_end cursor addr > clobber a0,a7 [955:960] :ends the census line at the cursor and prints it
