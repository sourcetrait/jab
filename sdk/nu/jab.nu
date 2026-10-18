# jab.nu: the Jab SDK's nushell tooling.
#
# As a module (`use jab.nu`) it gives a program's integration test
# `jab launch`, which runs a program headless and can take its screen,
# and the helpers that read a screen: `jab screen`, `jab ink`,
# `jab pixel`, `jab thumbnail`. As a script (`nu jab.nu <command> ...`)
# it builds, runs, and tests the kernel and the programs for the
# repository's one justfile, doing every lookup the workspace defines:
# the programs (the members workspace.jab.toml lists and every other
# program under the workspace, each by its path from it or a word its
# `shortcuts` table names), the workspace directory (the nearest parent
# holding workspace.jab.toml, or the one a program's manifest names from
# outside any), the toolchain (RISCV_TOOLCHAIN, else extern/riscv beside
# the kernel or program, else the workspace's, else the tools on PATH,
# under the official triple or a distribution's name), QEMU (extern/qemu
# beside the program, else the workspace's, else qemu-system-riscv64 on
# PATH), the target (target-root: one tree for the whole workspace,
# .target at its root or $XDG_CACHE_HOME/jab/target/<checkout> where
# that is set, every build and every tool's output sharded within it),
# and the manifests. Nothing a build, a test, a bench, or a clean clears
# away is deleted: it is retired into the tmp beside the checkouts'
# targets, or into a `.target`'s own (retire), and `retire` is the one
# command that deletes, that tmp alone.
#
# A build is described by its symbols: `--set debug,stats` names them,
# comma separated, in any case, and each reaches the assembler as
# `--defsym NAME=1` for `.ifdef NAME` to read, in the kernel and the
# programs alike. DEBUG picks the target's debug tree, and every other
# build lands in its release tree, so the two coexist. A program's
# manifest may name a `prepare` script, run before it is built, tested,
# or run, and a `do` script, whose commands `just do` lists; and the
# `specs` it supports, by the names the workspace's asset/spec.nuon gives
# them, with the harts it reserves, `[reserved]`, and those each of its
# optional features demands, `[feature.<name>]`, which the build checks,
# hands the program as constants (program-demand), and records beside
# its image, where a launch reads it (image-demand). Every image begins
# with a page the build writes ahead of its code, the jump to it, a
# header, and for a program listing specs its declaration, each spec's
# definition and the base demand (header-source), which the kernel holds
# the machine to before the program starts and check-image reads. `test`
# always sets DEBUG, so a program's own debug reporting is there for its
# test; `run` and `build` are release unless asked otherwise. The API,
# a port between the program and the host, is not a build symbol: every
# kernel carries it, and `--api` on a run (or `jab launch --api`) puts
# the port on the machine, off by default, so one build runs either
# way. A build is skipped when its output is newer than every input and
# the flags, symbols included, match the last build.

# This tool's own file, which `do` runs again for the SDK's commands.
const self = (path self)
# The riscv64 binutils prefixes: the official toolchain's triple first,
# then the names distributions package the tools under.
const triples = [
    "riscv64-unknown-linux-gnu-" "riscv64-linux-gnu-"
    "riscv64-unknown-elf-" "riscv64-elf-"
]
# The window's base (jab.inc): the kernel's 2 MiB and the framebuffer's
# 8 MiB come first, and the program has the rest of the machine's 4 GiB.
const program_base = "0x80a00000"
# A custom machine's RAM, the 4 GiB every machine had before named specs;
# a named spec's is its own.
const custom_ram_gib = 4
# virt's map has this many virtio-mmio transports, a hard ceiling on
# the devices a line can carry.
const transport_limit = 8
# The QEMU every machine runs on, by its binary's name.
const qemu_name = "qemu-system-riscv64"
# The display's size, jab.inc's JAB_DISPLAY_WIDTH by JAB_DISPLAY_HEIGHT:
# every screen a launch takes is this many pixels.
const display_size = { width: 1920, height: 1080 }
# The image's first page (jab.inc's JAB_IMAGE_* and JAB_DECL_*), which the
# kernel reads before the program starts (start_check): at the window's
# base one uncompressed `jal x0` to the code at the second page,
# image_jump; the header after it, image_header bytes from the base, the
# magic `JABD` as a little-endian word, the version, the flags, bit 0
# declared, and the declaration's offset, length, and CRC-32; the
# declaration at decl_offset, never executed: the base demand, the count
# of the specs listed, at most decl_specs_max, and an entry of
# decl_spec_bytes a spec, its name zero padded to decl_name_bytes.
const image_code = 4096
const image_header = 64
const image_magic = 0x4442414a
const image_version = 1
const image_declared = 1
const image_jump = 0x0000106f
const decl_offset = 64
const decl_specs_max = 16
const decl_spec_bytes = 32
const decl_name_bytes = 8
# The ISAs a declaration names, by the spec data's profile: RVA23 is 1.
const decl_isas = { RVA23: 1 }
# RVA23 is the profile Jab pins, so everything it mandates is on whether
# or not Jab itself uses it; the supervisor profile is the one carrying
# an MMU mode and the supervisor timer the frame clock needs. RVA23 says
# nothing about machine mode, so QEMU's model of it has no physical
# memory protection at all, and the kernel enters in machine mode and
# opens PMP before it has a trap vector: without `pmp=true` that write
# is an illegal instruction which traps to address zero and spins there
# forever. It is the one CPU a machine runs: QEMU carries it from 9.2,
# and a QEMU without it is refused rather than run on another model.
const cpu_profile = "rva23s64,pmp=true"
# The assembler takes the same profile, so the source may use whatever
# the CPU carries: the user profile for a program, which runs in U-mode,
# and the supervisor profile for the kernel.
const march_program = "-march=rva23u64"
const march_kernel = "-march=rva23s64"
# Multithreaded TCG, a host thread a hart, stated on every line: QEMU
# 11.1.2 already takes it for riscv64 when no instruction counting is
# asked, and the line says so whatever the host's QEMU would choose.
const accel = "tcg,thread=multi"
# The interrupt platform: the APLIC in MSI mode feeding each hart's IMSIC
# interrupt files, with the ACLINT's timer, which only TCG offers.
const machine_name = "virt,aia=aplic-imsic,aclint=on"
# The harts a machine takes, up to the eight of JAB_HARTS_MAX in jab.inc,
# the most the ABI names: a named spec's cores, or a custom machine's
# count, which its record labels diagnostic whatever it is.
const harts_allowed = [1 2 3 4 5 6 7 8]
# No parallel port: QEMU's default is a text console of its own, which
# under SDL is a second, hidden window with its own GL context, drawn
# on every refresh its cursor blinks.
const machine_rest = [
    "-global" "virtio-mmio.force-legacy=false"
    "-parallel" "none"
]
# The console's rectangle update in QEMU's two families, the function a
# device's flush calls and its whole-surface form: 11.1.2's names, then
# 10.2.2's, which a modular build exports to its modules.
const console_updates = [
    ["qemu_console_update" "qemu_console_update_full"]
    ["dpy_gfx_update" "dpy_gfx_update_full"]
]
# How a virtio-gpu module's file name starts in a modular QEMU's
# packages: hw-display-virtio-gpu.so and its -gl and -pci kin.
const device_module = "hw-display-virtio-gpu"
# Every line the sdl shim writes (shim/crates/sdl), its time first, in
# seconds to the microsecond: an object-table line, its index, the file's
# inode, size, and modification time in nanoseconds or `- - -` where there
# is no file, then its path, the rest of the line, empty allowed; a run's
# line, `process` or `nonce` with whatever follows, held to its own form
# apart so a malformed one is refused by name (sdl-run-lines); a
# make_current with its frames, each an object's index or `?` with an
# address in lowercase hex; a window-size call, a swap, or a poll; or a
# notice the shim writes as it stops the run.
const sdl_line = (
    '^[0-9]+\.[0-9]{6} (?:'
    + 'object [0-9]+ (?:[0-9]+ [0-9]+ -?[0-9]+|- - -) .*'
    + '|process(?: .*)?|nonce(?: .*)?'
    + '|make_current(?: (?:[0-9]+|\?)\+[0-9a-f]+)*'
    + '|size|swap|poll'
    + '|libSDL2 not found|symbol not found'
    + ')$'
)
# The shim's notices, each written as it aborts QEMU when it cannot reach
# SDL: libSDL2 missing, or a function missing from it.
const sdl_notices = ["libSDL2 not found" "symbol not found"]

# The QEMU a machine runs on: an extern when there is one, else PATH.
# `extern/qemu` is a QEMU install, the binary under its `bin/` or at its
# top, where the Windows installer puts it, looked for as the
# toolchain's `extern/riscv` is, beside `here` (the program) and then in
# the workspace; one that holds no binary is an error rather than a
# quiet fall to PATH, since a run on another QEMU is what the link is
# there to prevent. With no extern, the name, for PATH.
def qemu-binary [here: path, workspace: oneof<string, nothing>]: nothing -> string {
    let places = (if $workspace == null { [$here] } else { [$here $workspace] })
    let file = (exe-name $qemu_name)
    for place in $places {
        let prefix = ($place | path join "extern" "qemu")
        if ($prefix | path type) != null {
            let found = ([($prefix | path join "bin" $file) ($prefix | path join $file)] | where {|b| $b | path exists })
            if ($found | is-empty) {
                error make {msg: $"($prefix) holds no ($file), in bin/ or at its top: link extern/qemu to a QEMU install"}
            }
            return ($found | first)
        }
    }
    $qemu_name
}

# An executable's file name on this host: `<name>.exe` on Windows, which
# a path checked for the file has to name whole.
def exe-name [name: string]: nothing -> string {
    if $nu.os-info.name == "windows" { $name + ".exe" } else { $name }
}

# Where a launch looks for extern/qemu before the workspace, as a run
# does: the directory of the program a built image came from, which the
# build writes beside the image as `home`. An image built before that
# is read from its path: a member's under the workspace's .target at the
# member's path, any other program's under the program's own .target,
# and an image under no .target is taken to sit beside its program.
def image-home [image: path]: nothing -> string {
    let marker = ($image | path expand | path dirname | path join "home")
    if ($marker | path exists) { return (open --raw $marker | decode | str trim) }
    let parts = ($image | path expand | path split)
    let marks = ($parts | enumerate | where item == ".target" | get index)
    if ($marks | is-empty) { return ($image | path expand | path dirname) }
    let mark = ($marks | last)
    let base = ($parts | first $mark | path join)
    # past .target: the tree, debug or release, then the program's
    # workspace-relative path or its name, then the image
    let relative = ($parts | skip ($mark + 2) | drop 1)
    if ($relative | is-empty) or not ($base | path join "workspace.jab.toml" | path exists) { return $base }
    let program = ($base | path join ...$relative)
    if (member-of $program $base) { $program } else { $base }
}

# The CPU every machine runs, the RVA23 profile, once the QEMU it runs on
# lists the model; a QEMU that does not is refused with its version.
def cpu-model [qemu: string]: nothing -> string {
    let listed = (^$qemu -cpu help | complete | get stdout | lines | any {|l| ($l | str trim) == "rva23s64" })
    if not $listed {
        let version = (^$qemu --version | complete | get stdout | lines | get -o 0 | default "a QEMU")
        let found = (which $qemu | get -o 0.path | default $qemu)
        error make {msg: $"($version) at ($found) has no rva23s64, the RVA23 CPU every Jab machine runs on\nlink extern/qemu, in the workspace or beside the program, to a QEMU 11 install"}
    }
    $cpu_profile
}

# What a launch's machine is, the record a run keeps of it. A named
# spec's, given its row (spec-row): its cores the harts and its RAM, with
# `spec` its name in lowercase, its cores, its RAM in GiB, and its
# display, `diagnostic` null. A custom machine of `harts` harts, 1 to 8
# (harts_allowed), and custom_ram_gib: `diagnostic` its harts and RAM and
# `spec` null, whatever its count. Never both, and one of them always.
# Beside either the harts and the RAM it has, the -machine options, the
# CPU model, the accelerator with its thread mode, and `overrides`, QEMU
# words of a launch's own on its line.
export def machine-of [harts?: int, --spec: any = null, --overrides: list<string> = []]: nothing -> record<harts: int, ram_gib: int, spec: any, diagnostic: any, machine: string, cpu: string, accel: string, overrides: list<string>> {
    if $spec != null and $harts != null { error make {msg: "--spec with --harts: a named spec provisions its own harts, and --harts names a custom machine"} }
    if $spec == null and $harts == null { error make {msg: "a machine is a named spec's, --spec, or a custom one, --harts N"} }
    let common = { machine: $machine_name, cpu: $cpu_profile, accel: $accel, overrides: $overrides }
    if $spec != null {
        let ram = ($spec.ram / 1GiB | into int)
        let named = { name: ($spec.name | str lowercase), cores: $spec.cores, ram_gib: $ram, display: $spec.display }
        { harts: $spec.cores, ram_gib: $ram, spec: $named, diagnostic: null } | merge $common
    } else {
        if $harts not-in $harts_allowed { error make {msg: $"--harts takes ($harts_allowed | first) to ($harts_allowed | last), a custom machine's harts, not ($harts)"} }
        { harts: $harts, ram_gib: $custom_ram_gib, spec: null, diagnostic: { harts: $harts, ram_gib: $custom_ram_gib } } | merge $common
    }
}

# The machine a launch asks for (machine-of): `--harts`, given past 0, a
# custom machine; else the spec `--spec` names, or the configured default
# (spec-default), its row from `ws`'s spec data (spec-row). Both given are
# refused, naming both, before QEMU starts.
export def machine-for [ws: oneof<string, nothing>, spec: string, harts: int]: nothing -> record {
    if $spec != "" and $harts != 0 { error make {msg: $"--spec ($spec) with --harts ($harts): a named spec provisions its own harts, and --harts names a custom machine; one or the other"} }
    if $harts != 0 { return (machine-of $harts) }
    if $ws == null { error make {msg: "a named spec needs its workspace's asset/spec.nuon, and this launch has no workspace; name a custom machine with --harts"} }
    let name = (if $spec != "" { $spec } else { spec-default $ws })
    machine-of --spec (spec-row $ws $name)
}

# A spec's row from the workspace's spec data (specs-of), its name matched
# in any case, held to what the launcher can provision: its cores within
# the harts a machine takes (harts_allowed), and the ABI's display, 1920 by
# 1080 (display_size); otherwise refused, naming the spec and why.
export def spec-row [ws: path, name: string]: nothing -> record {
    let rows = (specs-of $ws)
    let found = ($rows | where {|r| ($r.name | str lowercase) == ($name | str lowercase) })
    if ($found | is-empty) { error make {msg: $"no spec ($name) in the spec data, which defines ($rows | get name | str join ', ')"} }
    let r = ($found | first)
    if $r.cores not-in $harts_allowed { error make {msg: $"($r.name) has ($r.cores) cores, past the ($harts_allowed | last) harts a machine takes; the launcher cannot provision it"} }
    if $r.display != $display_size { error make {msg: $"($r.name)'s display is ($r.display.width) by ($r.display.height), and the ABI's ($display_size.width) by ($display_size.height); the launcher cannot provision it yet"} }
    $r
}

# The default spec: JAB_SPEC where it is set, else `spec` in
# `jab/config.toml` under the XDG config home, $XDG_CONFIG_HOME or
# ~/.config, which is checked and never made; `jab/` under it is made, and
# the file, where there is none, seeded from the workspace's
# asset/default/config.toml, never over one there.
export def spec-default [ws: path]: nothing -> string {
    let forced = ($env.JAB_SPEC? | default "")
    if $forced != "" { return $forced }
    let given = ($env.XDG_CONFIG_HOME? | default "")
    let home = (if $given == "" { $nu.home-dir | path join ".config" } else { $given })
    if ($home | path type) != "dir" { error make {msg: $"the XDG config home ($home) is not there, where jab/config.toml names the default spec; set JAB_SPEC or pass --spec"} }
    let dir = ($home | path join "jab")
    mkdir $dir
    let file = ($dir | path join "config.toml")
    if ($file | path type) == null {
        let seed = ($ws | path join "asset" "default" "config.toml")
        if not ($seed | path exists) { error make {msg: $"no ($seed) to seed ($file) from"} }
        cp $seed $file
    }
    let cfg = (try { open --raw $file | into binary | decode | from toml } catch {|e| error make {msg: $"($file) is no TOML the tools read: ($e.msg)"} })
    let spec = ($cfg | get -o spec)
    if ($spec | describe) != "string" or ($spec | str trim) == "" { error make {msg: $"($file) names no `spec`, the default spec a launch runs"} }
    $spec
}

# A launch's command line for the kernel: `bootargs`, then a named spec's
# `jab.spec=<name>`; a custom machine's `bootargs` alone.
def spec-bootargs [m: record, bootargs: string]: nothing -> string {
    if $m.spec == null { return $bootargs }
    [$bootargs $"jab.spec=($m.spec.name)"] | where {|w| $w != "" } | str join " "
}

# A debug kernel's knob as it reads one from its command line
# (knob_value): the first word of `line` that starts `<name>=`, its value
# when the rest is digits alone; null with no such word, or with anything
# else after its `=`.
def knob-of [line: string, name: string]: nothing -> oneof<int, nothing> {
    let word = ($line | split row " " | where {|w| $w starts-with $"($name)=" } | get -o 0)
    if $word == null { return null }
    let value = ($word | str substring (($name | str length) + 1)..)
    if ($value =~ '^[0-9]+$') { $value | into int } else { null }
}

# The machine on `qemu` as `m` (machine-of) provisions it: virt with
# `options` after it when given, the RVA23 CPU, multithreaded TCG, its
# harts, every transport modern.
def machine-args [qemu: string, m: record, --options: string = ""]: nothing -> list<string> {
    let machine = (if $options == "" { $m.machine } else { $"($m.machine),($options)" })
    ["-machine" $machine "-cpu" (cpu-model $qemu) "-accel" $m.accel "-smp" ($m.harts | into string)] ++ $machine_rest
}

# The RAM `m` has (machine-of), in GiB.
def memory-args [m: record]: nothing -> list<string> {
    ["-m" $"($m.ram_gib)G"]
}

# The scalar types a spec's type may name.
const spec_scalars = [string int float number bool filesize duration datetime binary nothing path directory]

# The system specifications as the tools read them. doc/SPEC.md is the
# authority, TheUser's, and the workspace's asset/spec.nuon carries its
# definitions for the tools, a table of one row a spec, held to
# asset/spec.nutype, the type the table takes, which is read from its file
# with the data and kept nowhere in this tool. `spec-table` reads any such
# pair and `specs-of` the workspace's own, the one reader the launcher, a
# build's checks, and an image's list share. Every value is checked
# against the type field by field: a field missing, a value of another
# type, and a field the type does not name, at any depth, are each refused
# naming the row and the field, which nushell's own check of a type does
# not name. Past the type, the rows must mean something: a spec at least,
# every name given and none twice without regard to case, since a
# program's manifest names its specs in any case, and every count, clock,
# rate, and size the type names above zero, the VRAM only where a spec
# gives one. A file that does not parse is refused naming it, NUON's own
# refusal of a field given twice in a record among them. Every problem
# found is named, a line each. The rows come back as the file has them.
# Untyped because it ends in an error.
export def spec-table [data: path, type: path] {
    for f in [$type $data] { if not ($f | path exists) { error make {msg: $"($f): no such file"} } }
    let text = (try { open --raw $type | decode } catch {|e| error make {msg: $"($type): unreadable: ($e.msg)"} })
    let schema = (type-schema $text $type)
    if $schema.kind != "table" { error make {msg: $"($type): the tools read a table of specs, table<...>, not (type-name $schema)"} }
    let name_field = ($schema.fields | where name == "name" | get -o 0)
    if $name_field == null or $name_field.schema != { kind: "scalar", name: "string" } { error make {msg: $"($type): `name: string` is the field the tools match a spec by, and the type has none"} }
    let rows = (try { open --raw $data | decode | from nuon } catch {|e| error make {msg: $"($data): not NUON the tools can read: ($e.msg)"} })
    let got = ($rows | describe)
    if not (($got | str starts-with "table") or ($got | str starts-with "list")) { error make {msg: $"($data): a table of specs expected, ($got) found"} }
    if ($rows | is-empty) { error make {msg: $"($data): no spec in it"} }
    let typed = ($rows | enumerate | each {|r|
        let label = (spec-label $r.index $r.item)
        record-problems $r.item $schema.fields "" | each {|p| $"  ($label): ($p)" }
    } | flatten)
    if not ($typed | is-empty) { error make {msg: ([$"($data) does not hold to ($type):"] ++ $typed | str join "\n")} }
    let meant = (spec-meaning $rows ($schema.fields | get name))
    if not ($meant | is-empty) { error make {msg: ([$"($data): its specs do not hold:"] ++ ($meant | each {|m| $"  ($m)" }) | str join "\n")} }
    $rows
}

# The workspace's spec data, its asset/spec.nuon held to its
# asset/spec.nutype (spec-table). Untyped because it ends in an error.
export def specs-of [ws: path] {
    let asset = ($ws | path expand | path join "asset")
    spec-table ($asset | path join "spec.nuon") ($asset | path join "spec.nutype")
}

# A type's text as nushell writes it, comment lines aside, as its parts:
# `table` and `record` with their fields in order, `list` with its
# element, `oneof` with its members, and a scalar by its name. Only that
# much of the type grammar is read, and anything else is refused naming
# it, so a type the tools cannot hold a spec to never passes as one they
# can. Untyped because it ends in an error.
def type-schema [text: string, file: string] {
    let body = ($text | lines | where {|l| not ($l | str trim | str starts-with "#") } | str join " ")
    let tokens = ($body | str replace --all --regex '([<>,:])' ' $1 ' | split row --regex '\s+' | where {|t| $t != "" })
    if ($tokens | is-empty) { error make {msg: $"($file): no type in it"} }
    let parsed = (type-parse $tokens 0 $file)
    if $parsed.next != ($tokens | length) { error make {msg: $"($file): more after the type: ($tokens | skip $parsed.next | first 3 | str join ' ')"} }
    $parsed.schema
}

# The type that starts at word `at` of a type's words, and the word after
# it. Untyped because it ends in an error.
def type-parse [tokens: list<string>, at: int, file: string] {
    let name = ($tokens | get -o $at)
    if $name == null or $name in ["<" ">" "," ":"] {
        error make {msg: $"($file): a type expected at word ($at + 1), (if $name == null { 'the end' } else { $name }) found"}
    }
    if ($tokens | get -o ($at + 1)) != "<" {
        if $name not-in $spec_scalars { error make {msg: $"($file): ($name) is no type the tools read; they read ($spec_scalars | str join ', '), oneof, list, record, and table"} }
        return { schema: { kind: "scalar", name: $name }, next: ($at + 1) }
    }
    match $name {
        "table" | "record" => {
            mut i = ($at + 2)
            mut fields = []
            while ($tokens | get -o $i) != ">" {
                let field = ($tokens | get -o $i)
                if $field == null or $field in ["<" ">" "," ":"] or ($tokens | get -o ($i + 1)) != ":" {
                    error make {msg: $"($file): a field and its type expected in ($name)<...>, (if $field == null { 'the end' } else { $tokens | skip $i | first 3 | str join ' ' }) found"}
                }
                if ($fields | any {|f| $f.name == $field }) { error make {msg: $"($file): ($field) named twice in ($name)<...>"} }
                let inner = (type-parse $tokens ($i + 2) $file)
                $fields = ($fields | append { name: $field, schema: $inner.schema })
                $i = $inner.next
                if ($tokens | get -o $i) == "," { $i += 1 }
            }
            { schema: { kind: $name, fields: $fields }, next: ($i + 1) }
        },
        "list" => {
            let inner = (type-parse $tokens ($at + 2) $file)
            if ($tokens | get -o $inner.next) != ">" { error make {msg: $"($file): list<...> holds one type"} }
            { schema: { kind: "list", of: $inner.schema }, next: ($inner.next + 1) }
        },
        "oneof" => {
            mut i = ($at + 2)
            mut members = []
            while ($tokens | get -o $i) != ">" {
                let inner = (type-parse $tokens $i $file)
                $members = ($members | append $inner.schema)
                $i = $inner.next
                if ($tokens | get -o $i) == "," { $i += 1 }
            }
            { schema: { kind: "oneof", members: $members }, next: ($i + 1) }
        },
        _ => { error make {msg: $"($file): ($name)<...> is no type the tools read; they read oneof, list, record, and table"} },
    }
}

# A type's part as nushell writes it.
def type-name [schema: record]: nothing -> string {
    match $schema.kind {
        "scalar" => $schema.name,
        "oneof" => $"oneof<($schema.members | each {|m| type-name $m } | str join ', ')>",
        "list" => $"list<(type-name $schema.of)>",
        _ => $"($schema.kind)<($schema.fields | each {|f| $'($f.name): (type-name $f.schema)' } | str join ', ')>",
    }
}

# A spec's row as a problem names it: its place, and its name when it
# has one.
def spec-label [index: int, row: any]: nothing -> string {
    let name = (if ($row | describe | str starts-with "record") { $row | get -o name } else { null })
    if ($name | describe) == "string" and $name != "" { $"row ($index + 1) \(($name)\)" } else { $"row ($index + 1)" }
}

# A field's path below `at`, "" being a row's own.
def field-path [at: string, name: string]: nothing -> string {
    if $at == "" { $name } else { $"($at).($name)" }
}

# What is wrong with a record against its fields, a line each, `at` the
# path to it: a field missing, a value of another type, and a field the
# type does not name.
def record-problems [value: any, fields: list<any>, at: string]: nothing -> list<string> {
    let got = ($value | describe)
    if not ($got | str starts-with "record") { return [$"(if $at == '' { 'the row' } else { $at }): a record expected, ($got) found"] }
    let named = ($fields | get name)
    let present = ($value | columns)
    let checked = ($fields | each {|f|
        let path = (field-path $at $f.name)
        if $f.name not-in $present { [$"($path): missing"] } else { value-problems ($value | get $f.name) $f.schema $path }
    } | flatten)
    let unknown = ($present | where {|c| $c not-in $named } | each {|c| $"(field-path $at $c): a field the type does not name" })
    $checked ++ $unknown
}

# What is wrong with a value against its part of a type, a line each, `at`
# its path; none when it holds.
def value-problems [value: any, schema: record, at: string]: nothing -> list<string> {
    let got = ($value | describe)
    match $schema.kind {
        "scalar" => {
            let holds = (match $schema.name {
                "number" => ($got in ["int" "float"]),
                "path" | "directory" => ($got == "string"),
                _ => ($got == $schema.name),
            })
            if $holds { [] } else { [$"($at): ($schema.name) expected, ($got) found"] }
        },
        "oneof" => {
            if ($schema.members | any {|m| value-problems $value $m $at | is-empty }) { [] } else { [$"($at): (type-name $schema) expected, ($got) found"] }
        },
        "record" => (record-problems $value $schema.fields $at),
        "list" => {
            if (not ($got | str starts-with "list")) and (not ($got | str starts-with "table")) { return [$"($at): (type-name $schema) expected, ($got) found"] }
            $value | enumerate | each {|e| value-problems $e.item $schema.of $"($at).($e.index)" } | flatten
        },
        _ => {
            if (not ($got | str starts-with "list")) and (not ($got | str starts-with "table")) { return [$"($at): (type-name $schema) expected, ($got) found"] }
            $value | enumerate | each {|e| record-problems $e.item $schema.fields $"($at).($e.index)" } | flatten
        },
    }
}

# What a spec table means that its type cannot say, a line each: every
# name given and none twice without regard to case; each count, clock,
# rate, and size the type names above zero, the VRAM only where a spec
# gives one. `named` are the type's fields, so a rule for a field the type
# no longer names is passed over.
def spec-meaning [rows: list<any>, named: list<string>]: nothing -> list<string> {
    let labelled = ($rows | enumerate | each {|r| { label: (spec-label $r.index $r.item), row: $r.item } })
    let unnamed = ($labelled | where {|r| ($r.row.name | str trim) == "" } | each {|r| $"($r.label): name empty" })
    let twice = ($labelled
        | where {|r| ($r.row.name | str trim) != "" }
        | group-by {|r| $r.row.name | str trim | str lowercase }
        | transpose key rows
        | where {|g| ($g.rows | length) > 1 }
        | each {|g| $"($g.rows | get label | str join ' and ') name one spec, ($g.key) in any case" })
    let numbers = {|v| ($v | describe) in ["int" "float"] }
    let sizes = {|v| ($v | describe) == "filesize" }
    let below = ($labelled | each {|r|
        let counts = ([cores clock_ghz fps] | where {|f| $f in $named and (do $numbers ($r.row | get $f)) and ($r.row | get $f) <= 0 } | each {|f| $"($r.label): ($f) ($r.row | get $f), above zero wanted" })
        let ram = (if "ram" in $named and (do $sizes $r.row.ram) and $r.row.ram <= 0B { [$"($r.label): ram ($r.row.ram), above zero wanted"] } else { [] })
        let display = (if "display" in $named and ($r.row.display | describe | str starts-with "record") {
            [width height] | where {|s| (do $numbers ($r.row.display | get -o $s)) and ($r.row.display | get $s) <= 0 } | each {|s| $"($r.label): display.($s) ($r.row.display | get $s), above zero wanted" }
        } else { [] })
        let vram = (if "vram" in $named and (do $sizes $r.row.vram) and $r.row.vram <= 0B { [$"($r.label): vram ($r.row.vram), above zero wanted where a spec gives one"] } else { [] })
        $counts ++ $ram ++ $display ++ $vram
    } | flatten)
    $unnamed ++ $twice ++ $below
}
# The guest is named for the program, `jab <program>`, which is what
# QEMU's window shows inside its own prefix, hardcoded in every front
# end (SDL adds the console's index too: `QEMU (jab pad-0)`), and the
# threads are named (CPU 0/TCG and the rest), so a per-thread listing
# reads; on Linux the process is named jab, so `pgrep -x jab` finds it.
# `-name` alone names only the guest, and `process=` is a Linux prctl
# that QEMU refuses to start without elsewhere ("Change of process name
# not supported by your OS"), so the process name is Linux's alone.
def name-args [program: string]: nothing -> list<string> {
    let process = (if $nu.os-info.name == "linux" { ",process=jab" } else { "" })
    ["-name" $"jab ($program)($process),debug-threads=on"]
}
const display_device = ["-device" "virtio-gpu-device,xres=1920,yres=1080"]
const input_devices = [
    "-device" "virtio-keyboard-device"
    "-device" "virtio-tablet-device"
]
# The entropy device, on a run and on a launch alike, since the
# kernel's jab.sys.random draws from it
const rng_device = ["-device" "virtio-rng-device"]
const devices = [
    "-device" "virtio-net-device,netdev=net0" "-netdev" "user,id=net0"
] ++ $rng_device

# The sound device over a host backend: `backend` is an -audiodev
# driver name with any of its own options after it (`pipewire`,
# `coreaudio`, `none`, `wav,path=...`), and the backend runs at the
# kernel's one rate so nothing resamples between them. The device
# carries `streams`, playback and capture by default; a launch's wav
# recorder has no capture voice and QEMU says so on its stderr for a
# device that asks for one, so a launch gives the device playback
# alone, the one stream the kernel drives.
def sound-args [backend: string, --streams: int = 2]: nothing -> list<string> {
    ["-audiodev" $"($backend),id=snd0,out.frequency=48000" "-device" $"virtio-sound-device,audiodev=snd0,streams=($streams)"]
}

# The host's audio backend for a run, from jabdisco's audio record:
# JAB_AUDIO as given is the backend and its options verbatim; no
# output found is `none`, which discards, so a program's sound calls
# still answer; an output found goes to the backend that reaches it,
# the device named: on Linux ALSA's `default`, which is the sound
# server's default sink, the one the record names, through the server's
# ALSA plugin (the pipewire backend dropped the start of a stream and
# the pa backend errored on volume and cut off, both measured on the
# reference host); on macOS coreaudio and on Windows dsound, whose
# default is the system's chosen output, the one the record names.
def audio-plan [found: oneof<record, nothing>]: nothing -> string {
    let forced = ($env.JAB_AUDIO? | default "")
    if $forced != "" { return $forced }
    if $found == null { return "none" }
    match $nu.os-info.name {
        "linux" => "alsa,out.dev=default",
        "macos" => "coreaudio",
        "windows" => "dsound",
        _ => "none",
    }
}

# A headless machine prepared and not run: everything a launch sets up
# before QEMU starts, handed back for whoever runs and drives it, the
# SDK's own `launch` or a harness that plays interactively. `qemu_binary`
# is the QEMU it runs on (qemu-binary, beside the program the image came
# from and then in the workspace, as a run's), `qemu` the whole argument
# vector after it, `env` what the process runs under (the evdev shim
# preloaded when a gamepad rides the fifo), and the rest the paths: the
# UART's log, QEMU's guest-error log, the screen a screendump lands in,
# the pid file, the monitor's pipe pair (`<monitor>.in` and `.out`), the
# debug channel's log under DEBUG, the API's `api_in` pipe and `api_out`
# file with `--api`, and the pad: with `--gamepad`, on Linux the fifo
# QEMU reads as the pad, which the driver writes 24-byte input_event
# records into, else (and with `--pad-port`) the pad port's `pad_pipe_in`
# pipe, whose header, `pad_header` as hex, the driver writes first, the
# pipes made. On Windows, where QEMU makes each pipe chardev one named
# pipe and waits for its client before it starts (pipe-path), each pipe's
# in-file is a plain file a writer appends to (pipe-write), and `relays`
# names the relay each pipe with no client of its own takes, the
# monitor's, the API's, and a scripted pad's port (relays-of), its
# binary `relay_binary` (relay-build), none and "" elsewhere;
# `bridge_pipe` is the pipe the pad bridge writes, "" with no pad port
# (bridge-pipe). The machine is headless unless `--window` puts it in the
# window a run of the program would open (`window`, `none` without); the sound device
# records to `sound` with `--sound`, or plays through the host's audio as
# a run's does with `--live-sound` (`audio`, the backend); and
# `--host-pad` attaches the host's own gamepad as a run does, on macOS
# through the bridge `bridge` names, to be started beside QEMU. A
# recording and the host's audio together are refused, as is the host's
# pad beside a scripted one. A previous run's files in `out` are retired
# into the retire home of `target`, the workspace's target or else the
# program's, wherever `out` lies (retire), its pipes kept; `target` is
# handed back for a harness that clears away files of its own. The
# machine is the one `--spec` names, or with `--harts` a custom one of 1
# to 8 harts, or with neither the configured default (machine-for), and
# `machine` is its record (machine-of), `below_minimum` true beside it
# where `bootargs` carries a debug kernel's jab.nominimum=1, which skips
# the program's minimum (knob-of); a named spec the image's demand
# does not list is refused before anything is made, a legacy image's run
# taking the named machine. `bootargs` goes to the kernel through QEMU's
# -append, into the device tree's /chosen, a named spec's
# `jab.spec=<name>` after it (spec-bootargs), where a debug kernel reads its test
# knobs, and the record's `bootargs` is the line as given; `dtb` hands the kernel that
# tree through -dtb in place of the one QEMU builds, QEMU checking its
# header before any hart runs. `demand` is the demand recorded with the
# image at its build (image-demand), null for a program on the legacy path
# and for an image with no record; a record that does not hold is refused.
# `send` is what a launch writes into the API at its times, kept as given
# in `sends`, and anything to send puts the port on as `--api` does. With
# `--sdl-probe`, a probing launch, Linux only: the window `sdl,gl=on`, the
# sdl shim built and preloaded beside any other (`shim`), logging to that
# file (`sdl_log`, a stale one retired), SDL's offscreen driver where no
# display server is. `capture_nonce` is the caller's, never minted here,
# 1 to 2^63 - 1 or none, handed to the shim as `SDL_SHIM_NONCE` in its
# sixteen hex digits (nonce-hex); `profile` the capture's, `paired` only
# with a nonce, `generic` for a probe that names none, "" for a run that
# claims none; `capture` the run's capture identity as it stands before
# QEMU starts (capture-identity).
export def plan [
    --kernel: path
    --image: path
    --out: path
    --api
    --disk: path = ""
    --serial: string = "disk0"
    --set: string = ""
    --gamepad
    --pad-port
    --no-kbm
    --sound
    --window
    --live-sound
    --host-pad
    --spec: string = ""
    --harts: int = 0
    --bootargs: string = ""
    --dtb: path = ""
    --send: table<at: duration, bytes: binary> = []
    --sdl-probe: path = ""
    --capture-nonce: int = 0
    --profile: string = ""
]: nothing -> record<qemu_binary: string, timeout_binary: string, timeout_version: string, qemu: list<string>, env: record, out: string, serial_log: string, qemu_log: string, screen: string, pidfile: string, monitor: string, debug_log: string, api_in: string, api_out: string, pad_fifo: string, pad_pipe_in: string, pad_port: bool, pad_header: string, sound: string, workspace: string, target: string, window: string, audio: string, bridge: oneof<record<name: string, vendor: oneof<int, nothing>, product: oneof<int, nothing>>, nothing>, bridge_pipe: string, relays: list<record<endpoint: string, name: string, inward: string, outward: string, done: string>>, relay_binary: string, machine: record, bootargs: string, demand: oneof<record, nothing>, sends: table<at: duration, bytes: binary>, sdl_log: string, shim: string, capture_nonce: oneof<int, nothing>, profile: string, capture: record> {
    let out = ($out | path expand)
    let ws = (launch-workspace $kernel $image $out)
    # a debug kernel's jab.nominimum=1 skips a program's minimum, so the run
    # is recorded below it, where a release kernel reads no knob and refuses
    let asked = (machine-for $ws $spec $harts)
    let machine = (if (knob-of $bootargs "jab.nominimum") == 1 { $asked | insert below_minimum true } else { $asked })
    let demand = (image-demand $image)
    spec-listed $machine $demand ($image | path parse | get stem)
    if $sound and $live_sound { error make {msg: "--sound and --live-sound together: the recording or the host's audio, one or the other"} }
    if $host_pad and ($gamepad or $pad_port) { error make {msg: "--host-pad with a scripted pad: the host's own gamepad or a table, one or the other"} }
    let probed = ($sdl_probe != "")
    if $probed and $nu.os-info.name != "linux" { error make {msg: "--sdl-probe preloads the sdl shim into QEMU, which is Linux only"} }
    if $capture_nonce < 0 { error make {msg: $"--capture-nonce ($capture_nonce): a capture nonce is 1 to 2^63 - 1, or 0 for none"} }
    let profile = (if $profile == "" and $probed { "generic" } else { $profile })
    if $profile not-in ["" "generic" "paired"] { error make {msg: $"--profile ($profile): a capture's profile is paired or generic"} }
    if $profile == "generic" and not $probed { error make {msg: "--profile generic is a probing launch's, classification alone; it needs --sdl-probe"} }
    if $profile == "paired" and $capture_nonce == 0 { error make {msg: "--profile paired needs the run's --capture-nonce, minted by the caller that makes the request"} }
    mkdir $out
    let root = (target-root (if $ws != null { $ws } else { image-home $image }))
    let log = ($out | path join "serial.log")
    let qemu_log = ($out | path join "qemu.log")
    let screen = ($out | path join "screen.ppm")
    let pidfile = ($out | path join "qemu.pid")
    let monitor = ($out | path join "monitor")
    for f in [$log $qemu_log $screen $pidfile] { retire $f $root }
    # a Windows run's pipes are named pipes, named by a nonce of its own
    let windows = ($nu.os-info.name == "windows")
    let nonce = (if $windows { random int 1.. } else { 0 })
    let watch = (if $windows { pipe-pair $out "monitor" $nonce "windows" $root } else {
        fifo-at ($monitor + ".in") $root
        fifo-at ($monitor + ".out") $root
        { name: $monitor, inward: ($monitor + ".in"), outward: ($monitor + ".out") }
    })
    let qemu = (qemu-binary (image-home $image) $ws)
    let bound = (timeout-binary)
    let found = (if (discovery-wanted $host_pad $live_sound) { discover $ws } else { { gamepad: null, audio: null } })
    let hosted = (if $host_pad { gamepad-plan $found } else { { args: [], port: false, bridge: null } })
    let pad = (pad-attach $gamepad $out $pad_port $ws $root)
    let api_on = ($api or (not ($send | is-empty)))
    let ports = (ports (symbols $set) $out $api_on ($pad.port or $hosted.port) $root $nonce)
    # Windows' relays, one a pipe with no client of its own: the monitor's,
    # the API's, and a scripted pad's port, the host's pad's client being
    # the bridge
    let piped = (if not $windows { [] } else {
        [{ endpoint: "monitor", pipe: $watch } { endpoint: "api", pipe: $ports.api }] ++ (if $hosted.port { [] } else { [{ endpoint: "padport", pipe: $ports.pad }] })
    })
    let relays = (relays-of $out $piped)
    let relay_binary = (relay-build $relays $ws)
    let inputs = (if $no_kbm { [] } else { $input_devices })
    let wav = (if $sound { $out | path join "sound.wav" } else { "" })
    if $wav != "" { retire $wav $root }
    let backend = (if $sound { $"wav,path=($wav)" } else if $live_sound { audio-plan ($found | get -o audio) } else { "" })
    let audio = (if $sound { sound-args $backend --streams 1 } else if $live_sound { sound-args $backend } else { [] })
    if $probed and $ws == null { error make {msg: "--sdl-probe needs the program's workspace, which holds shim/crates/sdl"} }
    let shim = (if $probed { shim-build $ws "jabshim_sdl" } else { "" })
    let sdl_log = (if $probed { $sdl_probe | path expand } else { "" })
    if $probed { retire $sdl_log $root }
    let shown = (if $probed { "sdl,gl=on" } else if $window { display (image-manifest $image) } else { "none" })
    let run_env = (if not $probed { $pad.env } else {
        let server = (($env.DISPLAY? | default "") != "") or (($env.WAYLAND_DISPLAY? | default "") != "")
        let preload = ([($pad.env | get -o LD_PRELOAD | default "") $shim] | where {|p| $p != "" } | str join " ")
        let nonce = (if $capture_nonce == 0 { {} } else { { SDL_SHIM_NONCE: (nonce-hex $capture_nonce) } })
        let driver = (if $server { {} } else { { SDL_VIDEODRIVER: "offscreen" } })
        $pad.env | merge { LD_PRELOAD: $preload, SDL_SHIM_LOG: $sdl_log } | merge $nonce | merge $driver
    })
    let line = (spec-bootargs $machine $bootargs)
    let append = (if $line == "" { [] } else { ["-append" $line] }) ++ (if $dtb == "" { [] } else { ["-dtb" ($dtb | path expand)] })
    let args = ((machine-args $qemu $machine) ++ (name-args ($image | path parse | get stem)) ++ (memory-args $machine) ++ $display_device ++ $inputs ++ $hosted.args ++ $rng_device ++ $audio ++ $ports.args ++ $pad.args ++ [
        "-bios" "none" "-kernel" ($kernel | path expand)
        "-device" $"loader,file=($image | path expand),addr=($program_base),force-raw=on"
        "-display" $shown "-monitor" $"pipe:($watch.name)" "-serial" $"file:($log)"
        "-pidfile" $pidfile "-d" "guest_errors" "-D" $qemu_log
    ] ++ $append ++ (disks-args (machine-disks $disk $serial true $ws)))
    let planned = {
        qemu_binary: $qemu,
        timeout_binary: $bound.path,
        timeout_version: $bound.version,
        qemu: $args,
        env: $run_env,
        out: $out,
        serial_log: $log,
        qemu_log: $qemu_log,
        screen: $screen,
        pidfile: $pidfile,
        monitor: $monitor,
        debug_log: $ports.debug_log,
        api_in: (if $ports.api == null { "" } else { $ports.api.inward }),
        api_out: (if $ports.api == null { "" } else { $ports.api.outward }),
        pad_fifo: $pad.fifo,
        pad_pipe_in: (if $ports.pad == null { "" } else { $ports.pad.inward }),
        pad_port: $pad.port,
        pad_header: ($pad.header | encode hex),
        sound: $wav,
        workspace: ($ws | default ""),
        target: $root,
        window: $shown,
        audio: $backend,
        bridge: $hosted.bridge,
        bridge_pipe: (bridge-pipe $ports.pad),
        relays: $relays,
        relay_binary: $relay_binary,
        machine: $machine,
        bootargs: $line,
        demand: $demand,
        sends: $send,
        sdl_log: $sdl_log,
        shim: $shim,
        capture_nonce: (if $capture_nonce == 0 { null } else { $capture_nonce }),
        profile: $profile,
    }
    $planned | insert capture (capture-identity $planned null)
}

# A run's capture identity, what its identity records of the capture
# (CaptureBundle), from a machine as plan prepared it and the pid of the
# QEMU that ran it, read while it lived (null before or without one): the
# profile; `capture_nonce`; `qemu_pid`; the shim's log and library, ""
# for a run unprobed; the window; `api`, whether the API's port was on the
# machine; and `sends`, each entry to write into it by its time in
# seconds, its bytes' length, and their SHA-256.
export def capture-identity [machine: record, pid: oneof<int, nothing>]: nothing -> record<profile: string, capture_nonce: oneof<int, nothing>, qemu_pid: oneof<int, nothing>, sdl_log: string, shim: string, window: string, api: bool, sends: list<record<at: float, length: int, sha256: string>>> {
    {
        profile: $machine.profile,
        capture_nonce: $machine.capture_nonce,
        qemu_pid: $pid,
        sdl_log: $machine.sdl_log,
        shim: $machine.shim,
        window: $machine.window,
        api: ($machine.api_in != ""),
        sends: ($machine.sends | each {|s| { at: ($s.at / 1sec), length: ($s.bytes | bytes length), sha256: ($s.bytes | hash sha256) } }),
    }
}

# A launch's capture nonce: the one its caller gives, else for a probing
# launch one minted here, 1 to 2^63 - 1, so 0 names none and a launch
# never mints a second; plan never mints (CaptureBundle).
export def launch-nonce [given: int, probed: bool]: nothing -> int {
    if $given != 0 or not $probed { return $given }
    random int 1..
}

# A capture nonce as the shim's log writes it: sixteen lowercase hex
# digits.
export def nonce-hex [nonce: int]: nothing -> string {
    $nonce | into binary --endian big | encode hex | str lowercase
}

# The workspace a launch belongs to, whose generic disk rides along and
# whose shims play a pad: the one the image's program builds against
# (workspace-of, through the manifest at the image's home), since the
# target an image and a kernel sit in can lie outside every workspace;
# else the one above the kernel's ELF, else the one above `out`.
def launch-workspace [kernel: path, image: path, out: path]: nothing -> oneof<string, nothing> {
    let home = (image-home $image)
    let manifest = ($home | path join "program.jab.toml")
    let found = (if ($manifest | path exists) { try { workspace-of $home (open $manifest) } catch { null } } else { null })
    if $found != null { return $found }
    workspace-dir ($kernel | path expand) | default (workspace-dir $out)
}

# The manifest of the program an image was built from (image-home), for
# the window it names; an empty record when there is none.
def image-manifest [image: path]: nothing -> record {
    let manifest = (image-home $image | path join "program.jab.toml")
    if ($manifest | path exists) { open $manifest } else { {} }
}

# Run a program on the kernel under QEMU with no window, the UART to
# serial.log in `out`, for at most `seconds`. The status is what jab.sys.exit
# gave, 1 on a program fault, 124 when the bound ended the run. With
# `capture`, the screen is taken into screen.ppm that long after the
# start and the run is then ended (status 0); with `screen`, it is taken
# that long after the start while the run goes on to its bound or its
# exit; with `keys`, each key is pressed through the monitor that long
# after the start. `set` names the
# symbols the kernel was built with: DEBUG puts the kernel's debug
# channel on the machine, whose text comes back as `debug`. With `api`,
# or with anything to `send`, the API's port is on the machine: each
# entry of `send` is written into it that long after the start, and
# every byte the program sent, landed in api.out, comes back as `api`.
# QEMU's own complaints about the guest go to qemu.log and what it
# wrote to its stderr comes back as `stderr`, so a backend's complaint
# reaches a test; cpu_seconds is the QEMU process's CPU time over the
# run, on a host with /proc, and wall_seconds the run's length. The
# timed actions, the pad header, the keys, the API bytes, the pad
# events, and the screen, go in while QEMU's process is alive, which
# is asked of the process table rather than of /proc, so they happen
# on every host. Each poll takes the keys, the API bytes, and the pad
# events in due-order's order: every one due in the order of its time,
# and the screen after those due before its time and ahead of those
# due at or after it, which wait until its file is whole
# (screen-whole); a screen that fails or never comes whole leaves the
# result no screen and every action after it unwritten.
# `screen_started` and `screen_completed` are the screen's asking and
# its file's completion, and `send_seconds` each entry of `send`'s
# write, all seconds from the start, null for what never happened. The
# workspace, whose generic disk rides along and whose shim plays a pad,
# is the one above the kernel ELF, else the one above `out`. `--window`, `--live-sound`, and `--host-pad` put the
# machine on the host as a run puts it, the window, the host's audio,
# and the host's own gamepad (plan), with the bridge run beside QEMU
# where the pad needs one and ended after; the screen and the timed
# actions go through the monitor and the pipes as headless. The result
# carries the machine's line, `qemu_binary` and `qemu`, with the
# `window` and the `audio` backend it ran with, and `machine`, the
# record of the machine it had (machine-of); `--spec`, `--harts`,
# `--bootargs`, and `--dtb` are plan's. With `--threads`, every QEMU thread's CPU is read
# that long after the start and again a second on (threads-of), each
# reading timed as it is taken, since the loop polls: `threads_span` is
# the seconds between the two, a second give or take a poll, and
# `threads` carries each thread's name, the CPU seconds it used in
# between, and those over the span (threads-between), the harts' threads
# named `CPU N/TCG` on Linux; empty, its span null, when the run ended
# before the second reading. With `--threads-at`, every QEMU thread's
# cumulative CPU seconds are read at each time it lists, `thread_readings`
# keeping each reading whole: the time asked, `requested`, and the time
# it was taken, `at`, both seconds from the launch's start, which comes
# before QEMU's spawn, the reading taken at the first poll past its
# request, so `at` trails `requested` by up to a poll; and every thread's
# id, name, and counter (threads-of); a time the run ended before keeps
# its request with `at` and `threads` null, missing. `--qemu` appends words of its own
# to the line, unchanged, after the launch's: a device or a property a
# test needs that no launch flag gives. Such a run is diagnostic, its
# `machine` keeping the platform asked for with the words in its
# `overrides`, and the words
# come back apart as `overrides` too, so the requested platform and the
# custom command stay distinct; `qemu` is the line as it ran. `declared`
# says whether the demand recorded with the image at its build declares
# one (image-demand), and `diagnostic` is the run's standing: on a
# custom machine, with QEMU words of its own, of an image built on the
# legacy path or with no record beside it, undeclared and claiming no
# console, or below its program's minimum (plan's `below_minimum`). `--sdl-probe`,
# `--capture-nonce`, and `--profile` are plan's, the nonce the caller's,
# minted here only for a probing launch given none (launch-nonce); the
# launch writes the API only what its caller sends, never for itself. On
# Windows, where QEMU waits for a client of each of its pipes before it
# starts, the relays plan names start beside QEMU, a job each
# (relays-start), every write goes into a pipe's in-file (pipe-write), and
# once QEMU has ended each relay is given a second to end with its pipe,
# any left stopped, and one that ended in failure fails the launch,
# naming its pipe (relays-held).
# `qemu_pid` is QEMU's pid as the loop read it while QEMU lived, since
# QEMU removes its pid file as it exits, null where it never came up; the
# result carries `sdl_log`, `shim`, `capture_nonce`, and `profile` as
# planned, and `capture`, the run's capture identity (capture-identity).
export def launch [
    --kernel: path             # the kernel ELF
    --image: path              # the program's .jab
    --out: path                # where serial.log and the rest go
    --seconds: int = 10        # the bound
    --capture: duration = 0sec # when to take the screen and end the run; 0 never
    --screen: duration = 0sec  # when to take the screen while the run goes on; 0 never
    --keys: table<at: duration, key: string, hold: int> = [] # keys to press that long after the start, QEMU's names, held for hold ms
    --api                      # put the API's port on the machine
    --send: table<at: duration, bytes: binary> = [] # bytes to write into the API that long after the start; puts the port on the machine
    --disk: path = ""          # a raw image to put on the machine as its first virtio-blk disk; the workspace's generic disk follows it
    --serial: string = "disk0" # the disk's serial, which the guest reads back as its own; 19 characters at most
    --set: string = ""         # the symbols the kernel was built with, comma separated
    --pad: path = ""           # a NUON file of pad events, [[at, type, code, value]; ...], played as a gamepad: into a fifo attached through the evdev shim on Linux, else into the pad port
    --pad-port                 # play --pad into the pad port on Linux too, the route every other host takes
    --kbm                      # the keyboard and the tablet on the machine, which is the default
    --no-kbm                   # neither on the machine
    --sound                    # the sound device on the machine, its output recorded to sound.wav in `out`, handed back as `sound`
    --window                   # the window a run of the program opens, in place of none
    --live-sound               # the sound device over the host's audio as a run discovers it, in place of the --sound recording
    --host-pad                 # the host's own gamepad as a run attaches it, in place of a --pad table
    --spec (-s): string = ""   # the named spec the machine is, its cores, RAM, and display; the configured default unless given
    --harts: int = 0           # a custom machine of 1 to 8 harts in place of a named spec, the run then diagnostic
    --bootargs: string = ""    # the kernel's command line, its debug knobs, through -append
    --dtb: path = ""           # a device tree for the kernel in place of QEMU's, through -dtb
    --threads: duration = 0sec # when to read every QEMU thread's CPU and again a second on, the result's `threads` and `threads_span`; 0 never
    --threads-at: list<duration> = [] # each time to read every QEMU thread's CPU, kept whole in the result's `thread_readings`; none unless given
    --qemu: list<string> = []  # words appended to the QEMU line unchanged, after the launch's own; the run is then diagnostic
    --sdl-probe: path = ""     # the sdl shim's log: QEMU under sdl,gl=on with the shim preloaded, Linux only
    --capture-nonce: int = 0   # the run's capture nonce from the caller making the request; minted here for a probe given none
    --profile: string = ""     # the capture's profile, paired or generic (plan)
]: nothing -> record<status: int, serial: string, debug: string, api: binary, screen: string, qemu_log: string, stderr: string, cpu_seconds: float, wall_seconds: float, sound: string, qemu_binary: string, timeout_binary: string, timeout_version: string, qemu: list<string>, overrides: list<string>, window: string, audio: string, machine: record, threads: list<record<name: string, delta: float, rate: float>>, threads_span: oneof<float, nothing>, thread_readings: list<any>, screen_started: oneof<float, nothing>, screen_completed: oneof<float, nothing>, send_seconds: list<oneof<float, nothing>>, declared: bool, diagnostic: bool, qemu_pid: oneof<int, nothing>, sdl_log: string, shim: string, capture_nonce: oneof<int, nothing>, profile: string, capture: record> {
    if $kbm and $no_kbm { error make {msg: "--kbm and --no-kbm together: one or the other"} }
    if $capture != 0sec and $screen != 0sec { error make {msg: "--capture and --screen together: one screen a run, ending it or not"} }
    let gamepad = (pad-table $pad)
    let nonce = (launch-nonce $capture_nonce ($sdl_probe != ""))
    let machine = (plan --kernel $kernel --image $image --out $out --api=$api --send $send --disk $disk --serial $serial --set $set --gamepad=(not ($pad | is-empty)) --pad-port=$pad_port --no-kbm=$no_kbm --sound=$sound --window=$window --live-sound=$live_sound --host-pad=$host_pad --spec $spec --harts $harts --bootargs $bootargs --dtb $dtb --sdl-probe $sdl_probe --capture-nonce $nonce --profile $profile)
    let send = $machine.sends
    let out = $machine.out
    let log = $machine.serial_log
    let qemu_log = $machine.qemu_log
    let screen_file = $machine.screen
    let pidfile = $machine.pidfile
    let monitor = $machine.monitor
    let ports = { debug_log: $machine.debug_log }
    let wav = $machine.sound
    let line = ($machine.qemu ++ $qemu)
    let disked = (["--signal=TERM" $"($seconds)" $machine.qemu_binary] ++ $line)
    let api_out = $machine.api_out
    let api_in = $machine.api_in
    let pad_in = $machine.pad_pipe_in
    let gamepad = ($gamepad | merge { port: $machine.pad_port, fifo: $machine.pad_fifo, header: ($machine.pad_header | decode hex), env: $machine.env })
    let bridge = (if $machine.bridge == null { null } else {
        let bin = (shim-build $machine.workspace "jabshim_pad" --bin)
        let b = $machine.bridge
        let vendor = (if $b.vendor == null { "" } else { $b.vendor | into string })
        let product = (if $b.product == null { "" } else { $b.product | into string })
        let pipe = $machine.bridge_pipe
        job spawn { ^$bin $pipe $b.name $vendor $product | complete | ignore }
    })
    # the timed actions in the order a poll takes them (due-order): by
    # time, and at one time the keys, then the API's bytes, then the pad's
    # groups, each in its table's order
    let events = ([
        ($keys | enumerate | each {|e| { kind: "key", index: $e.index, at: $e.item.at } })
        ($send | enumerate | each {|e| { kind: "send", index: $e.index, at: $e.item.at } })
        ($gamepad.groups | enumerate | each {|e| { kind: "pad", index: $e.index, at: $e.item.at } })
    ] | flatten | enumerate | each {|e| $e.item | insert order $e.index } | sort-by at order | reject -o order)
    let started = (date now)
    let bound = $machine.timeout_binary
    job spawn { with-env $gamepad.env { ^$bound ...$disked | complete } | job send 0 }
    let relays = (relays-start $machine.relays $machine.relay_binary $machine.target)
    mut result: any = null
    mut cpu = 0.0
    mut events_taken = 0
    mut screen_due = (if $capture != 0sec { $capture } else if $screen != 0sec { $screen } else { null })
    mut screen_started: any = null
    mut screen_completed: any = null
    mut held = false
    mut send_seconds = ($send | each --keep-empty {|_| null })
    mut header_sent = (not $gamepad.port)
    mut threads_first: any = null
    mut threads_held: any = null
    let thread_requests = ($threads_at | sort)
    mut readings = []
    mut taken = 0
    mut qemu_pid: any = null
    while $result == null {
        $result = (try { job recv --timeout 100ms } catch { null })
        # QEMU deletes its pid file as it exits, so the read is tried, never
        # checked first: an exit between a check and the open is no pid
        let pid = (try { open --raw $pidfile | str trim } catch { "" })
        let alive = ($result == null and (process-alive $pid))
        # the pid kept while QEMU lives, its pid file gone once it ends
        if $alive and $qemu_pid == null { $qemu_pid = ($pid | into int) }
        let sample = (if $pid == "" { null } else { cpu-seconds $pid })
        if $sample != null { $cpu = $sample }
        let elapsed = ((date now) - $started)
        # the pad port's header goes in as soon as QEMU is up, before any
        # event, since the kernel waits for the whole of it
        # every write into QEMU's pipes is bounded (pipe-write), since QEMU
        # can end between the check that it runs and the write
        if (not $header_sent) and $alive {
            pipe-write $pad_in $gamepad.header $bound | ignore
            $header_sent = true
        }
        # every due action in due-order's order: a screen that fails holds
        # every action after it for the rest of the run, as the capture's
        # quit does
        if not $held {
            for action in (due-order ($events | skip $events_taken) $screen_due $elapsed) {
                if $action.kind == "screen" {
                    $screen_started = (((date now) - $started) / 1sec)
                    let asked = (if $alive { monitor-send $monitor $"screendump (hmp-quoted $screen_file)" $bound } else { false })
                    if not ($asked and (screen-whole $screen_file)) {
                        $held = true
                        break
                    }
                    $screen_completed = (((date now) - $started) / 1sec)
                    $screen_due = null
                    if $capture != 0sec {
                        if (process-alive $pid) { monitor-send $monitor "quit" $bound | ignore }
                        $held = true
                        break
                    }
                } else {
                    let written = (if not $alive { false } else if $action.kind == "key" {
                        let k = ($keys | get $action.index)
                        monitor-send $monitor $"sendkey ($k.key) ($k.hold)" $bound
                    } else if $action.kind == "send" {
                        if $api_in == "" { false } else { pipe-write $api_in ($send | get $action.index | get bytes) $bound }
                    } else {
                        let g = ($gamepad.groups | get $action.index)
                        if $gamepad.port { pipe-write $pad_in (pad-frames $g.items) $bound } else if $gamepad.fifo != "" { fifo-write $gamepad.fifo (pad-report $g.items) $bound } else { false }
                    })
                    if $written and $action.kind == "send" {
                        $send_seconds = ($send_seconds | update $action.index (((date now) - $started) / 1sec))
                    }
                    $events_taken += 1
                }
            }
        }
        # each thread's CPU over the held span: a reading at `threads`,
        # another a second on, each timed as it is taken, since the loop
        # polls and the span is a second give or take a poll
        if $threads != 0sec and $alive {
            if $threads_first == null and $elapsed >= $threads {
                let reading = (threads-of ($pid | into int))
                $threads_first = { threads: $reading, at: (date now) }
            } else if $threads_first != null and $threads_held == null and $elapsed >= ($threads + 1sec) {
                let reading = (threads-of ($pid | into int))
                let at = (date now)
                $threads_held = (threads-between $threads_first.threads $reading (($at - $threads_first.at) / 1sec))
            }
        }
        # every thread's counter at each time `--threads-at` asks, read at
        # the first poll past it, its own time taken with it
        while $alive and $taken < ($thread_requests | length) and ($thread_requests | get $taken) <= $elapsed {
            let threads = (threads-of ($pid | into int))
            $readings = ($readings | append { requested: (($thread_requests | get $taken) / 1sec), at: (((date now) - $started) / 1sec), threads: $threads })
            $taken += 1
        }
    }
    let unread = ($thread_requests | skip $taken | each {|r| { requested: ($r / 1sec), at: null, threads: null } })
    let relayed = (relays-stop $relays)
    if $bridge != null { try { job kill $bridge } }
    relays-held $relayed $result
    let ran_on = ($machine.machine | update overrides $qemu)
    {
        status: $result.exit_code,
        serial: (if ($log | path exists) { open --raw $log | decode } else { "" }),
        debug: (if $ports.debug_log != "" and ($ports.debug_log | path exists) { open --raw $ports.debug_log | decode } else { "" }),
        api: (if $api_out != "" and ($api_out | path exists) { open --raw $api_out | into binary } else { 0x[] }),
        screen: (if $screen_completed != null { $screen_file } else { "" }),
        qemu_log: $qemu_log,
        stderr: $result.stderr,
        cpu_seconds: $cpu,
        wall_seconds: (((date now) - $started) / 1sec),
        sound: (if $wav != "" and ($wav | path exists) { $wav } else { "" }),
        qemu_binary: $machine.qemu_binary,
        timeout_binary: $machine.timeout_binary,
        timeout_version: $machine.timeout_version,
        qemu: $line,
        overrides: $qemu,
        window: $machine.window,
        audio: $machine.audio,
        machine: $ran_on,
        threads: (if $threads_held == null { [] } else { $threads_held.threads }),
        threads_span: (if $threads_held == null { null } else { $threads_held.span }),
        thread_readings: ($readings | append $unread),
        screen_started: $screen_started,
        screen_completed: $screen_completed,
        send_seconds: $send_seconds,
        declared: ($machine.demand != null),
        diagnostic: ($ran_on.diagnostic != null or (not ($qemu | is-empty)) or $machine.demand == null or ($ran_on | get -o below_minimum | default false)),
        qemu_pid: $qemu_pid,
        sdl_log: $machine.sdl_log,
        shim: $machine.shim,
        capture_nonce: $machine.capture_nonce,
        profile: $machine.profile,
        capture: (capture-identity $machine $qemu_pid),
    }
}

# The order a launch's poll takes its timed actions in, `elapsed` after
# the start: every event due by then, its `at` at or before it, in the
# order of their times and at one time in the order given; and the
# screen, due at `screen` while it is still to take (null when none
# is), once due after every event due before its time and ahead of
# every event due at or after it, which wait on it, the poll writing
# them only once the screen is whole. The events come back as given,
# the screen as a row of kind `screen`, its `index` 0 and its `at` its
# time.
export def due-order [events: table<kind: string, index: int, at: duration>, screen: oneof<duration, nothing>, elapsed: duration]: nothing -> table<kind: string, index: int, at: duration> {
    let due = ($events | enumerate | each {|e| $e.item | insert order $e.index } | where {|e| $e.at <= $elapsed } | sort-by at order | reject -o order)
    if $screen == null or $screen > $elapsed { return $due }
    ($due | where {|e| $e.at < $screen }) ++ [{ kind: "screen", index: 0, at: $screen }] ++ ($due | where {|e| $e.at >= $screen })
}

# The device tree QEMU builds for a launch's machine, the one `--spec`
# names, a custom one of `--harts` harts, or the configured default
# (machine-for), written to the file `out` through -machine dumpdtb, QEMU
# exiting once it is written and before any hart runs, `bootargs` in
# /chosen as a launch's -append puts it, a named spec's
# `jab.spec=<name>` after it; the kernel and the image place the line as plan
# places it, and a previous file there is retired. The file's path.
export def dump-tree [--kernel: path, --image: path, --out: path, --spec: string = "", --harts: int = 0, --bootargs: string = ""]: nothing -> string {
    let file = ($out | path expand)
    let dir = ($file | path dirname)
    let ws = (launch-workspace $kernel $image $dir)
    let machine = (machine-for $ws $spec $harts)
    mkdir $dir
    let root = (target-root (if $ws != null { $ws } else { image-home $image }))
    retire $file $root
    let qemu = (qemu-binary (image-home $image) $ws)
    let line = (spec-bootargs $machine $bootargs)
    let append = (if $line == "" { [] } else { ["-append" $line] })
    let args = ((machine-args $qemu $machine --options $"dumpdtb=($file)") ++ (memory-args $machine) ++ ["-bios" "none" "-kernel" ($kernel | path expand) "-display" "none"] ++ $append)
    let made = (^$qemu ...$args | complete)
    if $made.exit_code != 0 or not ($file | path exists) { error make {msg: $"QEMU wrote no device tree to ($file): ($made.stderr | str trim)"} }
    $file
}

# Read a wav QEMU's wav backend recorded: its rate, channels, and bits
# a sample from the format chunk, and the data chunk's samples as they
# lie, little-endian, the channels interleaved a frame at a time, to the
# end of the file when the chunk's size was never written.
export def wave [path: path]: nothing -> record<rate: int, channels: int, bits: int, frames: int, samples: binary> {
    let bytes = (open --raw ($path | path expand) | into binary)
    let total = ($bytes | bytes length)
    if ($bytes | bytes at 0..<4 | decode) != "RIFF" or ($bytes | bytes at 8..<12 | decode) != "WAVE" { error make {msg: $"($path): not a wav"} }
    mut at = 12
    mut rate = 0
    mut channels = 0
    mut bits = 0
    mut samples = 0x[]
    while $at + 8 <= $total {
        let id = ($bytes | bytes at $at..<($at + 4) | decode)
        let size = ($bytes | bytes at ($at + 4)..<($at + 8) | into int --endian little)
        let body = ($at + 8)
        if $id == "fmt " {
            $channels = ($bytes | bytes at ($body + 2)..<($body + 4) | into int --endian little)
            $rate = ($bytes | bytes at ($body + 4)..<($body + 8) | into int --endian little)
            $bits = ($bytes | bytes at ($body + 14)..<($body + 16) | into int --endian little)
        } else if $id == "data" {
            # the backend writes this size as it closes the file, which
            # QEMU 11.1.2 never does at exit, so a size of 0, or one past
            # the file's end, means the samples run to the end of the file
            let unwritten = ($size == 0 or ($body + $size) > $total)
            $samples = ($bytes | bytes at $body..<(if $unwritten { $total } else { $body + $size }))
            if $unwritten { break }
        }
        $at = ($body + $size + ($size mod 2))
    }
    if $rate == 0 or $channels == 0 { error make {msg: $"($path): no format chunk"} }
    { rate: $rate, channels: $channels, bits: $bits, frames: (($samples | bytes length) // ($channels * ($bits // 8))), samples: $samples }
}

# Read a screen `jab launch` took: its size and its pixels, three bytes
# each, red, green, blue, row by row from the top left.
export def screen [path: path]: nothing -> record<width: int, height: int, pixels: binary> {
    # Bytes whatever the file holds: `open --raw` gives text for a file of
    # valid UTF-8, a capture whose every channel is below 0x80 among them
    let bytes = (open --raw ($path | path expand) | into binary)
    # P6, a line of width and height, the maximum, then the pixels
    let newlines = ($bytes | bytes index-of --all 0x[0a] | take 3)
    let header = ($bytes | bytes at 0..<($newlines.2) | decode | lines)
    let size = ($header.1 | split row " ")
    { width: ($size.0 | into int), height: ($size.1 | into int), pixels: ($bytes | bytes at ($newlines.2 + 1)..) }
}

# Where a color is on a screen: how many pixels have it and their
# bounding box (-1 all round when none do). `color` is six hex digits,
# RRGGBB.
export def ink [screen: record<width: int, height: int, pixels: binary>, color: string]: nothing -> record<count: int, left: int, top: int, right: int, bottom: int> {
    let pattern = ($color | decode hex)
    let hits = ($screen.pixels | bytes index-of --all $pattern | where {|i| $i mod 3 == 0 })
    if ($hits | is-empty) { return { count: 0, left: -1, top: -1, right: -1, bottom: -1 } }
    let xs = ($hits | each {|i| ($i // 3) mod $screen.width })
    let ys = ($hits | each {|i| ($i // 3) // $screen.width })
    { count: ($hits | length), left: ($xs | math min), top: ($ys | math min), right: ($xs | math max), bottom: ($ys | math max) }
}

# The color of the pixel at x, y as six hex digits, RRGGBB.
export def pixel [screen: record<width: int, height: int, pixels: binary>, x: int, y: int]: nothing -> string {
    let i = (($y * $screen.width + $x) * 3)
    $screen.pixels | bytes at $i..<($i + 3) | encode hex | str lowercase
}

# A rough look at a screen as text, one character per block from the
# pixel at the block's centre: space for black, then . o # by
# brightness.
export def thumbnail [screen: record<width: int, height: int, pixels: binary>, --columns: int = 96, --rows: int = 27]: nothing -> string {
    let block_w = ($screen.width // $columns)
    let block_h = ($screen.height // $rows)
    let row_bytes = ($screen.width * 3)
    0..<$rows | each {|r|
        let y = ($r * $block_h + ($block_h // 2))
        let row = ($screen.pixels | bytes at ($y * $row_bytes)..<(($y + 1) * $row_bytes))
        0..<$columns | each {|c|
            let x = ($c * $block_w + ($block_w // 2))
            let p = ($row | bytes at ($x * 3)..<($x * 3 + 3))
            let brightness = (($p | bytes at 0..<1 | into int) + ($p | bytes at 1..<2 | into int) + ($p | bytes at 2..<3 | into int))
            if $brightness < 48 { " " } else if $brightness < 256 { "." } else if $brightness < 512 { "o" } else { "#" }
        } | str join ""
    } | str join "\n"
}

# The strings in a binary that start with `prefix`, each read to its
# terminator: how a test asks a kernel image what text it carries.
export def strings [path: path, prefix: string]: nothing -> list<string> {
    let bytes = (open --raw ($path | path expand) | into binary)
    let total = ($bytes | bytes length)
    $bytes | bytes index-of --all ($prefix | into binary) | each {|at|
        let tail = ($bytes | bytes at $at..<([($at + 256) $total] | math min))
        let end = ($tail | bytes index-of 0x[00])
        (if $end < 0 { $tail } else { $tail | bytes at 0..<$end }) | decode
    }
}

# The named functions of a program's ELF as QEMU's translator sees
# them: each one's start and end from the ELF's symbols, the end being
# the next symbol's address, an assembler constant passed over (`nm`
# lists a `.set` as an absolute symbol, its value no address, and one
# valued inside the code would cut a function short; JAB_DENIED's all
# ones would not even parse), whether it lies within one page of code,
# since a translation block ends at a page boundary and chains within
# a page only, so a loop straddling one runs several times slower, and
# how many ecalls its code holds, read from the disassembly, since a
# kernel call in a hot loop is a trap each time round. The tools are
# the ones the build's flags stamp names, beside the ELF.
export def hot [elf: path, names: list<string>]: nothing -> table<name: string, start: int, end: int, paged: bool, ecalls: int> {
    let elf = ($elf | path expand)
    let built = ($elf | path dirname)
    let prefix = (open --raw ($built | path join "flags") | lines | first | split row " " | last)
    let symbols = (^$"($prefix)nm" -n $elf | lines | parse "{addr} {kind} {name}" | where {|s| $s.kind not-in ["a" "A"] } | each {|s| { addr: ($s.addr | into int --radix 16), name: $s.name } })
    let ecalls = (^$"($prefix)objdump" -d $elf | lines | parse --regex '^\s*(?P<addr>[0-9a-f]+):\s+[0-9a-f]+\s+ecall\b' | each {|d| $d.addr | into int --radix 16 })
    $names | each {|name|
        let at = ($symbols | enumerate | where {|s| $s.item.name == $name } | get -o 0.index)
        if $at == null { error make {msg: $"($name) is not among the symbols of ($elf)"} }
        let start = ($symbols | get $at | get addr)
        let next = ($symbols | get -o ($at + 1))
        if $next == null { error make {msg: $"($name) is the last symbol of ($elf), so its end is unknown"} }
        let end = $next.addr
        {
            name: $name,
            start: $start,
            end: $end,
            paged: (($start // 4096) == (($end - 1) // 4096)),
            ecalls: ($ecalls | where {|a| $a >= $start and $a < $end } | length),
        }
    }
}

# The QEMU arguments that put raw images on the machine as virtio-blk
# disks, in the order given, so the first is disk 1 to the kernel. Each
# rides the PCI Express root rather than one of the eight mmio slots,
# modern-only and on INTx (`disable-legacy=on,vectors=0`), which is how
# the kernel drives it. A serial is what the guest reads back with
# jab.sys.block.list, so it is how a program tells one disk from another.
# An image built from assets, the program's own or the generic disk,
# is attached read-only, so a program cannot change what the next run
# reads: a write to it comes back to the program as the device's error
# code, and the file on the host is never touched. The blank data disk
# a run carries when a program ships no assets stays writable.
def disks-args [disks: table<id: string, file: string, serial: string, readonly: bool>]: nothing -> list<string> {
    $disks | each {|d| [
        "-drive" $"if=none,id=($d.id),file=($d.file | path expand),format=raw(if $d.readonly { ',readonly=on' } else { '' })"
        "-device" $"virtio-blk-pci,disable-legacy=on,vectors=0,drive=($d.id),serial=($d.serial)"
    ] } | flatten
}

# The disks a machine carries: the program's own first, when there is
# one, read-only when it is an asset image, then the generic assets
# disk, always read-only, when the workspace has one, so a program's
# disk is 1 and the generic disk 2, or 1 on its own.
def machine-disks [own: string, own_serial: string, own_readonly: bool, ws: oneof<string, nothing>]: nothing -> table<id: string, file: string, serial: string, readonly: bool> {
    let first = (if ($own | is-empty) { [] } else { [{ id: "disk0", file: $own, serial: $own_serial, readonly: $own_readonly }] })
    let mix = (mix-image $ws)
    let second = (if $mix == "" { [] } else { [{ id: "mix", file: $mix, serial: "mix", readonly: true }] })
    $first ++ $second
}

# The generic assets disk, disk 1 of every run and launch: `generic/`
# in the workspace mirrored to the image's root, plus what
# `generic/manifest.nuon` fetches, each entry an archive by URL and
# sha256 with the members to take and where each lands, so the large
# third-party assets, the soundfonts today, are never committed and
# are verified on every build. Staged under the target's generic/ and
# built into its mix.romfs whenever the tree or the manifest changes,
# the archives kept under its fetch/, a stale stage retired. The path,
# or "" with no workspace or no generic/ in it.
def mix-image [ws: oneof<string, nothing>]: nothing -> string {
    if $ws == null { return "" }
    let generic = ($ws | path join "generic")
    if not ($generic | path exists) { return "" }
    let target = (target-root $ws)
    let image = ($target | path join "mix.romfs")
    let stamp = ($target | path join "mix.flags")
    let manifest_path = ($generic | path join "manifest.nuon")
    let manifest = (if ($manifest_path | path exists) { open $manifest_path } else { [] })
    let inputs = (tree-under [$generic])
    let flags = (build-id ($manifest | to nuon) $inputs)
    if ($image | path exists) and (not (stale $image $inputs $flags $stamp)) { return $image }
    let stage = ($target | path join "generic")
    retire $stage $target
    mkdir $stage
    for f in (files-under [$generic]) {
        let relative = ($f | path relative-to $generic)
        if $relative == "manifest.nuon" { continue }
        let dest = ($stage | path join $relative)
        mkdir ($dest | path dirname)
        cp $f $dest
    }
    for entry in $manifest {
        let archive = (fetched $target $entry.url $entry.sha256)
        let unpack = ($target | path join "fetch" "unpack")
        retire $unpack $target
        mkdir $unpack
        ^tar -xzf $archive -C $unpack ...($entry.members | get from)
        for m in $entry.members {
            let dest = ($stage | path join $m.to)
            mkdir ($dest | path dirname)
            mv ($unpack | path join $m.from) $dest
        }
        retire $unpack $target
    }
    assets-names $stage
    ^genromfs -d $stage -f $image -V (volume-name "mix")
    $flags | save -f $stamp
    $image
}

# An archive the manifest names, fetched into the target's fetch/ on
# first use, which a run says once since it can take a while, and verified
# by its sha256 then and on every later build; a mismatch stops with
# both digests named.
def fetched [target: path, url: string, sha256: string]: nothing -> string {
    let dir = ($target | path join "fetch")
    mkdir $dir
    let file = ($dir | path join ($url | path basename))
    if not ($file | path exists) {
        http get --raw $url | save --raw -f $file
    }
    let digest = (open --raw $file | hash sha256)
    if $digest != $sha256 { error make {msg: $"($file): sha256 ($digest), where the manifest says ($sha256)"} }
    $file
}

# The ports, each of one virtio-serial-device: DEBUG in the build puts
# the kernel's debug channel on port 1 with the host's end a file,
# debug.log in `out`; `api` puts the API on port 2 with the host's end
# QEMU's pipe chardev over the pipe pair api.in and api.out (pipe-pair),
# api.in what the host writes into and api.out a plain file the
# program's bytes land in as they are sent, both made here. A file
# rather than a second pipe, so nothing has to hold a pipe open for the
# run and a program is never held by a host that stopped reading.
# `pad_port` puts the pad's port on port 3 the same way, over padport.in,
# which the host writes the pad's header and events into
# (doc/padport.md). Nothing at all with none, so the machine carries no
# serial device. The console keeps the UART in every build, since a fault
# line has to reach the host when a port has not come up. A previous
# run's debug.log is retired into `root`'s retire home (retire). `nonce`
# names a Windows run's pipes (pipe-path). Each port's pipe comes back as
# pipe-pair made it, null for a port the machine lacks.
def ports [names: list<string>, out: path, api: bool, pad_port: bool, root: path, nonce: int]: nothing -> record<args: list<string>, debug_log: string, api: oneof<record<name: string, inward: string, outward: string>, nothing>, pad: oneof<record<name: string, inward: string, outward: string>, nothing>> {
    mkdir $out
    let debug = (if "DEBUG" in $names {
        let log = ($out | path join "debug.log")
        retire $log $root
        { args: ["-chardev" $"file,id=jabdebug,path=($log)" "-device" "virtserialport,chardev=jabdebug,nr=1,name=jab.debug"], log: $log }
    } else { { args: [], log: "" } })
    let port = (if $api { pipe-pair $out "api" $nonce $nu.os-info.name $root } else { null })
    let pad = (if $pad_port { pipe-pair $out "padport" $nonce $nu.os-info.name $root } else { null })
    let port_args = (if $port == null { [] } else { ["-chardev" $"pipe,id=jabapi,path=($port.name)" "-device" "virtserialport,chardev=jabapi,nr=2,name=jab.api"] })
    let pad_args = (if $pad == null { [] } else { ["-chardev" $"pipe,id=jabpad,path=($pad.name)" "-device" "virtserialport,chardev=jabpad,nr=3,name=jab.pad"] })
    let device = (if ($debug.args | is-empty) and ($port_args | is-empty) and ($pad_args | is-empty) { [] } else { ["-device" "virtio-serial-device"] })
    { args: ($device ++ $debug.args ++ $port_args ++ $pad_args), debug_log: $debug.log, api: $port, pad: $pad }
}

# The path QEMU's pipe chardev takes for a pipe of `endpoint` beside a
# run's other files in `out`, on the host `os` names as $nu.os-info.name
# does (PipeShape): on every host but Windows `<out>/<endpoint>`, whose
# `<endpoint>.in` and `<endpoint>.out` QEMU opens itself; on Windows a
# bare name, `jab-<nonce>-<endpoint>`, the run's nonce in sixteen hex
# digits (nonce-hex), since QEMU makes one duplex named pipe of the option
# there, `\\.\pipe\` and the option as given, a filesystem path being no
# pipe's name, and the nonce keeps one run's pipes apart from another's. A
# Windows pipe with no nonce, under 1, is refused.
export def pipe-path [out: path, endpoint: string, nonce: int, os: string]: nothing -> string {
    if $os != "windows" { return ($out | path join $endpoint) }
    if $nonce < 1 { error make {msg: $"a Windows run's pipes are named by its nonce, 1 to 2^63 - 1, not ($nonce)"} }
    $"jab-(nonce-hex $nonce)-($endpoint)"
}

# A pipe of `endpoint` for QEMU's pipe chardev, made in `out` as the host
# `os` names takes it (pipe-path): `name`, the chardev's path, with
# `inward`, `<endpoint>.in`, what the host writes into, and `outward`,
# `<endpoint>.out`, a plain file made empty, where the guest's bytes land.
# On every host but Windows QEMU opens the two itself, inward a named pipe
# (fifo-at); on Windows, where the pipe is one named pipe and a relay or
# the pad bridge its client (relays-start), inward is a plain file made
# empty too, which a writer appends to (pipe-write) and the relay forwards
# into the pipe, as outward takes what the relay reads from it. A previous
# run's files are retired first into `root`'s retire home (retire).
export def pipe-pair [out: path, endpoint: string, nonce: int, os: string, root: path]: nothing -> record<name: string, inward: string, outward: string> {
    let name = (pipe-path $out $endpoint $nonce $os)
    let inward = ($out | path join $"($endpoint).in")
    let outward = ($out | path join $"($endpoint).out")
    if $os == "windows" {
        retire $inward $root
        "" | save $inward
    } else {
        fifo-at $inward $root
    }
    retire $outward $root
    "" | save $outward
    { name: $name, inward: $inward, outward: $outward }
}

# The relays a Windows machine's pipes take (PipeShape), one for each of
# `pipes`, its endpoint with its pipe as pipe-pair made it, null for a
# port the machine lacks, which takes none: the pipe's name, its in-file
# and its out-file, and `done`, `<endpoint>.relay.nuon` in `out`, where
# the relay's job saves how it ended (relays-start).
export def relays-of [out: path, pipes: list<record<endpoint: string, pipe: any>>]: nothing -> list<record<endpoint: string, name: string, inward: string, outward: string, done: string>> {
    $pipes | where {|p| $p.pipe != null } | each {|p|
        { endpoint: $p.endpoint, name: $p.pipe.name, inward: $p.pipe.inward, outward: $p.pipe.outward, done: ($out | path join $"($p.endpoint).relay.nuon") }
    }
}

# The relay's binary for a machine with relays (relays-of), built from
# the workspace's shim/crates/pipe (shim-build), "" for one with none; a
# machine with relays and no workspace to build it in is refused.
def relay-build [relays: list<any>, ws: oneof<string, nothing>]: nothing -> string {
    if ($relays | is-empty) { return "" }
    if $ws == null { error make {msg: "a Windows run's pipes need their relay, which the workspace builds from shim/crates/pipe, and this run has no workspace"} }
    shim-build $ws "jabpipe" --bin
}

# The pipe the pad bridge writes, from the pad port's pipe as pipe-pair
# made it, "" for none: its in-file, a fifo QEMU holds open, on every host
# but Windows, where the bridge is the pipe's client and takes its name.
def bridge-pipe [pad: oneof<record<name: string, inward: string, outward: string>, nothing>]: nothing -> string {
    if $pad == null { "" } else if $nu.os-info.name == "windows" { $pad.name } else { $pad.inward }
}

# A Windows machine's relays started beside its QEMU, one job each
# (PipeShape): `jabpipe <name> <inward> <outward>`, each connecting to its
# pipe as soon as QEMU makes it and holding the run's one connection,
# then forwarding what is appended to the in-file into the pipe and
# writing what the pipe gives into the out-file, until QEMU closes it.
# Each saves its exit and what it said to its `done` file as it ends,
# through a file beside it moved over it, so a read never takes half of
# one; a `done` file already there, an earlier start's, is retired first
# into `root`'s retire home (retire), so the record read back is this
# start's own. Each relay started with its job's id; none for a machine
# with none.
export def relays-start [relays: list<any>, binary: string, root: path]: nothing -> list<record<job: int, relay: record>> {
    mut started = []
    for r in $relays {
        retire $r.done $root
        retire $"($r.done).next" $root
        let id = (job spawn {
            let next = $"($r.done).next"
            ^$binary $r.name $r.inward $r.outward | complete | to nuon | save -f $next
            mv -f $next $r.done
        })
        $started = ($started | append { job: $id, relay: $r })
    }
    $started
}

# A machine's relays once its QEMU has ended (relays-start): each given a
# second to end on its own, its pipe closed with QEMU, then any still
# running stopped (job kill). How each ended: its endpoint, its pipe's
# name, its exit, null for one stopped, and what it said.
export def relays-stop [started: list<record<job: int, relay: record>>]: nothing -> list<record<endpoint: string, name: string, exit: oneof<int, nothing>, said: string>> {
    if ($started | is-empty) { return [] }
    let deadline = ((date now) + 1sec)
    while ((date now) < $deadline) and ($started | any {|s| not ($s.relay.done | path exists) }) { sleep 50ms }
    $started | each {|s|
        let done = (if ($s.relay.done | path exists) { try { open --raw $s.relay.done | decode | from nuon } catch { null } } else { null })
        if $done == null { try { job kill $s.job } }
        { endpoint: $s.relay.endpoint, name: $s.relay.name, exit: (if $done == null { null } else { $done.exit_code }), said: (if $done == null { "" } else { $done.stderr }) }
    }
}

# A launch's relays held to how they ended (relays-stop): one that ended
# on its own in failure, a pipe it never connected to or a pipe or a file
# that failed it, fails the launch once QEMU has ended, naming its pipe
# and what it said, beside QEMU's exit and its stderr; one stopped after
# QEMU ended, its pipe never made, leaves QEMU's own record to say why.
# Untyped because it ends in an error.
export def relays-held [relayed: list<any>, qemu: record] {
    let failed = ($relayed | where {|r| $r.exit != null and $r.exit != 0 })
    if ($failed | is-empty) { return }
    let told = ($failed | each {|r| $"the ($r.endpoint) pipe's relay, for ($r.name), ended with ($r.exit): ($r.said | str trim)" } | str join "; ")
    let said = ($qemu.stderr | str trim)
    error make {msg: $"($told); QEMU ended with ($qemu.exit_code)(if $said == '' { '' } else { $', saying: ($said)' })"}
}

# A named pipe at `path`: one already there is kept, since a pipe holds
# nothing once every end has closed, and anything else there is retired
# into `root`'s retire home (retire) before a fresh pipe is made.
def fifo-at [path: path, root: path]: nothing -> nothing {
    if ($path | path type) == "pipe" { return }
    retire $path $root
    ^mkfifo $path
}

# The gamepad a machine carries: nothing at all unless asked. Asked, on
# Linux unless `port` says otherwise, the fifo `pad` in `out`, made fresh,
# which QEMU's host-input device opens as the pad with the evdev shim
# preloaded to answer its ioctls as the reference pad, the QEMU arguments
# and environment for that; on every other host, and on Linux with
# `port`, the pad port instead, the same reference pad described by the
# header the driver writes first. The shim is one of the workspace's,
# `ws`, the kernel's or the one above `out`; anything at the fifo's path
# is retired into `root`'s retire home (fifo-at).
def pad-attach [wanted: bool, out: path, port: bool, ws: oneof<string, nothing>, root: path]: nothing -> record<args: list<string>, env: record, fifo: string, port: bool, header: binary> {
    let none = { args: [], env: {}, fifo: "", port: false, header: 0x[] }
    if not $wanted { return $none }
    if $port or $nu.os-info.name != "linux" {
        return ($none | merge { port: true, header: (pad-port-header) })
    }
    if $ws == null { error make {msg: "a gamepad needs a workspace, above the kernel or the output directory, which holds shim/crates/evdev"} }
    let shim = (shim-build $ws "jabshim_evdev")
    let fifo = ($out | path join "pad")
    fifo-at $fifo $root
    {
        args: ["-device" $"virtio-input-host-device,evdev=($fifo)"],
        env: { LD_PRELOAD: $shim, EVDEV_SHIM_FIFO: $fifo },
        fifo: $fifo,
        port: false,
        header: 0x[],
    }
}

# A launch's pad table as the groups it plays: the rows grouped by their
# time, each group one report the launch loop writes at that time; none
# without a table, and none for a table with no rows, which still puts
# the pad on the machine with nothing played into it.
def pad-table [table: path]: nothing -> record<groups: list<any>> {
    if ($table | is-empty) { return { groups: [] } }
    let rows = (open ($table | path expand))
    if ($rows | is-empty) { return { groups: [] } }
    let wanted = [at type code value]
    if not ($wanted | all {|c| $c in ($rows | columns) }) {
        error make {msg: $"($table): a pad table has the columns at, type, code, value; this one has ($rows | columns | str join ', ')"}
    }
    { groups: ($rows | sort-by at | group-by --to-table {|r| $r.at | into int } | each {|g| { at: ($g.items | first | get at), items: $g.items } }) }
}

# One report of pad events, as the device would send them: each row an
# input_event, then a SYN_REPORT closing the report.
def pad-report [items: table<type: int, code: int, value: int>]: nothing -> binary {
    ($items | each {|e| input-event $e.type $e.code $e.value } | bytes collect) ++ (input-event 0 0 0)
}

# The same events as the pad port takes them: eight bytes each, type,
# code, value, little-endian, no SYN (doc/padport.md).
def pad-frames [items: table<type: int, code: int, value: int>]: nothing -> binary {
    $items | each {|e| (le $e.type 2) ++ (le $e.code 2) ++ (le $e.value 4) } | bytes collect
}

# The pad port's header for the reference pad, the one the evdev shim
# answers as, so a table plays the same either way (doc/padport.md):
# the magic, the version, the name, the buttons BTN_GAMEPAD to
# BTN_GAMEPAD plus 15, the axes X, Y, Z, RZ, GAS, BRAKE, HAT0X, HAT0Y
# with the shim's absinfo, and zero for every other axis.
def pad-port-header []: nothing -> binary {
    let name = ("8BitDo Ultimate" | into binary)
    let axes = {
        0: [0 255 0 15 0], 1: [0 255 0 15 0], 2: [0 255 0 15 0], 5: [0 255 0 15 46],
        9: [0 255 0 15 0], 10: [0 255 0 15 0], 16: [-1 1 0 0 0], 17: [-1 1 0 0 0],
    }
    let axis_mask = ($axes | columns | each {|c| 1 bit-shl ($c | into int) } | math sum)
    let absinfo = (0..<64 | each {|code|
        let info = ($axes | get -o ($code | into string))
        if $info == null { zeros 20 } else { $info | each {|f| le $f 4 } | bytes collect }
    } | bytes collect)
    ("JPAD" | into binary) ++ (le 1 4) ++ $name ++ (zeros (128 - ($name | bytes length))) ++ (le 0xffff 4) ++ (le 0 4) ++ (le $axis_mask 8) ++ $absinfo
}

# A value as `width` little-endian bytes, two's complement.
export def le [value: int, width: int]: nothing -> binary {
    $value | into binary --endian little | bytes at 0..<$width
}

# `n` zero bytes.
export def zeros [n: int]: nothing -> binary {
    if $n <= 0 { 0x[] } else { 1..$n | each {|| 0x[00] } | bytes collect }
}

# One input_event as an evdev device writes it, 24 bytes: the wall
# clock's seconds and microseconds as two 64-bit fields, then the type
# and the code as 16 bits each and the value as 32, all little-endian.
def input-event [type: int, code: int, value: int]: nothing -> binary {
    let ns = (date now | into int)
    let sec = ($ns // 1_000_000_000)
    let usec = (($ns mod 1_000_000_000) // 1000)
    ($sec | into binary --endian little | bytes at 0..<8) ++ ($usec | into binary --endian little | bytes at 0..<8) ++ ($type | into binary --endian little | bytes at 0..<2) ++ ($code | into binary --endian little | bytes at 0..<2) ++ ($value | into binary --endian little | bytes at 0..<4)
}

# The build symbols named by `--set`: comma separated, in any case,
# each made screaming snake case (debug, Debug and some-thing become
# DEBUG and SOME_THING), sorted so order cannot matter, and refused when
# the assembler would not take the name, which it would only say much
# later.
def symbols [set: string]: nothing -> list<string> {
    let names = ($set | split row "," | each {|s| $s | str trim } | where {|s| $s != "" } | each {|s| $s | str screaming-snake-case } | uniq | sort)
    for n in $names {
        if not ($n =~ '^[A-Z_][A-Z0-9_]*$') {
            error make {msg: $"--set ($n): not a symbol the assembler takes; a name starts with a letter"}
        }
    }
    $names
}

# A test build's symbols: whatever was asked, and DEBUG.
def with-debug [names: list<string>]: nothing -> list<string> { $names | append "DEBUG" | uniq | sort }

# Which tree a build lands in: debug with DEBUG set, else release.
def profile [names: list<string>]: nothing -> string { if "DEBUG" in $names { "debug" } else { "release" } }

# The symbols as the assembler takes them.
def defsyms [names: list<string>]: nothing -> list<string> { $names | each {|n| ["--defsym" $"($n)=1"] } | flatten }

# A program's assets as a romfs image, built when the directory it names
# has moved on: `assets` in its manifest, relative to the manifest, or
# `target_assets`, a tree the program's content compiles to under its
# asset shard of the target (program-shard), with the program's own name
# as the volume's. The image is what `just run` puts on the machine, and
# the program reads it with jab.sys.romfs.*.
def assets-image [c: record]: nothing -> string {
    let declared = ($c.manifest | get -o assets | default "")
    let compiled = ($c.manifest | get -o target_assets | default "")
    if $declared == "" and $compiled == "" { return "" }
    if $declared != "" and $compiled != "" { error make {msg: $"($c.manifest.name): assets and target_assets together; a program's disk is one or the other"} }
    let dir = (if $compiled != "" { shard-dir $c "asset" | path join $compiled } else { $c.here | path join $declared | path expand })
    if not ($dir | path exists) {
        let named = (if $compiled != "" { $"target_assets = '($compiled)'" } else { $"assets = '($declared)'" })
        error make {msg: $"($c.manifest.name): ($named) names no directory at ($dir)"}
    }
    assets-names $dir
    let image = ($c.out | path join $"($c.manifest.name).romfs")
    let stamp = ($c.out | path join "assets.flags")
    let inputs = (tree-under [$dir])
    let id = (build-id $c.manifest.name $inputs)
    if ($image | path exists) and (not (stale $image $inputs $id $stamp)) { return $image }
    mkdir $c.out
    ^genromfs -d $dir -f $image -V (volume-name $c.manifest.name)
    $id | save -f $stamp
    $image
}

# A romfs name is at most 127 bytes of UTF-8, which is what a Linux
# mount of the same image can read: its driver lists through a
# 128-byte buffer and works out where a file's data begins from a
# length that stops there, so a longer name makes it read the wrong
# bytes. The kernel reports such a name cut rather than wrong, but an
# image Jab builds never has one. `str length` counts bytes, which is
# the measure the record and the driver use.
def assets-names [dir: path]: nothing -> nothing {
    let long = (paths-of ($dir | path join "**" "*") | each {|p| $p | path basename } | where {|n| ($n | str length) > 127 })
    if not ($long | is-empty) {
        error make {msg: $"romfs names are 127 bytes at most, which is what a linux mount can read; too long: ($long | first)"}
    }
}

# A volume's name is bound the same way, and a disk's serial by virtio's
# 20-byte ID string, which carries a terminator only when it fits; each
# is cut on a character, never inside one.
def volume-name [name: string]: nothing -> string { cut-bytes $name 127 }
def disk-serial [name: string]: nothing -> string { cut-bytes $name 19 }

# The longest prefix of `name` within `limit` bytes of UTF-8 that ends
# on a whole character.
def cut-bytes [name: string, limit: int]: nothing -> string {
    mut out = ""
    for g in ($name | split chars --grapheme-clusters) {
        if (($out + $g) | str length) > $limit { break }
        $out = ($out + $g)
    }
    $out
}

# Whether the process is in the process table, which nushell reads on
# every host; "" is no process at all.
def process-alive [pid: string]: nothing -> bool {
    if $pid == "" { return false }
    let id = (try { $pid | into int } catch { -1 })
    if $id < 0 { return false }
    ps | where pid == $id | is-not-empty
}

# The CPU seconds a process has used, user plus system, from /proc,
# or null where there is no /proc or the process is gone; accounting
# only, never what a launch's actions wait on.
def cpu-seconds [pid: string]: nothing -> oneof<float, nothing> {
    let stat = (try { open --raw ("/proc" | path join $pid "stat") | decode } catch { "" })
    if $stat == "" { return null }
    # after the command's closing parenthesis: state, ppid, pgrp,
    # session, tty, tpgid, flags, minflt, cminflt, majflt, cmajflt,
    # utime, stime, in clock ticks of a hundredth
    let fields = ($stat | split row ") " | last | split row " ")
    (($fields | get 11 | into int) + ($fields | get 12 | into int)) / 100.0
}

# Give the QEMU monitor a command through its pipe (pipe-write) under
# `bound`, the run's timeout (timeout-binary); true when it went in.
def monitor-send [monitor: path, command: string, bound: string]: nothing -> bool {
    pipe-write ($monitor + ".in") $"($command)\n" $bound
}

# Bytes into one of QEMU's pipes as this host's pipes take them, `inward`
# the pipe's in-file (pipe-pair): on Windows appended to the file, which
# never waits and which the pipe's relay forwards (relays-start); on every
# other host into the named pipe itself under `bound` (fifo-write). True
# when they went in.
def pipe-write [inward: path, data: any, bound: string]: nothing -> bool {
    if $nu.os-info.name != "windows" { return (fifo-write $inward $data $bound) }
    $data | save --raw --append $inward
    true
}

# Bytes into one of QEMU's named pipes without waiting on a reader that is
# gone: opening a pipe to write waits until some process reads it, and
# QEMU can end between any check that it runs and the open, so `tee`
# appends the bytes under a one-second bound, `bound` the run's timeout
# (timeout-binary). True when they went in; false when no reader came
# within the second.
export def fifo-write [fifo: path, data: any, bound: string]: nothing -> bool {
    let r = ($data | ^$bound 1 tee -a $fifo | complete)
    $r.exit_code == 0
}

# The GNU coreutils `timeout` every bound of a run takes (LaunchBound),
# resolved once a run: JAB_TIMEOUT when it is set, the one candidate, the
# launch refused naming it when its `--version` line names no GNU
# coreutils, never a fall to discovery; else, on Windows, MSYS2's
# /usr/bin/timeout.exe by its Windows path first, since Windows' own
# `timeout`, a pause, comes ahead of it on PATH, then every `timeout` on
# PATH in order, the first whose line names GNU coreutils taken, the
# launch refused naming every candidate tried when none does. Its path,
# run as a value wherever a bound runs, and its version line. Untyped
# because it ends in an error.
export def timeout-binary [] {
    let forced = ($env.JAB_TIMEOUT? | default "")
    if $forced != "" {
        let line = (timeout-version $forced)
        if not (gnu-timeout $line) { error make {msg: $"JAB_TIMEOUT names ($forced), whose --version reads ($line | to nuon), no GNU coreutils timeout, which every bound of a run takes"} }
        return { path: $forced, version: $line }
    }
    let msys = (if $nu.os-info.name == "windows" { try { [(^cygpath -w /usr/bin/timeout.exe | str trim)] } catch { [] } } else { [] })
    let listed = (which -a timeout | where type == "external" | get path)
    let candidates = ($msys ++ $listed | uniq)
    for c in $candidates {
        let line = (timeout-version $c)
        if (gnu-timeout $line) { return { path: $c, version: $line } }
    }
    error make {msg: $"no GNU coreutils timeout, which every bound of a run takes: tried (if ($candidates | is-empty) { 'none on PATH' } else { $candidates | str join ', ' }); install coreutils, or name one with JAB_TIMEOUT"}
}

# The first line a `timeout` prints for --version, "" when it prints none
# or will not run.
def timeout-version [path: string]: nothing -> string {
    try { ^$path --version | complete | get stdout | lines | get -o 0 | default "" } catch { "" }
}

# Whether a version line is GNU coreutils' `timeout`'s.
def gnu-timeout [line: string]: nothing -> bool {
    $line =~ '^timeout \(GNU coreutils\) '
}

# A word for the QEMU monitor's command line, which splits on spaces: in
# double quotes, a backslash and a double quote inside escaped, so a
# path with spaces in it stays one argument.
def hmp-quoted [text: string]: nothing -> string {
    let escaped = ($text | str replace --all '\' '\\' | str replace --all '"' '\"')
    $"\"($escaped)\""
}

# Whether a screen QEMU writes comes whole: its file the PPM header
# naming the display's size (display_size) and every pixel's three bytes
# after it, looked at every 50 ms for at most five seconds.
def screen-whole [path: path]: nothing -> bool {
    let header = ($"P6\n($display_size.width) ($display_size.height)\n255\n" | into binary)
    let whole = (($header | bytes length) + $display_size.width * $display_size.height * 3)
    for _ in 0..100 {
        if ($path | path exists) {
            if (ls -D $path | get 0.size | into int) == $whole {
                return ((open --raw $path | into binary | bytes at 0..<($header | bytes length)) == $header)
            }
        }
        sleep 50ms
    }
    false
}

# The Jab QEMU processes on this host, by their command line, which
# every Jab line marks with `-name jab`: the QEMU itself, wherever its
# binary lives, never the `timeout` a test wraps it in, whose command
# line carries the same words.
def jab-pids []: nothing -> list<int> {
    ps -l | where {|p| ((command-binary $p.command | path basename) == $qemu_name) and ($p.command | str contains "-name jab") } | get pid
}

# The binary a command line runs: everything before its first option, so
# a binary whose path holds a space, an extern/qemu under such a
# directory, stays whole.
def command-binary [command: string]: nothing -> string {
    $command | split row " -" | first
}

# The threads of a process with their cumulative CPU seconds: on Linux
# from /proc, by thread id and name (the harts `CPU 0/TCG` and on, the
# main loop under the process name); on macOS from `ps -M`, its rows
# in order, the first the AppKit thread that draws the window, the
# rest unnamed, so a thread is identified by its row.
def threads-of [pid: int]: nothing -> table<id: string, name: string, cpu: float> {
    match $nu.os-info.name {
        "linux" => {
            let tasks = (try { ls ("/proc" | path join ($pid | into string) "task") | get name } catch { [] })
            $tasks | each {|t|
                let stat = (try { open --raw ($t | path join "stat") | decode } catch { "" })
                if $stat == "" { null } else {
                    let fields = ($stat | split row ") " | last | split row " ")
                    let name = (try { open --raw ($t | path join "comm") | decode | str trim } catch { "" })
                    { id: ($t | path basename), name: $name, cpu: ((($fields | get 11 | into int) + ($fields | get 12 | into int)) / 100.0) }
                }
            } | compact
        },
        "macos" => {
            let out = (^ps -M -p ($pid | into string) | complete | get stdout)
            $out | lines | skip 1 | enumerate | each {|row|
                let times = ($row.item | parse --regex '(?P<stime>\d+:\d+(?::\d+)?\.\d+)\s+(?P<utime>\d+:\d+(?::\d+)?\.\d+)' | get -o 0)
                if $times == null { null } else {
                    { id: ($row.index | into string), name: (if $row.index == 0 { "main" } else { $"thread ($row.index)" }), cpu: ((clock-seconds $times.stime) + (clock-seconds $times.utime)) }
                }
            } | compact
        },
        _ => { error make {msg: $"no thread reading here for ($nu.os-info.name)"} },
    }
}

# Each thread's CPU between two readings of threads-of taken `span`
# seconds apart: by thread id, its name, `delta` the CPU seconds it used
# in between, and `rate` those over the span, its share of a core; a
# thread in one reading alone is passed over. The span rides along, so a
# rate never travels without the stretch it was measured over. A span
# that is not past zero is refused.
export def threads-between [first: table<id: string, name: string, cpu: float>, second: table<id: string, name: string, cpu: float>, span: float]: nothing -> record<span: float, threads: list<record<name: string, delta: float, rate: float>>> {
    if $span <= 0.0 { error make {msg: $"a span of ($span) s holds no rate"} }
    let threads = ($second | each {|t|
        let before = ($first | where id == $t.id | get -o 0)
        if $before == null { null } else {
            let delta = ($t.cpu - $before.cpu)
            { name: $t.name, delta: $delta, rate: ($delta / $span) }
        }
    } | compact)
    { span: $span, threads: $threads }
}

# A process's resident memory in bytes as its host reports it: VmRSS in
# /proc/<pid>/status on Linux, `ps -o rss=` in KiB on macOS; null where
# neither reads, the process gone or the host another.
def memory-of [pid: int]: nothing -> any {
    match $nu.os-info.name {
        "linux" => {
            let status = (try { open --raw ("/proc" | path join ($pid | into string) "status") | decode } catch { "" })
            let kb = ($status | lines | parse --regex '^VmRSS:\s+(?P<kb>\d+) kB' | get -o 0.kb)
            if $kb == null { null } else { ($kb | into int) * 1024 }
        },
        "macos" => {
            let out = (try { ^ps -o rss= -p ($pid | into string) | complete | get stdout | str trim } catch { "" })
            if $out == "" { null } else { ($out | into int) * 1024 }
        },
        _ => null,
    }
}

# `ps` clock text, M:SS.hh or H:MM:SS.hh, as seconds.
def clock-seconds [text: string]: nothing -> float {
    $text | split row ":" | each {|p| $p | into float } | reduce --fold 0.0 {|it, acc| $acc * 60.0 + $it }
}

# Where `watch` records: watch.nuonl in the workspace's target.
def watch-file [ws: path]: nothing -> string {
    target-root $ws | path join "watch.nuonl"
}

# What a recording says first about the QEMU it records: the host, the
# QEMU's version, the machine from its line (the harts, -machine, the
# CPU, and the accelerator), the window, the kernel and the symbols it
# was built with, read from its tree's flags stamp, its pid, and when the
# recording started.
def watch-header [pid: int, started: datetime]: nothing -> record {
    let command = (ps -l | where pid == $pid | get -o 0.command | default "")
    let window = ($command | parse --regex '-display (?P<w>\S+)' | get -o 0.w | default "")
    let kernel = ($command | parse --regex '-kernel (?P<k>\S+)' | get -o 0.k | default "")
    let smp = ($command | parse --regex '-smp (?P<n>\d+)' | get -o 0.n | default "")
    let machine = ($command | parse --regex '-machine (?P<m>\S+)' | get -o 0.m | default "")
    let cpu = ($command | parse --regex '-cpu (?P<c>\S+)' | get -o 0.c | default "")
    let accel = ($command | parse --regex '-accel (?P<a>\S+)' | get -o 0.a | default "")
    let stamp_file = (if $kernel == "" { "" } else { $kernel | path dirname | path join "flags" })
    let stamp = (if $stamp_file != "" and ($stamp_file | path exists) { open --raw $stamp_file | decode | str trim } else { "" })
    let symbols = ($stamp | parse --regex '--defsym (?P<s>[A-Z0-9_]+)=1' | get s)
    let binary = (command-binary $command)
    let qemu = (try { ^$binary --version | complete | get stdout | lines | get -o 0 | default "" } catch { "" })
    { os: $nu.os-info.name, arch: $nu.os-info.arch, qemu: $qemu, harts: (if $smp == "" { null } else { $smp | into int }), machine: $machine, cpu: $cpu, accel: $accel, window: $window, kernel: $kernel, symbols: $symbols, pid: $pid, started: ($started | format date "%Y-%m-%dT%H:%M:%S") }
}

# Record the running Jab QEMU per thread, once a second, to the
# workspace's target's watch.nuonl, a previous recording retired,
# whatever shell this is run from: a first line describing the run
# (watch-header), then a line per sample with every thread's cumulative
# CPU seconds and the process's resident memory (memory-of), one short
# line printed per sample with the rates since the last. When the run ends, the report on the recording is printed to
# paste (watch-report-of), the first `--skip` seconds dropped as the
# load. Interrupted, it ends with no report. `watch bench` records a
# bench's runs instead.
def "main watch" [ws: path, --skip: float = 5.0] {
    let pids = (jab-pids)
    if ($pids | is-empty) { error make {msg: "no jab is running"} }
    let pid = ($pids | first)
    let file = (watch-file $ws)
    mkdir ($file | path dirname)
    retire $file (target-root $ws)
    let started = (date now)
    let run = (watch-header $pid $started)
    ({ run: $run } | to nuon) + (char nl) | save --raw $file
    print $"jab watch: recording ($pid) to ($file), ($run.symbols | str join ', ') under ($run.window)"
    if ($pids | length) > 1 { print $"jab watch: ($pids | length) jab processes; recording the first" }
    mut last: any = null
    loop {
        if (jab-pids | where {|p| $p == $pid } | is-empty) { print "jab watch: the run has ended"; break }
        let at = (((date now) - $started) / 1sec)
        let threads = (threads-of $pid)
        ({ at: $at, threads: $threads, rss: (memory-of $pid) } | to nuon) + (char nl) | save --raw --append $file
        let previous = $last
        if $previous != null {
            let seconds = ($at - $previous.at)
            let rates = ($threads | each {|t|
                let before = ($previous.threads | where id == $t.id | get -o 0.cpu | default $t.cpu)
                { name: $t.name, rate: (($t.cpu - $before) / $seconds) }
            } | where rate >= 0.01 | sort-by rate --reverse)
            print $"($at | math round)s  ($rates | each {|r| $'($r.name) ($r.rate | math round -p 2)' } | str join '  ')"
        }
        $last = { at: $at, threads: $threads }
        sleep 1sec
    }
    print (watch-report-of $file $skip | to nuon --indent 2)
}

# The report on a recording `watch` made, as one NUON record: the run
# as recorded, the stretch reported on, and per thread the steady CPU
# seconds a second over that stretch and the peak second, with the
# process total; threads under 0.005 a second are left out. The stretch
# drops the first `skip` seconds as the load, or nothing for a run too
# short to spare them, `skipped` saying which. On macOS a thread is its
# row, and QEMU's worker threads come and go, so a row can change
# identity between samples: a row whose second-by-second rate is
# impossible for one thread, negative or past one, is reported with
# `stable: false` and no peak, its steady figure a mix. `tcg` names the
# translator's mode from the threads' names: a lone `ALL CPUs/TCG` thread
# runs every hart on one host thread, single-threaded and never evidence
# of multicore performance, `CPU N/TCG` threads a thread a hart; null
# where the names say neither, as on macOS. `memory` the process's
# resident memory in bytes over the stretch, its median by nearest rank
# and its peak with the samples holding it, null for a recording made
# before the watch read it.
def watch-report-of [file: path, skip: float]: nothing -> record {
    let lines = (open --raw $file | decode | lines | where {|l| ($l | str trim) != "" })
    let header = ($lines | first | from nuon)
    let recorded = ($lines | skip 1 | each {|l| $l | from nuon })
    let after = ($recorded | where at >= $skip)
    let skipped = (if ($after | length) >= 2 { $skip } else { 0.0 })
    let samples = (if ($after | length) >= 2 { $after } else { $recorded })
    if ($samples | length) < 2 { error make {msg: $"the run ended after ($samples | length) samples, too few for a report; watch a run of two seconds or more"} }
    let first = ($samples | first)
    let last = ($samples | last)
    let seconds = ($last.at - $first.at)
    let threads = ($last.threads | get id | each {|id|
        let series = ($samples | each {|s|
            let t = ($s.threads | where id == $id | get -o 0)
            if $t == null { null } else { { at: $s.at, cpu: $t.cpu, name: $t.name } }
        } | compact)
        if ($series | length) < 2 { null } else {
            let steady = ((($series | last).cpu - ($series | first).cpu) / (($series | last).at - ($series | first).at))
            let rates = ($series | window 2 | each {|w| ($w.1.cpu - $w.0.cpu) / ($w.1.at - $w.0.at) })
            let stable = (not ($rates | any {|r| $r < -0.001 or $r > 1.05 }))
            { name: ($series | last).name, id: $id, steady: ($steady | math round -p 3), peak: (if $stable { $rates | math max | math round -p 3 } else { null }), stable: $stable }
        }
    } | compact | where steady >= 0.005 | sort-by steady --reverse)
    let names = ($last.threads | get name)
    let tcg = (if ($names | any {|n| $n == "ALL CPUs/TCG" }) { "single-threaded" } else if ($names | any {|n| $n =~ '^CPU \d+/TCG$' }) { "multi-threaded" } else { null })
    let resident = ($samples | each {|s| $s | get -o rss } | compact | sort)
    {
        run: $header.run,
        skipped: $skipped,
        seconds: ($seconds | math round -p 1),
        samples: ($samples | length),
        tcg: $tcg,
        process: (if ($threads | is-empty) { 0.0 } else { $threads | get steady | math sum | math round -p 3 }),
        threads: $threads,
        memory: (if ($resident | is-empty) { null } else { { median: ($resident | get ((($resident | length) * 0.5 | math ceil) - 1)), peak: ($resident | last), samples: ($resident | length) } }),
    }
}

# A watch report's memory in words, the resident median and peak in MiB,
# empty where it holds none.
def memory-text [memory: any]: nothing -> string {
    if $memory == null { "" } else { $"; resident ($memory.median / 1048576 | math round) MiB at the median, ($memory.peak / 1048576 | math round) at the peak" }
}

# The one build tree a workspace writes into, every build and every
# tool's output sharded within it: `.target` at the workspace's root, or
# where XDG_CACHE_HOME is set `$XDG_CACHE_HOME/jab/target/<checkout>`,
# the checkout its directory's name and the first eight hex digits of the
# SHA-256 of its path, so two checkouts on one machine never build over
# each other. `anchor` is the workspace, or a program with none above it.
export def target-root [anchor: path]: nothing -> string {
    let anchor = ($anchor | path expand)
    let cache = ($env.XDG_CACHE_HOME? | default "")
    if $cache == "" { return ($anchor | path join ".target") }
    let checkout = $"($anchor | path basename)-($anchor | hash sha256 | str substring 0..<8)"
    $cache | path expand | path join "jab" "target" $checkout
}

# Whether `dir` is a target this tool makes (target-root): a `.target`
# directory, or a checkout's under `jab/target` in the XDG cache, which
# is never that directory's shared `tmp` (retire-home).
def is-target [dir: path]: nothing -> bool {
    let name = ($dir | path basename)
    ($name == ".target") or ($name != "tmp" and ($dir | path dirname | path basename) == "target" and ($dir | path dirname | path dirname | path basename) == "jab")
}

# The target a path lies in, the nearest of its parents that is one
# (is-target), or null.
def target-of [path: path]: nothing -> oneof<string, nothing> {
    mut d = ($path | path expand --no-symlink | path dirname)
    loop {
        if (is-target $d) { return $d }
        let up = ($d | path dirname)
        if $up == $d { return null }
        $d = $up
    }
}

# Where a target's retirements go: `tmp`, which `just retire` empties,
# beside every checkout's target under `jab/target` in the XDG cache,
# else in the `.target` itself; `base` is the directory a retired path
# keeps its place under, so a checkout's name rides along in the shared
# one.
def retire-home [target: path]: nothing -> record<tmp: string, base: string> {
    let target = ($target | path expand)
    let base = (if ($target | path basename) == ".target" { $target } else { $target | path dirname })
    { tmp: ($base | path join "tmp"), base: $base }
}

# Moves `path` out of the way whole in place of deleting it, so nothing a
# build, a test, a bench, or a clean clears away is lost: into the
# retire home's `retired/<stamp>/` (retire-home) at its place under the
# home's base, the target `root` when given, else the one the path lies
# in (target-of); a path outside lands under `outside/` there at its
# absolute path. A second retirement of one path within a second takes
# a numbered name, and `--stamp` sets the stamp, so a clean's entries
# share one. Nothing when nothing is there; a link is moved as a link.
# A path in no target with no root given, or one already retired, is
# left as it is and refused. Untyped because it can end in an error.
export def retire [path: path, root?: path, --stamp: string = ""] {
    let from = ($path | path expand --no-symlink)
    if ($from | path type) == null { return }
    let target = (if $root != null { $root | path expand } else { target-of $from })
    if $target == null { error make {msg: $"($from) lies in no target, so there is nowhere to retire it to; it is left as it is"} }
    let home = (retire-home $target)
    if (under $from $home.tmp) { error make {msg: $"($from) is already retired; it is left as it is"} }
    let stamp = (if $stamp == "" { date now | format date "%Y%m%d-%H%M%S" } else { $stamp })
    let rest = (if (under $from $home.base) { $from | path relative-to $home.base | path split } else { ["outside"] ++ ($from | path split | skip 1) })
    let at = ($home.tmp | path join "retired" $stamp ...$rest)
    mut dest = $at
    mut n = 1
    while ($dest | path type) != null {
        $dest = $"($at).($n)"
        $n += 1
    }
    mkdir ($dest | path dirname)
    mv $from $dest
}

# Where a kernel's or a program's output lives in the target `root`:
# under its path relative to the workspace when it lies inside it,
# member or not; beside its own source when it lies inside the target
# itself, as a measured candidate's copy does, `inside`; under
# `external/<name>-<the first eight hex digits of its path's SHA-256>`
# when it lies outside both; under its name with no workspace.
def shard-of [here: path, workspace: oneof<string, nothing>, root: path, name: string]: nothing -> record<relative: string, inside: bool> {
    if (under $here $root) { return { relative: "", inside: true } }
    if $workspace == null { return { relative: $name, inside: false } }
    if (under $here $workspace) { return { relative: ($here | path relative-to $workspace | str replace --all "\\" "/"), inside: false } }
    { relative: (["external" $"($name)-($here | hash sha256 | str substring 0..<8)"] | path join), inside: false }
}

# A program's directory in the target for one purpose, whatever the
# tree: `<target>/<purpose>/<its shard>`, or `<its own>/<purpose>` for
# a program inside the target. The purposes: asset, the trees its
# content compiles to; bench, the benches' runs; gauge, measurements
# kept by name; candidates, measured copies of it; scratch.
export def program-shard [dir: path, purpose: string]: nothing -> string {
    let c = (context ($dir | path expand) "program" [])
    shard-dir $c $purpose
}

def shard-dir [c: record, purpose: string]: nothing -> string {
    if $c.inside { $c.here | path join $purpose } else { $c.root | path join $purpose $c.shard }
}

# Where a program's build of `tree`, release or debug, lands, its tests'
# and runs' output beside it.
export def program-out [dir: path, tree: string]: nothing -> string {
    (context ($dir | path expand) "program" (tree-symbols $tree)).out
}

# The kernel a program runs on in `tree` (kernel-elf).
export def program-kernel [dir: path, tree: string]: nothing -> string {
    kernel-elf (context ($dir | path expand) "program" (tree-symbols $tree))
}

# The symbols that put a build in `tree`: DEBUG for debug, none for
# release.
def tree-symbols [tree: string]: nothing -> list<string> {
    match $tree {
        "debug" => ["DEBUG"],
        "release" => [],
        _ => { error make {msg: $"a tree is release or debug, not ($tree)"} },
    }
}

# The nearest parent of `dir` holding workspace.jab.toml, or null.
def workspace-dir [dir: path]: nothing -> oneof<string, nothing> {
    mut d = ($dir | path expand)
    loop {
        if ($d | path join "workspace.jab.toml" | path exists) { return $d }
        let parent = ($d | path dirname)
        if $parent == $d { return null }
        $d = $parent
    }
}

# The toolchain's install directory, or null for the tools on PATH.
def toolchain [here: path, workspace: oneof<string, nothing>]: nothing -> oneof<string, nothing> {
    let from_env = ($env.RISCV_TOOLCHAIN? | default "")
    if $from_env != "" { return $from_env }
    let local = ($here | path join "extern" "riscv")
    if ($local | path exists) { return $local }
    if $workspace != null {
        let shared = ($workspace | path join "extern" "riscv")
        if ($shared | path exists) { return $shared }
    }
    null
}

# The tools' command prefix: under a toolchain directory, `bin/<triple>`
# for the first triple whose `as` is there, `as.exe` on Windows; on PATH,
# the first triple whose `as` `which` finds. Untyped because it ends in
# an error.
def tool-prefix [toolchain: oneof<string, nothing>] {
    let looked = ($triples | each {|t| exe-name ($t + "as") } | str join ", ")
    if $toolchain != null {
        let bin = ($toolchain | path join "bin")
        for t in $triples {
            let prefix = ($bin | path join $t)
            if (exe-name ($prefix + "as") | path exists) { return $prefix }
        }
        error make {msg: $"no riscv64 binutils under ($bin): looked for ($looked)"}
    }
    for t in $triples {
        if not (which ($t + "as") | is-empty) { return $t }
    }
    error make {msg: $"no riscv64 binutils on PATH: looked for ($looked); set RISCV_TOOLCHAIN or link extern/riscv to a toolchain"}
}

# Whether the assembler takes the RVA23 profile `march` names, tried on an
# empty source under `dir`'s march/ before a build assembles anything,
# the probe left there for the next; one that does not, binutils before
# 2.45, is refused with its version, since no other ISA will do. Untyped
# because it can end in an error.
def march-check [asm: string, march: string, dir: path] {
    let probe = ($dir | path join "march")
    mkdir $probe
    let source = ($probe | path join "march.S")
    let object = ($probe | path join "march.o")
    "" | save -f $source
    let tried = (^$asm $march $source -o $object | complete)
    if $tried.exit_code != 0 {
        let version = (^$asm --version | complete | get stdout | lines | get -o 0 | default "an assembler")
        let found = (which $asm | get -o 0.path | default $asm)
        error make {msg: $"($version) at ($found) has no RVA23 profile, ($march), which every Jab build assembles for\nlink extern/riscv, in the workspace or beside the kernel or program, to a toolchain with binutils 2.45 or later, or name one with RISCV_TOOLCHAIN"}
    }
}

# The paths a glob pattern names, exactly as `glob` names them, but
# through `ls` over the pattern as a glob, since nu's `glob` breaks on a
# Windows drive letter (WindowsHost): each joined to the working directory
# as written, never normalized, hidden entries among them; none when
# nothing matches, where `ls` refuses, any other refusal raised;
# `--no-dir` leaving the directories out. A pattern ending `**/*` names its
# root first, as `glob` does.
export def paths-of [pattern: string, --no-dir]: nothing -> list<string> {
    let found = (try { ls -a ($pattern | into glob) } catch {|e|
        if ($e.msg | str starts-with "No matches found") { [] } else { error make {msg: $e.msg} }
    })
    let kept = (if $no_dir { $found | where type != "dir" } else { $found })
    let parts = ($pattern | path split)
    let root = (if ($parts | length) > 2 and ($parts | last 2) == ["**" "*"] { $parts | drop 2 | path join } else { "" })
    let rooted = (if $root != "" and (not $no_dir) and ($root | path type) == "dir" { [$root] } else { [] })
    $rooted ++ ($kept | get name) | each {|p| $env.PWD | path join $p }
}

# Every file under the directories, for the staleness check.
def files-under [dirs: list<string>]: nothing -> list<string> {
    $dirs | each {|d| paths-of ($d | path join "**" "*") } | flatten | where {|p| ($p | path type) == "file" }
}

# Every file and directory under the directories, the directories
# included since a deletion inside one moves its time and nothing
# else's.
def tree-under [dirs: list<string>]: nothing -> list<string> {
    $dirs | each {|d| [$d] ++ (paths-of ($d | path join "**" "*")) } | flatten | where {|p| ($p | path type) in ["file" "dir"] }
}

# What a build was made from, for its stamp: the flags, then every
# input path, sorted, so a source or asset deleted or renamed changes
# the stamp and forces the build, which the newest-input check alone
# cannot see, since a file that is gone is newer than nothing.
def build-id [flags: string, inputs: list<string>]: nothing -> string {
    $flags + (char nl) + ($inputs | sort | str join (char nl))
}

# Whether `output` needs building: missing, older than an input, or
# built from other flags or inputs than `stamp` records.
def stale [output: path, inputs: list<string>, flags: string, stamp: path]: nothing -> bool {
    if not ($output | path exists) { return true }
    if not ($stamp | path exists) { return true }
    if (open --raw $stamp) != $flags { return true }
    let newest = ($inputs | each {|p| ls -D $p | get 0.modified } | sort | last)
    (ls -D $output | get 0.modified) <= $newest
}

# The workspace a kernel or a program builds against: the nearest
# parent holding workspace.jab.toml, else the one the manifest's
# `workspace` names, relative to the manifest, for a program that lives
# outside any. Its kernel is built there with the same symbols and
# found in that workspace's tree, and its generic disk, its toolchain
# link, its shims, and discovery come from there, and the program's own
# output lands in that workspace's target at the program's path
# (shard-of). Under a workspace the key is not read. Null with neither.
def workspace-of [here: path, manifest: record]: nothing -> oneof<string, nothing> {
    let above = (workspace-dir $here)
    if $above != null { return $above }
    let declared = ($manifest | get -o workspace | default "")
    if $declared == "" { return null }
    let ws = ($here | path join $declared | path expand)
    if not ($ws | path join "workspace.jab.toml" | path exists) {
        error make {msg: $"($manifest.name): workspace = '($declared)' names no workspace at ($ws), which would hold workspace.jab.toml"}
    }
    $ws
}

# Whether `dir` is `root` or lies under it.
def under [dir: path, root: path]: nothing -> bool {
    try { $dir | path relative-to $root | ignore; true } catch { false }
}

# Whether `dir` is one of the workspace's own, its kernel or a program
# workspace.jab.toml lists, by its workspace-relative path, which is how
# an image built before its `home` marker is placed (image-home).
def member-of [dir: path, ws: path]: nothing -> bool {
    if not (under $dir $ws) { return false }
    let relative = ($dir | path relative-to $ws | str replace --all "\\" "/")
    let listed = (open ($ws | path join "workspace.jab.toml"))
    $relative == $listed.kernel or ($relative in $listed.programs)
}

# The kernel's or a program's context for a build with `names` set:
# manifest, workspace (workspace-of), toolchain, symbols, the target
# (target-root, the workspace's or a lone program's own), the tree in
# it (debug or release), and the output directory, the tree's shard
# (shard-of).
def context [dir: path, kind: string, names: list<string>]: nothing -> record {
    let here = ($dir | path expand)
    let manifest_path = ($here | path join $"($kind).jab.toml")
    let manifest = (open $manifest_path)
    let workspace = (workspace-of $here $manifest)
    let tree = (profile $names)
    let root = (target-root (if $workspace == null { $here } else { $workspace }))
    let place = (shard-of $here $workspace $root $manifest.name)
    let target = (if $place.inside { $here | path join $tree } else { $root | path join $tree })
    let tc = (toolchain $here $workspace)
    {
        here: $here,
        manifest: $manifest,
        manifest_path: $manifest_path,
        workspace: $workspace,
        toolchain: $tc,
        prefix: (tool-prefix $tc),
        symbols: $names,
        profile: $tree,
        root: $root,
        shard: $place.relative,
        inside: $place.inside,
        target: $target,
        out: (if $place.inside { $target } else { $target | path join $place.relative }),
    }
}

# The kernel ELF a program runs on: the workspace's, in the same tree
# of that workspace's target, or JAB_KERNEL. Left untyped because it
# ends in an error, which the output check rejects.
def kernel-elf [c: record] {
    if $c.workspace != null {
        let ws = (open ($c.workspace | path join "workspace.jab.toml"))
        return (target-root $c.workspace | path join $c.profile $ws.kernel "jab.elf")
    }
    let from_env = ($env.JAB_KERNEL? | default "")
    if $from_env != "" { return $from_env }
    error make {msg: "no workspace above this program and no JAB_KERNEL: where is the kernel?"}
}

# The window for a run: JAB_DISPLAY, else the manifest's display, else
# the best QEMU window the host has: SDL with OpenGL on Linux and
# Windows, cocoa on macOS (its only window, and it has no OpenGL). A
# Linux machine with no display server is nobody's console; there the
# display goes out over VNC for development.
def display [manifest: record]: nothing -> string {
    let forced = ($env.JAB_DISPLAY? | default "")
    if $forced != "" { return $forced }
    let declared = ($manifest | get -o display | default "")
    if $declared != "" { return $declared }
    match $nu.os-info.name {
        "macos" => "cocoa",
        "windows" => "sdl,gl=on",
        _ => {
            let server = (($env.DISPLAY? | default "") != "") or (($env.WAYLAND_DISPLAY? | default "") != "")
            if $server { "sdl,gl=on" } else { "vnc=127.0.0.1:30" }
        },
    }
}

def build-kernel [dir: path, names: list<string>]: nothing -> nothing {
    let c = (context $dir "kernel" $names)
    let m = $c.manifest
    let includes = ($m | get -o includes | default [])
    let include_flags = ($includes | each {|i| ["-I" $i] } | flatten)
    let set_flags = (defsyms $names)
    let flags = (($include_flags ++ $set_flags ++ [$march_kernel $c.prefix]) | str join " ")
    let elf = ($c.out | path join "jab.elf")
    let stamp = ($c.out | path join "flags")
    cd $c.here
    let inputs = ((files-under (["src"] ++ $includes)) ++ [$c.manifest_path $m.link])
    let id = (build-id $flags $inputs)
    if not (stale $elf $inputs $id $stamp) { return }
    mkdir $c.out
    let asm = ($c.prefix + "as")
    let ld = ($c.prefix + "ld")
    let objdump = ($c.prefix + "objdump")
    march-check $asm $march_kernel $c.out
    # only the objects of the sources there are go into the link, so an
    # object left by a source since deleted or renamed never rides along
    let objects = (paths-of ("src" | path join "*.S") | sort | each {|f|
        let obj = ($c.out | path join (($f | path parse | get stem) + ".o"))
        ^$asm $march_kernel ...$include_flags ...$set_flags $f -o $obj
        $obj
    })
    for stray in (paths-of ($c.out | path join "*.o") | where {|o| $o not-in $objects }) { retire $stray $c.root }
    ^$ld -T $m.link -nostdlib ...$objects -o $elf
    ^$objdump -d $elf | save -f ($c.out | path join "jab.disas")
    $id | save -f $stamp
}

# The roles a manifest's sections may name, each a count of harts: those
# `[reserved]` may reserve, and those a `[feature.<name>]` may demand.
const reserved_roles = [gfx_harts]
const feature_roles = [io_harts]

# A program's declared demand, from the manifest in its directory
# (program-demand): the specs it supports as asset/spec.nuon names them,
# its reservation by role, each feature's demand, and its base demand.
# Null for the legacy path, a manifest with no `specs`. Untyped because it
# ends in an error.
export def demand-of [dir: path] {
    let here = ($dir | path expand)
    let manifest = (open ($here | path join "program.jab.toml"))
    program-demand $manifest (workspace-of $here $manifest)
}

# A manifest's declared demand, validated. `specs` is a nonempty list of
# names the workspace's spec data defines, matched without regard to case
# and none twice; either section stands only beside it; `[reserved]` names
# only the roles a program reserves, and each `[feature.<name>]` has a
# snake_case name and demands at least one of the roles a feature may,
# every count a whole number of one or more. The base demand, the main
# hart and every hart reserved, is held against every listed spec's
# harts, its `cores`, a spec that cannot hold it refused by name; a
# feature's demand refuses nothing, since a spec it does not fit runs the
# program without the feature. The specs come back by their names in the
# spec data, the reservation with every role, 0 for one not reserved.
# Null for the legacy path, a manifest with no `specs` and neither
# section, which builds and launches as before, its runs recorded
# undeclared. Untyped because it ends in an error.
def program-demand [m: record, ws: oneof<string, nothing>] {
    let name = $m.name
    let specs = ($m | get -o specs)
    if $specs == null {
        let sections = ([reserved feature] | where {|k| ($m | get -o $k) != null } | each {|k| $"[($k)]" })
        if not ($sections | is-empty) { error make {msg: $"($name): ($sections | str join ' and ') beside no `specs`; a reservation or a feature's demand holds only on the specs a program lists"} }
        return null
    }
    if not ($specs | describe | str starts-with "list") { error make {msg: $"($name): `specs` is a list of spec names, not ($specs | describe)"} }
    if ($specs | is-empty) { error make {msg: $"($name): `specs` names no spec; list the specs it supports, or leave `specs` out for the legacy path"} }
    let unnamed = ($specs | where {|s| ($s | describe) != "string" or ($s | str trim) == "" })
    if not ($unnamed | is-empty) { error make {msg: $"($name): `specs` holds ($unnamed | each {|u| $u | to nuon } | str join ', '), no spec's name"} }
    if $ws == null { error make {msg: $"($name) lists specs and has no workspace, whose asset/spec.nuon defines them"} }
    let table = (specs-of $ws)
    let picked = ($specs | each {|s| { asked: $s, row: ($table | where {|r| ($r.name | str trim | str lowercase) == ($s | str trim | str lowercase) } | get -o 0) } })
    let unknown = ($picked | where {|p| $p.row == null } | each {|p| $p.asked })
    if not ($unknown | is-empty) { error make {msg: $"($name): `specs` names ($unknown | str join ', '), which its workspace's asset/spec.nuon does not define; it defines ($table | get name | str join ', ')"} }
    let twice = ($picked | group-by {|p| $p.row.name } | transpose spec asked | where {|g| ($g.asked | length) > 1 } | each {|g| $g.spec })
    if not ($twice | is-empty) { error make {msg: $"($name): `specs` names ($twice | str join ', ') twice, without regard to case"} }
    let uncounted = ($picked | where {|p| ($p.row | get -o cores | describe) != "int" } | each {|p| $p.row.name })
    if not ($uncounted | is-empty) { error make {msg: $"($name): ($uncounted | str join ', ') gives no `cores: int`, the harts a base demand is held against"} }
    let held = (section-counts $name "reserved" ($m | get -o reserved) $reserved_roles)
    let feature = ($m | get -o feature)
    if $feature != null and not ($feature | describe | str starts-with "record") { error make {msg: $"($name): `feature` holds a [feature.<name>] table for each feature, not ($feature | describe)"} }
    mut features = []
    for f in (if $feature == null { [] } else { $feature | transpose feature demand }) {
        if not ($f.feature =~ '^[a-z][a-z0-9_]*$') { error make {msg: $"($name): [feature.($f.feature)]: a feature's name is snake_case, a lowercase letter, then lowercase letters, digits, and underscores"} }
        let counts = (section-counts $name $"feature.($f.feature)" $f.demand $feature_roles)
        if ($counts | is-empty) { error make {msg: $"($name): [feature.($f.feature)] demands no hart; it names ($feature_roles | str join ' or ')"} }
        $features = ($features | append ({ name: $f.feature } | merge $counts))
    }
    let reservation = ($reserved_roles | reduce --fold {} {|r, acc| $acc | insert $r ($held | get -o $r | default 0) })
    let reserving = ($reservation | values | math sum)
    let base = (1 + $reserving)
    let short = ($picked | where {|p| $p.row.cores < $base } | each {|p| $"($p.row.name)'s ($p.row.cores)" })
    if not ($short | is-empty) { error make {msg: $"($name): its base demand, the main hart and the ($reserving) its [reserved] holds, is ($base) harts, more than ($short | str join ' and ')"} }
    { specs: ($picked | each {|p| $p.row.name }), reserved: $reservation, features: $features, base: $base }
}

# A section's counts as given, a record of role and harts, each role one
# of `roles` and each count a whole number of one or more; an empty
# record for a section left out. Untyped because it ends in an error.
def section-counts [name: string, section: string, value: any, roles: list<string>] {
    if $value == null { return {} }
    if not ($value | describe | str starts-with "record") { error make {msg: $"($name): [($section)] is a table of roles and their harts, not ($value | describe)"} }
    for k in ($value | columns) {
        if $k not-in $roles { error make {msg: $"($name): [($section)] names ($k); it names ($roles | str join ' or ')"} }
        let n = ($value | get $k)
        if ($n | describe) != "int" or $n < 1 { error make {msg: $"($name): ($section).($k) is ($n | to nuon), where a whole number of harts, one or more, is wanted"} }
    }
    $value
}

# A declared demand as the assembly takes it, generated at every build of
# the program ahead of its staleness check: `jab_manifest.inc` in the
# build's output directory, which the build carries among its includes
# and its inputs, so a program reads its numbers with `.include
# "jab_manifest.inc"` and keeps no copy of them: JAB_BASE_HARTS;
# JAB_RESERVED_<ROLE> for every role a program may reserve, 0 where it
# reserves none; and JAB_FEATURE_<NAME>_<ROLE> for every role each feature
# demands. The file is written only when its text differs from what is
# there, so its time moves with its text alone. Its path.
def demand-include [d: record, out: path]: nothing -> string {
    let reserved = ($d.reserved | transpose role harts | each {|r| $".set JAB_RESERVED_($r.role | str uppercase), ($r.harts)" })
    let features = ($d.features | each {|f| $f | reject name | transpose role harts | each {|r| $".set JAB_FEATURE_($f.name | str uppercase)_($r.role | str uppercase), ($r.harts)" } } | flatten)
    let file = ($out | path join "jab_manifest.inc")
    let text = (([$".set JAB_BASE_HARTS, ($d.base)"] ++ $reserved ++ $features | str join "\n") + "\n")
    let held = (if ($file | path exists) { open --raw $file | into binary | decode } else { "" })
    if $held != $text { $text | save -f $file }
    $file
}

# A program's declaration, the bytes its image's first page carries at
# decl_offset for the kernel to hold the machine to before the program
# starts (start_check), from its declared demand (program-demand) and its
# workspace's spec data: the base demand (u16), the count of the specs it
# lists (u8), a zero byte, then each spec's entry, decl_spec_bytes long, in
# the demand's order: its name in lowercase ASCII, zero padded to
# decl_name_bytes, then its cores, its RAM in GiB, its display's width and
# height, its frame rate, and its ISA (decl_isas), each u16, the rest zero;
# little-endian throughout. A listed spec an image cannot declare is
# refused naming the program, the spec, and why: a display other than the
# ABI's, display_size, the one every image renders at; an ISA profile
# decl_isas gives no number; RAM in no whole number of GiB; a name past
# decl_name_bytes or of other than letters and digits; a count past a u16.
# More specs than decl_specs_max are refused too. Beside the bytes the
# header's flags, offset, length, and CRC-32 (crc32): 1, decl_offset, the
# bytes' length, and their CRC for a declared program; every one 0 and no
# bytes for one declaring no demand. Untyped because it ends in an error.
def image-declaration [d: any, ws: any, program: string] {
    if $d == null { return { flags: 0, offset: 0, length: 0, crc: 0, bytes: 0x[] } }
    let count = ($d.specs | length)
    if $count > $decl_specs_max { error make {msg: $"($program) lists ($count) specs, and an image declares ($decl_specs_max) at most"} }
    let table = (specs-of $ws)
    let entries = ($d.specs | each {|listed|
        let r = ($table | where {|row| ($row.name | str lowercase) == ($listed | str lowercase) } | first)
        let name = ($r.name | str lowercase)
        if not ($name =~ '^[a-z0-9]+$') or ($name | str length) > $decl_name_bytes { error make {msg: $"($program) lists ($r.name), whose name an image declares in ($decl_name_bytes) letters and digits at most"} }
        if $r.display != $display_size { error make {msg: $"($program) lists ($r.name), whose display is ($r.display.width) by ($r.display.height), and an image renders at the ABI's ($display_size.width) by ($display_size.height)"} }
        let isa = ($decl_isas | get -o $r.isa_profile)
        if $isa == null { error make {msg: $"($program) lists ($r.name), whose ISA profile ($r.isa_profile) an image cannot declare; it declares ($decl_isas | columns | str join ', ')"} }
        if ($r.ram mod 1GiB) != 0B { error make {msg: $"($program) lists ($r.name), whose RAM, ($r.ram), is no whole number of GiB"} }
        let fields = [$r.cores ($r.ram / 1GiB | into int) $r.display.width $r.display.height $r.fps $isa]
        if ($fields | any {|f| $f < 0 or $f > 0xffff }) { error make {msg: $"($program) lists ($r.name), a count of which an image's u16 cannot hold: ($fields | str join ', ')"} }
        let named = ($name | into binary)
        $named ++ (zeros ($decl_name_bytes - ($named | bytes length))) ++ ($fields | each {|f| le $f 2 } | bytes collect) ++ (zeros ($decl_spec_bytes - $decl_name_bytes - 2 * ($fields | length)))
    })
    let bytes = ((le $d.base 2) ++ (le $count 1) ++ 0x[00] ++ ($entries | bytes collect))
    { flags: $image_declared, offset: $decl_offset, length: ($bytes | bytes length), crc: (crc32 $bytes), bytes: $bytes }
}

# The CRC-32 gzip and PNG carry, as the kernel's gz.S computes it over an
# image's declaration: the reflected polynomial 0xedb88320 through a
# table, the register starting all ones and inverted at the end.
export def crc32 [bytes: binary]: nothing -> int {
    let table = (0..255 | each {|n|
        mut c = $n
        for _ in 1..8 {
            $c = (if ($c bit-and 1) == 1 { ($c bit-shr 1) bit-xor 0xedb88320 } else { $c bit-shr 1 })
        }
        $c
    })
    mut crc = 0xffffffff
    for b in ($bytes | chunks 1) {
        let i = (($crc bit-xor ($b | into int)) bit-and 0xff)
        $crc = (($table | get $i) bit-xor ($crc bit-shr 8))
    }
    $crc bit-xor 0xffffffff
}

# The image's first page as the assembly takes it: `jab_header.S` in the
# build's output directory, generated at every build of a program ahead of
# its staleness check and counted among its inputs, its sections placed by
# program.ld, `.jab.header` at the window's base and `.jab.decl`
# decl_offset bytes on: the jump to `__jab_code`, the code's first byte at
# the second page, assembled uncompressed and unrelaxed so it is the four
# bytes of image_jump; the magic, the version, and the declaration's
# flags, offset, length, and CRC (image-declaration), then zeros to
# image_header bytes; then the declaration's bytes, none for a program
# declaring no demand. The file is written only when its text differs from
# what is there, so its time moves with its text alone. Its path.
def header-source [decl: record, out: path]: nothing -> string {
    let hex = {|v: int| $v | format number | get lowerhex }
    let rows = ($decl.bytes | chunks 16 | each {|row| "    .byte " + ($row | chunks 1 | each {|b| $"0x($b | encode hex | str lowercase)" } | str join ", ") })
    # the jump and six words, then zeros to the header's end
    let text = (([
        ".section .jab.header, \"ax\""
        ".option push"
        ".option norvc"
        ".option norelax"
        "    jal x0, __jab_code"
        ".option pop"
        $"    .4byte (do $hex $image_magic), ($image_version), ($decl.flags), ($decl.offset), ($decl.length), (do $hex $decl.crc)"
        $"    .zero ($image_header - 7 * 4)"
        ".section .jab.decl, \"a\""
    ] ++ $rows | str join "\n") + "\n")
    let file = ($out | path join "jab_header.S")
    let there = (if ($file | path exists) { open --raw $file | into binary | decode } else { "" })
    if $there != $text { $text | save -f $file }
    $file
}

# An image's first page, read as the kernel reads it before the program
# starts (start_check) and held to the rules the build writes it by
# (header-source): `legacy`, no magic at offset 4, an image built before
# the header, its first page its own code; `undeclared`, the header with
# flags 0 and the offset, the length, and the CRC 0, a program declaring no
# demand; `declared`, flags 1, the declaration at decl_offset, its length
# from one spec's to the first page's end and exactly its list's, its CRC
# holding. Where the kernel refuses an image, so does this, by the kernel's
# own reason (`declaration refused: <reason>`); past the kernel's rules, the
# jump at offset 0 is image_jump, the image holds its whole first page and
# code after it, and each entry is a name of lowercase letters and digits
# zero padded, an ISA decl_isas numbers, and zeros past its fields. The
# record: `kind`; `header`, the magic, version, flags, offset, length, and
# CRC, null for a legacy image; and `declaration`, the base demand and each
# spec with its cores, RAM in GiB, display, frame rate, and ISA, null but
# for a declared image. Each refusal names the image. Untyped because it
# ends in an error.
export def check-image [image: path] {
    let image = ($image | path expand)
    let b = (open --raw $image | into binary)
    let size = ($b | bytes length)
    let word = {|at: int| $b | bytes at $at..<($at + 4) | into int --endian little }
    let half = {|at: int| $b | bytes at $at..<($at + 2) | into int --endian little }
    let hex = {|v: int| $"0x($v | into binary --endian big | encode hex | str lowercase)" }
    if $size < 8 or (do $word 4) != $image_magic { return { kind: "legacy", header: null, declaration: null } }
    if $size < $image_header { error make {msg: $"($image): its header ends at ($size) bytes, short of ($image_header)"} }
    let header = { magic: (do $word 4), version: (do $word 8), flags: (do $word 12), offset: (do $word 16), length: (do $word 20), crc: (do $word 24) }
    let refused = {|why: string| $"($image): declaration refused: ($why)" }
    if $header.version != $image_version { error make {msg: (do $refused $"version ($header.version)")} }
    if ($header.flags bit-and (bit-not-of $image_declared)) != 0 { error make {msg: (do $refused $"flags (do $hex $header.flags)")} }
    if $header.flags == 0 {
        if $header.length != 0 { error make {msg: (do $refused "flags 0 with a length")} }
        if $header.offset != 0 { error make {msg: (do $refused "flags 0 with an offset")} }
        if $header.crc != 0 { error make {msg: (do $refused "flags 0 with a CRC")} }
    } else {
        if $header.length == 0 { error make {msg: (do $refused "flags 1 with length 0")} }
        if $header.offset != $decl_offset { error make {msg: (do $refused $"offset ($header.offset)")} }
        let least = (4 + $decl_spec_bytes)
        if $header.length < $least or $header.length > ($image_code - $decl_offset) { error make {msg: (do $refused $"length ($header.length)")} }
        if $size < ($decl_offset + $header.length) { error make {msg: $"($image): its declaration ends at ($decl_offset + $header.length) bytes, past the image's ($size)"} }
        let computed = (crc32 ($b | bytes at $decl_offset..<($decl_offset + $header.length)))
        if $computed != $header.crc { error make {msg: (do $refused $"CRC (do $hex $computed) computed, the header's (do $hex $header.crc)")} }
        let count = ($b | bytes at ($decl_offset + 2)..<($decl_offset + 3) | into int)
        if $count == 0 or $count > $decl_specs_max { error make {msg: (do $refused $"spec count ($count)")} }
        if $header.length != (4 + $count * $decl_spec_bytes) { error make {msg: (do $refused $"length ($header.length) for ($count) specs")} }
    }
    let jump = (do $word 0)
    if $jump != $image_jump { error make {msg: $"($image): the jump at offset 0 is (do $hex $jump), where jal x0 to the code, (do $hex $image_jump), belongs"} }
    if $size <= $image_code { error make {msg: $"($image): it ends at ($size) bytes, where its code begins at ($image_code)"} }
    let zeroed = {|from: int, to: int| ($b | bytes at $from..<$to | bytes index-of --all 0x[00] | length) == ($to - $from) }
    if not (do $zeroed 28 $image_header) { error make {msg: $"($image): its header past the CRC is not zero"} }
    if $header.flags == 0 { return { kind: "undeclared", header: $header, declaration: null } }
    let count = ($b | bytes at ($decl_offset + 2)..<($decl_offset + 3) | into int)
    if ($b | bytes at ($decl_offset + 3)..<($decl_offset + 4) | into int) != 0 { error make {msg: $"($image): the declaration's byte after its count is not zero"} }
    let isas = ($decl_isas | transpose name code)
    let specs = (0..<$count | each {|k|
        let at = ($decl_offset + 4 + $k * $decl_spec_bytes)
        let raw = ($b | bytes at $at..<($at + $decl_name_bytes))
        let end = ($raw | bytes index-of 0x[00])
        let used = (if $end < 0 { $decl_name_bytes } else { $end })
        let name = ($raw | bytes at 0..<$used | decode)
        if not ($name =~ '^[a-z0-9]+$') { error make {msg: $"($image): spec ($k)'s name, ($name | to nuon), is no lowercase letters and digits"} }
        if not (do $zeroed ($at + $used) ($at + $decl_name_bytes)) { error make {msg: $"($image): spec ($k)'s name, ($name), is not zero padded"} }
        let f = ($at + $decl_name_bytes)
        let isa = (do $half ($f + 10))
        if ($isas | where code == $isa | is-empty) { error make {msg: $"($image): spec ($name)'s ISA, ($isa), is none a declaration names"} }
        if not (do $zeroed ($f + 12) ($at + $decl_spec_bytes)) { error make {msg: $"($image): spec ($name)'s entry past its fields is not zero"} }
        { name: $name, cores: (do $half $f), ram_gib: (do $half ($f + 2)), display: { width: (do $half ($f + 4)), height: (do $half ($f + 6)) }, fps: (do $half ($f + 8)), isa: ($isas | where code == $isa | first | get name) }
    })
    { kind: "declared", header: $header, declaration: { base: (do $half $decl_offset), specs: $specs } }
}

# Every bit of a 32-bit word but those of `mask`.
def bit-not-of [mask: int]: nothing -> int {
    0xffffffff bit-xor $mask
}

# The demand recorded with an image at its build, `demand.nuon` beside it,
# read and held to its rules (demand-record-problems): exactly `image`, the
# image's SHA-256, and `demand`, null on the legacy path, else a demand in
# program-demand's shape. No record beside the image is absent evidence,
# no declaration, and comes back null as the legacy record's demand does;
# a record present and unsound, unreadable as NUON, of other fields, of
# another image, or of a demand off the shape, is refused naming the
# record and its faults, never read as the legacy path, as is a record
# beside no image. The demand, or null. Untyped because it can end in an
# error.
export def image-demand [image: path] {
    let image = ($image | path expand)
    let file = (demand-record-of $image)
    if not ($file | path exists) { return null }
    if not ($image | path exists) { error make {msg: $"($file) is the record of an image, and there is none at ($image)"} }
    let record = (try { open --raw $file | decode | from nuon } catch {|e| error make {msg: $"($file): not NUON the tools can read: ($e.msg)"} })
    let problems = (demand-record-problems $record (open --raw $image | hash sha256))
    if not ($problems | is-empty) { error make {msg: ([$"($file) does not hold for ($image):"] ++ ($problems | each {|p| $"  ($p)" }) | str join "\n")} }
    $record.demand
}

# Where an image's demand record lies: beside it, demand.nuon.
def demand-record-of [image: path]: nothing -> string {
    $image | path expand | path dirname | path join "demand.nuon"
}

# What is wrong with a demand record for an image of that hash, a line
# each; none when it holds: a record of exactly `image` and `demand`;
# `image` the hash; `demand` null, or in program-demand's shape
# (demand-shape-problems).
def demand-record-problems [record: any, hash: string]: nothing -> list<string> {
    let got = ($record | describe)
    if not ($got | str starts-with "record") { return [$"a record of `image` and `demand` expected, ($got) found"] }
    let fields = ($record | columns)
    let missing = ([image demand] | where {|f| $f not-in $fields } | each {|f| $"($f): missing" })
    let others = ($fields | where {|f| $f not-in [image demand] } | each {|f| $"($f): a field the record does not hold" })
    let image = (if "image" not-in $fields { [] } else {
        let i = $record.image
        if ($i | describe) != "string" { [$"image: string expected, ($i | describe) found"] } else if not ($i =~ '^[0-9a-f]{64}$') { [$"image: ($i | to nuon), no SHA-256"] } else if $i != $hash { [$"image: ($i), where the image's SHA-256 is ($hash)"] } else { [] }
    })
    let demand = (if "demand" not-in $fields { [] } else { demand-shape-problems $record.demand })
    $missing ++ $others ++ $image ++ $demand
}

# What is wrong with a recorded demand against program-demand's shape, a
# line each; none for null, the legacy path's: `specs` a nonempty list of
# names; `reserved` a record of every role reserved_roles names and no
# other, each an int of 0 or more; `features` a list of records, each a
# snake_case `name` and at least one role of feature_roles, each an int of
# 1 or more, and no other field; `base` an int, 1 plus the reserved harts.
def demand-shape-problems [d: any]: nothing -> list<string> {
    if $d == null { return [] }
    let got = ($d | describe)
    if not ($got | str starts-with "record") { return [$"demand: a record or null expected, ($got) found"] }
    let fields = ($d | columns)
    let missing = ([specs reserved features base] | where {|f| $f not-in $fields } | each {|f| $"demand.($f): missing" })
    let others = ($fields | where {|f| $f not-in [specs reserved features base] } | each {|f| $"demand.($f): a field the demand does not hold" })
    let specs = (if "specs" not-in $fields { [] } else {
        let s = $d.specs
        let kind = ($s | describe)
        if not ($kind | str starts-with "list") { [$"demand.specs: a list of names expected, ($kind) found"] } else if ($s | is-empty) { ["demand.specs: empty"] } else {
            $s | enumerate | where {|e| ($e.item | describe) != "string" or ($e.item | str trim) == "" } | each {|e| $"demand.specs.($e.index): ($e.item | to nuon), no spec's name" }
        }
    })
    let reserved = (if "reserved" not-in $fields { [] } else {
        let r = $d.reserved
        if not ($r | describe | str starts-with "record") { [$"demand.reserved: a record expected, ($r | describe) found"] } else {
            let roles = ($r | columns)
            let absent = ($reserved_roles | where {|k| $k not-in $roles } | each {|k| $"demand.reserved.($k): missing" })
            let foreign = ($roles | where {|k| $k not-in $reserved_roles } | each {|k| $"demand.reserved.($k): a role no program reserves" })
            let counts = ($roles | where {|k| $k in $reserved_roles and (($r | get $k | describe) != "int" or ($r | get $k) < 0) } | each {|k| $"demand.reserved.($k): ($r | get $k | to nuon), where a whole number of harts, 0 or more, is wanted" })
            $absent ++ $foreign ++ $counts
        }
    })
    let features = (if "features" not-in $fields { [] } else {
        let fs = $d.features
        let kind = ($fs | describe)
        if not (($kind | str starts-with "list") or ($kind | str starts-with "table")) { [$"demand.features: a list expected, ($kind) found"] } else {
            $fs | enumerate | each {|e|
                let f = $e.item
                let at = $"demand.features.($e.index)"
                if not ($f | describe | str starts-with "record") { [$"($at): a record expected, ($f | describe) found"] } else {
                    let keys = ($f | columns)
                    let named = (if "name" not-in $keys { [$"($at).name: missing"] } else if ($f.name | describe) != "string" or not ($f.name =~ '^[a-z][a-z0-9_]*$') { [$"($at).name: ($f.name | to nuon), no snake_case name"] } else { [] })
                    let roles = ($keys | where {|k| $k != "name" })
                    let foreign = ($roles | where {|k| $k not-in $feature_roles } | each {|k| $"($at).($k): a role no feature demands" })
                    let none = (if ($roles | where {|k| $k in $feature_roles } | is-empty) { [$"($at): demands no hart"] } else { [] })
                    let counts = ($roles | where {|k| $k in $feature_roles and (($f | get $k | describe) != "int" or ($f | get $k) < 1) } | each {|k| $"($at).($k): ($f | get $k | to nuon), where a whole number of harts, 1 or more, is wanted" })
                    $named ++ $foreign ++ $none ++ $counts
                }
            } | flatten
        }
    })
    let base = (if "base" not-in $fields { [] } else {
        let b = $d.base
        let r = ($d | get -o reserved)
        let summed = (if ($r | describe | str starts-with "record") and ($reserved_roles | all {|k| ($r | get -o $k | describe) == "int" }) { 1 + ($reserved_roles | each {|k| $r | get $k } | math sum) } else { null })
        if ($b | describe) != "int" { [$"demand.base: int expected, ($b | describe) found"] } else if $summed != null and $b != $summed { [$"demand.base: ($b), where 1 plus the reserved harts is ($summed)"] } else { [] }
    })
    $missing ++ $others ++ $specs ++ $reserved ++ $features ++ $base
}

# Whether the record beside an image holds (image-demand) and names the
# demand a build resolved; a record missing, unsound, of another image,
# or of another demand is false, so the build runs again whole.
def record-holds [image: path, demand: any]: nothing -> bool {
    if not (demand-record-of $image | path exists) { return false }
    try { (image-demand $image) == $demand } catch { false }
}

# The spec data a program's build reads when its manifest lists `specs`:
# the workspace's asset/spec.nuon and asset/spec.nutype, inputs of its
# build, so a changed definition or a changed type alone builds it again
# rather than leaving an image built under the old ones standing; none
# for a program that lists no specs. A program listing specs whose
# workspace has no spec data is refused naming where it looked.
def spec-inputs [c: record]: nothing -> list<string> {
    if ($c.manifest | get -o specs) == null { return [] }
    if $c.workspace == null { error make {msg: $"($c.manifest.name) lists specs and has no workspace, whose asset/spec.nuon defines them"} }
    let asset = ($c.workspace | path join "asset")
    let files = [($asset | path join "spec.nuon") ($asset | path join "spec.nutype")]
    let missing = ($files | where {|f| not ($f | path exists) })
    if not ($missing | is-empty) { error make {msg: $"($c.manifest.name) lists specs, and its workspace has no ($missing | str join ' or ')"} }
    $files
}

# Builds a program's image when stale, and writes beside it `home`, the
# program's directory, which image-home reads back from the image. A
# program declaring its demand (program-demand) has it checked at every
# build and assembles with its constants (demand-include), written ahead
# of the staleness check and counted among the build's inputs, so a
# change in the text the SDK generates builds the image again; a build of
# one declaring none retires the constants an earlier declaration left.
# Every image begins with its first page (header-source), the jump to its
# code, the header, and its declaration (image-declaration), generated and
# counted among the inputs the same way and linked ahead of the program's
# own object, so a change to a listed spec's row builds the image again
# with the new declaration, and a build with nothing changed builds
# nothing. Every build writes `demand.nuon` beside the image, the demand
# recorded with it (image-demand), and a cached image is taken only beside
# a record that holds and names the build's demand, any other building
# again whole, the image and its record together.
def build-program [dir: path, names: list<string>]: nothing -> nothing {
    let c = (context $dir "program" $names)
    let m = $c.manifest
    let specs = (spec-inputs $c)
    let demand = (program-demand $m $c.workspace)
    let declaration = (image-declaration $demand $c.workspace $m.name)
    let includes = ($m | get -o includes | default [])
    let generated = (if $demand == null { [] } else { [$c.out] })
    let include_flags = (($includes ++ $generated) | each {|i| ["-I" $i] } | flatten)
    let set_flags = (defsyms $names)
    let flags = (($include_flags ++ $set_flags ++ [$march_program $c.prefix]) | str join " ")
    let image = ($c.out | path join $"($m.name).jab")
    let stamp = ($c.out | path join "flags")
    mkdir $c.out
    let home = ($c.out | path join "home")
    if not ($home | path exists) or ((open --raw $home | decode | str trim) != $c.here) { $c.here | save -f $home }
    let constants = (if $demand == null { [] } else { [(demand-include $demand $c.out)] })
    let header = (header-source $declaration $c.out)
    cd $c.here
    let inputs = ((files-under (["src"] ++ $includes)) ++ [$c.manifest_path $m.link] ++ $specs ++ $constants ++ [$header])
    let id = (build-id $flags $inputs)
    if (not (stale $image $inputs $id $stamp)) and (record-holds $image $demand) { return }
    mkdir $c.out
    if $demand == null { retire ($c.out | path join "jab_manifest.inc") $c.root }
    let asm = ($c.prefix + "as")
    let ld = ($c.prefix + "ld")
    let objcopy = ($c.prefix + "objcopy")
    march-check $asm $march_program $c.out
    let obj = ($c.out | path join $"($m.name).o")
    let header_obj = ($c.out | path join "jab_header.o")
    let elf = ($c.out | path join $"($m.name).elf")
    ^$asm $march_program $header -o $header_obj
    ^$asm $march_program ...$include_flags ...$set_flags src/main.S -o $obj
    ^$ld -T $m.link -nostdlib $header_obj $obj -o $elf
    ^$objcopy -O binary $elf $image
    { image: (open --raw $image | hash sha256), demand: $demand } | to nuon | save -f (demand-record-of $image)
    $id | save -f $stamp
}

# What a program's test or run needs, after building it with `names`
# set: the kernel built with the same symbols in the same tree, so a
# debug program runs on a debug kernel; standalone, with no workspace,
# JAB_KERNEL is taken as it is.
def prepared [dir: path, names: list<string>]: nothing -> record {
    build-program $dir $names
    let c = (context $dir "program" $names)
    if $c.workspace != null {
        let ws = (open ($c.workspace | path join "workspace.jab.toml"))
        build-kernel ($c.workspace | path join $ws.kernel) $names
    }
    let kernel = (kernel-elf $c)
    if not ($kernel | path exists) { error make {msg: $"no kernel at ($kernel); build the kernel first, with the same --set"} }
    { context: $c, kernel: $kernel, image: ($c.out | path join $"($c.manifest.name).jab") }
}

# The arguments that run a program's test/test.nu on the kernel: the
# kernel, the image, the output directory, the assets image when the
# program has one, and the symbols the build was made with.
def test-args [ready: record]: nothing -> list<string> {
    let script = ($ready.context.here | path join "test" "test.nu")
    if not ($script | path exists) { error make {msg: $"($ready.context.manifest.name) has no test/test.nu"} }
    let assets = (assets-image $ready.context)
    let set = ($ready.context.symbols | str join ",")
    let common = [$script "--kernel" $ready.kernel "--image" $ready.image "--out" $ready.context.out "--set" $set]
    if $assets == "" { $common } else { $common ++ ["--assets" $assets] }
}

# The QEMU line that runs a program, built first: the QEMU it runs on
# (qemu-binary, beside the program and then in the workspace) and its
# arguments, the full virtio device set, the program's own disk when it
# has one, its serial the manifest's `serial` else the program's name,
# else the blank image that has always been there, the debug
# channel to a file when DEBUG is set, the API's port when `api` asks,
# the window given (null for the one a run would open), the UART where
# `serial` says (`stdio` or `none`), and no monitor, on the machine
# `spec` names, a custom one of `harts` harts, or the configured default
# (machine-for), a named spec the program does not list refused before
# QEMU starts (spec-listed). The ports' files sit beside the build
# output, named in the README. With a pad on the port, `bridge` is the
# pad's identity and `bridge_pipe` the pipe the bridge writes
# (bridge-pipe); on Windows the API's pipe takes a relay, `relays` and
# `relay_binary` as plan names them, none and "" elsewhere.
def run-line [dir: path, names: list<string>, api: bool, window: oneof<string, nothing>, serial: string, kbm: bool, pad: bool, sound: bool, --spec: string = "", --harts: int = 0]: nothing -> record<qemu_binary: string, args: list<string>, window: string, context: record, bridge: oneof<record<name: string, vendor: oneof<int, nothing>, product: oneof<int, nothing>>, nothing>, bridge_pipe: string, relays: list<record<endpoint: string, name: string, inward: string, outward: string, done: string>>, relay_binary: string, machine: record> {
    let ready = (prepared $dir $names)
    let c = $ready.context
    let m = (machine-for $c.workspace $spec $harts)
    spec-listed $m (image-demand $ready.image) $c.manifest.name
    let qemu = (qemu-binary $c.here $c.workspace)
    let line = (spec-bootargs $m "")
    let machine = ((machine-args $qemu $m) ++ (if $line == "" { [] } else { ["-append" $line] }))
    let assets = (assets-image $c)
    let disk = (if $assets == "" {
        let blank = ($c.target | path join "disk.img")
        if not ($blank | path exists) { ^truncate -s 64M $blank }
        $blank
    } else { $assets })
    let disk_serial = (if $assets == "" { "disk0" } else { disk-serial ($c.manifest | get -o serial | default $c.manifest.name) })
    let shown = (if $window == null { display $c.manifest } else { $window })
    let found = (if (discovery-wanted $pad $sound) { discover $c.workspace } else { { gamepad: null, audio: null } })
    let gamepad = (if $pad { gamepad-plan $found } else { { args: [], port: false, bridge: null } })
    # a Windows run's pipes are named pipes, named by a nonce of its own,
    # the API's taking a relay and the pad port's client the bridge
    let windows = ($nu.os-info.name == "windows")
    let nonce = (if $windows { random int 1.. } else { 0 })
    let ports = (ports $c.symbols $c.out $api $gamepad.port $c.root $nonce)
    let relays = (if $windows { relays-of $c.out [{ endpoint: "api", pipe: $ports.api }] } else { [] })
    let relay_binary = (relay-build $relays $c.workspace)
    let inputs = (if $kbm { $input_devices } else { [] })
    let audio = (if $sound { sound-args (audio-plan ($found | get -o audio)) } else { [] })
    let args = ($machine ++ (name-args $c.manifest.name) ++ (memory-args $m) ++ $display_device ++ $inputs ++ $gamepad.args ++ $devices ++ $audio ++ (disks-args (machine-disks $disk $disk_serial ($assets != "") $c.workspace)) ++ $ports.args ++ [
        "-bios" "none" "-kernel" $ready.kernel
        "-device" $"loader,file=($ready.image),addr=($program_base),force-raw=on"
        "-display" $shown "-serial" $serial "-monitor" "none"
    ] ++ (extra-args))
    let count = (transports $args)
    if $count > $transport_limit {
        error make {msg: $"the machine line carries ($count) virtio transports and virt has ($transport_limit): drop --api or --set debug, which share one, or run with --no-kbm, which frees two"}
    }
    { qemu_binary: $qemu, args: $args, window: $shown, context: $c, bridge: $gamepad.bridge, bridge_pipe: (bridge-pipe $ports.pad), relays: $relays, relay_binary: $relay_binary, machine: $m }
}

# A named spec held to the program's demand: refused naming both when the
# demand recorded with its image (image-demand) does not list it; a
# custom machine, and a legacy image, null demand, on any machine, pass.
# Untyped because it ends in an error.
def spec-listed [m: record, demand: oneof<record, nothing>, program: string] {
    if $m.spec == null or $demand == null { return }
    if $m.spec.name in ($demand.specs | each {|s| $s | str lowercase }) { return }
    error make {msg: $"($program) does not list ($m.spec.name), the spec this launch names; it lists ($demand.specs | str join ', ')"}
}

# Whatever JAB_QEMU_ARGS holds, split into words as a shell would read
# them and nothing more, appended to a run's QEMU line after everything
# else: for looking at a run with QEMU's own instruments, `-trace
# alsa_* -trace virtio_snd_* -D trace.log` on a host where a stream
# misbehaves. No shell reads the value, so a quote is removed here and
# a `*` is passed as it is; quotes keep a word with spaces together, as
# `-D "my trace.log"`. Nothing without it.
def extra-args []: nothing -> list<string> {
    shell-words ($env.JAB_QEMU_ARGS? | default "")
}

# The words of a line as a POSIX shell splits them, nothing expanded
# and nothing run: spaces separate words; a run inside single or double
# quotes is part of one word with the quotes removed; a backslash keeps
# the character after it, outside single quotes. An unclosed quote is
# an error.
def shell-words [line: string]: nothing -> list<string> {
    mut words: list<string> = []
    mut word = ""
    mut in_word = false
    mut quote = ""
    mut escaped = false
    for c in ($line | split chars) {
        if $escaped {
            $word = ($word + $c)
            $escaped = false
            $in_word = true
        } else if $quote != "" {
            if $c == $quote {
                $quote = ""
            } else if $c == "\\" and $quote == '"' {
                $escaped = true
            } else {
                $word = ($word + $c)
            }
        } else if $c == "'" or $c == '"' {
            $quote = $c
            $in_word = true
        } else if $c == "\\" {
            $escaped = true
        } else if $c in [" " "\t" "\n"] {
            if $in_word {
                $words = ($words | append $word)
                $word = ""
                $in_word = false
            }
        } else {
            $word = ($word + $c)
            $in_word = true
        }
    }
    if $quote != "" { error make {msg: $"JAB_QEMU_ARGS: a ($quote) quote is not closed: ($line)"} }
    if $escaped { error make {msg: $"JAB_QEMU_ARGS: a backslash ends the value: ($line)"} }
    if $in_word { $words = ($words | append $word) }
    $words
}

# The virtio transports a QEMU line uses: every `-device` of a
# virtio-*-device, which is how a device rides virt's mmio transports;
# a port on the serial device's own bus, and the loader, ride none.
def transports [args: list<string>]: nothing -> int {
    $args | window 2 | where {|w| $w.0 == "-device" and ($w.1 =~ '^virtio-.*-device') } | length
}

# The gamepad on the line, when there is one, from jabdisco's record.
# On Linux the pad is passed through: JAB_PAD names its evdev path
# outright, else the expected pad's path from the record, and nothing
# goes on the line with none. On macOS and Windows QEMU cannot pass a pad
# through, so with a pad in the record the pad port goes on the line and
# the bridge, jabshim_pad, is to be started beside QEMU with the pad's
# identity, which is what `bridge` carries (doc/padport.md), on Windows
# as the pad pipe's own client (PadWindows); Linux never takes that
# route. Any other host gets no pad.
def gamepad-plan [found: record]: nothing -> record<args: list<string>, port: bool, bridge: oneof<record<name: string, vendor: oneof<int, nothing>, product: oneof<int, nothing>>, nothing>> {
    let none = { args: [], port: false, bridge: null }
    let pad = ($found | get -o gamepad)
    match $nu.os-info.name {
        "linux" => {
            let forced = ($env.JAB_PAD? | default "")
            let path = (if $forced != "" { $forced } else if $pad == null { "" } else { $pad | get -o path | default "" })
            if $path == "" { $none } else { { args: ["-device" $"virtio-input-host-device,evdev=($path)"], port: false, bridge: null } }
        },
        "macos" | "windows" => {
            if $pad == null { $none } else { { args: [], port: true, bridge: { name: $pad.name, vendor: ($pad | get -o vendor), product: ($pad | get -o product) } } }
        },
        _ => $none,
    }
}

# Whether a run needs jabdisco's record at all: for the pad, unless
# JAB_PAD names one or the host takes none; for the sound, unless
# JAB_AUDIO names the backend. Nothing is discovered that an
# override already decides.
def discovery-wanted [pad: bool, sound: bool]: nothing -> bool {
    let pad_wanted = ($pad and ($env.JAB_PAD? | default "") == "" and ($nu.os-info.name in ["linux" "macos" "windows"]))
    let sound_wanted = ($sound and ($env.JAB_AUDIO? | default "") == "")
    $pad_wanted or $sound_wanted
}

# jabdisco's record: the expected gamepad and the audio output, each
# null when it finds none. With no workspace to build jabdisco in the
# record is empty.
def discover [ws: oneof<string, nothing>]: nothing -> record {
    if $ws == null { return { gamepad: null, audio: null } }
    let disco = (disco-build $ws)
    let found = (^$disco | complete)
    if $found.exit_code != 0 { error make {msg: $"jabdisco failed:\n($found.stderr)"} }
    $found.stdout | from nuon
}

# The jabdisco binary, one package of the tool workspace (tool-build).
def disco-build [ws: path]: nothing -> string {
    tool-build $ws "jabdisco" "JAB_PAD names a pad's evdev path outright and --no-pad leaves the pad off; JAB_AUDIO names the audio backend outright and --no-sound leaves the sound device off"
}

# The robojab binary, the play harness, one package of the tool workspace
# (tool-build): its path, for a script that serves a planned machine to
# an agent.
export def robo-build [ws: path]: nothing -> string {
    tool-build $ws "robojab" "the harness needs it"
}

# A package of the tool workspace, tool/ in the jab workspace, built with
# cargo into its own target/ on first use and whenever it changes, so a
# `cargo build --release` there is the same build: the binary's path,
# named as the package is. `without` says what to do with no workspace.
def tool-build [ws: path, package: string, without: string]: nothing -> string {
    let tool = ($ws | path join "tool")
    let manifest = ($tool | path join "Cargo.toml")
    if not ($manifest | path exists) { error make {msg: $"no tool workspace in this one at ($tool); ($without)"} }
    let built = (^cargo build --release --quiet --manifest-path $manifest -p $package | complete)
    if $built.exit_code != 0 { error make {msg: $"building ($package) failed:\n($built.stderr)"} }
    $tool | path join "target" "release" $package
}

# Run a program with the console window, the UART on stdio; QEMU's exit
# code is the program's exit status. A run says nothing of its own.
# With a pad on the port, the bridge runs beside QEMU, started first
# so it is writing the header as the kernel comes up, and ended with
# it; the bridge ends itself as well once its pipe has no reader. On
# Windows the relays run-line names start ahead of QEMU too, which waits
# for each pipe's client as it makes the pipe, and once QEMU has ended
# each is given a second to end with its pipe, any left stopped, and one
# that ended in failure said on stderr, naming its pipe.
def run-program [dir: path, names: list<string>, api: bool, kbm: bool, pad: bool, sound: bool, --spec: string = "", --harts: int = 0]: nothing -> nothing {
    let line = (run-line $dir $names $api null "stdio" $kbm $pad $sound --spec $spec --harts $harts)
    if ($line.window | str starts-with "vnc=") {
        print "no display server here, so this is a development run: the display is served over VNC on 127.0.0.1:5930; tunnel it with `ssh -N -L 5930:127.0.0.1:5930 <this host>` and view it with `vncviewer 127.0.0.1:5930`"
    }
    let bridge = (if $line.bridge == null { null } else {
        let bin = (shim-build $line.context.workspace "jabshim_pad" --bin)
        let pipe = $line.bridge_pipe
        let b = $line.bridge
        let vendor = (if $b.vendor == null { "" } else { $b.vendor | into string })
        let product = (if $b.product == null { "" } else { $b.product | into string })
        job spawn { ^$bin $pipe $b.name $vendor $product | complete | ignore }
    })
    let relays = (relays-start $line.relays $line.relay_binary $line.context.root)
    let qemu = $line.qemu_binary
    ^$qemu ...$line.args
    let relayed = (relays-stop $relays)
    if $bridge != null { try { job kill $bridge } }
    for r in ($relayed | where {|r| $r.exit != null and $r.exit != 0 }) {
        print -e $"jab: the ($r.endpoint) pipe's relay, for ($r.name), ended with ($r.exit): ($r.said | str trim)"
    }
}

# A shim, one package of the workspace's shim/ workspace, built with
# cargo into the target's shim/ on first use and whenever it changes:
# the path of its shared library, to preload into QEMU, or with --bin
# of its binary, named as the host names an executable (exe-name);
# --static builds a binary non-PIE, through `cargo rustc` with the
# static relocation model.
export def shim-build [ws: path, name: string, --bin, --static]: nothing -> string {
    let manifest = ($ws | path join "shim" "Cargo.toml")
    let target = (target-root $ws | path join "shim")
    let built = (if $static {
        ^cargo rustc --release --quiet --manifest-path $manifest -p $name --bin $name --target-dir $target -- -C relocation-model=static | complete
    } else {
        ^cargo build --release --quiet --manifest-path $manifest -p $name --target-dir $target | complete
    })
    if $built.exit_code != 0 { error make {msg: $"building the shim package ($name) failed:\n($built.stderr)"} }
    if $bin or $static { $target | path join "release" (exe-name $name) } else { $target | path join "release" $"lib($name).so" }
}

# Probe a program under a window. `sdl`: run it under SDL with OpenGL
# for `seconds` with shim/crates/sdl preloaded into QEMU, then report how
# its flips reached the window, read through QEMU's own symbol tables;
# `api`, `send`, and `trace` are probe-sdl's.
def probe [dir: path, kind: string, names: list<string>, seconds: int, --api, --send: string = "", --trace]: nothing -> nothing {
    match $kind {
        "sdl" => { probe-sdl $dir $names $seconds --api=$api --send $send --trace=$trace },
        _ => { error make {msg: $"no probe called ($kind); there is `sdl`"} },
    }
}

# The SDL probe: the shim built with cargo into the target's shim/, the
# program run under `sdl,gl=on` with the UART off for `seconds`, the
# shim's log read back through binutils' nm (sdl-report), and one NUON
# record printed, or the refusal saying why the log cannot be read and
# no record. Linux only, since it preloads a library into QEMU. With no
# display server SDL runs its offscreen driver, which draws nothing but
# keeps every path the same. Each run mints its capture nonce for the
# shim (launch-nonce), keeps QEMU's pid while it lives (probe-launch),
# and writes the run's identity beside the log, `identity.nuon`. Its
# profile, its port, and its sends are probe-plan's: paired where the
# build sets the manifest's `paired`, the nonce's frame sent first;
# `--api` puts the port on with nothing sent for it; `--send <file>`
# writes the file's bytes. With the port on, the program's bytes are kept
# beside the log as `api.out`.
# `--trace` has QEMU trace the device's flushes and set_scanouts into
# `trace.log` there, its messages stamped (trace-args). The run is
# bundled last (sdl-bundle) into `bundle` there, a previous bundle and
# every file the probe writes retired first.
def probe-sdl [dir: path, names: list<string>, seconds: int, --api, --send: string = "", --trace]: nothing -> nothing {
    if $nu.os-info.name != "linux" { error make {msg: "the sdl probe preloads a library into QEMU, which is Linux only"} }
    let c = (context $dir "program" $names)
    if $c.workspace == null { error make {msg: "the sdl probe needs the program's workspace, above it or named by its manifest, which holds shim/crates/sdl"} }
    if $send != "" and not ($send | path exists) { error make {msg: $"--send ($send): no such file"} }
    let shim = (shim-build $c.workspace "jabshim_sdl")
    let nonce = (launch-nonce 0 true)
    let planned = (probe-plan $c.manifest $names $nonce --api=$api --send (if $send == "" { 0x[] } else { open --raw $send | into binary }))
    let sends = $planned.sends
    let api_on = $planned.api
    let line = (run-line $dir $names $api_on "sdl,gl=on" "none" true false false)
    let out = ($line.context.out | path join "probe")
    mkdir $out
    let log = ($out | path join "sdl.log")
    let identity_file = ($out | path join "identity.nuon")
    let bundle = ($out | path join "bundle")
    let kept = ($out | path join "api.out")
    let trace_log = ($out | path join "trace.log")
    let pidfile = ($out | path join "qemu.pid")
    for f in [$log $identity_file $bundle $kept $trace_log $pidfile] { retire $f $line.context.root }
    let traced = (if $trace { trace-args $line.qemu_binary $trace_log } else { [] })
    let server = (($env.DISPLAY? | default "") != "") or (($env.WAYLAND_DISPLAY? | default "") != "")
    let driver = (if $server { "" } else { "offscreen" })
    let preload = { LD_PRELOAD: $shim, SDL_SHIM_LOG: $log, SDL_SHIM_NONCE: (nonce-hex $nonce) }
    let extra = (if $driver == "" { $preload } else { $preload | insert SDL_VIDEODRIVER $driver })
    let binary = $line.qemu_binary
    let api_in = (if $api_on { $line.context.out | path join "api.in" } else { "" })
    let bound = (timeout-binary)
    let run = (probe-launch $binary ($line.args ++ ["-pidfile" $pidfile] ++ $traced) $extra $seconds $pidfile $api_in $sends $bound.path)
    if not ($log | path exists) { error make {msg: $"QEMU wrote no shim log; its stderr:\n($run.stderr)"} }
    if $api_on { cp ($line.context.out | path join "api.out") $kept }
    let qemu = (^$binary --version | complete | get stdout | lines | get -o 0 | default "")
    let profile = $planned.profile
    let sent = ($sends | each {|s| { at: ($s.at / 1sec), length: ($s.bytes | bytes length), sha256: ($s.bytes | hash sha256) } })
    { profile: $profile, capture_nonce: $nonce, qemu_pid: $run.qemu_pid, sdl_log: $log, shim: $shim, window: "sdl,gl=on", api: $api_on, sends: $sent } | to nuon --indent 2 | save --raw $identity_file
    let report = (sdl-report $log)
    sdl-bundle $out $bundle | ignore
    let record = ({
        run: {
            program: $line.context.manifest.name,
            os: $nu.os-info.name,
            qemu: $qemu,
            binary: $report.run.binary,
            window: "sdl,gl=on",
            driver: (if $driver == "" { "the host's" } else { $driver }),
            symbols: $line.context.symbols,
            seconds: $seconds,
            qemu_said: ($run.stderr | lines | where {|l| not ($l | str contains "terminating on signal") } | first 3),
            exit: $run.exit,
            capture_nonce: $nonce,
            qemu_pid: $run.qemu_pid,
            profile: $profile,
            api: (if $api_on { $kept } else { "" }),
            sends: ($sent | zip $run.send_seconds | each {|p| $p.0 | insert written $p.1 }),
            trace: (if $trace { $trace_log } else { "" }),
            bundle: $bundle,
        },
    } | merge ($report | reject run))
    print ($record | to nuon --indent 2)
}

# What a probe of a program's build puts on the machine and sends
# (CaptureBundle's profiles): paired where the build sets the manifest's
# `paired` (probe-paired), the port on and the nonce's frame (nonce-frame)
# at 200 ms, then `send`'s bytes at 200 ms where there are any; generic
# otherwise, the port on with `api` or bytes to send, and only those
# bytes sent, never a frame of the probe's own.
export def probe-plan [manifest: record, names: list<string>, nonce: int, --api, --send: binary = 0x[]]: nothing -> record<profile: string, api: bool, sends: list<record<at: duration, bytes: binary>>> {
    let paired = (probe-paired $manifest $names)
    let framed = (if $paired { [{ at: 200ms, bytes: (nonce-frame $nonce) }] } else { [] })
    let sends = ($framed ++ (if ($send | bytes length) == 0 { [] } else { [{ at: 200ms, bytes: $send }] }))
    { profile: (if $paired { "paired" } else { "generic" }), api: ($api or not ($sends | is-empty)), sends: $sends }
}

# Whether a probe of a program's build is paired (CaptureBundle): the
# manifest's `paired` names the build symbol under which the program
# reads the capture nonce's frame from the API before it starts, and the
# build sets it. Any other probe is generic.
def probe-paired [manifest: record, names: list<string>]: nothing -> bool {
    let symbol = ($manifest | get -o paired | default "")
    $symbol != "" and (($symbol | str screaming-snake-case) in $names)
}

# The capture nonce's frame, what a paired program reads from the API
# before it starts (CaptureBundle): `WNON` as a le32, a zero word, and
# the nonce as a le64, 16 bytes; the nonce 1 to 2^63 - 1.
export def nonce-frame [nonce: int]: nothing -> binary {
    if $nonce < 1 { error make {msg: $"a capture nonce is 1 to 2^63 - 1, not ($nonce)"} }
    0x[57 4e 4f 4e 00 00 00 00] ++ ($nonce | into binary --endian little)
}

# The QEMU words that trace the GPU device's flushes and set_scanouts into
# `log`, each message stamped with the host's wall clock (-msg
# timestamp=on), which sdl-bundle-check pairs with the shim's uploads;
# refused on a QEMU whose trace events do not list both.
export def trace-args [qemu: string, log: path]: nothing -> list<string> {
    let events = (^$qemu -trace help | complete | get stdout | lines | each {|l| $l | str trim })
    let missing = (["virtio_gpu_cmd_res_flush" "virtio_gpu_cmd_set_scanout"] | where {|e| $e not-in $events })
    if not ($missing | is-empty) { error make {msg: $"($qemu) lists no trace event ($missing | str join ' or '), which --trace needs"} }
    ["-msg" "timestamp=on" "-trace" "virtio_gpu_cmd_res_flush" "-trace" "virtio_gpu_cmd_set_scanout" "-D" $log]
}

# A probe's QEMU run to its exit or its bound, `seconds`, polled as a
# launch polls (launch): QEMU's pid kept from `pidfile` at the first poll
# that finds it alive, since QEMU unlinks the file as it exits, and each
# entry of `sends` written into `api_in` once its time has come, in
# order, through fifo-write. The exit, QEMU's stderr, the pid, null where
# QEMU never came up, and each entry's write in seconds from the start,
# null where it never went in.
def probe-launch [binary: string, args: list<string>, environment: record, seconds: int, pidfile: path, api_in: string, sends: list<record<at: duration, bytes: binary>>, bound: string]: nothing -> record<exit: int, stderr: string, qemu_pid: oneof<int, nothing>, send_seconds: list<oneof<float, nothing>>> {
    let started = (date now)
    job spawn { with-env $environment { ^$bound --signal=TERM ($seconds | into string) $binary ...$args | complete } | job send 0 }
    mut result: any = null
    mut qemu_pid: any = null
    mut written = ($sends | each --keep-empty {|_| null })
    mut taken = 0
    while $result == null {
        $result = (try { job recv --timeout 100ms } catch { null })
        let pid = (try { open --raw $pidfile | str trim } catch { "" })
        let alive = ($result == null and (process-alive $pid))
        if $alive and $qemu_pid == null { $qemu_pid = ($pid | into int) }
        let elapsed = ((date now) - $started)
        while $alive and $taken < ($sends | length) and ($sends | get $taken | get at) <= $elapsed {
            if $api_in != "" and (fifo-write $api_in ($sends | get $taken | get bytes) $bound) {
                $written = ($written | update $taken (((date now) - $started) / 1sec))
            }
            $taken += 1
        }
    }
    { exit: $result.exit_code, stderr: $result.stderr, qemu_pid: $qemu_pid, send_seconds: $written }
}

# The shim's log as written (shim/crates/sdl): the object table, each
# object by index with its path and the inode, size, and modification
# time in nanoseconds its file had as its line was written, null where it
# had no file, as the vDSO has none; and the events in order, each
# make_current with its frames past the leading ones in the shim's own
# library, object 1, which it counts, a frame by its object's index (null
# for none) and its address as written and as a number, and whether the
# timing rule makes it a render: a window-size call the next event,
# within 2 ms; every event with its stamp as the log wrote it. A last line
# the run's end cut short is left out. The run's lines are events too, and
# their values come back apart: `process`, QEMU's pid, and `nonce`, the
# capture nonce as its sixteen hex digits, each null where the log has
# none, as a log written before them has neither. Every complete line is
# held to the lines the shim writes (sdl_line) before any is read, and a
# log the shim could not have written is refused, in order: a line outside
# them, counted in lines with up to four shown by number; a notice the
# shim wrote as it stopped the run, by name; a run's line given twice,
# malformed, or out of its place (sdl-run-lines); then no object table,
# an index given twice, a frame naming an index with no line ahead of it,
# or a make_current whose frames do not start in the shim's library.
export def sdl-log [log: path]: nothing -> record<objects: table, events: table, process: oneof<int, nothing>, nonce: oneof<string, nothing>> {
    let text = (open --raw $log | into binary | decode)
    let whole = ($text | split row (char nl) | drop 1)
    if ($whole | is-empty) { error make {msg: "the shim log is empty; the window made no SDL calls"} }
    let unwritten = ($whole | enumerate | where {|l| not ($l.item =~ $sdl_line) })
    if not ($unwritten | is-empty) {
        let shown = ($unwritten | first 4 | each {|l| $"line ($l.index + 1): ($l.item | str substring --grapheme-clusters 0..<80)" })
        error make {msg: (sdl-refusal [{ fault: "the log has a line the shim does not write", held: ($unwritten | length), unit: "line", examples: $shown }])}
    }
    let notices = ($whole | each {|l| $l | str replace --regex '^[0-9]+\.[0-9]{6} ' '' } | where {|l| $l in $sdl_notices })
    if not ($notices | is-empty) {
        let stops = ($notices | uniq --count | each {|n| { fault: $"the shim stopped the run: ($n.value)", held: $n.count, unit: "line", examples: [] } })
        error make {msg: (sdl-refusal $stops)}
    }
    let run = (sdl-run-lines ($whole | enumerate | each {|l| { line: ($l.index + 1), text: ($l.item | str replace --regex '^[0-9]+\.[0-9]{6} ' '') } } | where {|l| not ($l.text | str starts-with "object ") }))
    if $run.fault != "" { error make {msg: (sdl-refusal [{ fault: $run.fault, held: $run.held, unit: "line", examples: $run.examples }])} }
    let rows = ($whole
        | parse --regex '^(?P<ts>\d+\.\d+) (?P<name>\S+) ?(?P<rest>.*)$'
        | enumerate
        | each {|r| { at: $r.index, stamp: $r.item.ts, ts: ($r.item.ts | into float), name: $r.item.name, rest: $r.item.rest } })
    let objects = ($rows | where name == "object" | each {|r|
        let o = ($r.rest | parse --regex '^(?P<index>\d+) (?P<inode>\d+|-) (?P<size>\d+|-) (?P<mtime>-?\d+|-) (?P<path>.*)$' | first)
        {
            at: $r.at,
            index: ($o.index | into int),
            inode: (if $o.inode == "-" { null } else { $o.inode | into int }),
            size: (if $o.size == "-" { null } else { $o.size | into int }),
            mtime: (if $o.mtime == "-" { null } else { $o.mtime | into int }),
            path: $o.path,
        }
    })
    let first = ($objects | reduce --fold {} {|o, seen|
        let key = ($o.index | into string)
        if ($seen | get -o $key) == null { $seen | insert $key $o.at } else { $seen }
    })
    let happened = ($rows | where name != "object")
    let events = ($happened | enumerate | each {|r|
        let e = $r.item
        if $e.name != "make_current" {
            { at: $e.at, stamp: $e.stamp, ts: $e.ts, name: $e.name, render: false, shim_frames: 0, frames: [], fault: "", example: "" }
        } else {
            let frames = ($e.rest
                | str trim
                | split row " "
                | compact --empty
                | parse --regex '^(?P<object>\d+|\?)\+(?P<hex>[0-9a-f]+)$'
                | each {|f| { object: (if $f.object == "?" { null } else { $f.object | into int }), hex: $f.hex, address: ($f.hex | into int --radix 16) } })
            let shim = ($frames | take while {|f| $f.object == 1 } | length)
            let next = ($happened | get -o ($r.index + 1))
            let render = ($next != null and $next.name == "size" and ($next.ts - $e.ts) < 0.002)
            let unnamed = ($frames | where {|f| $f.object != null and (($first | get -o ($f.object | into string)) == null or ($first | get ($f.object | into string)) > $e.at) })
            let fault = (if not ($unnamed | is-empty) { "unnamed" } else if $shim == 0 { "outside" } else { "" })
            let example = (if $fault == "unnamed" {
                let f = ($unnamed | first)
                $"($f.object)+($f.hex)"
            } else if $fault == "outside" and ($frames | is-empty) {
                "no frames"
            } else if $fault == "outside" {
                let f = ($frames | first)
                let file = (if $f.object == null { "?" } else { $objects | where index == $f.object | get -o 0.path | default "" | path basename })
                $"($file)+($f.hex)"
            } else { "" })
            { at: $e.at, stamp: $e.stamp, ts: $e.ts, name: $e.name, render: $render, shim_frames: $shim, frames: ($frames | skip $shim), fault: $fault, example: $example }
        }
    })
    let made = ($events | where name == "make_current")
    let total = ($made | length)
    if ($objects | is-empty) { error make {msg: (sdl-refusal [{ fault: "the log has no object table", held: $total, unit: "make_current", examples: [] }])} }
    let twice = ($objects | get index | uniq --repeated)
    if not ($twice | is-empty) { error make {msg: (sdl-refusal [{ fault: "the object table gives an index twice", held: $total, unit: "make_current", examples: ($twice | each {|i| $"object ($i)" }) }])} }
    for fault in [
        ["unnamed" "a frame names an object the table has no line for ahead of it"]
        ["outside" "a make_current's frames do not start in the shim's own library"]
    ] {
        let held = ($made | where fault == $fault.0)
        if not ($held | is-empty) { error make {msg: (sdl-refusal [{ fault: $fault.1, held: ($held | length), unit: "make_current", examples: ($held | get example | uniq) }])} }
    }
    { objects: ($objects | reject at), events: ($events | reject fault example), process: $run.process, nonce: $run.nonce }
}

# A shim log's run lines (sdl-log), from its events in order, each its
# line number and its text past the stamp: the process as the first event,
# `process` and QEMU's pid in ASCII digits, and the capture nonce as the
# second, `nonce` and sixteen lowercase hex digits, not all zero, a run's
# line at most once each. The pid and the nonce, null where the log has
# none; or the first fault, a process line before a nonce line: one given
# twice, one malformed, a nonce with no process line ahead of it, then one
# out of its place, with how many lines hold it and up to four.
def sdl-run-lines [events: list<record<line: int, text: string>>]: nothing -> record<process: oneof<int, nothing>, nonce: oneof<string, nothing>, fault: string, held: int, examples: list<string>> {
    let process = ($events | enumerate | where {|e| $e.item.text =~ '^process(?: |$)' })
    let nonce = ($events | enumerate | where {|e| $e.item.text =~ '^nonce(?: |$)' })
    let refused = {|fault: string, rows: list<any>|
        { process: null, nonce: null, fault: $fault, held: ($rows | length), examples: ($rows | first 4 | each {|r| $"line ($r.item.line): ($r.item.text | str substring --grapheme-clusters 0..<80)" }) }
    }
    if ($process | length) > 1 { return (do $refused "the log gives its process line twice" $process) }
    if ($nonce | length) > 1 { return (do $refused "the log gives its nonce line twice" $nonce) }
    let bad_process = ($process | where {|e| not ($e.item.text =~ '^process [1-9][0-9]{0,9}$') })
    if not ($bad_process | is-empty) { return (do $refused "the log's process line is malformed, where `process` and a pid in ASCII digits are wanted" $bad_process) }
    let bad_nonce = ($nonce | where {|e| not ($e.item.text =~ '^nonce [0-9a-f]{16}$') or $e.item.text == "nonce 0000000000000000" })
    if not ($bad_nonce | is-empty) { return (do $refused "the log's nonce line is malformed, where `nonce` and sixteen lowercase hex digits, not all zero, are wanted" $bad_nonce) }
    let ahead = ($nonce | where {|e| ($process | is-empty) or $e.index < ($process | first | get index) })
    if not ($ahead | is-empty) { return (do $refused "the log's nonce line comes with no process line ahead of it" $ahead) }
    let early = ($process | where {|e| $e.index != 0 })
    if not ($early | is-empty) { return (do $refused "the log's process line is out of its place, the first event" $early) }
    let astray = ($nonce | where {|e| $e.index != 1 })
    if not ($astray | is-empty) { return (do $refused "the log's nonce line is out of its place, the second event after the process line" $astray) }
    {
        process: (if ($process | is-empty) { null } else { $process | first | get item.text | str substring 8.. | into int }),
        nonce: (if ($nonce | is-empty) { null } else { $nonce | first | get item.text | str substring 6.. }),
        fault: "",
        held: 0,
        examples: [],
    }
}

# An object's table left unread, with the state that kept it so.
def sdl-unread [state: string, why: string]: nothing -> record {
    { state: $state, why: $why, source: "", starts: [], ends: [], reach: [], names: [], console: false, nm: "" }
}

# A file's inode, size, and modification time in nanoseconds as `ls -l`
# gives them now, the three an object's line records; null where no file
# is there.
def sdl-stat [path: string]: nothing -> oneof<record<inode: int, size: int, mtime: int>, nothing> {
    let now = (try { ls -l $path | get -o 0 } catch { null })
    if $now == null { return null }
    { inode: $now.inode, size: ($now.size | into int), mtime: ($now.modified | into int) }
}

# The symbol table of an object a decision needs, as binutils' nm reads
# it: its full table, else on "no symbols" its dynamic one, keeping the
# function symbols that carry a size, each name read up to its first `.`
# so gcc's parts (.cold, .part.N, .isra.N, .constprop.N, .lto_priv.N)
# read as their function, sorted by start with the furthest end reached
# so far beside each, which bounds a search back to an enclosing function
# (sdl-functions-at). The file is read only while it is the one its line
# names, the inode, size, and modification time `ls -l` gives now the
# same, and an executable whose path ends ` (deleted)` never is. `state`
# says which held: read, no_file, nm_absent, deleted, changed, or
# unreadable, with nm's own words in `why`; `source` which table
# answered: symtab, dynsym, or none; `console` whether it holds both of
# the console's update functions of one family; and `nm`, nm's text as it
# was read, which a bundle keeps (sdl-bundle).
def sdl-table [object: record, nm: bool]: nothing -> record {
    if $object.inode == null or $object.size == null or $object.mtime == null { return (sdl-unread "no_file" "") }
    if not $nm { return (sdl-unread "nm_absent" "") }
    if $object.index == 0 and ($object.path | str ends-with " (deleted)") { return (sdl-unread "deleted" "") }
    let now = (try { ls -l $object.path | get -o 0 } catch { null })
    if $now == null { return (sdl-unread "changed" "no file is there now") }
    if $now.inode != $object.inode or ($now.size | into int) != $object.size or ($now.modified | into int) != $object.mtime {
        return (sdl-unread "changed" "its inode, size, or modification time is not its line's")
    }
    let full = (^nm -P -t x --defined-only $object.path | complete)
    let dynamic = ($full.exit_code == 0 and ($full.stdout | str trim) == "" and ($full.stderr | str contains "no symbols"))
    let run = (if $dynamic { ^nm -P -t x --defined-only -D $object.path | complete } else { $full })
    if $run.exit_code != 0 { return (sdl-unread "unreadable" ($run.stderr | str trim | split row $"($object.path): " | last)) }
    let source = (if not $dynamic { "symtab" } else if ($run.stdout | str trim) == "" { "none" } else { "dynsym" })
    sdl-table-from $run.stdout $source
}

# A symbol table read from nm's POSIX text as sdl-table reads it, `source`
# the table the text came from, the text kept whole as `nm`.
def sdl-table-from [text: string, source: string]: nothing -> record {
    let functions = ($text | lines
        | parse --regex '^(?P<name>\S+) (?P<type>[tTwW]) (?P<value>[0-9a-f]+) (?P<size>[0-9a-f]+)$'
        | into int --radix 16 value size
        | where size > 0
        | str replace --regex '^([^.]+)\..*$' '$1' name
        | sort-by value)
    let spans = ($functions | generate {|f, most|
        let end = ($f.value + $f.size)
        let reach = (if $end > $most { $end } else { $most })
        { out: { end: $end, reach: $reach }, next: $reach }
    } 0)
    let names = ($functions | get name)
    let console = ($console_updates | any {|family| $family | all {|n| $n in $names } })
    { state: "read", why: "", source: $source, starts: ($functions | get value), ends: ($spans | get end), reach: ($spans | get reach), names: $names, console: $console, nm: $text }
}

# A needed object's table out of a bundle (sdl-bundle) in place of nm on
# its path, the replay's source (sdl-bundle-check): the state its
# manifest entry records where that is not `read`, else its table file,
# taken only when the file's raw bytes have the SHA-256 the entry names;
# `unbundled` where the manifest holds no entry, no table, or another
# table's bytes.
def sdl-bundled-table [object: record, manifest: record, bundle: path]: nothing -> record {
    let entry = ($manifest.objects | where index == $object.index | get -o 0)
    if $entry == null { return (sdl-unread "unbundled" "the manifest has no entry for it") }
    if $entry.state != "read" { return (sdl-unread $entry.state $entry.why) }
    let file = ($bundle | path join $entry.table)
    if not ($file | path exists) { return (sdl-unread "unbundled" "its table is not in the bundle") }
    let bytes = (open --raw $file | into binary)
    if ($bytes | hash sha256) != $entry.table_sha256 { return (sdl-unread "unbundled" "its table's bytes are not those the manifest names") }
    sdl-table-from ($bytes | decode) $entry.source
}

# The functions of a table (sdl-table) whose [start, end) holds an
# address, aliases included: a binary search for the last start at or
# below it, then back while the furthest end reached so far lies past
# it. None where the address falls between functions.
def sdl-functions-at [table: record, address: int]: nothing -> list<string> {
    let starts = $table.starts
    let ends = $table.ends
    let reach = $table.reach
    let names = $table.names
    mut low = 0
    mut high = ($starts | length)
    while $low < $high {
        let middle = (($low + $high) // 2)
        if ($starts | get $middle) <= $address { $low = $middle + 1 } else { $high = $middle }
    }
    mut at = $low - 1
    mut found: list<string> = []
    while $at >= 0 and ($reach | get $at) > $address {
        if ($ends | get $at) > $address { $found = ($found ++ [($names | get $at)]) }
        $at -= 1
    }
    $found | uniq | sort
}

# The shim's log at `log` (sdl-log) with its make_currents' frames
# resolved: the object table, each object with its file name and the
# state of its symbol table (sdl-table); `virtio_gpu_in`, module or
# executable; and every event in order, each frame of a make_current
# with its object's file name, its table's state, and the functions that
# hold it. A frame is a return address, so it resolves at the address
# less one: a call that ends its function returns to the first byte past
# it. It lies in every function of its object's table whose [value,
# value + size) holds that address, an alias included, and in none where
# the address falls between functions. The tables read are the ones a
# decision needs: the objects of the immediate caller and of its caller
# in every make_current the timing rule leaves, and the executable's
# where the device's code is there; with --every, every object a
# make_current's frame lies in. The device's code lives in a module when
# the table lists one whose file name starts hw-display-virtio-gpu, else
# in the executable. With --tables, a bundle's directory (sdl-bundle),
# each table comes out of the bundle in place of nm on its object's path,
# as a bundle's check replays it (sdl-bundled-table). A log the shim could
# not have written is refused.
export def sdl-resolve [log: path, --every, --tables: string = ""]: nothing -> record<objects: table, virtio_gpu_in: string, events: table> {
    sdl-resolved $log $every $tables | reject tables process nonce
}

# sdl-resolve's reading, beside it each object's table whole as read
# (sdl-table), by index, and the run's lines (sdl-log); `bundle` the
# tables' bundle, "" for nm.
def sdl-resolved [log: path, every: bool, bundle: string]: nothing -> record<objects: table, virtio_gpu_in: string, events: table, tables: record, process: oneof<int, nothing>, nonce: oneof<string, nothing>> {
    let read = (sdl-log $log)
    let modules = ($read.objects | where {|o| $o.path | path basename | str starts-with $device_module } | get index)
    let device_in = (if ($modules | is-empty) { "executable" } else { "module" })
    let made = ($read.events | where name == "make_current")
    let decided = ($made | where render == false)
    let needed = (if $every {
        $made | each {|e| $e.frames | each {|f| $f.object } } | flatten | uniq
    } else {
        let callers = ($decided | each {|e| $e.frames | first 2 | each {|f| $f.object } } | flatten)
        let executable = (if $device_in == "executable" and (not ($decided | is-empty)) { [0] } else { [] })
        $callers ++ $executable | uniq
    })
    let manifest = (if $bundle == "" { null } else { open --raw ($bundle | path join "bundle.nuon") | into binary | decode | from nuon })
    let nm = ($manifest == null and (which nm | where type == "external" | is-not-empty))
    let tables = ($read.objects | reduce --fold {} {|o, all|
        let table = (if $o.index not-in $needed { sdl-unread "unread" "" } else if $manifest == null { sdl-table $o $nm } else { sdl-bundled-table $o $manifest $bundle })
        $all | insert ($o.index | into string) $table
    })
    let pairs = ($made | each {|e| $e.frames } | flatten | where object != null | uniq-by object hex)
    let found = ($pairs | reduce --fold {} {|f, all|
        let table = ($tables | get ($f.object | into string))
        let functions = (if $table.state == "read" { sdl-functions-at $table ($f.address - 1) } else { [] })
        $all | insert $"($f.object)+($f.hex)" $functions
    })
    let objects = ($read.objects | each {|o|
        let table = ($tables | get ($o.index | into string))
        $o | merge { file: ($o.path | path basename), state: $table.state, source: $table.source, functions: ($table.names | length), console: $table.console, why: $table.why }
    })
    let places = ($objects | reduce --fold {} {|o, all| $all | insert ($o.index | into string) { file: $o.file, state: $o.state } })
    let events = ($read.events | each {|e|
        if $e.name != "make_current" { $e } else {
            $e | update frames ($e.frames | each {|f|
                if $f.object == null { $f | merge { file: "", state: "no_object", functions: [] } } else {
                    let place = ($places | get ($f.object | into string))
                    $f | merge { file: $place.file, state: $place.state, functions: ($found | get $"($f.object)+($f.hex)") }
                }
            })
        }
    })
    { objects: $objects, virtio_gpu_in: $device_in, events: $events, tables: $tables, process: $read.process, nonce: $read.nonce }
}

# The refusal a frame's object holds before its symbols can answer: nm
# absent, the file changed or the executable deleted, a replay's table
# not in its bundle, or nm unable to read it; null when its table was
# read or it has none to read.
def sdl-held [frame: record]: nothing -> oneof<record, nothing> {
    match $frame.state {
        "nm_absent" => ({ kind: "refused", class: 2, fault: "nm_absent", at: $frame }),
        "deleted" => ({ kind: "refused", class: 3, fault: "deleted", at: $frame }),
        "changed" => ({ kind: "refused", class: 3, fault: "changed", at: $frame }),
        "unbundled" => ({ kind: "refused", class: 3, fault: "unbundled", at: $frame }),
        "unreadable" => ({ kind: "refused", class: 4, fault: "unreadable", at: $frame }),
        _ => null,
    }
}

# Whether a frame lies in the device's code: in a virtio-gpu module, or,
# with the device in the executable, in an executable function named
# virtio_gpu_*.
def sdl-device [frame: record, device_in: string, modules: list<int>]: nothing -> bool {
    if $device_in == "module" { $frame.object in $modules } else { $frame.object == 0 and ($frame.functions | any {|n| $n | str starts-with "virtio_gpu_" }) }
}

# How a make_current the timing rule leaves reached the window, by its
# frames past the shim's own (sdl-resolve). Its immediate caller must
# resolve to the SDL front end, the anchor: sdl2_gl_switch makes a
# `switch`, the window taking a new surface; sdl2_gl_update an upload,
# read by its second frame, the function that called it. The console's
# update there makes it a flip's `upload` when a later frame lies in the
# device's code, and leaves it unresolved however many frames follow
# otherwise; any other resolved function outside the device's code makes
# it the `console`'s own, a new surface's redraw or the registration's
# first update; an unresolved frame of the executable makes it the
# console's own only beside a device module, with the executable's table
# read and holding both of the console's update functions of one family,
# since a module reaches the console through those alone. Anything else
# is `refused`: `class` says which refusal (sdl-report), `fault` what
# failed, and `at` the frame at fault.
def sdl-decide [frames: list, device_in: string, modules: list<int>, executable: oneof<record, nothing>]: nothing -> record<kind: string, class: int, fault: string, at: oneof<record, nothing>> {
    let caller = ($frames | get -o 0)
    if $caller == null { return { kind: "refused", class: 5, fault: "anchor", at: null } }
    let caller_held = (sdl-held $caller)
    if $caller_held != null { return $caller_held }
    if not ($caller.functions | any {|n| $n | str starts-with "sdl2_" }) { return { kind: "refused", class: 5, fault: "anchor", at: $caller } }
    let switch = ("sdl2_gl_switch" in $caller.functions)
    let update = ("sdl2_gl_update" in $caller.functions)
    if $switch and (not $update) { return { kind: "switch", class: 0, fault: "", at: null } }
    if (not $update) or $switch { return { kind: "refused", class: 5, fault: "front_end", at: $caller } }
    let second = ($frames | get -o 1)
    if $second == null { return { kind: "refused", class: 6, fault: "absent", at: $caller } }
    if $second.object == null { return { kind: "refused", class: 6, fault: "nowhere", at: $second } }
    let second_held = (sdl-held $second)
    if $second_held != null { return $second_held }
    if (sdl-device $second $device_in $modules) { return { kind: "refused", class: 5, fault: "device", at: $second } }
    if not ($second.functions | is-empty) {
        if not ($console_updates | flatten | any {|n| $n in $second.functions }) { return { kind: "console", class: 0, fault: "", at: null } }
        let later = ($frames | skip 2)
        if $device_in == "executable" {
            let later_held = ($later | where {|f| $f.object == 0 } | each {|f| sdl-held $f } | get -o 0)
            if $later_held != null { return $later_held }
        }
        if ($later | any {|f| sdl-device $f $device_in $modules }) { return { kind: "upload", class: 0, fault: "", at: null } }
        return { kind: "refused", class: 6, fault: "cut_short", at: $second }
    }
    if $second.object == 0 and $device_in == "module" and $executable != null and $executable.state == "read" and $executable.console {
        return { kind: "console", class: 0, fault: "", at: null }
    }
    { kind: "refused", class: 6, fault: "unanswered", at: $second }
}

# A frame as the record's callers name it: its function where it
# resolves, aliases joined by `/`, else its object's file name and
# address, `?` for no object.
def sdl-frame-name [frame: record]: nothing -> string {
    if not ($frame.functions | is-empty) { $frame.functions | str join "/" } else if $frame.object == null { $"?+($frame.hex)" } else { $"($frame.file)+($frame.hex)" }
}

# A frame at fault, for a refusal: its object's file name and address,
# `?` for no object, with its functions where it resolves.
def sdl-frame-text [frame: oneof<record, nothing>]: nothing -> string {
    if $frame == null { return "the shim's own frames alone" }
    let place = (if $frame.object == null { $"?+($frame.hex)" } else { $"($frame.file)+($frame.hex)" })
    if ($frame.functions | is-empty) { $place } else { $"($place) \(($frame.functions | str join '/'))" }
}

# What an object's symbol table holds, for a refusal, the executable
# named as such.
def sdl-table-text [object: record]: nothing -> string {
    let who = (if $object.index == 0 { $"the executable at ($object.path)" } else { $object.path })
    if $object.state == "no_file" { return $"($who) has no file to read" }
    if $object.state != "read" { return $"($who) went unread" }
    match $object.source {
        "symtab" => $"($who) keeps a symbol table of ($object.functions) sized functions",
        "dynsym" => $"($who) keeps no symbol table, only dynamic symbols, ($object.functions) sized functions among them",
        _ => $"($who) keeps no symbol table and no dynamic symbols",
    }
}

# A fault's words for a refusal, naming the object it lies in.
def sdl-fault-text [fault: string, at: oneof<record, nothing>, objects: table]: nothing -> string {
    let object = (if $at == null or $at.object == null { null } else { $objects | where index == $at.object | get -o 0 })
    let table = (if $at == null { "its frames end in the shim's own library" } else if $object == null { "it lies in no object" } else { sdl-table-text $object })
    let path = (if $object == null { "" } else { $object.path | str replace --regex ' \(deleted\)$' '' })
    match $fault {
        "nm_absent" => "binutils' nm is not on PATH, and the frames' symbol tables are read with it",
        "deleted" => $"the executable at ($path) was deleted after it started",
        "changed" => $"($path) is not the file its line in the object table names, rebuilt or replaced since the run",
        "unbundled" => (if $object.why == "" { $"the bundle holds no table for ($path)" } else { $"the bundle holds no table for ($path): ($object.why)" }),
        "unreadable" => (if $object.why == "" { $"nm cannot read ($path)" } else { $"nm cannot read ($path): ($object.why)" }),
        "anchor" => $"a make_current's immediate caller is not in the SDL front end, and ($table)",
        "front_end" => "a make_current comes from a front-end function the probe does not model",
        "device" => "an upload's second frame is the device's own code, which the probe does not model",
        "absent" => "an upload's chain ends at its immediate caller",
        "nowhere" => "an upload's second frame lies in no object",
        "unanswered" => $"an upload's second frame resolves in no table, and ($table)",
        "cut_short" => "a console update has no device frame after it",
        _ => $fault,
    }
}

# A refusal's faults (sdl-refusal) from the chains one class refused: one
# a fault and the object it lies in, how many make_currents hold it by
# the chains' counts, and the frames at fault.
def sdl-faults [cases: table, counts: record, objects: table]: nothing -> table<fault: string, held: int, unit: string, examples: list<string>> {
    let described = ($cases | each {|c| $c | insert text (sdl-fault-text $c.fault $c.at $objects) })
    $described | get text | uniq | each {|text|
        let group = ($described | where text == $text)
        {
            fault: $text,
            held: ($group | each {|c| $counts | get $c.key } | math sum),
            unit: "make_current",
            examples: ($group | each {|c| sdl-frame-text $c.at } | uniq | first 4),
        }
    }
}

# A refusal's message: each fault it holds, how many of its unit hold it,
# make_currents or the log's lines, and up to four of them.
def sdl-refusal [faults: table<fault: string, held: int, unit: string, examples: list<string>>]: nothing -> string {
    let parts = ($faults | each {|f|
        let plural = (if $f.held == 1 { "" } else { "s" })
        let shown = (if ($f.examples | is-empty) { "" } else { ", among them " + ($f.examples | first 4 | str join ", ") })
        $"($f.fault): ($f.held) ($f.unit)($plural)($shown)"
    })
    $"the sdl probe refuses the log: ($parts | str join '; ')"
}

# The shim's log at `log` (sdl-resolve) with each make_current read by
# where it came from. A make_current followed by a window-size call
# within 2 ms opens a drawn frame, a `render`. Every other is read by its
# frames (sdl-decide): a `switch`, the window taking a new surface; a
# flip's `upload`, one per rectangle the device flushed; or one of the
# `console`'s own, which is no flip of the program's. Each event gains
# its `kind`, a make_current's one of those four and any other event's
# its name, and its `callers` as the record names them (sdl-frame-name),
# the immediate caller first. The reading comes only when every
# make_current is decided; otherwise the first refusal in order: the
# log's lines, a stop notice, and its structure (sdl-log), nm absent, an
# object that is no longer the file its line names or a deleted
# executable, an object nm cannot read, a make_current failing the anchor
# or unmodelled, and an upload whose second frame does not resolve, each
# naming its fault, how many make_currents or lines hold it, and up to
# four of them. With --tables, a bundle's directory, the tables come out
# of the bundle (sdl-resolve).
export def sdl-classify [log: path, --tables: string = ""]: nothing -> record<objects: table, virtio_gpu_in: string, events: table> {
    let c = (sdl-classified $log $tables)
    { objects: $c.objects, virtio_gpu_in: $c.virtio_gpu_in, events: ($c.events | reject key) }
}

# A make_current's chain as the reading keys it: its frames past the
# shim's own, each an object's index or `?` with its address in hex; an
# event with no frames keys the empty chain.
def sdl-chain-key [frames: list<any>]: nothing -> string {
    let chain = ($frames | each {|f| $"(if $f.object == null { '?' } else { $f.object })+($f.hex)" } | str join " ")
    $"chain:($chain)"
}

# sdl-classify's reading with each event's chain key kept, each chain's
# decision by key, every object's table whole (sdl-resolved), and the
# run's lines; `bundle` the tables' bundle, "" for nm.
def sdl-classified [log: path, bundle: string]: nothing -> record<objects: table, virtio_gpu_in: string, events: table, decisions: list<any>, tables: record, process: oneof<int, nothing>, nonce: oneof<string, nothing>> {
    let resolved = (sdl-resolved $log false $bundle)
    let events = $resolved.events
    if ($events | is-empty) { error make {msg: "the shim log holds no events; the window made no SDL calls"} }
    let executable = ($resolved.objects | where index == 0 | get -o 0)
    let modules = ($resolved.objects | where {|o| $o.file | str starts-with $device_module } | get index)
    let keyed = ($events | each {|e| $e | insert key (sdl-chain-key $e.frames) })
    let made = ($keyed | where name == "make_current")
    let decided = ($made | where render == false)
    let chains = ($decided | uniq-by key)
    let decisions = ($chains | reduce --fold {} {|e, all| $all | insert $e.key (sdl-decide $e.frames $resolved.virtio_gpu_in $modules $executable) })
    let counts = ($decided | get key | uniq --count | reduce --fold {} {|c, all| $all | insert $c.value $c.count })
    let refused = ($chains | each {|e|
        let d = ($decisions | get $e.key)
        if $d.kind == "refused" { $d | insert key $e.key }
    })
    for class in [2 3 4 5 6] {
        let cases = ($refused | where class == $class)
        if not ($cases | is-empty) { error make {msg: (sdl-refusal (sdl-faults $cases $counts $resolved.objects))} }
    }
    let named = ($made | uniq-by key | reduce --fold {} {|e, all| $all | insert $e.key ($e.frames | each {|f| sdl-frame-name $f } | str join " < ") })
    let read = ($keyed | each {|e|
        if $e.name != "make_current" { $e | merge { kind: $e.name, callers: "" } } else {
            let kind = (if $e.render { "render" } else { $decisions | get $e.key | get kind })
            $e | merge { kind: $kind, callers: ($named | get $e.key) }
        }
    })
    let decided_chains = ($chains | each {|e| { key: $e.key } | merge ($decisions | get $e.key | reject at) })
    { objects: $resolved.objects, virtio_gpu_in: $resolved.virtio_gpu_in, events: $read, decisions: $decided_chains, tables: $resolved.tables, process: $resolved.process, nonce: $resolved.nonce }
}

# The report on a shim log (sdl-classify): how the flips reached the
# window, one record, or the refusal saying why the log cannot be read.
# A flip's uploads within 5 ms of the previous belong to one flip;
# switches and the console's own never join one. A drawn frame with a
# flip's upload under 3 ms on each side sits inside a flip, which is the
# half-drawn tick to look for.
export def sdl-report [log: path]: nothing -> record {
    let classified = (sdl-classify $log)
    let events = $classified.events
    let executable = ($classified.objects | where index == 0 | get -o 0)
    let kinds = ($events | select ts kind callers)
    let t0 = ($events | first | get ts)
    let uploads = ($kinds | where kind == "upload")
    let others = ($kinds | where kind == "console")
    let switches = ($kinds | where kind == "switch")
    let renders = ($kinds | where kind == "render" | get ts)
    let polls = ($kinds | where kind == "poll" | get ts)
    mut flips: list<record<start: float, end: float, size: int, gaps: list<float>>> = []
    for u in $uploads {
        if (($flips | length) > 0) and (($u.ts - ($flips | last | get end)) < 0.005) {
            let f = ($flips | last)
            $flips = (($flips | drop 1) ++ [{ start: $f.start, end: $u.ts, size: ($f.size + 1), gaps: ($f.gaps ++ [(($u.ts - $f.end) * 1000.0)]) }])
        } else {
            $flips = ($flips ++ [{ start: $u.ts, end: $u.ts, size: 1, gaps: [] }])
        }
    }
    let done = $flips
    mut last_upload = -1.0
    mut befores: list<float> = []
    for e in $kinds {
        if $e.kind == "upload" { $last_upload = $e.ts } else if $e.kind == "render" { $befores = ($befores ++ [(if $last_upload < 0.0 { 1.0 } else { $e.ts - $last_upload })]) }
    }
    mut next_upload = -1.0
    mut afters: list<float> = []
    for e in ($kinds | reverse) {
        if $e.kind == "upload" { $next_upload = $e.ts } else if $e.kind == "render" { $afters = ($afters ++ [(if $next_upload < 0.0 { 1.0 } else { $next_upload - $e.ts })]) }
    }
    let afters_in_order = ($afters | reverse)
    let befores_in_order = $befores
    let inside = ($renders | enumerate | each {|r|
        let before = (($befores_in_order | get $r.index) * 1000.0)
        let after = (($afters_in_order | get $r.index) * 1000.0)
        if $before < 3.0 and $after < 3.0 { { at: (($r.item - $t0) | math round -p 3), upload_before_ms: ($before | math round -p 2), upload_after_ms: ($after | math round -p 2) } } else { null }
    } | compact)
    let spans = ($done | where size > 1 | each {|f| ($f.end - $f.start) * 1000.0 })
    let gaps = ($done | get gaps | flatten)
    let cadence = ($done | window 2 | each {|w| ($w.1.start - $w.0.start) * 1000.0 })
    let intervals = ($renders | window 2 | each {|w| ($w.1 - $w.0) * 1000.0 })
    let hist = {|values: list<float>| $values | each {|v| $v | math round -p 0 } | uniq --count | sort-by count --reverse | first 6 | each {|c| { ms: $c.value, count: $c.count } } }
    let stat = {|values: list<float>| if ($values | is-empty) { { median: 0.0, max: 0.0 } } else { { median: ($values | math median | math round -p 2), max: ($values | math max | math round -p 2) } } }
    let range = {|values: list<float>| if ($values | is-empty) { { median: 0.0, min: 0.0, max: 0.0 } } else { { median: ($values | math median | math round -p 0), min: ($values | math min | math round -p 0), max: ($values | math max | math round -p 0) } } }
    let top = {|rows: list| $rows | get callers | uniq --count | sort-by count --reverse | first 2 | each {|c| { callers: $c.value, count: $c.count } } }
    # which guest frame each render showed: the flips whose last upload
    # landed since the render before it; none is the frame before shown
    # again, one is that flip shown, more is every one but the last
    # skipped, so a beat between the guest's cadence and the window's
    # timer reads as skips or repeats at a steady interval and a stall
    # as a burst of them
    let flip_count = ($done | length)
    mut next_flip = 0
    mut showings: list<record<at: float, flips: int>> = []
    for r in $renders {
        mut n = 0
        while ($next_flip < $flip_count) and (($done | get $next_flip | get end) <= $r) {
            $n += 1
            $next_flip += 1
        }
        $showings = ($showings ++ [{ at: ($r - $t0), flips: $n }])
    }
    let showed = $showings
    let repeats = ($showed | where flips == 0)
    let skips = ($showed | where flips > 1)
    let skipped = (if ($skips | is-empty) { 0 } else { $skips | each {|s| $s.flips - 1 } | math sum })
    let skip_times = ($skips | get at)
    let repeat_times = ($repeats | get at)
    let between = {|times: list<float>| $times | window 2 | each {|w| ($w.1 - $w.0) * 1000.0 } }
    {
        run: { binary: (if $executable == null { "" } else { $executable.path }) },
        virtio_gpu_in: $classified.virtio_gpu_in,
        seconds_logged: ((($events | last | get ts) - $t0) | math round -p 1),
        flips: ($done | length),
        uploads_per_flip: ($done | get size | uniq --count | sort-by count --reverse | first 6 | each {|c| { uploads: $c.value, count: $c.count } }),
        flip_span_ms: (do $stat $spans),
        upload_gap_ms: (do $stat $gaps),
        flip_cadence_ms: (do $hist $cadence),
        renders: ($renders | length),
        render_interval_ms: (do $hist $intervals),
        frames_shown: { shown: ($showed | where flips == 1 | length), repeated: ($repeats | length), skipped: $skipped, unshown_at_end: ($flip_count - $next_flip) },
        skip_times_s: ($skip_times | first 24 | each {|t| $t | math round -p 3 }),
        skip_interval_ms: (do $range (do $between $skip_times)),
        repeat_times_s: ($repeat_times | first 24 | each {|t| $t | math round -p 3 }),
        repeat_interval_ms: (do $range (do $between $repeat_times)),
        renders_inside_flip: ($inside | length),
        inside_cases: ($inside | first 8),
        polls: ($polls | length),
        switches: ($switches | length),
        other_uploads: ($others | length),
        upload_callers: (do $top $uploads),
        other_upload_callers: (do $top $others),
        switch_callers: (do $top $switches),
        render_callers: (do $top ($kinds | where kind == "render")),
    }
}

# A probed run's capture made portable, `jab sdl-bundle <probe dir>
# <bundle dir>`, on the host that took it as the run's last step, while
# the objects its log names are still the files their lines name. The log
# in the probe directory, `sdl.log`, is classified as the probe reads it
# (sdl-classify), a refusal ending the bundle with nothing written; then
# into `bundle`, a directory not yet there, go the log as it was written;
# for each object whose table the reading read, nm's text as it was
# parsed, `tables/<index>.nm`, the file's own SHA-256 taken with its
# inode, size, and modification time its line's before the hash and
# unchanged after it, a change refusing the bundle as changed while
# bundling; `classified.nuon`, every event with its line, stamp, name,
# render flag, chain key, kind, and callers, each chain's decision, and
# the counts by kind; the probe directory's `api.out`, `identity.nuon`,
# `trace.log`, and each file `extra` names, where it has them, copied
# whole; and last `bundle.nuon`, the manifest, bundle_schema 1: the
# profile; the reader (sdl-reader); the host, its OS, kernel release,
# hostname, and QEMU (sdl-qemu-of); every object of the log's table with
# its line's fields, its state, and for a read one its SHA-256 and its
# table with that file's SHA-256 and its source; every other file with
# its SHA-256 and size; the events counted; and the run, the identity's
# capture fields beside the log's process and nonce. The profile is
# `--profile`, else the identity's, else generic, and historical for a
# log written before the run's lines; a paired bundle needs the log's
# nonce, `api.out`, and `identity.nuon`. The manifest. Untyped because it
# ends in an error.
export def sdl-bundle [probe: path, bundle: path, --profile: string = "", --extra: list<string> = []] {
    let probe = ($probe | path expand)
    let bundle = ($bundle | path expand)
    let log = ($probe | path join "sdl.log")
    if not ($log | path exists) { error make {msg: $"($probe) holds no sdl.log to bundle"} }
    if ($bundle | path type) != null { error make {msg: $"($bundle) is already there; a bundle is written once"} }
    let identity_file = ($probe | path join "identity.nuon")
    let identity = (if ($identity_file | path exists) { open --raw $identity_file | into binary | decode | from nuon } else { null })
    let c = (sdl-classified $log "")
    let lined = ($c.process != null)
    let given = (if $identity == null { "" } else { $identity | get -o profile | default "" })
    let named = (if $profile != "" { $profile } else if $given != "" { $given } else if $lined { "generic" } else { "historical" })
    if $named not-in [paired generic historical] { error make {msg: $"a bundle's profile is paired, generic, or historical, not ($named)"} }
    if $lined and $named == "historical" { error make {msg: "the log carries the run's lines, so its bundle is paired or generic, never historical"} }
    if (not $lined) and $named != "historical" { error make {msg: $"the log has no process line, so it was written before the run's lines and its bundle is historical, not ($named)"} }
    if $named == "paired" {
        if $c.nonce == null { error make {msg: "a paired bundle needs the log's nonce line, and this log has none"} }
        let missing = (["api.out" "identity.nuon"] | where {|f| not ($probe | path join $f | path exists) })
        if not ($missing | is-empty) { error make {msg: $"a paired bundle needs ($missing | str join ' and ') beside the log in ($probe)"} }
    }
    let carried = (["api.out" "identity.nuon" "trace.log"] ++ $extra | uniq | where {|f| $probe | path join $f | path exists })
    let read = ($c.objects | where {|o| ($c.tables | get ($o.index | into string) | get state) == "read" })
    let hashed = ($read | each {|o|
        let before = (sdl-stat $o.path)
        if $before != { inode: $o.inode, size: $o.size, mtime: $o.mtime } { error make {msg: $"($o.path) changed while bundling: it is no longer the file its line names"} }
        let sha256 = (open --raw $o.path | hash sha256)
        if (sdl-stat $o.path) != $before { error make {msg: $"($o.path) changed while bundling, during its hash"} }
        { index: $o.index, sha256: $sha256 }
    })
    mkdir ($bundle | path join "tables")
    cp $log ($bundle | path join "sdl.log")
    for x in $hashed { $c.tables | get ($x.index | into string) | get nm | save --raw ($bundle | path join "tables" $"($x.index).nm") }
    let events = ($c.events | each {|e| { line: ($e.at + 1), stamp: $e.stamp, name: $e.name, render: $e.render, key: $e.key, kind: $e.kind, callers: $e.callers } })
    let counts = ($events | get kind | uniq --count | reduce --fold {} {|k, acc| $acc | insert $k.value $k.count })
    { events: $events, decisions: $c.decisions, counts: $counts } | to nuon --indent 1 | save --raw ($bundle | path join "classified.nuon")
    for f in $carried {
        mkdir ($bundle | path join $f | path dirname)
        cp ($probe | path join $f) ($bundle | path join $f)
    }
    let files = (paths-of ($bundle | path join "**" "*") --no-dir | each {|p| { path: ($p | path relative-to $bundle), sha256: (open --raw $p | hash sha256), size: (ls -D $p | get 0.size | into int) } } | sort-by path)
    let field = {|name: string| if $identity == null { null } else { $identity | get -o $name } }
    let manifest = {
        bundle_schema: 1,
        profile: $named,
        reader: (sdl-reader),
        host: { os: $nu.os-info.name, kernel: $nu.os-info.kernel_version, hostname: (sys host | get hostname), qemu: (sdl-qemu-of ($c.objects | where index == 0 | get -o 0) ($hashed | where index == 0 | get -o 0.sha256)) },
        objects: ($c.objects | each {|o|
            let t = ($c.tables | get ($o.index | into string))
            let h = ($hashed | where index == $o.index | get -o 0)
            let table = (if $h == null { null } else { $"tables/($o.index).nm" })
            {
                index: $o.index, path: $o.path, inode: $o.inode, size: $o.size, mtime: $o.mtime,
                state: $t.state, why: $t.why, sha256: (if $h == null { null } else { $h.sha256 }),
                table: $table, table_sha256: (if $table == null { null } else { $files | where path == $table | get 0.sha256 }), source: $t.source,
            }
        }),
        files: $files,
        events: ($events | length),
        run: { process: $c.process, nonce: $c.nonce, capture_nonce: (do $field "capture_nonce"), qemu_pid: (do $field "qemu_pid"), api: (do $field "api"), sends: (do $field "sends") },
    }
    $manifest | to nuon --indent 1 | save --raw ($bundle | path join "bundle.nuon")
    $manifest
}

# The reader a bundle records and its check sets beside its own: the jab
# commit this tool runs from, null outside a git checkout, and this
# file's SHA-256.
def sdl-reader []: nothing -> record<jab: oneof<string, nothing>, jab_nu_sha256: string> {
    let at = (try { ^git -C ($self | path dirname) rev-parse HEAD | complete } catch { { exit_code: 1, stdout: "" } })
    { jab: (if $at.exit_code == 0 { $at.stdout | str trim } else { null }), jab_nu_sha256: (open --raw $self | hash sha256) }
}

# The QEMU a log names, object 0 of its table (sdl-log): its path, and
# while the file is the one its line names, its version and its SHA-256,
# `sha256` where it was taken already; null fields otherwise.
def sdl-qemu-of [exe: oneof<record, nothing>, sha256: oneof<string, nothing>]: nothing -> record<path: string, version: oneof<string, nothing>, sha256: oneof<string, nothing>> {
    if $exe == null { return { path: "", version: null, sha256: null } }
    if (sdl-stat $exe.path) != { inode: $exe.inode, size: $exe.size, mtime: $exe.mtime } { return { path: $exe.path, version: null, sha256: null } }
    let version = (try { ^$exe.path --version | complete | get stdout | lines | get -o 0 } catch { null })
    { path: $exe.path, version: $version, sha256: (if $sha256 != null { $sha256 } else { open --raw $exe.path | hash sha256 }) }
}

# A bundle (sdl-bundle) held to its manifest wherever it is read, `jab
# sdl-bundle-check <bundle dir>`, stage by stage, the first that fails
# refusing it by its stage and name with nothing read from it: 1, the
# inventory, every file the manifest lists there with its SHA-256 and size
# and none it does not but bundle.nuon, sdl.log and classified.nuon among
# them and a paired bundle's api.out and identity.nuon; 2, the
# correspondence, the manifest's objects one for one with the log's table
# lines, index, path, inode, size, and modification time alike, a read
# object's table listed and no other's; 3, the sequence, the log's events
# as sdl-log reads them, which reads no object file, classified.nuon's in
# count and line by line in line, stamp, name, render flag, and chain key;
# 4, the replay, the log classified again from the bundle's tables
# (sdl-classify --tables), every event's kind and callers classified.nuon's;
# 5, the run by its profile: paired, the log's process the identity's
# qemu_pid, the log's nonce the identity's capture_nonce, and the nonce
# the guest echoed, read from the bundle's api.out by `guest`, the
# program's reader, equal to both, a 0 or a missing value refused; generic
# and historical, nothing bound and nothing paired; and with trace.log,
# QEMU's flushes paired in order one for one with the log's flip uploads,
# each upload within 5 ms after its flush on the one host clock; 6, the
# reader, the host's set beside this one, the replay's equality being what
# admits another revision. The profile, the run, both readers, the trace's
# pairing, and classified.nuon's events. Untyped because it ends in an
# error.
export def sdl-bundle-check [bundle: path, --guest: closure] {
    let dir = ($bundle | path expand)
    let refuse = {|stage: int, name: string, why: string| error make {msg: $"the bundle is refused at stage ($stage), ($name): ($why)"} }
    let manifest_file = ($dir | path join "bundle.nuon")
    if not ($manifest_file | path exists) { do $refuse 1 "the inventory" $"($dir) holds no bundle.nuon" }
    let m = (try { open --raw $manifest_file | into binary | decode | from nuon } catch {|e| do $refuse 1 "the inventory" $"bundle.nuon is no NUON the check reads: ($e.msg)" })
    if ($m | get -o bundle_schema) != 1 { do $refuse 1 "the inventory" $"bundle.nuon's bundle_schema is ($m | get -o bundle_schema | to nuon), where 1 is read" }
    let profile = ($m | get -o profile | default "")
    let listed = ($m | get -o files | default [])
    let names = ($listed | get -o path | default [])
    let present = (paths-of ($dir | path join "**" "*") --no-dir | each {|p| $p | path relative-to $dir } | where {|p| $p != "bundle.nuon" } | sort)
    let unlisted = ($present | where {|p| $p not-in $names })
    if not ($unlisted | is-empty) { do $refuse 1 "the inventory" $"files the manifest does not list: ($unlisted | str join ', ')" }
    for f in $listed {
        let file = ($dir | path join $f.path)
        if not ($file | path exists) { do $refuse 1 "the inventory" $"($f.path), listed, is not there" }
        let size = (ls -D $file | get 0.size | into int)
        let sha256 = (open --raw $file | hash sha256)
        if $size != $f.size or $sha256 != $f.sha256 { do $refuse 1 "the inventory" $"($f.path) is not the file the manifest lists: ($size) bytes of ($sha256), where it lists ($f.size) of ($f.sha256)" }
    }
    let required = (["sdl.log" "classified.nuon"] ++ (if $profile == "paired" { ["api.out" "identity.nuon"] } else { [] }))
    for r in $required { if $r not-in $names { do $refuse 1 "the inventory" $"the manifest lists no ($r), which a ($profile) bundle holds" } }
    let read = (try { sdl-log ($dir | path join "sdl.log") } catch {|e| do $refuse 2 "the correspondence" $"the reader refuses the log: ($e.msg)" })
    let objects = ($m | get -o objects | default [])
    if ($objects | length) != ($read.objects | length) { do $refuse 2 "the correspondence" $"the manifest lists ($objects | length) objects and the log's table ($read.objects | length)" }
    for pair in ($read.objects | zip $objects) {
        let o = $pair.0
        let e = $pair.1
        for k in [index path inode size mtime] {
            if ($o | get $k) != ($e | get -o $k) { do $refuse 2 "the correspondence" $"object ($o.index)'s ($k) is ($e | get -o $k | to nuon) in the manifest and ($o | get $k | to nuon) in the log's table" }
        }
        let table = ($e | get -o table)
        if ($e | get -o state) == "read" {
            if $table == null or $table not-in $names { do $refuse 2 "the correspondence" $"object ($o.index)'s table was read, and the manifest lists none for it" }
        } else if $table != null { do $refuse 2 "the correspondence" $"object ($o.index)'s table went unread, and the manifest lists one for it" }
    }
    let cls = (try { open --raw ($dir | path join "classified.nuon") | into binary | decode | from nuon } catch {|e| do $refuse 3 "the sequence" $"classified.nuon is no NUON the check reads: ($e.msg)" })
    let logged = ($read.events | each {|e| { line: ($e.at + 1), stamp: $e.stamp, name: $e.name, render: $e.render, key: (sdl-chain-key $e.frames) } })
    let held = ($cls.events | each {|e| { line: $e.line, stamp: $e.stamp, name: $e.name, render: $e.render, key: $e.key } })
    if ($logged | length) != ($held | length) { do $refuse 3 "the sequence" $"the log holds ($logged | length) events and classified.nuon ($held | length)" }
    for pair in ($logged | zip $held) {
        if $pair.0 != $pair.1 { do $refuse 3 "the sequence" $"the log's event at line ($pair.0.line) is ($pair.0 | to nuon), classified.nuon's ($pair.1 | to nuon)" }
    }
    let replay = (try { sdl-classified ($dir | path join "sdl.log") $dir } catch {|e| do $refuse 4 "the replay" $"the log classified from the bundle's tables is refused: ($e.msg)" })
    for pair in ($replay.events | zip $cls.events) {
        let got = { kind: $pair.0.kind, callers: $pair.0.callers }
        let want = { kind: $pair.1.kind, callers: $pair.1.callers }
        if $got != $want { do $refuse 4 "the replay" $"the event at line ($pair.1.line) replays as ($got | to nuon), where classified.nuon holds ($want | to nuon)" }
    }
    let run = (match $profile {
        "paired" => {
            let id = (open --raw ($dir | path join "identity.nuon") | into binary | decode | from nuon)
            let pid = ($id | get -o qemu_pid)
            let nonce = ($id | get -o capture_nonce)
            if $read.process == null { do $refuse 5 "the run" "the log has no process line" }
            if $pid == null or $pid == 0 { do $refuse 5 "the run" "the identity records no qemu_pid" }
            if $read.process != $pid { do $refuse 5 "the run" $"the log's process ($read.process) is not the identity's qemu_pid ($pid)" }
            if $read.nonce == null { do $refuse 5 "the run" "the log has no nonce line" }
            if $nonce == null or $nonce == 0 { do $refuse 5 "the run" "the identity records no capture_nonce" }
            if $read.nonce != (nonce-hex $nonce) { do $refuse 5 "the run" $"the log's nonce ($read.nonce) is not the identity's capture_nonce, (nonce-hex $nonce)" }
            if $guest == null { do $refuse 5 "the run" "the guest's echoed nonce goes unread: a paired bundle is checked with its program's reader of api.out, --guest" }
            let echoed = (do $guest ($dir | path join "api.out"))
            if $echoed == null or $echoed == 0 { do $refuse 5 "the run" "the guest echoed no nonce, its records reading 0" }
            if $echoed != $nonce { do $refuse 5 "the run" $"the guest echoed (nonce-hex $echoed), where the run's nonce is (nonce-hex $nonce)" }
            { process: $read.process, nonce: $read.nonce, capture_nonce: $nonce, qemu_pid: $pid, guest_nonce: $echoed }
        },
        "generic" | "historical" => { { process: $read.process, nonce: $read.nonce, capture_nonce: null, qemu_pid: null, guest_nonce: null } },
        _ => { do $refuse 5 "the run" $"the manifest's profile is ($profile | to nuon), where paired, generic, or historical is read" },
    })
    let trace = (if "trace.log" not-in $names { null } else {
        let flushes = (open --raw ($dir | path join "trace.log") | into binary | decode | lines
            | parse --regex '^(?P<at>\S+) virtio_gpu_cmd_res_flush\b'
            | each {|c| ($c.at | into datetime | into int) / 1e9 })
        let uploads = ($replay.events | where kind == "upload" | get ts)
        if ($flushes | length) != ($uploads | length) { do $refuse 5 "the run" $"the trace holds ($flushes | length) flushes and the log ($uploads | length) flip uploads" }
        let lags = ($flushes | zip $uploads | each {|p| ($p.1 - $p.0) * 1000.0 })
        let off = ($lags | enumerate | where {|l| $l.item < 0.0 or $l.item >= 5.0 })
        if not ($off | is-empty) { do $refuse 5 "the run" $"flip upload ($off | first | get index | $in + 1) lies ($off | first | get item | math round -p 3) ms after its flush, outside the 5 ms after it" }
        { flushes: ($flushes | length), uploads: ($uploads | length), max_lag_ms: (if ($lags | is-empty) { null } else { $lags | math max | math round -p 3 }) }
    })
    let host = ($m | get -o reader)
    let box = (sdl-reader)
    { profile: $profile, run: $run, reader: { host: $host, box: $box, same: ($host == $box) }, trace: $trace, events: $cls.events }
}

# A guest's present sequence held to the device's count (ProbeRuns'
# receipt stage): `frames` in order, each presented or not with the
# present ordinal it carries, `anchor` the ordinal of the last present
# before them. A presented frame's ordinal is one past the last, any
# other frame's the last; every violation comes back by the frame's
# index with the rule it broke, `skip` an advance past one, `repeat` a
# present with the last's ordinal, `backward` an ordinal below the last,
# `advance` a frame that presented nothing yet moved on, with its ordinal
# and the one wanted, each frame judged against the one before as it
# reads, so one fault is one violation. None where the sequence holds.
export def ordinal-violations [anchor: int, frames: list<record<presented: bool, ordinal: int>>]: nothing -> list<record<index: int, rule: string, ordinal: int, wanted: int>> {
    mut last = $anchor
    mut found = []
    for f in ($frames | enumerate) {
        let got = $f.item.ordinal
        let wanted = (if $f.item.presented { $last + 1 } else { $last })
        if $got != $wanted {
            let rule = (if $got < $last { "backward" } else if not $f.item.presented { "advance" } else if $got == $last { "repeat" } else { "skip" })
            $found = ($found | append { index: $f.index, rule: $rule, ordinal: $got, wanted: $wanted })
        }
        $last = $got
    }
    $found
}

# The presentation contract's K over a run's presented acceptances in
# order, the receipts' stamps in ticks: every pair i < j stands more than
# (j - i) periods less `eps` apart. With q the acceptance less its index
# times the period, K holds for every pair exactly when each q exceeds
# the largest earlier q less eps, so the running maximum and its index
# are kept and the check is linear. Every violation by its flip's index,
# its witness the index of that maximum, the two flips' gap, and the
# bound it did not pass. Read only on a present sequence that held
# (ordinal-violations), so no present is missing from the flips.
export def k-violations [accepted: list<int>, period: int, eps: int]: nothing -> list<record<index: int, witness: int, gap: int, bound: int>> {
    mut found = []
    mut top = 0
    mut witness = -1
    for a in ($accepted | enumerate) {
        let q = ($a.item - $a.index * $period)
        if $witness >= 0 and $q <= ($top - $eps) {
            let before = ($accepted | get $witness)
            $found = ($found | append { index: $a.index, witness: $witness, gap: ($a.item - $before), bound: (($a.index - $witness) * $period - $eps) })
        }
        if $witness < 0 or $q > $top {
            $top = $q
            $witness = $a.index
        }
    }
    $found
}

# The pairing's limits, printed with every reading (sdl-pair).
const pair_limits = "the pairing assumes the run binding, which ties the guest's records to the log, and that the log records every upload once and that every flush the device accepted makes one upload; under those assumptions it is exact, and the oracle's flush trace rechecks them run by run on the box. The residual is a consistency check: it proves no absence of a loss and an addition that compensate inside the window, and it catches a uniform shift only where the paired intervals are irregular past half a period. The fit gives intervals and jitter, and no absolute guest-to-SDL latency."

# A probed run's presents paired one for one with the host's flip uploads
# (ProbeRuns), from the run's classified events, a validated paired
# bundle's (sdl-bundle-check) or sdl-classify's on the host with the run's
# binding checked there, and the guest's flips in its window in order,
# each its status, its present ordinal, and its end in microseconds on the
# guest's clock: 1, the presented flips' ordinals each one past the one
# before (ordinal-violations), a gap refusing the run; 2, the host's flip
# uploads numbered from the log's first, 1 on, the shim logging from
# QEMU's start; 3, the present of ordinal k paired with upload k, the log
# holding every ordinal through the window's last present and going on at
# least 1 s of host time past its upload, uploads past the window read for
# nothing; 4, the fit, least squares for the offset and the drift of the
# paired uploads' stamps against the presents' ends, every residual under
# half the period. Refused, each named and counted, all of them found: an
# ordinal gap; the log short of an ordinal; a duplicated event, two in a
# row alike in stamp, name, and chain; a stamp going backwards; a residual
# past half the period; a device error in the window; the log ending under
# 1 s past the window's last upload; fewer than two presents to fit. A
# refused run is unresolved and never trimmed to make counts agree. `ok`,
# the refusals, the pairs with their residuals, the fit, the window's
# ordinals, and the limits (pair_limits), printed with every reading.
export def sdl-pair [events: list<any>, flips: list<record<status: int, ordinal: int, end_us: number>>, --period: float = 0.016666666666666666]: nothing -> record<ok: bool, refusals: list<record<refusal: string, count: int>>, pairs: list<any>, fit: oneof<record, nothing>, window: oneof<record, nothing>, limits: string> {
    let host = ($events | each {|e| { ts: (if ($e | get -o ts) != null { $e.ts } else { $e.stamp | into float }), name: $e.name, kind: ($e | get -o kind | default $e.name), key: ($e | get -o key | default "") } })
    let presented = ($flips | where status == 0)
    let uploads = ($host | where kind == "upload")
    mut refusals = []
    let gaps = (if ($presented | is-empty) { [] } else { ordinal-violations (($presented | first | get ordinal) - 1) ($presented | each {|p| { presented: true, ordinal: $p.ordinal } }) })
    if not ($gaps | is-empty) { $refusals = ($refusals | append { refusal: "an ordinal gap in the guest's presents", count: ($gaps | length) }) }
    let last = (if ($presented | is-empty) { 0 } else { $presented | last | get ordinal })
    let short = ($last - ($uploads | length))
    if $short > 0 { $refusals = ($refusals | append { refusal: "the log short of an ordinal", count: $short }) }
    let duplicated = ($host | window 2 | where {|w| $w.0 == $w.1 } | length)
    if $duplicated > 0 { $refusals = ($refusals | append { refusal: "a duplicated event", count: $duplicated }) }
    let backwards = ($host | window 2 | where {|w| $w.1.ts < $w.0.ts } | length)
    if $backwards > 0 { $refusals = ($refusals | append { refusal: "a stamp going backwards", count: $backwards }) }
    let errors = ($flips | where status == 3 | length)
    if $errors > 0 { $refusals = ($refusals | append { refusal: "a device error in the window", count: $errors }) }
    if ($presented | length) < 2 { $refusals = ($refusals | append { refusal: "fewer than two presents to fit", count: ($presented | length) }) }
    let held = ($short <= 0 and $last >= 1)
    if $held {
        let after = (($host | last | get ts) - ($uploads | get ($last - 1) | get ts))
        if $after < 1.0 { $refusals = ($refusals | append { refusal: "the log ending under 1 s past the window's last upload", count: 1 }) }
    }
    let paired = (if (not $held) or ($presented | length) < 2 { [] } else { $presented | each {|p| { ordinal: $p.ordinal, end_us: $p.end_us, upload: ($uploads | get ($p.ordinal - 1) | get ts) } } })
    let fit = (if ($paired | is-empty) { null } else {
        let base = ($paired | first | get upload)
        let xs = ($paired | each {|p| $p.end_us / 1e6 })
        let ys = ($paired | each {|p| $p.upload - $base })
        let mx = ($xs | math avg)
        let my = ($ys | math avg)
        let sxx = ($xs | each {|x| ($x - $mx) * ($x - $mx) } | math sum)
        let sxy = ($xs | zip $ys | each {|p| ($p.0 - $mx) * ($p.1 - $my) } | math sum)
        let drift = (if $sxx == 0.0 { 1.0 } else { $sxy / $sxx })
        let offset = ($my - $drift * $mx)
        let residuals = ($xs | zip $ys | each {|p| ($p.1 - ($offset + $drift * $p.0)) * 1000.0 })
        { base: $base, offset: $offset, drift: $drift, residuals_ms: $residuals }
    })
    let pairs = (if $fit == null { [] } else { $paired | zip $fit.residuals_ms | each {|p| $p.0 | insert residual_ms $p.1 } })
    let past = ($pairs | where {|p| ($p.residual_ms | math abs) >= ($period * 500.0) } | length)
    if $past > 0 { $refusals = ($refusals | append { refusal: "a residual past half the period", count: $past }) }
    {
        ok: ($refusals | is-empty),
        refusals: $refusals,
        pairs: $pairs,
        fit: (if $fit == null { null } else { { offset_s: ($fit.base + $fit.offset), drift: $fit.drift, max_residual_ms: ($fit.residuals_ms | each {|r| $r | math abs } | math max) } }),
        window: (if ($presented | is-empty) { null } else { { first: ($presented | first | get ordinal), last: $last, presents: ($presented | length), uploads: ($uploads | length) } }),
        limits: $pair_limits,
    }
}

# Whether `dir` is a workspace's root, holding workspace.jab.toml.
def is-workspace [dir: path]: nothing -> bool {
    $dir | path expand | path join "workspace.jab.toml" | path exists
}

# Every program of the workspace at `ws` by its path from it: the members
# workspace.jab.toml lists, then the programs under its directory it does
# not list, the game's among them, found by their manifests outside the
# target, the cargo trees, and extern/.
def programs-of [ws: path]: nothing -> list<string> {
    let ws = ($ws | path expand)
    let listed = (open ($ws | path join "workspace.jab.toml") | get programs)
    let root = (target-root $ws)
    # glob's exclusions as a filter on each path's words below the workspace
    let found = (paths-of ($ws | path join "**" "program.jab.toml")
        | where {|f| not ($f | path relative-to $ws | path split | any {|w| $w in [".git" ".target" "target" "extern"] }) }
        | each {|f| $f | path dirname }
        | where {|d| not (under $d $root) }
        | each {|d| $d | path relative-to $ws | str replace --all "\\" "/" }
        | where {|p| $p not-in $listed }
        | sort)
    $listed ++ $found
}

# A path given as words, each split on its slashes, so `example bounce`,
# `example/bounce`, and `kit/fierce` all read; "" for none.
def path-words [words: list<string>]: nothing -> string {
    $words | each {|w| $w | split row "/" } | flatten | where {|w| $w != "" and $w != "." } | str join "/"
}

# A program's path in the workspace from words (path-words), a word the
# workspace's `shortcuts` table names standing for its path: `fierce` for
# kit/fierce.
def program-path [ws: path, words: list<string>]: nothing -> string {
    let at = (path-words $words)
    let shortcuts = (open ($ws | path expand | path join "workspace.jab.toml") | get -o shortcuts | default {})
    $shortcuts | get -o $at | default $at
}

# The programs at or under a path in the workspace, every program for no
# path; a path matching none is an error naming them all. Untyped because
# it ends in an error.
def programs-under [ws: path, words: list<string>] {
    let at = (program-path $ws $words)
    let all = (programs-of $ws)
    let picked = (if $at == "" { $all } else { $all | where {|p| $p == $at or ($p | str starts-with $"($at)/") } })
    if ($picked | is-empty) { error make {msg: $"no program at or under ($at); the programs: ($all | str join ', ')"} }
    $picked
}

# The one program at a path in the workspace, its directory. Untyped
# because it ends in an error.
def program-at [ws: path, words: list<string>] {
    let at = (program-path $ws $words)
    if $at == "" { error make {msg: "a program by its path from the workspace, or its shortcut: example/bounce, kit/fierce, fierce"} }
    let all = (programs-of $ws)
    if $at not-in $all { error make {msg: $"no program at ($at); the programs: ($all | str join ', ')"} }
    $ws | path expand | path join $at
}

# Whether a program, by its path from the workspace, is a test: one under
# a `test` directory, which `just test` runs and `just run` does not.
def is-test [at: string]: nothing -> bool {
    "test" in ($at | split row "/")
}

# The one program `just run` takes at a path in the workspace, its
# directory: any program but a test (is-test). Untyped because it ends
# in an error.
def run-target [ws: path, words: list<string>] {
    let at = (program-path $ws $words)
    let all = (programs-of $ws)
    let runnable = ($all | where {|p| not (is-test $p) })
    if $at == "" { error make {msg: $"a program to run by its path from the workspace, or its shortcut: ($runnable | str join ', ')"} }
    if $at in $all and (is-test $at) { error make {msg: $"($at) is a test; `just test ($at)` runs it"} }
    if $at not-in $runnable { error make {msg: $"no program to run at ($at); the programs: ($runnable | str join ', ')"} }
    $ws | path expand | path join $at
}

# A program's preparation before it is built, tested, or run: the script
# its manifest's `prepare` names, relative to the manifest, run from the
# program's directory with the phase, build, test, or run; nothing
# without one. A preparation that fails stops the command with its
# output.
def prepare [dir: path, phase: string]: nothing -> nothing {
    let here = ($dir | path expand)
    let script = (open ($here | path join "program.jab.toml") | get -o prepare | default "")
    if $script == "" { return }
    let r = (do { cd $here; ^nu ($here | path join $script) $phase } | complete)
    print -n $r.stdout
    if $r.exit_code != 0 { error make {msg: $"preparing ($here) to ($phase) failed:\n($r.stderr)"} }
}

# Build the kernel, then the programs at or under a path in the
# workspace, every program for none, each prepared first, with `names`.
def build-under [ws: path, words: list<string>, names: list<string>]: nothing -> nothing {
    let ws = ($ws | path expand)
    let m = (open ($ws | path join "workspace.jab.toml"))
    build-kernel ($ws | path join $m.kernel) $names
    for p in (programs-under $ws $words) {
        let dir = ($ws | path join $p)
        prepare $dir "build"
        build-program $dir $names
    }
}

# Test the programs at or under a path in the workspace, every program
# for none, each on a build with DEBUG beside `names` and prepared to
# test first; prints each test's output and a summary, exits 1 if any
# fails. A test that drives the API asks `jab launch` for the port
# itself.
def test-under [ws: path, words: list<string>, names: list<string>]: nothing -> nothing {
    let ws = ($ws | path expand)
    let names = (with-debug $names)
    let selected = (programs-under $ws $words)
    let m = (open ($ws | path join "workspace.jab.toml"))
    build-kernel ($ws | path join $m.kernel) $names
    let results = ($selected | each {|p|
        let dir = ($ws | path join $p)
        prepare $dir "test"
        let ready = (prepared $dir $names)
        let r = (^nu ...(test-args $ready) | complete)
        print $"--- ($p)"
        print -n $r.stdout
        if $r.exit_code != 0 { print -n $r.stderr }
        { program: $p, passed: ($r.exit_code == 0) }
    })
    print ($results | table)
    if not ($results | all {|r| $r.passed }) { exit 1 }
}

# The development commands, `just do`: with no command the list, the
# SDK's own, probe and clean, then the kernel's and every program's, the
# `main <command>` definitions of the nushell script its manifest's `do`
# names; with one, the SDK's or the script's that defines it, run with
# the rest of the words as they came, from the directory the command was
# given in, so a relative path among them is the caller's.
def --wrapped "main do" [dir: path, ...words: string] {
    let ws = ($dir | path expand)
    if not (is-workspace $ws) { error make {msg: $"($ws) is no workspace's root"} }
    let commands = (do-commands $ws)
    if ($words | is-empty) { print (do-list $commands); return }
    let name = ($words | first)
    let rest = ($words | skip 1)
    if $name == "probe" { ^nu $self probe $ws ...$rest; return }
    if $name == "clean" { do-clean $ws $rest; return }
    let hit = ($commands | where command == $name)
    if ($hit | is-empty) { error make {msg: $"no development command called ($name); `just do` lists them"} }
    ^nu ($hit | first | get script) $name ...$rest
}

# Every development command the kernel and the programs declare: the
# `main <command>` definitions of the script a manifest's `do` names,
# relative to it, each with the comment above it, the script, and its
# owner's path and directory.
def do-commands [ws: path]: nothing -> table<command: string, usage: string, owner: string, home: string, script: string, summary: string> {
    let m = (open ($ws | path join "workspace.jab.toml"))
    let owners = ([{ path: $m.kernel, manifest: "kernel.jab.toml" }] ++ (programs-of $ws | each {|p| { path: $p, manifest: "program.jab.toml" } }))
    $owners | each {|o|
        let home = ($ws | path join $o.path)
        let declared = (open ($home | path join $o.manifest) | get -o "do" | default "")
        if $declared == "" { [] } else {
            let script = ($home | path join $declared)
            let lines = (open --raw $script | decode | lines)
            $lines | enumerate | each {|l|
                let hit = ($l.item | parse --regex '^def (?:--wrapped )?"main (?P<command>[^"]+)"\s*\[(?P<params>.*)\][^\]]*$' | get -o 0)
                if $hit == null { null } else {
                    let above = ($lines | first $l.index | reverse | take while {|x| $x | str starts-with "#" } | reverse | each {|x| $x | str replace --regex '^#\s?' '' } | str join " ")
                    { command: $hit.command, usage: (do-usage $hit.params), owner: $o.path, home: $home, script: $script, summary: $above }
                }
            } | compact
        }
    } | flatten
}

# A command's arguments as `just do` shows them, from its definition's
# parameters: a required one `<name>`, one with a default `[name]`, a
# flag `[--flag value]` or `[--flag]`, the rest `[args...]`.
def do-usage [params: string]: nothing -> string {
    $params | split row "," | each {|p| $p | str trim } | where {|p| $p != "" } | each {|p|
        let name = ($p | split row ":" | first | split row "=" | first | str trim)
        let default = (if ($p | str contains "=") { $p | split row "=" | skip 1 | str join "=" | str trim | str trim --char '"' } else { "" })
        if ($name | str starts-with "...") { "[args...]" } else if ($name | str starts-with "--") {
            if ($p | str contains ":") { $"[($name) ($default)]" } else { $"[($name)]" }
        } else if $default != "" { $"[($name)]" } else { $"<($name)>" }
    } | str join " "
}

# The list `just do` prints: each command with its arguments and its
# owner, and its description up to its first example or full stop.
def do-list [commands: table]: nothing -> string {
    let sdk = [
        { command: "probe", usage: "<kind> <program> [--seconds 12] [--set names] [--api] [--send <file>] [--trace]", owner: "sdk", summary: "Probe one program under a window and print one NUON record on how its flips reached it, `sdl` the one kind, Linux only" }
        { command: "clean", usage: "[path] [--tree release|debug]", owner: "sdk", summary: "Retire the build outputs of the programs at or under a path, or the kernel's with `kernel`, in both trees or the one --tree names; with no path the whole target, as `just clean` does" }
    ]
    let all = ($sdk ++ ($commands | select command usage owner summary))
    let shown = ($all | each {|c|
        let cut = ($c.summary | split row ": `" | first | split row ". " | first)
        let usage = (if $c.usage == "" { "" } else { $" ($c.usage)" })
        $"  just do ($c.command)($usage)  [($c.owner)]\n      ($cut)"
    })
    (["the commands for development, `just do <command> [args]`:"] ++ $shown) | str join "\n"
}

# `just clean`: the workspace's target retired whole under one stamp
# (retire), so the next build starts from nothing while nothing is
# deleted: a checkout's target under the XDG cache moved as one into the
# shared tmp beside it, a `.target`'s entries but its own tmp into that
# tmp; only a directory that is a target this tool makes (is-target).
def clean-target [ws: path]: nothing -> nothing {
    let target = (target-root $ws)
    if ($target | path type) != "dir" { print $"jab: no target at ($target)"; return }
    if not (is-target $target) { error make {msg: $"($target) is not a target this tool makes; leaving it"} }
    let home = (retire-home $target)
    let stamp = (date now | format date "%Y%m%d-%H%M%S")
    let entries = (if $home.base == $target { ls -a $target | get name | where {|e| ($e | path basename) != "tmp" } } else { [$target] })
    for e in $entries { retire $e $target --stamp $stamp }
    print $"jab: retired ($target) to ($home.tmp | path join 'retired' $stamp); `just retire` deletes everything retired"
}

# `just do clean`: with no path the whole target, as `just clean`
# (clean-target); with one, the build outputs of the programs at or
# under it, or the kernel's with `kernel`, in both trees or the one
# `--tree` names, each retired (retire) under one stamp. A program's
# output holds the outputs of the programs under it, which go with it.
def do-clean [ws: path, words: list<string>]: nothing -> nothing {
    let at = ($words | enumerate | where item == "--tree" | get -o 0.index)
    let trees = (if $at == null { ["release" "debug"] } else { [($words | get -o ($at + 1) | default "")] })
    for t in $trees { if $t not-in ["release" "debug"] { error make {msg: $"--tree is release or debug, not ($t)"} } }
    let words = (if $at == null { $words } else { $words | enumerate | where {|e| $e.index != $at and $e.index != ($at + 1) } | get item })
    if ($words | is-empty) { clean-target $ws; return }
    let target = (target-root $ws)
    let stamp = (date now | format date "%Y%m%d-%H%M%S")
    let dirs = (if (path-words $words) == "kernel" {
        let m = (open ($ws | path join "workspace.jab.toml"))
        $trees | each {|t| (context ($ws | path join $m.kernel) "kernel" (tree-symbols $t)).out }
    } else {
        programs-under $ws $words | each {|p| $trees | each {|t| program-out ($ws | path join $p) $t } } | flatten
    })
    mut retired = []
    for d in $dirs {
        if ($d | path type) != null {
            retire $d $target --stamp $stamp
            $retired = ($retired | append $d)
        }
    }
    print (if ($retired | is-empty) { "jab: nothing built there to retire" } else { $"jab: retired ($retired | str join ', ') to ((retire-home $target).tmp | path join 'retired' $stamp)" })
}

# `just retire`: everything retired deleted, the retire home's tmp
# (retire-home) removed whole, the one thing this tool deletes; only a
# directory named tmp in a `.target` or beside the checkouts under
# `jab/target`, never a link, and nothing when it is not there.
def retire-all [ws: path]: nothing -> nothing {
    let home = (retire-home (target-root $ws))
    let tmp = $home.tmp
    if ($tmp | path type) == null { print $"jab: nothing retired at ($tmp)"; return }
    let kind = (ls -D $tmp | get 0.type)
    let base = ($home.base | path basename)
    let placed = (($tmp | path basename) == "tmp") and ($base == ".target" or ($base == "target" and ($home.base | path dirname | path basename) == "jab"))
    if $kind != "dir" or not $placed { error make {msg: $"($tmp) is not the retire home this tool keeps; leaving it"} }
    let size = (du $tmp | get -o 0.apparent | default 0b)
    rm --recursive --permanent $tmp
    print $"jab: deleted ($tmp), ($size) retired"
}

# The benches of the workspace's programs, `<program>/<bench>` each: the
# NUON files under a program's bench/ directory.
def benches-of [ws: path]: nothing -> list<string> {
    programs-of $ws | each {|p|
        paths-of ($ws | path expand | path join $p "bench" "*.nuon") | sort | each {|f| $"($p)/($f | path parse | get stem)" }
    } | flatten
}

# The bench `name` names, `<program>/<bench>`, the program by its path
# or a shortcut (program-path): the program's path and directory, the
# bench's name and file, and its definition, held to its shape: a
# summary, and steps each with a label of its own and the script it runs
# with its arguments. Untyped because it ends in an error.
def bench-at [ws: path, name: string] {
    let words = ($name | split row "/" | where {|w| $w != "" })
    let all = (benches-of $ws)
    if ($words | length) < 2 { error make {msg: $"a bench by its program's path and its name, `just bench <program>/<bench>`: ($all | str join ', ')"} }
    let bench = ($words | last)
    let program = (program-path $ws ($words | drop 1))
    let file = ($ws | path expand | path join $program "bench" $"($bench).nuon")
    if not ($file | path exists) { error make {msg: $"no bench ($bench) in ($program); the benches: ($all | str join ', ')"} }
    let def = (open $file)
    if ($def | get -o summary) == null or ($def | get -o steps) == null { error make {msg: $"($file) needs a summary and steps"} }
    let labels = ($def.steps | each {|s| $s | get -o label | default "" })
    if ($labels | any {|l| $l == "" }) or ($labels | uniq | length) != ($labels | length) { error make {msg: $"($file): every step needs a label of its own"} }
    if ($def.steps | any {|s| ($s | get -o run | default [] | is-empty) }) { error make {msg: $"($file): every step needs `run`, its script and the script's arguments"} }
    { name: $"($program)/($bench)", program: $program, dir: ($ws | path expand | path join $program), bench: $bench, file: $file, def: $def }
}

# Where a bench's runs land: the program's bench shard of the target
# under the bench's name, each run a stamped directory in it, beside
# state.nuon, which says what the latest run is doing for `watch bench`.
def bench-home [b: record]: nothing -> string {
    program-shard $b.dir "bench" | path join $b.bench
}

# The list `just bench` prints: each bench with its summary.
def bench-list [ws: path]: nothing -> string {
    let shown = (benches-of $ws | each {|n|
        let b = (bench-at $ws $n)
        $"  just bench ($n)\n      ($b.def.summary)"
    })
    (["the benches, `just bench <program>/<bench>` with `just watch bench <program>/<bench>` in a second terminal:"] ++ $shown) | str join "\n"
}

# A bench's state file as its run last wrote it; null when there is
# none.
def bench-state [file: path]: nothing -> oneof<record, nothing> {
    if not ($file | path exists) { return null }
    try { open $file } catch { null }
}

# Whether the run a state describes is under way: not finished, and its
# process alive.
def bench-live [s: record]: nothing -> bool {
    ($s.state not-in [done failed]) and (process-alive ($s.pid | into string))
}

# The state file written whole, through a file beside it moved over it,
# so `watch bench` never reads half of one.
def bench-save-state [file: path, state: record]: nothing -> nothing {
    let next = $"($file).next"
    $state | to nuon | save --raw -f $next
    mv -f $next $file
}

# A bench's run packed whole into one tar beside its directory in the
# bench's home, so the run travels as one file: named for the bench, its
# path's slashes as underscores, and the stamp, `<bench>-<stamp>.tar`,
# the run's directory at the archive's top under its stamp. A tar of the
# run already there, an earlier packing, is retired first (retire), since
# nothing is deleted. The tar's path. Untyped because it can end in an
# error.
def bench-tar [home: path, stamp: string, name: string, root: path] {
    let file = ($home | path join $"($name | str replace --all '/' '_')-($stamp).tar")
    retire $file $root
    let r = (do { cd $home; ^tar -cf ($file | path basename) $stamp | complete })
    if $r.exit_code != 0 { error make {msg: $"tar of ($home | path join $stamp) ended with ($r.exit_code): ($r.stderr | str trim)"} }
    $file
}

# Run a bench, `just bench <program>/<bench>`: the NUON file of that name
# under the program's bench/ directory, with a summary, the tree, the
# steps, each a label and the program's script with its arguments and,
# for a step a person attends, `attend`, what they do; and the report, a
# script run over the run's directory at the end. The program is built
# in the tree, then every step runs in order with `--out` its own
# directory and `--label` its label, an attended step announced and
# counted down first, a step that fails recorded and the rest run; then
# the report. A run is a stamped directory in the program's bench shard
# of the target, its bench.nuon recording every step's outcome as it
# lands, and state.nuon beside the stamps says what the run is doing,
# for `just watch bench`. At the end the run is packed whole into one tar
# beside its directory (bench-tar), the file to copy off the host, and
# the last line names it; a watch recording the run packs it again when
# it ends, its recording included. A run with a failed step or a failed
# report exits 1 once everything is recorded, reported, packed, and said.
# `--only` runs the steps its comma-separated labels name; with no bench,
# the list. Nothing is deleted: a run writes its own directory, its tar,
# and the state.
def "main bench" [ws: path, name?: string, --only: string = ""] {
    let ws = ($ws | path expand)
    if not (is-workspace $ws) { error make {msg: $"($ws) is no workspace's root"} }
    if $name == null { print (bench-list $ws); return }
    let b = (bench-at $ws $name)
    let labels = ($b.def.steps | get label)
    let picked = ($only | split row "," | each {|l| $l | str trim } | where {|l| $l != "" })
    let unknown = ($picked | where {|l| $l not-in $labels })
    if not ($unknown | is-empty) { error make {msg: $"($b.name) has no step ($unknown | str join ', '); its steps: ($labels | str join ', ')"} }
    let steps = (if ($picked | is-empty) { $b.def.steps } else { $b.def.steps | where {|s| $s.label in $picked } })
    let tree = ($b.def | get -o tree | default "release")
    let names = (tree-symbols $tree)
    let home = (bench-home $b)
    let stamp = (date now | format date "%Y%m%d-%H%M%S")
    let dir = ($home | path join $stamp)
    if ($dir | path exists) { error make {msg: $"a run of ($b.name) started this second, at ($dir)"} }
    mkdir $dir
    let state_file = ($home | path join "state.nuon")
    let record_file = ($dir | path join "bench.nuon")
    let total = ($steps | length)
    let base = { bench: $b.name, stamp: $stamp, dir: $dir, pid: $nu.pid, started: (date now | format date "%Y-%m-%dT%H:%M:%S"), total: $total }
    mut record: record = {
        bench: $b.name, summary: $b.def.summary, tree: $tree, stamp: $stamp, started: $base.started, file: $b.file,
        steps: ($steps | each {|s| { label: $s.label, attend: ($s | get -o attend), run: $s.run, state: "pending", exit: null, seconds: null } }),
        report: null, state: "building",
    }
    $record | to nuon --indent 2 | save --raw $record_file
    bench-save-state $state_file ($base | merge { step: 0, label: "", state: "building" })
    print $"jab bench: ($b.name), ($total) steps, into ($dir): ($b.def.summary)"
    let broken = (try {
        let m = (open ($ws | path join "workspace.jab.toml"))
        build-kernel ($ws | path join $m.kernel) $names
        prepare $b.dir "build"
        build-program $b.dir $names
        null
    } catch {|e| $e.msg })
    if $broken != null {
        $record = ($record | merge { state: "failed" })
        $record | to nuon --indent 2 | save --raw -f $record_file
        bench-save-state $state_file ($base | merge { step: 0, label: "", state: "failed" })
        error make {msg: $"($b.name): the build failed: ($broken)"}
    }
    for entry in ($steps | enumerate) {
        let s = $entry.item
        let n = ($entry.index + 1)
        bench-save-state $state_file ($base | merge { step: $n, label: $s.label, state: "running" })
        let attend = ($s | get -o attend)
        if $attend != null {
            print $"jab bench: step ($n) of ($total), ($s.label): ($attend)"
            for left in 10..1 { print -n $"\r  starting in ($left) s "; sleep 1sec }
            print ""
        } else {
            print $"jab bench: step ($n) of ($total), ($s.label)"
        }
        let script = ($b.dir | path join ($s.run | first))
        let started = (date now)
        let code = (try {
            ^nu $script ...($s.run | skip 1) --out ($dir | path join $s.label) --label $s.label
            0
        } catch { $env.LAST_EXIT_CODE? | default 1 })
        let seconds = ((((date now) - $started) / 1sec) | math round --precision 1)
        let i = $entry.index
        let outcome = { state: (if $code == 0 { "done" } else { "failed" }), exit: $code, seconds: $seconds }
        let updated = ($record.steps | enumerate | each {|e| if $e.index == $i { $e.item | merge $outcome } else { $e.item } })
        $record = ($record | merge { steps: $updated })
        $record | to nuon --indent 2 | save --raw -f $record_file
        if $code != 0 { print $"jab bench: ($s.label) failed with exit ($code); on to the next step" }
    }
    bench-save-state $state_file ($base | merge { step: $total, label: "", state: "reporting" })
    let report = ($b.def | get -o report)
    let reported = (if $report == null { null } else {
        try { ^nu ($b.dir | path join ($report | first)) ...($report | skip 1) $dir; 0 } catch { $env.LAST_EXIT_CODE? | default 1 }
    })
    let failed = ($record.steps | where state != "done" | get label)
    let final = (if ($failed | is-empty) and ($reported == null or $reported == 0) { "done" } else { "failed" })
    $record = ($record | merge { report: $reported, state: $final })
    $record | to nuon --indent 2 | save --raw -f $record_file
    let packed = (try { { tar: (bench-tar $home $stamp $b.name (target-root $ws)), error: "" } } catch {|e| { tar: null, error: $e.msg } })
    bench-save-state $state_file ($base | merge { step: $total, label: "", state: $final })
    let failures = (if ($failed | is-empty) { "" } else { $"; failed: ($failed | str join ', ')" })
    let unreported = (if $reported == null or $reported == 0 { "" } else { $"; the report failed with exit ($reported)" })
    if $packed.tar == null { print $"jab bench: the run is left unpacked in its directory: ($packed.error)" }
    if ($dir | path join "watch" | path exists) { print "jab bench: the watch recording this run packs it again, its recording included, when it ends" }
    print $"jab bench: ($b.name) ($final), ($total) steps($failures)($unreported); everything in (if $packed.tar == null { $dir } else { $packed.tar })"
    if $final != "done" { exit 1 }
}

# The QEMUs of a bench's run, each its pid with its command line from
# one look at the process table: those whose command lines name the
# run's directory.
def bench-qemus [run: path]: nothing -> list<record<pid: int, command: string>> {
    ps -l | where {|p| ((command-binary $p.command | path basename) == (exe-name $qemu_name)) and ($p.command | str contains $run) } | each {|p| { pid: $p.pid, command: $p.command } }
}

# The step a QEMU of a bench's run belongs to, read from the command
# line the process table showed with its pid (bench-qemus): the step
# directory under the run's directory its pid file and its logs sit in,
# every step writing under `<run>/<label>/`; `unknown` when the line
# names none of the bench's steps.
def bench-step-of [command: string, run: path, labels: list<string>]: nothing -> string {
    let parts = ($command | split row $"($run)/")
    if ($parts | length) < 2 { return "unknown" }
    let named = ($parts | get 1 | split row "/" | first)
    if $named in $labels { $named } else { "unknown" }
}

# The busiest threads of a watch report as one short line.
def watch-top [threads: list<any>]: nothing -> string {
    $threads | first 4 | each {|t| $"($t.name) ($t.steady)" } | str join ", "
}

# A recording's threads' rates over its last `span` samples, the
# busiest first, as one short line; "" while it holds too few.
def watch-rates [file: path, span: int]: nothing -> string {
    let samples = (open --raw $file | decode | lines | where {|l| ($l | str trim) != "" } | skip 1)
    if ($samples | length) < 2 { return "" }
    let last = ($samples | last | from nuon)
    let first = ($samples | last ([($span + 1) ($samples | length)] | math min) | first | from nuon)
    let seconds = ($last.at - $first.at)
    if $seconds <= 0 { return "" }
    $last.threads | each {|t|
        let before = ($first.threads | where id == $t.id | get -o 0.cpu | default $t.cpu)
        { name: $t.name, rate: (($t.cpu - $before) / $seconds) }
    } | where rate >= 0.01 | sort-by rate --reverse | first 4 | each {|r| $"($r.name) ($r.rate | math round --precision 2)" } | str join "  "
}

# Record every QEMU of a bench's run, `just watch bench
# <program>/<bench>` in a second terminal: it waits for the bench's next
# run, or takes up one under way, then records each QEMU of the run per
# thread once a second, under the step its own command line names as the
# process table showed it, or `unknown` (bench-step-of), to
# watch/<step>-<n>.nuonl in the run's directory, a
# line printed as each
# starts and ends and the rates every five seconds. When the bench has
# finished and no QEMU of it is left, it prints the bench's report and
# its own per QEMU, the steady CPU seconds a second after the first
# `--skip` (watch-report-of), writes them together as watch.nuon in the
# run's directory, then packs the run again, its recording included
# (bench-tar), and names that tar last, the file to copy off the host.
# Interrupted, it ends with no report.
def "main watch bench" [...words: string, --skip: float = 5.0] {
    if ($words | is-empty) { error make {msg: "nu jab.nu watch bench <program>/<bench> <workspace>"} }
    let ws = ($words | last | path expand)
    if not (is-workspace $ws) { error make {msg: $"($ws) is no workspace's root"} }
    let named = ($words | drop 1)
    if ($named | is-empty) { print (bench-list $ws); return }
    let b = (bench-at $ws ($named | first))
    let state_file = (bench-home $b | path join "state.nuon")
    let before = (bench-state $state_file)
    mut state: any = (if $before != null and (bench-live $before) { $before } else { null })
    if $state == null { print $"jab watch: waiting for ($b.name) to start: `just bench ($b.name)` in another terminal" }
    while $state == null {
        sleep 1sec
        let s = (bench-state $state_file)
        if $s != null and ($before == null or $s.stamp != $before.stamp) { $state = $s }
    }
    let run = $state.dir
    let stamp = $state.stamp
    let root = (target-root $ws)
    let labels = ($b.def.steps | get label)
    let watch_dir = ($run | path join "watch")
    mkdir $watch_dir
    print $"jab watch: recording ($b.name)'s run ($stamp), ($state.total) steps, into ($watch_dir)"
    mut seen = []
    mut label = ""
    mut tick = 0
    loop {
        let read = (bench-state $state_file)
        let current = (if $read != null and $read.stamp == $stamp { $read } else { $state })
        if $current.label != "" and $current.label != $label { print $"jab watch: step ($current.step) of ($current.total), ($current.label)" }
        $label = $current.label
        let found = (bench-qemus $run)
        let pids = ($found | each {|q| $q.pid })
        let known = ($seen | each {|e| $e.pid })
        for q in ($found | where {|x| $x.pid not-in $known }) {
            let pid = $q.pid
            let step = (bench-step-of $q.command $run $labels)
            let n = (($seen | where {|e| $e.label == $step } | length) + 1)
            let file = ($watch_dir | path join $"($step)-($n).nuonl")
            let started = (date now)
            retire $file $root
            ({ run: (watch-header $pid $started) } | to nuon) + (char nl) | save --raw $file
            $seen = ($seen | append { pid: $pid, label: $step, n: $n, file: $file, started: $started, ended: false })
            print $"jab watch: ($step), QEMU ($n), ($pid)"
        }
        let now = (date now)
        for e in ($seen | enumerate | where {|x| not $x.item.ended }) {
            if $e.item.pid in $pids {
                ({ at: (($now - $e.item.started) / 1sec), threads: (threads-of $e.item.pid), rss: (memory-of $e.item.pid) } | to nuon) + (char nl) | save --raw --append $e.item.file
            } else {
                let i = $e.index
                $seen = ($seen | enumerate | each {|x| if $x.index == $i { $x.item | merge { ended: true } } else { $x.item } })
                let r = (try { watch-report-of $e.item.file $skip } catch { null })
                print (if $r == null { $"jab watch: ($e.item.label), QEMU ($e.item.n) ended, too short to report" } else { $"jab watch: ($e.item.label), QEMU ($e.item.n) ended: ($r.process) of a core over ($r.seconds) s; (watch-top $r.threads)(memory-text $r.memory)" })
            }
        }
        $tick += 1
        if ($tick mod 5) == 0 {
            for e in ($seen | where {|x| not $x.ended }) {
                let rates = (watch-rates $e.file 5)
                if $rates != "" { print $"  ($e.label) ($e.n): ($rates)" }
            }
        }
        let finished = ($current.state in [done failed]) or (not (process-alive ($current.pid | into string)))
        if $finished and ($pids | is-empty) and ($seen | all {|x| $x.ended }) { break }
        sleep 1sec
    }
    let last = (bench-state $state_file)
    let ended = (if $last == null or $last.stamp != $stamp { "superseded by a later run" } else if $last.state in [done failed] { $last.state } else { "ended unfinished" })
    let per = ($seen | each {|e|
        let w = (try { watch-report-of $e.file $skip } catch {|err| { error: $err.msg } })
        { step: $e.label, n: $e.n, pid: $e.pid, file: $e.file, watch: $w }
    })
    let text_file = ($run | path join "report.txt")
    print ""
    print $"jab watch: ($b.name)'s run ($stamp) ($ended)"
    print (if ($text_file | path exists) { open --raw $text_file | decode | str trim --right } else { "the bench wrote no report" })
    print "per QEMU, the steady CPU seconds a second:"
    for p in $per {
        print (if ($p.watch | get -o error) != null { $"  ($p.step) ($p.n): ($p.watch.error)" } else { $"  ($p.step) ($p.n): ($p.watch.process) of a core over ($p.watch.seconds) s; (watch-top $p.watch.threads)(memory-text $p.watch.memory)" })
    }
    let report_file = ($run | path join "report.nuon")
    let whole = {
        bench: $b.name, run: $stamp, dir: $run, state: $ended,
        steps: (try { open ($run | path join "bench.nuon") | get steps } catch { null }),
        report: (if ($report_file | path exists) { open $report_file } else { null }),
        watch: $per,
    }
    let out = ($run | path join "watch.nuon")
    retire $out $root
    $whole | to nuon --indent 2 | save --raw $out
    let packed = (try { { tar: (bench-tar ($run | path dirname) $stamp $b.name $root), error: "" } } catch {|e| { tar: null, error: $e.msg } })
    print (if $packed.tar == null { $"jab watch: ($out); the run is left unpacked in its directory: ($packed.error)" } else { $"jab watch: everything in ($packed.tar)" })
}

# The keyboard and the tablet on the line: on unless --no-kbm, and
# never both flags of the pair.
def kbm-choice [kbm: bool, no_kbm: bool]: nothing -> bool {
    if $kbm and $no_kbm { error make {msg: "--kbm and --no-kbm together: one or the other"} }
    not $no_kbm
}

# The gamepad on the line: on unless --no-pad, and never both flags.
def pad-choice [pad: bool, no_pad: bool]: nothing -> bool {
    if $pad and $no_pad { error make {msg: "--pad and --no-pad together: one or the other"} }
    not $no_pad
}

# The headless machine for a program prepared and printed as JSON, for a
# harness in another language to run and drive: `nu jab.nu plan <dir>
# --disk <romfs> --serial fps --api --gamepad --set debug`, the kernel and
# the image the program's own builds, `out` under the program's build tree
# unless given, `--spec`, `--harts`, and `--bootargs` plan's.
def "main plan" [dir: path, --out: string = "", --disk: string = "", --serial: string = "disk0", --set: string = "", --api, --gamepad, --pad-port, --no-kbm, --sound, --spec (-s): string = "", --harts: int = 0, --bootargs: string = ""] {
    let names = (symbols $set)
    let c = (context ($dir | path expand) "program" $names)
    let ready = (prepared ($dir | path expand) $names)
    let out = (if $out == "" { $c.out | path join "machine" } else { $out | path expand })
    plan --kernel $ready.kernel --image $ready.image --out $out --api=$api --disk $disk --serial $serial --set $set --gamepad=$gamepad --pad-port=$pad_port --no-kbm=$no_kbm --sound=$sound --spec $spec --harts $harts --bootargs $bootargs | to json
}

# Build: at a workspace's root the kernel and every program, or the
# programs at or under a path (`example`, `example/bounce`,
# `kit/fierce`), each prepared first; at a program's directory that
# program, prepared; with --kernel at the kernel's, the kernel. Release
# unless --set says otherwise.
def "main build" [dir: path, ...words: string, --kernel, --set: string = ""] {
    let names = (symbols $set)
    if (is-workspace $dir) { build-under $dir $words $names; return }
    if $kernel { build-kernel $dir $names } else {
        prepare $dir "build"
        build-program $dir $names
    }
}

# Test with DEBUG set beside whatever --set names: at a workspace's root
# every program's test, or those at or under a path, with a summary,
# failing if any fails; at a program's directory its test/test.nu on the
# debug kernel. `--spec` names the spec every launch of the tests runs
# that names none of its own, JAB_SPEC for them (spec-default).
def "main test" [dir: path, ...words: string, --set: string = "", --spec (-s): string = ""] {
    let names = (symbols $set)
    let forced = (if $spec == "" { {} } else { { JAB_SPEC: $spec } })
    with-env $forced {
        if (is-workspace $dir) { test-under $dir $words $names; return }
        prepare $dir "test"
        ^nu ...(test-args (prepared $dir (with-debug $names)))
    }
}

# Build, then run one program with its window and the UART on stdio: at
# a workspace's root the program at a path, never a test (run-target),
# at a program's directory that program. Release unless --set says
# otherwise; the API's port on the machine with --api; the keyboard and
# the tablet off with --no-kbm, the gamepad the host has off with
# --no-pad, the sound device off with --no-sound; the machine the spec
# --spec names, its cores, RAM, and display, or the configured default,
# or a custom one of one to eight harts with --harts for a diagnostic run,
# the two together refused.
# QEMU's exit code is the program's status.
def "main run" [dir: path, ...words: string, --set: string = "", --api, --kbm, --no-kbm, --pad, --no-pad, --no-sound, --spec (-s): string = "", --harts: int = 0] {
    let program = (if (is-workspace $dir) { run-target $dir $words } else { $dir | path expand })
    if $spec != "" and $harts != 0 { error make {msg: $"--spec ($spec) with --harts ($harts): a named spec provisions its own harts, and --harts names a custom machine; one or the other"} }
    if $harts != 0 { machine-of $harts | ignore }
    prepare $program "run"
    run-program $program (symbols $set) $api (kbm-choice $kbm $no_kbm) (pad-choice $pad $no_pad) (not $no_sound) --spec $spec --harts $harts
}

# Probe one program under a window for --seconds and print one NUON
# record on how its flips reached the window, at a workspace's root the
# program at a path, at a program's directory that program; release
# unless --set says otherwise. `sdl` is the one probe; `--api`, `--send
# <file>`, and `--trace` are probe-sdl's.
def "main probe" [dir: path, kind: string, ...words: string, --seconds: int = 12, --set: string = "", --api, --send: string = "", --trace] {
    let program = (if (is-workspace $dir) { program-at $dir $words } else { $dir | path expand })
    let send = (if $send == "" { "" } else { $send | path expand })
    prepare $program "run"
    probe $program $kind (symbols $set) $seconds --api=$api --send $send --trace=$trace
}

# Retire the workspace's whole target (clean-target): `just clean`.
def "main clean" [ws: path] {
    if not (is-workspace $ws) { error make {msg: $"($ws | path expand) is no workspace's root"} }
    clean-target ($ws | path expand)
}

# Delete everything retired (retire-all): `just retire`.
def "main retire" [ws: path] {
    if not (is-workspace $ws) { error make {msg: $"($ws | path expand) is no workspace's root"} }
    retire-all ($ws | path expand)
}

def main [] {
    print "nu jab.nu <build|test> <workspace> [path] [--set names]; nu jab.nu run <workspace> <path> [--set names] [--api] [--no-kbm] [--no-pad] [--no-sound] [--spec name | --harts 1..8]; nu jab.nu <build|test|run> <program dir> [--kernel] [--set names]; nu jab.nu probe <workspace> sdl <path> [--seconds N]; nu jab.nu do <workspace> [command] [args]; nu jab.nu bench <workspace> [<program>/<bench>] [--only labels]; nu jab.nu clean <workspace>; nu jab.nu retire <workspace>; nu jab.nu watch [--skip N] <workspace>; nu jab.nu watch bench <program>/<bench> <workspace> [--skip N]; nu jab.nu plan <program dir> [flags]"
}
