set TAR_NAME u8 [5] :a ustar header's 100-byte name
set TAR_NAME_BYTES u64 [6]
set TAR_SIZE u8 [7] :the size as octal text
set TAR_SIZE_BYTES u64 [8]
set TAR_CHECKSUM u8 [9] :the checksum as octal text
set TAR_CHECKSUM_BYTES u64 [10]
set TAR_TYPE u8 [11] :the type byte
set TAR_MAGIC u8 [12] :the magic `ustar`
set TAR_MAGIC_BYTES u64 [13]
set TAR_PREFIX u8 [14] :the prefix that goes before the name
set TAR_PREFIX_BYTES u64 [15]
ecall sys_tar_list buffer address,archive address,length u64,offset u64,capacity u64 > count a0 u64,next a1 u64 [20:67] :writes a JAB_TAR_* record per entry of the archive the program holds into the buffer
 archive :ends the run unless the whole of it lies inside the program's window, as does each record written
 offset :the header this page starts at, 0 for the first
 capacity :the records the buffer holds
 count :the records written
 next :the offset to start the next page at, 0 once the archive has ended
ecall sys_tar_find buffer address,archive address,length u64,path address > status a0 u64,offset a1 u64 [68:111] :looks for the path in the archive and writes its record into the one-record buffer
 path :NUL-terminated, read no further than the window's end
 status :0 found, 1 no such name
 offset :the entry's own header offset, 0 when not found
call local tar_entry archive address,length u64,offset u64,record address > next a0 u64,entry 0(record),clobber a1-a2 [113:209] :reads the header at the offset into a JAB_TAR_* record
 record :where the record goes, 0 for none
 next :the offset of the header after it, 0 when the archive ends here
call local tar_copy_field destination address,field address,size u64 > copied a0 u64 [211:224] :copies a field that ends at a terminator or at its end
call local tar_octal text address,size u64 > value a0 u64 [226:244] :reads octal text that ends at a space or a terminator
call local tar_checksum header address > valid a0 bool,clobber a1 [246:278]
 valid :1 when the stored checksum answers for the header, the field itself counted as spaces
call local tar_name_equal name address,path address,end address > equal a0 bool [280:304]
 name :in a record
 path :NUL-terminated in the program's window, matching nothing when it reaches the end with no terminator
 equal :1 when they are the same, a trailing separator on the record's name ignored
bss local tar_scratch [308:309] :the record sys_tar_find reads each entry into
