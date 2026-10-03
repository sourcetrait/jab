# LowKick Jab workspace. Every recipe hands off to the SDK's nushell tool,
# sdk/nu/jab.nu, which reads workspace.jab.toml and does all lookups and
# up-to-date checks in one process. Needs nushell, just, a riscv64 GNU
# toolchain, and a QEMU with the RVA23 model, rva23s64; see the tool for
# how the toolchain, QEMU, and the target directory are found. `--set
# debug,stats` after a recipe names the build symbols; a build lands in
# .target/debug with DEBUG set and in .target/release otherwise. `--api`
# on a run puts the API's port on the machine; every build carries the
# API and runs either way.

set shell := ["nu", "-c"]
set windows-shell := ["nu", "-c"]
set quiet := true

here := justfile_directory()
jab := here / "sdk" / "nu" / "jab.nu"

default: build

# Build the kernel, then every program, skipping what is up to date;
# release, or `just build --set debug`
build *args:
    ^nu "{{jab}}" workspace build "{{here}}" {{args}}

# Build everything with DEBUG set, then run the integration test of every
# program, of one category (`just test example`), or of one program
# (`just test example helloworld`); prints each test's output and a
# summary, fails if any fails
test category="" name="" *args:
    ^nu "{{jab}}" workspace test "{{here}}" "{{category}}" "{{name}}" {{args}}

# Build everything, then run one program with the console window:
# `just run example helloworld`; release, or `just run example bounce
# --set debug`, which writes the kernel's debug channel to a file; `just
# run example wasd --api` with the API's port on the machine; the host's
# gamepad attached when one is found, or `--no-pad`; the keyboard and
# the tablet off with `--no-kbm`, which a pad run with a port needs. A
# program the workspace does not list runs by its path through its own
# directory's justfile, which builds it against the workspace: `just run
# game fps 1k`
run +args:
    let words = ("{{args}}" | split row " " | where {|w| $w != "" }); let path = ($words | take while {|w| not ($w | str starts-with "-") }); let flags = ($words | skip ($path | length)); let relative = ($path | str join "/"); let dir = ("{{here}}" | path join ...$path); if ($path | is-empty) { error make { msg: "just run <path to a program> [flags]: `just run example helloworld`, `just run game fps 1k`" } } else if $relative in (open "{{here}}/workspace.jab.toml" | get programs) { ^nu "{{jab}}" workspace run "{{here}}" ...$path ...$flags } else if ($dir | path join "justfile" | path exists) { ^just --justfile ($dir | path join "justfile") run ...$flags } else { error make { msg: $"no program at ($relative): the workspace lists none there and it has no justfile" } }

# Build, then probe one program under a window and print one NUON
# record on how its flips reached it: `just probe sdl example walk`,
# twelve seconds or `--seconds N`; Linux, with cargo for the shim
probe kind category name *args:
    ^nu "{{jab}}" workspace probe "{{here}}" "{{kind}}" "{{category}}" "{{name}}" {{args}}

# Record the running Jab QEMU per thread, once a second, to
# .target/watch.nuonl: `just watch` from any shell while a program
# runs; when the run ends, one NUON record on it to paste, per thread
# the steady CPU seconds a second after the first five, or `--skip N`
watch *args:
    ^nu "{{jab}}" watch "{{here}}" {{args}}

clean:
    rm -rf "{{here}}/.target"
