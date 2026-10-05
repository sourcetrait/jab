call page_build > tables page_root u64 [45:120] :hart 0, once, in kmain: the static tables written, everything at its physical address
 tables :the root table and page_l1_devices and page_l1_ram it points to, set once and never changed
call page_activate [121:128] :a hart's satp set to the tables, Sv39, and its TLB fenced; hart 0's in kmain, a secondary's in hart_park before its mret
