# Jab. The repository's one justfile: every recipe hands off to the SDK's
# nushell tool, sdk/nu/jab.nu, which reads workspace.jab.toml and does
# every lookup and up-to-date check in one process. Needs nushell, just,
# a riscv64 GNU toolchain, and a QEMU with the RVA23 model, rva23s64. A
# program is named by its path from here, its words spaced or joined by
# slashes, example/bounce, game/fps/1k, or by a shortcut
# workspace.jab.toml names, fps. `--set debug,stats` after a recipe
# names the build symbols. Everything the tool writes goes to one
# target, .target here, or $XDG_CACHE_HOME/jab/target/<checkout> where
# that is set, but for the cargo builds of tool/ and the game's rust/,
# which keep cargo's own. Nothing is deleted but by `just retire`: what
# the tools clear away is retired to the tmp beside the targets. `just
# adv` lists the commands for development.

set shell := ["nu", "-c"]
set windows-shell := ["nu", "-c"]
set quiet := true

here := justfile_directory()
jab := here / "sdk" / "nu" / "jab.nu"

default: build

# `just build`, `just build example`, `just build game/fps/1k --set
# debug`; what is up to date is skipped
# Build the kernel and every program, or the programs under a path
build *args:
    ^nu "{{jab}}" build "{{here}}" {{args}}

# `just test`, `just test example/pad`, `just test game/fps/1k`; each
# test's output, then a summary, failing if any fails
# Build with DEBUG set, then test every program, or those under a path
test *args:
    ^nu "{{jab}}" test "{{here}}" {{args}}

# `just run example/bounce`, `just run fps`; release, or `--set
# debug`; `--api` puts the API's port on the machine; the host's gamepad
# and sound come along unless `--no-pad` or `--no-sound`, the keyboard
# and the tablet unless `--no-kbm`
# Build, then run one program in its window
run +args:
    ^nu "{{jab}}" run "{{here}}" {{args}}

# From any shell while a program runs; when the run ends, one NUON record
# on it to paste, per thread the steady CPU seconds a second after the
# first five, or `--skip N`. `just watch bench game/fps/1k/cadence`, in
# a second terminal before or during that bench, records every run of it
# and reports the whole bench when it ends
# Record the running Jab QEMU per thread, once a second
watch *args:
    ^nu "{{jab}}" watch {{args}} "{{here}}"

# `just bench` lists them; `just bench game/fps/1k/cadence` runs one,
# `--only play0,cadence0_1` the steps named; nothing is deleted, and
# everything is written to the target
# Run a program's bench, every step one after another, then its report
bench *args:
    ^nu "{{jab}}" bench "{{here}}" {{args}}

# Every build, test, run, and bench here moved aside, so the next build
# starts from nothing; `just retire` deletes what it moved
# Retire the whole target
clean:
    ^nu "{{jab}}" clean "{{here}}"

# The one command that deletes: the tmp beside the targets,
# $XDG_CACHE_HOME/jab/target/tmp, or .target/tmp, where everything
# retired waits
# Delete everything retired
retire:
    ^nu "{{jab}}" retire "{{here}}"

# `just adv` lists them; `just adv <command> [args]` runs one, a relative
# path among its args taken from where you are
# The commands for development
[no-cd]
adv *args:
    ^nu "{{jab}}" adv "{{here}}" {{args}}
