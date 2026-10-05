# aia.S

The interrupt platform: the AIA, its APLIC in MSI mode delivering each
source as a message to a hart's IMSIC interrupt file. Machine mode, hart 0,
in the bootstrap: the platform's nodes read from the device tree and held
to QEMU's map, which the page tables fix at assembly, and the root APLIC
domain set up, every source delegated to the supervisor domain. Supervisor
mode: the supervisor domain enabled, hart 0's file delivering, and each
device's source let through as its driver comes up, level-high, aimed at
hart 0's file with an identity of its own. Every interrupt the kernel takes
goes through one service path, irq_drain, from the vector, the waits, and
the sound's checkpoint (sound.S), and a source stuck asserted with no
progress is masked and its driver put in its error state.

## aia_topology

Under /soc, each child by its compatible list (dtb_listed): an IMSIC is the
machine's or the supervisor's by the interrupt its interrupts-extended
names first, 11 or 9; the machine APLIC domain is the one with
riscv,children, and the supervisor domain is its child by phandle; an
ACLINT timer must be there. Each domain must deliver by MSI to its own
level's IMSIC (msi-parent), and the four addresses must be QEMU's
(qemu_virt.inc), since the page tables map the supervisor pages at
assembly. The supervisor IMSIC must take identities to 63 and the domain
the sources the kernel uses, to the PCI lines' last; a layout of groups,
harts over more than one socket, is refused, and guest files beside each
hart's are taken as the files' spacing. Each hart's file is the place of
its controller's phandle (harts.S's harts_intc) in the supervisor IMSIC's
interrupts-extended, a pair a file, and the hart index's width is the bits
the files' count needs. The supervisor domain's sources past
APLIC_SOURCES_MAX are refused (AIA_TOO_MANY), since aia_root writes a
sourcecfg for each. A refusal prints `jab: interrupt platform refused:
code N` on the UART, N an AIA_* code of aia.inc, and ends the run with
status 1, since hart 0 alone repairs none of it.

## aia_root

A message's address is the base page plus the hart index shifted by LHXS
pages; the supervisor domain's messages take their base and LHXS from the
smsicfgaddr pair and the hart index's width from the machine's high word
(QEMU's riscv_aplic.c, riscv_aplic_msi_send), so both pairs are written
here, under -bios none their only writer. sourcecfg[i] sits at 4i.

## aia_supervisor

The supervisor domain's sources stay inactive until a driver enables one.
Hart 0's own file then opens through aia_file_open, which it falls into.

## aia_file_open

The hart's own supervisor file, through siselect and sireg, which machine
mode reaches too, so a parked hart opens its own before it sleeps (boot.S's
hart_park): eidelivery 1 lets the file signal SEIP; eithreshold 0 admits
every enabled identity; eie0 holds identities 0 to 63, the wake's
(AIA_WAKE) alone enabled, each device's joining on hart 0 as its driver
comes up (irq_enable).

## aia_file_page

A message to a hart is a 32-bit write of the identity to its file's page:
the supervisor files' base plus the hart's file index shifted by 12 and
LHXS bits.

## irq_hold

The stuck-source fixtures' injection: a held line is serviced by none of
its devices (irq_serve), so a device's completion leaves its source
asserted with no progress and its window runs out. virtio_irq_enable holds
an mmio transport by its device id, block_probe a disk's PCI line by the
block id, so `jab.hold=2` holds every disk's line.

## irq_enable

A source's sourcecfg first, since its target is writable only while the
source is active. Its identity is the source plus 1, the wake's 1 kept
apart, so the sources the kernel uses, 1 to 8 and 32 to 35, fit eie0; a
source past AIA_SOURCE_MAX is passed over, and so is one already in
irq_faulted, which stays masked for the run: a driver coming up on a failed
line, a disk probed after its line failed, would otherwise let a dead
source assert again with no fault routine behind it.

## irq_drain

A claim is `csrrw rd, stopei, x0`, read and cleared in one instruction,
since a separate read and write can clear an identity that became pending
between them and lose it. The fence after the claims orders them, CSR
device input, before any memory read that depends on them. The sound's
identity is serviced first, its stream refilled on the device's clock
(sound.S), then the rest in identity order; the wake's is dropped, its
waking done. One pass and no more: the caller checks its own condition
between passes, and a wfi that returns with nothing to claim was a spurious
wake, since an interrupt file's changes reach mip eventually, not
necessarily at once.

## irq_serve

A PCI line's devices each read their ISR (pci.S), which drops the level; an
mmio transport's interrupt status is acknowledged, and the sound's stream
refilled. Then the source's rectified input: a level source still high once
its message has gone sends no other until its input falls and rises, so it
is pended again through setipnum. A source that stays high while none of
its devices makes progress, its driver's measure (the used indexes of its
queues) unchanged, for AIA_STALL_TICKS, the sound's own three seconds, is
masked at the domain (clrienum), and its fault routine puts its driver in
its error state and resets its devices (virtio.S's virtio_reset, block.S's
block_fault) before the failure is published in irq_faulted and
irq_unreported, with `fence io, rw` after the reset's readback: a wait sees
the failure only once the device has stopped using the buffers it held. The
line naming it waits for a safe point (irq_report). Under DEBUG a line the
jab.hold knob holds (irq_hold) is serviced by none of its devices: a PCI
line's ISRs go unread and an mmio transport's status unacknowledged, and a
held live sound's returned periods are taken back (sound_drain) with none
offered again, so the source's window fires before the stream's own stall
check. The sound's transport is still acknowledged before the stream is
live and while any period is with the device (sound_in_flight), so its
hold begins at the stream's last return: a live stream keeps the external
enable on in user mode, where a line held from the open would storm the
program to a standstill and fail the source outside every wait.

## irq_report

The waits and the vector call it after a drain, where printing interrupts
nothing: the line is `jab: interrupt source N stalled` on the UART, under
the line lock (uart.S).

## path_soc

`5 u8`: the node of the platform's devices.

## word_address_cells
## word_compatible
## word_imsics
## word_aplic
## word_mtimer
## word_interrupts_extended
## word_children
## word_msi_parent
## word_phandle
## word_reg
## word_num_ids
## word_num_sources
## word_group_bits
## word_guest_bits

`u8`: the properties and values aia_topology reads by.

## msg_platform_refused

`39 u8`: the refusal line's head, its code after it.

## msg_source
## msg_stalled

`u8`: a stuck source's line, its number between them.

## knob_hold

`10 u8`: under DEBUG, the knob that holds a device's line, its value a
virtio device id.

## aia_file

`JAB_HARTS_MAX u8`: each hart's supervisor file index by hart id, 0xff for
a hart with none.

## aia_sources

`u64`: the supervisor domain's riscv,num-sources.

## aia_lhxw

`u64`: the hart index's width in a message's address.

## aia_lhxs

`u64`: a file's spacing in pages past one, the supervisor IMSIC's guest
bits.

## irq_progress_fns
## irq_fault_fns

`AIA_IDENTITIES addr`: each source's progress and fault routines, by
source.

## irq_last

`AIA_IDENTITIES u64`: each source's progress when its window opened.

## irq_since

`AIA_IDENTITIES u64`: when each source's window opened, 0 for none.

## irq_faulted

`u64`: bit n set for source n masked as stuck.

## irq_unreported

`u64`: the masked sources whose line is still to print.

## irq_held

`u64`: under DEBUG, the sources a knob holds.
