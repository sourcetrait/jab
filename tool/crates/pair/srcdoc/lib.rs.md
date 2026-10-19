# lib.rs

`jabpair` is the bracket `sdl pair` checks a probed run's pairing by: given
each paired upload's host stamp and its flip call's bounds on the guest's
clock, whether one offset a and one drift b in the declared range put
every upload inside its call, host = a + b guest. The pairing itself, which
upload is which present, is decided by the binding (ordinals, counts, the
run's nonce and pid) on the nushell side; the bracket is a consistency check
on top of it, never the pairing.
