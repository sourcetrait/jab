call dtb_check tree addr,bytes u64 > code a0 u32,clobber a2-a7 [6:160] :0 when the tree is whole and well formed within bytes, else a DTB_* code
 bytes :what the caller vouches for at the tree; the total size fits within it and within DTB_MAX
call dtb_path tree addr,path addr > node a0 u32,clobber a1-a4 [161:245] :the node at a path from the root, or 0; a component with no unit address matches a name up to its @
 node :its offset in the tree, at its BEGIN_NODE token
call dtb_child tree addr,node u32,after u32 > child a0 u32 [246:318] :the node's child after the one at `after`, the first for 0, or 0 past the last
call dtb_prop tree addr,node u32,name addr > value a0 addr,bytes a1 u32,clobber a3-a5 [319:369] :the node's own property of that name, or a value of 0
call dtb_phandle tree addr,phandle u32 > node a0 u32,clobber a2-a5 [370:428] :the node whose phandle property holds that value, or 0
call dtb_name tree addr,node u32 > name a0 addr [429:434] :the node's name, NUL-terminated
call dtb_named tree addr,node u32,name addr > same a0 bool,clobber a2 [435:453] :1 when the node's name is that string whole
call dtb_equals value addr,bytes u32,string addr > same a0 bool,clobber a2 [454:472] :1 when a string property's value, its NUL counted in bytes, is that string
