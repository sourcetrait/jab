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

Agent-maintained documentation can be found in [UNDERSTOOD.md](./doc/understood/UNDERSTOOD.md).

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
directory and, optionally, specific relative file or directory.
(Eg, `eye-asm ./kernel/src`, `eye-asm ./kerne/src timer.S`)

## Components
- Jab Spec
- Jab Kernel
- Jab SDK
- Jab Launch
- Jab Metal
- Jab Dash
- JabIO
- jab (term)

## Spec
System specifications that lock-in minimum-maximum hardware requirements.

Nomenclature starts with the display type (1K (1080p), 2K (QHD), 4K, etc.)
followed by an optional generation number (1K1, 1K2, etc.).

Omission of the generation number implies first generation.

### Launch
Distribution for desktop systems (Linux, MacOS, Windows) including its
self-named launcher app.

### Metal
Distribution for dedicated hardware, including its own self-named customized
Alpine Linux distro.

### Dash
The system dashboard provided with Jab Metal and mirrored within Jab Launch.

## JabIO
Encompasses:
- Device management and passthru on the host system
- Drivers and SDK for the kernel

### jab (noun)
A `.jab` program assembled for the Jab Computer.

The term is also used to describe the program's package, containing its
executable and assets.

Jabs are distributed as `pacman` packages (`.pkg.tar.zst`) and are known
as *packs*.


## Environment

Agent operation occurs within a Fedora toolbox podman container. Final testing
with full access to devices is performed by the human against Linux and Windows
metal. Devices such as sound, gpu, etc. are not available within this container.

Each session should begin in a read-only code-review mode. Alteration of files,
running tests, accessing build tools, etc. should be not be performed while
in review until the user specifies anything different.
