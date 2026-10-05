# aia.inc

The AIA as the kernel drives it: the APLIC domain's registers, the IMSIC
interrupt file's registers reached through siselect and sireg, the
kernel's identities and bounds, and aia_topology's refusal codes. QEMU's
hw/intc/riscv_aplic.c and riscv_imsic.c, and the AIA specification's
chapters on them, are where each comes from. Guarded against a second
inclusion.

## .set AIA_INC

`u32`: set once the file is included, the guard.

## .set APLIC_DOMAINCFG

`u32`: a domain's configuration, IE in bit 8; DM reads 1 in MSI mode and
takes no write.

## .set APLIC_SOURCECFG

`u32`: sourcecfg[i] sits at this plus 4i, i from 1.

## .set APLIC_MMSICFGADDR
## .set APLIC_MMSICFGADDRH
## .set APLIC_SMSICFGADDR
## .set APLIC_SMSICFGADDRH

`u32`: the machine domain's message address configuration, the machine
files' base page and its high word (L, HHXS, LHXS, HHXW, LHXW, the base's
high bits), then the supervisor files' base page and its high word (LHXS
and the base's high bits). The AIA names them mmsiaddrcfg, mmsiaddrcfgh,
smsiaddrcfg, and smsiaddrcfgh.

## .set APLIC_SETIPNUM

`u32`: a source pended by number, while its input is high for a level
source.

## .set APLIC_IN_CLRIP

`u32`: in_clrip[k], read as 32 sources' rectified inputs.

## .set APLIC_SETIE

`u32`: setie[k], read as 32 sources' enables, source 32k plus the bit;
the debug build reads a disk's enable back from it (block_report).

## .set APLIC_SETIENUM
## .set APLIC_CLRIENUM

`u32`: a source enabled, or masked, by number.

## .set APLIC_TARGET

`u32`: target[i] sits at this plus 4i: in MSI mode the hart index from bit
18, the guest index from 12, the identity in 10 to 0.

## .set APLIC_DOMAINCFG_IE

`u32`: the domain's interrupts enabled.

## .set APLIC_SOURCECFG_D

`u32`: a source delegated, the child domain's index below it.

## .set APLIC_SM_LEVEL_HIGH

`u32`: a source's mode, asserted while its input is high.

## .set APLIC_TARGET_HART_SHIFT

`u64`: where a target's hart index sits.

## .set APLIC_MSICFGADDRH_LHXW_SHIFT
## .set APLIC_MSICFGADDRH_LHXS_SHIFT

`u64`: where the hart index's width and a file's spacing sit in a message
address's high word.

## .set APLIC_SOURCES_MAX

`u64`: the most sources a domain has, sourcecfg[1] to sourcecfg[1023]
(the AIA's APLIC register map); a riscv,num-sources past it would run
aia_root's delegation loop into the registers after them, mmsiaddrcfg
at the 1776th.

## .set IMSIC_EIDELIVERY
## .set IMSIC_EITHRESHOLD
## .set IMSIC_EIE0

`u64`: an interrupt file's registers by siselect: delivery on or off, the
threshold, and the enables of identities 0 to 63, on RV64 the even
registers alone.

## .set IMSIC_GUEST_BITS_MAX

`u64`: the most guest-index bits a target can carry.

## .set IMSIC_CAUSE_S
## .set IMSIC_CAUSE_M

`u64`: the interrupt an IMSIC node's interrupts-extended names, the
supervisor's external or the machine's.

## .set AIA_WAKE

`u64`: the identity that wakes a hart, sent from another.

## .set AIA_IDENTITIES

`u64`: the identities eie0 holds, 0 to 63.

## .set AIA_SOURCE_MAX

`u64`: the last source an identity fits, its identity one more.

## .set AIA_SOURCE_LAST_USED

`u64`: the last source the kernel uses, the PCI lines' last.

## .set AIA_DRAIN_CLAIMS

`u64`: the identities one drain pass claims at most.

## .set AIA_STALL_TICKS

`u64`: how long a source stays asserted with no progress before it is
masked, the sound's three seconds.

## .set AIA_NO_IMSIC_S
## .set AIA_NO_IMSIC_M
## .set AIA_NO_DOMAINS
## .set AIA_NO_TIMER
## .set AIA_NOT_QEMU
## .set AIA_TOO_FEW
## .set AIA_LAYOUT
## .set AIA_NO_FILE
## .set AIA_TOO_MANY

`u64`: aia_topology's refusal codes: no supervisor IMSIC, no machine
IMSIC, no pair of APLIC domains delivering by MSI to their levels' IMSICs,
no ACLINT timer, an address other than QEMU's, too few identities or
sources, a layout the kernel does not take, hart 0 with no file, and a
domain's sources past APLIC_SOURCES_MAX.
