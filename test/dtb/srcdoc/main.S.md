# main.S

dtb: the kernel's device tree reader, kernel/src/dtb.S assembled in through
the manifest's includes, run in user mode over trees the test laid on a
romfs disk of serial dtb. Every tree is checked, `check <name> <code>`;
then QEMU's own tree is read through every lookup: /cpus's #address-cells,
`cells <n>`; the cpus among its children, `cpus <n>`; its
timebase-frequency, `timebase <hz>`; a cpu's reg by a path with a unit
address and by one without, `reg <path> <reg>`; cpu@1's interrupt
controller's phandle and the node dtb_phandle finds for it, `phandle <n>
same|other <name>`; /chosen's bootargs, `bootargs <text>`; and paths found
or not, `found <path>` or `absent <path>`; and the supervisor IMSIC's
compatible list through dtb_listed, `listed <string> <0|1>`, for both of
its entries, a prefix of one, and a tail of one.

## .set FILE_BYTES

`u64`: the largest tree file read, tree's size.

## files

`14 addr`: the trees checked, in order, ended by 0.

## absent

`6 addr`: the paths looked up for found or absent, ended by 0.

## listed

`5 addr`: the strings looked for in the IMSIC's compatible, ended by 0.

## path_good
## path_magic
## path_version
## path_lastcomp
## path_size
## path_block
## path_cut
## path_name
## path_prop
## path_strings
## path_token
## path_deep16
## path_deep17

`u8`: the trees' files on the disk, QEMU's own first, then the test's
broken and nested ones.

## path_root
## path_cpus
## path_cpus_trailing
## path_cpu
## path_cpu2
## path_cpu9
## path_intc1
## path_chosen
## path_nope

`u8`: the paths looked up in QEMU's tree.

## path_imsic

`u8`: QEMU's supervisor IMSIC node.

## serial_dtb

`4 u8`: the disk's serial.

## word_check
## word_cells
## word_cpus
## word_timebase_line
## word_reg_line
## word_none
## word_phandle_line
## word_same
## word_other
## word_bootargs_line
## word_found
## word_absent
## word_missing

`u8`: the lines' words.

## word_address_cells
## word_device_type
## word_cpu
## word_timebase
## word_reg
## word_phandle
## word_bootargs
## word_compatible

`u8`: the property names and the value the lookups read by.

## word_listed

`u8`: the listed lines' first word.

## word_imsics
## word_qemu_imsics
## word_imsic
## word_imsics_tail

`u8`: the strings looked for: the list's two entries, a prefix of one, and
a tail of one.

## msg_no_disk
## msg_good_refused
## msg_lookup

`u8`: the lines of a run that cannot go on.

## tree

`FILE_BYTES u8`: the tree read, on an 8-byte boundary as dtb_check asks.

## rec

`144 u8`: the romfs record a find wrote.

## line

`512 u8`: the line being built.

## lineptr

`addr`: the cursor in line.

## digits

`32 u8`: line_dec's digits, built backward.
