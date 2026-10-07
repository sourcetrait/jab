# Jab. The repository's one justfile: every recipe hands off to the SDK's
# nushell tool, sdk/nu/jab.nu, which reads workspace.jab.toml and does
# every lookup and up-to-date check in one process. Needs nushell, just
# 1.32 or later for script recipes, a riscv64 GNU toolchain, and a QEMU
# with the RVA23 model, rva23s64. Script recipes are stable from just
# 1.44; `set unstable` below runs them on 1.32 to 1.43 without
# `--unstable`, and changes nothing on a later just. A program is named
# by its path from here, its words spaced or joined by slashes,
# example/bounce, game/fps, or by a shortcut workspace.jab.toml
# names, fps. `--set debug,stats` after a
# recipe names the build symbols. A recipe's arguments reach the tool
# each as it was given, spaces and all. Everything the tool writes goes
# to one target, .target here, or $XDG_CACHE_HOME/jab/target/<checkout>
# where that is set, but for the cargo builds of tool/ and the game's
# rust/, which keep cargo's own. Nothing is deleted but by `just retire`:
# what the tools clear away is retired to the tmp beside the targets.
# `just adv` lists the commands for development.

set shell := ["nu", "-c"]
set windows-shell := ["nu", "-c"]
set quiet := true
set positional-arguments := true
set unstable := true

here := justfile_directory()
jab := here / "sdk" / "nu" / "jab.nu"

default: build

# `just build`, `just build example`, `just build game/fps --set
# debug`; what is up to date is skipped
# Build the kernel and every program, or the programs under a path
[script("nu")]
build *args:
    def --wrapped main [...args] { ^nu '{{jab}}' build '{{here}}' ...$args }

# `just test`, `just test example/pad`, `just test game/fps`; each
# test's output, then a summary, failing if any fails
# Build with DEBUG set, then test every program, or those under a path
[script("nu")]
test *args:
    def --wrapped main [...args] { ^nu '{{jab}}' test '{{here}}' ...$args }

# `just run example/bounce`, `just run fps`; release, or `--set
# debug`; `--api` puts the API's port on the machine; the host's gamepad
# and sound come along unless `--no-pad` or `--no-sound`, the keyboard
# and the tablet unless `--no-kbm`; four harts, or `--harts 1` or `2` for
# a diagnostic machine
# Build, then run one program in its window
[script("nu")]
run +args:
    def --wrapped main [...args] { ^nu '{{jab}}' run '{{here}}' ...$args }

# From any shell while a program runs; when the run ends, one NUON record
# on it to paste, per thread the steady CPU seconds a second after the
# first five, or `--skip N`. `just watch bench game/fps/cadence`, in
# a second terminal before or during that bench, records every run of it
# and reports the whole bench when it ends, packing the run again with
# its recording into the one .tar it names last
# Record the running Jab QEMU per thread, once a second
[script("nu")]
watch *args:
    def --wrapped main [...args] { ^nu '{{jab}}' watch ...$args '{{here}}' }

# `just bench` lists them; `just bench game/fps/cadence` runs one,
# `--only play0,cadence0_1` the steps named; nothing is deleted, and
# everything is written to the target, the run packed at the end into
# one .tar beside it, whose path the last line prints, the file to copy
# off the host
# Run a program's bench, every step one after another, then its report
[script("nu")]
bench *args:
    def --wrapped main [...args] { ^nu '{{jab}}' bench '{{here}}' ...$args }

# Every build, test, run, and bench here moved aside, so the next build
# starts from nothing; `just retire` deletes what it moved
# Retire the whole target
clean:
    ^nu '{{jab}}' clean '{{here}}'

# The one command that deletes: the tmp beside the targets,
# $XDG_CACHE_HOME/jab/target/tmp, or .target/tmp, where everything
# retired waits
# Delete everything retired
retire:
    ^nu '{{jab}}' retire '{{here}}'

# `just adv` lists them; `just adv <command> [args]` runs one, a relative
# path among its args taken from where you are
# The commands for development
[no-cd]
[script("nu")]
adv *args:
    def --wrapped main [...args] { ^nu '{{jab}}' adv '{{here}}' ...$args }
