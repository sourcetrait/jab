# AGENTS.md
>REIN HUMAN

Jab is a specialized RISC-V (RVA23) system.

It defines a set of conservative [system specifications](./doc/SPEC.md) that
roughly follow current trends in affordable single-board computers.

Everything meant to be distributed and ran in Jab is in 100% assembly.

The Jab Computer (system) is built on-top of QEMU and uses it regardless of
whether the host natively supports RISC-V architecture or not. This allows for
simplicity in hardware support and isolation from the host.

Development tools are written in Rust. Build tools are written in Nushell.

Agent-maintained documentation can be found in [UNDERSTOOD.md](./doc/UNDERSTOOD.md).

## Assembly

Source is maintained in 'src' directories.

Source documentation is maintained in 'srcdoc' directories, mirroring its
sibling 'src' directory.

Source contains almost no documentation-style comments. Only, side-comments
when absolutely necessary.

The '.S.eye' files in 'srcdoc' provide a condensed and standardized signature
for each item documented. They are intended agents use, to initially and
conservatively read-in to an assembly codebase.

The 'eye-asm' tool can be used to view all signatures within a given src
directory and, optionally, specific relative file or directoryy.
(Eg, `eye-asm ./kernel/src`, `eye-asm ./kerne/src timer.S`)

## Environment

Agent operation occurs within a Fedora toolbox podman container. Final testing
with full access to devices is performed by the human against Linux and Windows
metal. Devices such as sound, gpu, etc. are not available within this container.

Each session should begin in a read-only code-review mode. Alteration of files,
running tests, accessing build tools, etc. should be not be performed while
in review until the user specifies anything different.
