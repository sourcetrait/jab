# ram.S

The machine's RAM as the device tree describes it. The reader is leaf
code over memory, like dtb.S: a program can assemble it in with
RAM_READER set before the include, which leaves the kernel's part and
jab.inc out. The kernel's part reads the RAM once, in machine mode on
hart 0 before paging, keeps the banks and their total, proves the ranges
the kernel and the program use backed, and builds the free view: the
banks less the protected prefix, the kernel's and the framebuffer's
leaves up to the program's window, and the window, which run together
from RAM's base to JAB_STACK_TOP. Nothing past the window is mapped or
handed to a program.

## .set RAM_BANKS

`u64`: the banks the kernel's table holds, and its free ranges.

## .set RAM_BANK_BYTES

`u64`: a bank's bytes in a table, its base then its end.

## .set RAM_BANK_BASE

`u64`: a bank's base, its first byte.

## .set RAM_BANK_END

`u64`: a bank's end, the byte past its last.

## .set RAM_REACH

`u64`: Sv39's identity reach, 256 GiB, the lower canonical half; no bank
may end past it.

## .set RAM_OK

`u64`: the banks read and held.

## .set RAM_NO_BANK

`u64`: no memory node gave a bank.

## .set RAM_CELLS

`u64`: the root's #address-cells or #size-cells absent or other than 1
or 2.

## .set RAM_REG

`u64`: a memory node with no reg, an empty one, or one not a whole
number of entries.

## .set RAM_EMPTY

`u64`: a bank of size 0.

## .set RAM_OVERFLOW

`u64`: a bank whose end passes 2^64.

## .set RAM_OVERLAP

`u64`: a bank beginning before the one below it ends.

## .set RAM_LOW

`u64`: a bank below RAM's base, 0x80000000, where the device space lies.

## .set RAM_HIGH

`u64`: a bank ending past RAM_REACH.

## .set RAM_TOO_MANY

`u64`: more banks than the table holds.

## ram_banks

Each entry is placed by insertion, so the table is sorted by base as it
fills; overlap is held once every node is read. The order of the faults
is the order met, a node at a time.

## ram_topology

The required ranges are ram_required's. Both refusals end the boot as
the boot's other refusals do, the line under uart_lock_fatal and the run
ended through qemu_exit, the hart records not yet up.

## ram_path_root

`2 u8`: the root's path.

## ram_word_address_cells
## ram_word_size_cells
## ram_word_device_type
## ram_word_memory
## ram_word_reg

`u8`: the names and the value the reader looks for.

## msg_ram_refused

`24 u8`: the line for a code, the code following.

## msg_ram_missing

`22 u8`: the line for a range not backed, its name, base, and end
following.

## msg_ram_colon

`3 u8`: between the range's name and its bounds.

## ram_name_kernel
## ram_name_display
## ram_name_window

`u8`: the required ranges' names.

## msg_ram_free

`15 u8`: the debug line for a free range, its bounds following.

## msg_ram_free_none

`20 u8`: the debug line for no free range.

## ram_required

`10 u64`: the ranges the kernel and the program use, each its name, its
base, and its end, then 0: the kernel from RAM's base to _kernel_end, the
framebuffer, and the program's window to JAB_STACK_TOP.

## ram_installed

`u64`: the banks' total, the machine's installed RAM.

## ram_bank_count

`u64`: the banks read.

## ram_bank_table

`32 u64`: the banks, sorted by base.

## ram_free_count

`u64`: the free ranges.

## ram_free_table

`32 u64`: the free ranges.
