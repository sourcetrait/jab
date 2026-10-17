# lib.rs

Dead code and unused imports are allowed off Windows: the relay's one
caller, `run`'s `duplex`, connects and relays on Windows alone, so
elsewhere the relay's core is reached by the tests and nothing else, and
`relay`'s glob import goes unused.
