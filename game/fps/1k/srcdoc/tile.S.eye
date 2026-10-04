call local tiles_reset > cursor tile_cursor addr,records tilemaps LUMAP_COUNT*11 u64 [3:14] :every surface's tiles forgotten and the arena emptied, at load and when an atlas does not fit
call local tiles_bind > records tilemaps LUMAP_COUNT*11 u64,budget tile_budget u64,mode POLY_MODE(poly) u64,fields POLY_TILES(poly) 8 u64,built STAT_TILES_BUILT(stats) u64,ticks STAT_TILE_TICKS(stats) u64,clobber a0-a7 [16:151] :the lit, mapped polygon in hand bound to its tiles, the atlases reserved on first sight, the surface's next cells built at the level in hand under the frame's budget, the padding columns stepped over, and the mode's tiled flag and the read's fields set once a level is whole; a surface whose atlas is too large stays on the lit loop; on a debug build no level past the console's cap is built
 fields :POLY_TILES to POLY_TILE_ROWS
call local tiles_alloc record addr,map addr > fields 0(record) 11 u64,cursor tile_cursor addr,resets STAT_TILE_RESETS(stats) u64,peak tile_peak u64,clobber a2-a6 [153:243] :a surface's atlases, one a level, reserved from the arena, the columns padded to a power of two, the rows as they are, each atlas a quarter of the one before; a level 0 atlas past TILE_ATLAS_MAX marks the record never; atlases the arena cannot hold reset it first
 fields :the record's TILE_* fields
call local tile_build record addr,map addr,index u64 > tile tile_arena u32,clobber a0-a7 [244:417] :one cell of the surface in hand built into its level 0 tile, the brightness at each texel's centre bilinear across the cell from its four nodes, the far nodes the greatest where the cell is the last, the texture's texel there scaled by it as the lit loop scales one
 index :the cell's tile index, its column in the low TILE_COLS_SHIFT bits
 tile :the cell's level 0 tile in the record's atlas
call local tile_shrink record addr,map addr,index u64,level u64 > tile tile_arena u32,clobber a0-a7 [419:490] :one cell of the surface in hand built into its tile at a coarser level from the level below, each texel by texel_shrink under the material's alpha scale for the level, so the level passes the masked test about where the texture does
 level :1 or more
 tile :the cell's tile in the level's atlas
call local alphas_measure > scales material_alpha MAX_MATERIALS*MIP_LEVELS u32,clobber a0-a5,a7 [492:712] :every material's alpha coverage at every level of its chain, the map's and the engine's images', and the scale that holds it, a chain with no level past 0 keeping one; a line a material under full coverage on a debug build, every level on it
call local alpha_hist_clear > counts alpha_hist 256 u64 [714:722] :the counts of each alpha value emptied
call local alpha_hist_pass > count a0 u64 [724:735] :the count of alphas at or above the pass in the histogram
call local alpha_shrink width u32,height u32,plane addr,source s10 addr,stride s11 u64 > alphas 0(plane) u8,counts alpha_hist 256 u64,clobber a3-a5 [737:785] :a level's alphas from the level before, each the mean of the two by two under it, into the plane, and the histogram of the plane's values
 width :the level's width, with height its height
 source :the level before's first alpha
 stride :the bytes between its alphas
call local alpha_search texels u64,whole s8 u64,target s9 u64 > threshold a0 u64,count a1 u64,clobber a2-a5 [787:830] :the threshold whose share of the level's alphas at or above it lies nearest the texture's target share, over the histogram, from 256, which passes nothing, down to 1; the least error in share wins, a tie the lower share, equal shares the threshold nearest the pass
 texels :the level's texels
 whole :the texture's texels
 target :the texture's count at or above the pass
 count :the count at or above the threshold
call local lumels_bright > lumels lumel_arena LUMEL_ARENA_BYTES u8 [832:858] :every lumel of every map set to the full brightness, one on each lane in a lumel's 256ths, for a debug build's console
