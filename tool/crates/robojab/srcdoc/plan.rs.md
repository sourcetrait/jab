# plan.rs

## struct Plan

`qemu_binary` is the QEMU the SDK chose for the machine, `extern/qemu` beside
the program or in the workspace, else the bare name for PATH, and the SDK
checked the CPU model against that binary; a plan without the field is
refused rather than run on whatever QEMU this process's PATH names.

### fn load

## fn unhex

## fn hex
