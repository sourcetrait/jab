# run.rs

The harness exists for the one case no QEMU here shows: an executable whose
load bias and lowest mapped address differ. Every QEMU on the box, and
Fedora's modules, is a PIE whose first segment sits at 0, so `l_addr` and
`dli_fbase` agree on every frame. Built non-PIE, the harness is an `EXEC`
linked above 0 with a bias of 0, so a capture that subtracted the lowest
mapped address would put the harness's frame one first-segment base low,
where no function lies. test/probe runs it with the SDL shim preloaded and
checks its premises before trusting the reading.

It is built by `cargo rustc` with `-C relocation-model=static`, which the
SDK's `shim-build --static` passes; a plain `cargo build` gives a PIE.

## const RTLD_DEFAULT

The global scope puts a preloaded library ahead of the rest, so the lookup
finds the shim's `SDL_GL_MakeCurrent`, which then calls libSDL2's. With no
video initialised libSDL2 answers -1, which is expected and printed.

## fn harness_make_current

Out of line and out of tail position, its answer passed through
`black_box` after the call, so the return address the shim captures lies
inside this function and the shim's report must name it as the immediate
caller. The unmangled name keeps it readable in `.symtab`.
