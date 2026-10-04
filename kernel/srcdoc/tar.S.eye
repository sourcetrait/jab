ecall sys_tar_list buffer addr,archive addr,length u64,offset u64,capacity u64 > count a0 u64,next a1 u64 [20:67] :writes a JAB_TAR_* record per entry of the archive the program holds into the buffer
 archive :ends the run unless the whole of it lies inside the program's window, as does each record written
 offset :the header this page starts at, 0 for the first
 capacity :the records the buffer holds
 count :the records written
 next :the offset to start the next page at, 0 once the archive has ended
ecall sys_tar_find buffer addr,archive addr,length u64,path addr > status a0 u64,offset a1 u64 [68:111] :looks for the path in the archive and writes its record into the one-record buffer
 path :NUL-terminated, read no further than the window's end
 status :0 found, 1 no such name
 offset :the entry's own header offset, 0 when not found
call local tar_entry archive addr,length u64,offset u64,record addr > next a0 u64,entry 0(record),clobber a1-a2 [113:209] :reads the header at the offset into a JAB_TAR_* record
 record :where the record goes, 0 for none
 next :the offset of the header after it, 0 when the archive ends here
call local tar_copy_field destination addr,field addr,size u64 > copied a0 u64 [211:224] :copies a field that ends at a terminator or at its end
call local tar_octal text addr,size u64 > value a0 u64 [226:244] :reads octal text that ends at a space or a terminator
call local tar_checksum header addr > valid a0 bool,clobber a1 [246:278]
 valid :1 when the stored checksum answers for the header, the field itself counted as spaces
call local tar_name_equal name addr,path addr,end addr > equal a0 bool [280:304]
 name :in a record
 path :NUL-terminated in the program's window, matching nothing when it reaches the end with no terminator
 equal :1 when they are the same, a trailing separator on the record's name ignored
