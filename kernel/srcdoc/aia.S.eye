call aia_topology tree addr > files aia_file u8,sources aia_sources u64,width aia_lhxw u64,guests aia_lhxs u64,clobber a0-a7 [11:287] :machine mode, hart 0, after harts_topology: the AIA's nodes under /soc found and held to QEMU's map, each hart's supervisor file found by its controller; a platform the kernel cannot take ends the run with its line on the UART and status 1
 files :JAB_HARTS_MAX entries by hart id, 0xff for a hart with none
call local aia_cell tree addr,node u32,name addr > value a0 u64,clobber a1,a3-a5 [289:303] :a property of exactly one cell, or -1
call local aia_reg tree addr,node u32,cells u64 > address a0 u64,clobber a1-a5 [305:329] :the first address in a node's reg, in one cell or two, or -1
call local aia_parent tree addr,imsic u32,aplic u32 > delivers a0 bool,clobber a1-a5 [331:357] :1 when the APLIC domain's msi-parent is the IMSIC's phandle
call aia_root [358:392] :machine mode: the root domain's message addresses for both levels, every source delegated to the supervisor domain, the domain enabled
call aia_supervisor [393:397] :supervisor mode, hart 0: the supervisor domain enabled, then its own file through aia_file_open
call aia_file_open [398:412] :the hart's own supervisor file delivering, its threshold open, the wake's identity alone enabled; a parked hart's in machine mode, hart 0's in supervisor mode
call aia_file_page hart u64 > page a0 addr [413:430] :the page of a hart's supervisor interrupt file, where a message to it is written
 page :0 for a hart with no file
call irq_mmio_source base addr > source a0 u64 [431:439] :a virtio-mmio transport's interrupt source
call virtio_irq_enable base addr,progress addr,fault addr [440:474] :irq_enable for a transport's source; under DEBUG a jab.hold knob naming its device id holds the line
call irq_enable source u64,progress addr,fault addr [475:511] :the source level-high, aimed at hart 0's file with identity source plus 1, and enabled at the domain and in the file
 progress :a routine giving its devices' progress, a0 the source, t registers alone
 fault :a routine putting its driver in its error state, the same contract
call irq_drain > stuck a0 bool [512:571] :one bounded pass, at most AIA_DRAIN_CLAIMS identities claimed through stopei and then serviced, the sound's first; keeps every a and s register
 stuck :1 when a source was masked this pass
call local irq_serve source u64 > stuck a0 bool [573:679] :a source's devices serviced, then, while its input stays high, a window kept: progress starts it again, AIA_STALL_TICKS without masks the source, and otherwise it is pended again
call irq_report [680:711] :at a safe point, a line on the UART for each source masked since the last, each under the line lock
