# LowKick
> REIN HUMAN

LowKick is a Virtual System suite.

It defines a set of conservative virtual system specifications that roughly
follow current trends in affordable single-board computers.

## LowKick Jab

Jab is a QEMU-based assembly-only kernel and SDK that allows users to
distribute and run `.jab` games and applications with opinionated support
built-in.

## Environment

Agent operation occurs within a Fedora toolbox podman container. Final testing
with full access to devices is performed by the human against Linux and Windows
metal. Devices such as sound, gpu, etc. are not available within this container.

Each session should begin in a read-only code-review mode. Alteration of files,
running tests, accessing build tools, etc. should be not be performed while
in review until the user specifies anything different.


