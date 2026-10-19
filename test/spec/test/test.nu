# spec's integration test: the launcher's named specs. Each spec the
# launcher provisions today, 1KA1 and 1KB1, planned from asset/spec.nuon:
# -smp its cores, -m its RAM, the GPU at its display, and `jab.spec=<name>`
# on the kernel's line, its record the spec's and no custom machine's;
# QEMU's tree for it dumped and read back, its cpus as many as the spec's
# cores and its one bank from RAM's base its RAM; and a launch on it,
# declared and not diagnostic. Every other spec refused before QEMU
# starts, naming why: cores past the eight harts a machine takes, or a
# display other than the ABI's. --spec with --harts refused by plan,
# launch, and dump-tree, naming both, with no QEMU run; a custom machine of
# three harts recorded diagnostic, its 4 GiB and no `jab.spec`; a name the
# spec data does not define refused; a program listing 1KA1 alone refused
# on 1KB1, naming both. Then the startup check (ProgramMinimums): this
# program's first page read back, its declaration the spec data's; the
# kernel refusing machines off the spec their command line names (CHECKS);
# a program's base demand held on a custom machine, its refusal skipped by
# the debug kernel's knob and the run recorded below the minimum, a release
# kernel refusing it still; a program declaring nothing and one built
# before the header each on the legacy path; malformed first pages each
# refused by name, by the kernel and by check-image; and a kernel without
# the check running a new image through its jump. Then the launch's bound
# (LaunchBound): the one GNU timeout a run resolves, a stand-in refused or
# passed over, its bound on a child, a fifo nobody reads, and a program
# that never exits ending at its bound. Then Windows' pipes (PipeShape):
# the chardev's path on each host, the pipe pairs, a plan's relays, and
# the relays a Windows launch starts, held to how they end with stand-ins
# for the relay. Last the default, in a
# scratch XDG config home: `jab/config.toml` seeded from
# asset/default/config.toml byte for byte, one there never written over,
# JAB_SPEC ahead of it, one naming no spec refused, a home that is not
# there refused and never made, and a launch naming neither flag on the
# configured spec.
use ../../../sdk/nu/jab.nu
use ../../../nu/mod/bound
use ../../../nu/mod/target
use ../../../nu/mod/walk
use ../../../nu/mod/spec
use std/assert

const GIB = 1073741824
# The startup check's refusals of machines off the spec they are named,
# each a custom machine whose command line names a spec, as a tree of a
# caller's own would, run on this program's image, with the status and the
# UART's one line: a spec the image does not list; 1KB1's seven cores on
# three harts; 1KA1 with hart 2 failed by the late check-in, three
# discovered and two online; 1KB1's 8 GiB on a machine of 4, and 1KA1's
# 4 GiB on one of 8; and a name in capitals, read as its lowercase entry,
# the program running
const CHECKS = [
    { name: "unlisted", harts: 3, bootargs: "jab.spec=2ka1", qemu: [], status: 1, line: "jab: spec 2ka1 not listed" }
    { name: "cores", harts: 3, bootargs: "jab.spec=1kb1", qemu: [], status: 1, line: "jab: spec 1kb1 wants 7 harts: 3 discovered, 3 online" }
    { name: "offline", harts: 3, bootargs: "jab.spec=1ka1 jab.late=2", qemu: [], status: 1, line: "jab: spec 1ka1 wants 3 harts: 3 discovered, 2 online" }
    { name: "ram_short", harts: 7, bootargs: "jab.spec=1kb1", qemu: [], status: 1, line: "jab: spec 1kb1 wants 8 GiB of RAM: 0x0000000100000000 bytes installed" }
    { name: "ram_long", harts: 3, bootargs: "jab.spec=1ka1", qemu: ["-m" "8G"], status: 1, line: "jab: spec 1ka1 wants 4 GiB of RAM: 0x0000000200000000 bytes installed" }
    { name: "capitals", harts: 3, bootargs: "jab.spec=1KA1", qemu: [], status: 0, line: "spec: up" }
]
# The minimum's refusal of a program reserving two graphics harts on a
# machine of two, and the debug kernel's knob that skips it
const SHORT = "jab: harts short of the program's demand: 2 for 3"
const NOMINIMUM = "jab.nominimum=1"
# The link script every program had before the first page: its code at
# the window's base
const LEGACY_LD = "ENTRY(_start)

PHDRS
{
    code PT_LOAD FLAGS(5);
    data PT_LOAD FLAGS(6);
}

SECTIONS
{
    . = 0x80a00000;

    .text : { *(.text .text.*) } :code
    .rodata : { *(.rodata .rodata.*) } :code
    .data : { *(.data .data.*) } :data
    .bss : { *(.bss .bss.*) *(COMMON) } :data
}
"

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let ws = ($env.FILE_PWD | path join ".." ".." ".." | path expand)
    let specs = (spec data $ws)

    # each spec provisioned: the line and the tree from the table
    let provisioned = ($specs | where {|s| $s.cores <= 8 and $s.display == { width: 1920, height: 1080 } })
    assert equal ($provisioned | get name | each {|n| $n | str lowercase }) ["1ka1" "1kb1"] $"the specs the launcher provisions: ($provisioned | get name)"
    for s in $provisioned {
        let name = ($s.name | str lowercase)
        let ram = ($s.ram / 1GiB | into int)
        let p = (jab plan --kernel $kernel --image $image --out ($out | path join $"plan_($name)") --spec $name)
        assert (paired $p.qemu "-smp" ($s.cores | into string)) $"($name): -smp ($s.cores): ($p.qemu)"
        assert (paired $p.qemu "-m" $"($ram)G") $"($name): -m ($ram)G: ($p.qemu)"
        assert (paired $p.qemu "-device" $"virtio-gpu-device,xres=($s.display.width),yres=($s.display.height)") $"($name): the GPU at its display: ($p.qemu)"
        assert ((after $p.qemu "-append") | split row " " | any {|w| $w == $"jab.spec=($name)" }) $"($name): jab.spec=($name) on the kernel's line: ($p.qemu)"
        assert equal [$p.machine.spec $p.machine.diagnostic] [{ name: $name, cores: $s.cores, ram_gib: $ram, display: $s.display } null] $"($name): the machine's record the spec's: ($p.machine)"
        let tree = (open --raw (jab dump-tree --kernel $kernel --image $image --out ($out | path join $"($name).dtb") --spec $name) | into binary)
        assert equal (cpus-of $tree) $s.cores $"($name): its tree's cpus"
        assert equal (banks-of $tree) [{ base: 0x80000000, size: ($ram * $GIB) }] $"($name): its tree's one bank, its RAM from RAM's base"
        let run = (jab launch --kernel $kernel --image $image --out ($out | path join $"run_($name)") --set $set --spec $name --seconds 20)
        assert equal [$run.status ($run.serial | lines)] [0 ["spec: up"]] $"($name): the program runs on it: ($run.serial)"
        assert equal [$run.declared $run.diagnostic] [true false] $"($name): a declared run, not diagnostic: ($run.declared), ($run.diagnostic)"
    }

    # every other spec refused before QEMU starts, naming why
    for s in ($specs | where {|s| $s.name not-in ($provisioned | get name) }) {
        let said = (refusal { jab plan --kernel $kernel --image $image --out ($out | path join $"plan_($s.name)") --spec $s.name })
        let why = (if $s.cores > 8 { $"($s.name) has ($s.cores) cores, past the 8 harts a machine takes" } else { $"($s.name)'s display is ($s.display.width) by ($s.display.height), and the ABI's 1920 by 1080" })
        assert ($said | str contains $why) $"($s.name) refused, saying ($why): ($said)"
    }

    # --spec with --harts, refused naming both, no QEMU run
    let both = $"--spec 1ka1 with --harts 3"
    let both_out = ($out | path join "both")
    target retire $both_out
    for c in [
        { name: "plan", call: { jab plan --kernel $kernel --image $image --out $both_out --spec 1ka1 --harts 3 } }
        { name: "launch", call: { jab launch --kernel $kernel --image $image --out $both_out --set $set --spec 1ka1 --harts 3 } }
        { name: "dump-tree", call: { jab dump-tree --kernel $kernel --image $image --out ($both_out | path join "both.dtb") --spec 1ka1 --harts 3 } }
    ] {
        let said = (refusal $c.call)
        assert ($said | str contains $both) $"($c.name): --spec with --harts refused naming both: ($said)"
    }
    assert (($both_out | path join "serial.log" | path type) == null) $"no QEMU run for --spec with --harts: ($both_out)"

    # a custom machine of three harts: diagnostic, 4 GiB, no jab.spec
    let custom = (jab plan --kernel $kernel --image $image --out ($out | path join "custom") --harts 3)
    assert equal [$custom.machine.spec $custom.machine.diagnostic] [null { harts: 3, ram_gib: 4 }] $"a custom machine of three harts, diagnostic: ($custom.machine)"
    assert (paired $custom.qemu "-m" "4G") $"a custom machine's 4 GiB: ($custom.qemu)"
    assert (not ($custom.qemu | any {|w| $w =~ 'jab\.spec=' })) $"no jab.spec on a custom machine's line: ($custom.qemu)"
    let custom_run = (jab launch --kernel $kernel --image $image --out ($out | path join "custom_run") --set $set --harts 3 --seconds 20)
    assert equal [$custom_run.status $custom_run.declared $custom_run.diagnostic] [0 true true] $"a custom machine's run declared and diagnostic: ($custom_run.serial)"

    # a name the data does not define
    let unknown = (refusal { jab plan --kernel $kernel --image $image --out ($out | path join "unknown") --spec 9zz9 })
    assert ($unknown | str contains "no spec 9zz9 in the spec data, which defines 1KA1") $"an unknown spec refused: ($unknown)"

    # a program listing 1KA1 alone, refused on 1KB1, naming both
    let listed = (fixture $ws ($out | path join "fixtures" "listed") "listed" "specs = ['1ka1']\n")
    let unlisted = (refusal { jab plan --kernel $kernel --image $listed --out ($out | path join "unlisted") --spec 1kb1 })
    assert ($unlisted | str contains "listed does not list 1kb1, the spec this launch names; it lists 1KA1") $"a spec its program does not list refused: ($unlisted)"
    let on_listed = (jab plan --kernel $kernel --image $listed --out ($out | path join "listed_plan") --spec 1ka1)
    assert equal $on_listed.machine.spec.name "1ka1" $"the spec it lists planned: ($on_listed.machine)"

    # the startup check: this program's first page, its declaration the
    # spec data's for both specs it lists and its base demand the main hart
    let own = (jab check-image $image)
    assert equal [$own.kind $own.declaration.base] ["declared" 1] $"this program's image declared, its base demand one hart: ($own | to nuon)"
    let declared = ($provisioned | each {|s| { name: ($s.name | str lowercase), cores: $s.cores, ram_gib: ($s.ram / 1GiB | into int), display: $s.display, fps: $s.fps, isa: $s.isa_profile } })
    assert equal $own.declaration.specs $declared $"its declaration's entries the spec data's: ($own.declaration.specs | to nuon)"
    # the kernel's refusals of a machine off the named spec, each before the
    # program starts, its line alone on the UART and status 1; a name in
    # capitals read as the entries' lowercase
    for r in $CHECKS {
        let run = (jab launch --kernel $kernel --image $image --out ($out | path join $"check_($r.name)") --set $set --harts $r.harts --bootargs $r.bootargs --qemu $r.qemu --seconds 20)
        assert equal [$run.status ($run.serial | lines)] [$r.status [$r.line]] $"($r.name): ($r.bootargs) on ($r.harts) harts (($r.qemu | str join ' ')): ($run.status), ($run.serial)"
    }

    # the minimum: a program reserving two graphics harts, its base demand
    # three, refused on a custom machine of two and run on three; past the
    # minimum on the debug kernel by its knob, the run recorded below it; and
    # the release kernel, reading no knob, refusing it still
    let reserving = (fixture $ws ($out | path join "fixtures" "reserving") "reserving" "specs = ['1ka1']\n\n[reserved]\ngfx_harts = 2\n")
    assert equal (jab check-image $reserving | get declaration.base) 3 "the reserving program's base demand three harts"
    let short = (jab launch --kernel $kernel --image $reserving --out ($out | path join "short") --set $set --harts 2 --seconds 20)
    assert equal [$short.status ($short.serial | lines)] [1 [$SHORT]] $"two harts short of the base demand refused: ($short.serial)"
    let held = (jab launch --kernel $kernel --image $reserving --out ($out | path join "held") --set $set --harts 3 --seconds 20)
    assert equal [$held.status ($held.serial | lines) $held.diagnostic] [0 [] true] $"three harts hold it, diagnostic as a custom machine: ($held.serial)"
    let below = (jab launch --kernel $kernel --image $reserving --out ($out | path join "below") --set $set --harts 2 --bootargs $NOMINIMUM --seconds 20)
    assert equal [$below.status ($below.machine | get -o below_minimum) $below.diagnostic] [0 true true] $"the knob runs it below the minimum, so recorded and diagnostic: ($below.serial), ($below.machine)"
    let tool = ($ws | path join "sdk" "nu" "jab.nu")
    ^nu $tool build --kernel ($ws | path join "kernel")
    let release = (target root $ws | path join "release" "kernel" "jab.elf")
    let release_below = (jab launch --kernel $release --image $reserving --out ($out | path join "release_below") --harts 2 --bootargs $NOMINIMUM --seconds 20)
    assert equal [$release_below.status ($release_below.serial | lines)] [1 [$SHORT]] $"the release kernel refuses it under the knob too: ($release_below.serial)"

    # no declaration: a program listing no specs, its header undeclared, and
    # one built before the header under the link script of then, its code at
    # the window's base; each runs on the legacy path, on a named machine its
    # kernel checks nothing of
    let undeclared = (fixture $ws ($out | path join "fixtures" "undeclared") "undeclared" "")
    assert equal (jab check-image $undeclared | get kind) "undeclared" "a program listing no specs has its header undeclared"
    let legacy = (legacy-image $ws ($out | path join "fixtures" "undeclared") ($undeclared | path dirname) ($out | path join "legacy"))
    assert equal (jab check-image $legacy | get kind) "legacy" "an image built before the header reads as legacy"
    for c in [{ name: "undeclared", image: $undeclared } { name: "legacy", image: $legacy }] {
        let run = (jab launch --kernel $kernel --image $c.image --out ($out | path join $"($c.name)_run") --set $set --spec 1kb1 --seconds 20)
        assert equal [$run.status ($run.serial | lines) $run.declared $run.diagnostic] [0 [] false true] $"the ($c.name) image on 1KB1, undeclared and diagnostic: ($run.serial)"
    }

    # malformed first pages: copies of this program's image, each patched,
    # the CRC made again where the patch lies inside the declaration, and
    # refused by name before the program starts, by the kernel and by
    # check-image alike
    let bytes = (open --raw $image | into binary)
    let crc = ($bytes | bytes at 24..<28 | into int --endian little)
    let malformed = [
        { name: "version", patches: [[8 2]], why: "version 2" }
        { name: "flag_bit", patches: [[12 3]], why: "flags 0x0000000000000003" }
        { name: "undeclared_length", patches: [[12 0]], why: "flags 0 with a length" }
        { name: "undeclared_offset", patches: [[12 0] [20 0]], why: "flags 0 with an offset" }
        { name: "undeclared_crc", patches: [[12 0] [20 0] [16 0]], why: "flags 0 with a CRC" }
        { name: "no_length", patches: [[20 0]], why: "flags 1 with length 0" }
        { name: "offset", patches: [[16 128]], why: "offset 128" }
        { name: "length_short", patches: [[20 20]], why: "length 20" }
        { name: "length_past", patches: [[20 4096]], why: "length 4096" }
        { name: "crc", patches: [[24 ($crc bit-xor 1)]], why: $"CRC (hex16 $crc) computed, the header's (hex16 ($crc bit-xor 1))" }
        { name: "count_none", count: 0, why: "spec count 0" }
        { name: "count_past", count: 17, why: "spec count 17" }
        { name: "count_off", count: 3, why: "length 68 for 3 specs" }
    ]
    # a loop rather than each, so an assertion raises alone, its own title
    mut copies = []
    for m in $malformed {
        let copy = (patched $bytes $m ($out | path join "malformed" $m.name) ($env.FILE_PWD | path join ".." | path expand))
        let checked = (refusal { jab check-image $copy })
        assert ($checked | str contains $"declaration refused: ($m.why)") $"($m.name): check-image refuses it, ($m.why): ($checked)"
        let run = (jab launch --kernel $kernel --image $copy --out ($out | path join $"malformed_($m.name)") --set $set --spec 1ka1 --seconds 20)
        assert equal [$run.status ($run.serial | lines)] [1 [$"jab: declaration refused: ($m.why)"]] $"($m.name): the kernel refuses it, ($m.why): ($run.serial)"
        $copies = ($copies | append { name: $m.name, image: $copy })
    }

    # a kernel without the check, from a copy of the kernel's sources with
    # its one call taken out, as every kernel before it entered an image at
    # its base: the jump takes it to the code, the bad CRC's copy unread
    let unchecked = (unchecked-kernel $ws $kernel $set ($out | path join "unchecked"))
    for c in [{ name: "own", image: $image } { name: "crc", image: ($copies | where name == "crc" | first | get image) }] {
        let run = (jab launch --kernel $unchecked --image $c.image --out ($out | path join $"unchecked_($c.name)") --set $set --spec 1ka1 --seconds 20)
        assert equal [$run.status ($run.serial | lines)] [0 ["spec: up"]] $"a kernel without the check runs the ($c.name) image through its jump: ($run.serial)"
    }

    # the launch's bound (LaunchBound): one GNU coreutils timeout resolved a
    # run, GNU's on PATH here; JAB_TIMEOUT naming a stand-in whose --version
    # is not GNU's refused naming it; with no override a stand-in first on
    # PATH passed over for the real one; the real one bounding a child of
    # 30 s at a second, 124 within two; fifo-write into a fifo nobody reads
    # giving up within two; the stand-ins and the fifo on every host but
    # Windows; and a launch of a program that never exits ending at its
    # --seconds 2 with 124 and the resolved timeout in its result
    let real = (with-env { JAB_TIMEOUT: "" } { bound timeout })
    assert ($real.version | str starts-with "timeout (GNU coreutils) ") $"the timeout resolved GNU's: ($real)"
    if $nu.os-info.name != "windows" {
        let stand = ($out | path join "timeout_stand")
        target retire $stand
        mkdir $stand
        let fake = ($stand | path join "timeout")
        "#!/bin/sh\necho 'timeout (not coreutils) 0.1'\n" | save -f $fake
        ^chmod +x $fake
        let forced = (refusal { with-env { JAB_TIMEOUT: $fake } { bound timeout } })
        assert ($forced | str contains $"JAB_TIMEOUT names ($fake)") $"a JAB_TIMEOUT not GNU's refused naming it, GNU's on PATH: ($forced)"
        let shadowed = (with-env { JAB_TIMEOUT: "", PATH: ([$stand] ++ $env.PATH) } { bound timeout })
        assert equal $shadowed.path $real.path $"a stand-in first on PATH passed over for GNU's: ($shadowed)"
        let fifo = ($stand | path join "nobody")
        ^mkfifo $fifo
        let w0 = (date now)
        let wrote = (jab fifo-write $fifo "x" $real.path)
        let waited = (((date now) - $w0) / 1sec)
        assert ((not $wrote) and $waited < 2) $"fifo-write into a fifo nobody reads gives up within two seconds: ($wrote) in ($waited) s"
    }
    let t0 = (date now)
    let bounded = (^$real.path 1 sleep 30 | complete)
    let took = (((date now) - $t0) / 1sec)
    assert ($bounded.exit_code == 124 and $took < 2) $"sleep 30 under a one-second bound: ($bounded.exit_code) in ($took) s"
    let forever = (fixture $ws ($out | path join "fixtures" "forever") "forever" "" --forever)
    let bound_run = (jab launch --kernel $kernel --image $forever --out ($out | path join "forever_run") --set $set --harts 1 --seconds 2)
    assert equal [$bound_run.status $bound_run.timeout_binary] [124 $real.path] $"a program that never exits ends at its bound, the resolved timeout in its record: ($bound_run.status), ($bound_run.timeout_binary)"

    # Windows' pipes (PipeShape): the chardev's path on each host, a POSIX
    # host's `<out>/<endpoint>` and Windows' bare name by the run's nonce,
    # none without one; Windows' pair of two plain files and, elsewhere,
    # this host's, a fifo in and a plain file out, each made empty with a
    # previous run's retired; a plan's relays, the monitor's and the API's
    # on Windows and none elsewhere, the monitor and the API on fifos as
    # before; and the relays a Windows launch starts, held here with
    # stand-ins for the relay on every host but Windows: one ending on its
    # own, one ending in failure, which fails the launch naming its pipe,
    # and one still running a second after QEMU's end, stopped
    let pipes = ($out | path join "pipes")
    let root = (target root $ws)
    target retire $pipes
    mkdir $pipes
    for os in ["linux" "macos"] {
        assert equal (jab pipe-path $pipes "api" 42 $os) ($pipes | path join "api") $"($os): the chardev's path the pair's base"
    }
    assert equal (jab pipe-path $pipes "monitor" 42 "windows") "jab-000000000000002a-monitor" "windows: the pipe's bare name by the run's nonce"
    let nameless = (refusal { jab pipe-path $pipes "api" 0 "windows" })
    assert ($nameless | str contains "named by its nonce") $"windows: a pipe with no nonce refused: ($nameless)"
    let windows = (jab pipe-pair $pipes "padport" 42 "windows" $root)
    assert equal [$windows.name ($windows.inward | path type) ($windows.outward | path type)] ["jab-000000000000002a-padport" "file" "file"] $"Windows' pair, two plain files: ($windows)"
    "header" | save --raw --append $windows.inward
    "guest" | save --raw --append $windows.outward
    let renewed = (jab pipe-pair $pipes "padport" 42 "windows" $root)
    assert equal [(ls $renewed.inward | get 0.size) (ls $renewed.outward | get 0.size)] [0B 0B] "a previous run's pair retired, the new one empty"
    let piped = (jab plan --kernel $kernel --image $image --out ($pipes | path join "plan") --spec 1ka1 --api)
    if $nu.os-info.name == "windows" {
        assert equal ($piped.relays | each {|r| $r.endpoint }) ["monitor" "api"] $"the monitor's relay and the API's: ($piped.relays)"
        assert ((after $piped.qemu "-monitor") | str starts-with "pipe:jab-") $"the monitor on a named pipe: ($piped.qemu)"
        assert equal [($piped.api_in | path type) ($piped.relay_binary | path type)] ["file" "file"] $"the API's in-file a plain file, the relay built: ($piped.api_in), ($piped.relay_binary)"
    } else {
        let here = (jab pipe-pair $pipes "api" 0 $nu.os-info.name $root)
        assert equal [$here.name ($here.inward | path type) ($here.outward | path type) (ls $here.outward | get 0.size)] [($pipes | path join "api") "pipe" "file" 0B] $"this host's pair, a fifo in and an empty file out: ($here)"
        assert equal [$piped.relays $piped.relay_binary $piped.bridge_pipe] [[] "" ""] $"no relay and no bridge's pipe: ($piped.relays), ($piped.relay_binary), ($piped.bridge_pipe)"
        assert equal [(after $piped.qemu "-monitor") ($piped.api_in | path type)] [$"pipe:($piped.monitor)" "pipe"] $"the monitor's pair and the API's fifo as before: ($piped.qemu)"
        let watched = (jab pipe-pair $pipes "monitor" 42 "windows" $root)
        let relays = (jab relays-of $pipes [{ endpoint: "monitor", pipe: $watched } { endpoint: "padport", pipe: null }])
        assert equal ($relays | each {|r| [$r.endpoint $r.name $r.done] }) [["monitor" "jab-000000000000002a-monitor" ($pipes | path join "monitor.relay.nuon")]] $"a relay for each pipe the machine has: ($relays)"
        let stands = ($pipes | path join "stands")
        mkdir $stands
        let ended = (jab relays-stop (jab relays-start $relays (stand-in $stands "ending" "exit 0") $root))
        assert equal ($ended | each {|r| [$r.endpoint $r.exit $r.said] }) [["monitor" 0 ""]] $"a relay ending on its own: ($ended)"
        jab relays-held $ended { exit_code: 0, stderr: "" }
        let failed = (jab relays-stop (jab relays-start $relays (stand-in $stands "failing" "echo 'no connection within 10 s' >&2\nexit 1") $root))
        let held = (refusal { jab relays-held $failed { exit_code: 124, stderr: "" } })
        assert ($held | str contains "the monitor pipe's relay, for jab-000000000000002a-monitor, ended with 1: no connection within 10 s; QEMU ended with 124") $"a relay ending in failure fails the launch, naming its pipe: ($held)"
        let s0 = (date now)
        let stopped = (jab relays-stop (jab relays-start $relays (stand-in $stands "staying" "exec sleep 31.4159") $root))
        let took = (((date now) - $s0) / 1sec)
        assert ($stopped.0.exit == null and $took < 3) $"a relay still running a second after QEMU's end stopped: ($stopped) in ($took) s"
        sleep 200ms
        assert (ps -l | where {|p| $p.command | str contains "31.4159" } | is-empty) "the stopped relay's process gone"
    }

    # the default, in a scratch XDG config home
    let xdg = ($out | path join "xdg")
    target retire $xdg
    mkdir $xdg
    let seed = ($ws | path join "asset" "default" "config.toml")
    let config = ($xdg | path join "jab" "config.toml")
    let in_xdg = {|task: closure| with-env { XDG_CONFIG_HOME: $xdg, JAB_SPEC: "" } { do $task } }
    let seeded = (do $in_xdg { spec configured $ws })
    assert equal $seeded (open $seed | get spec) $"the default seeded from the asset: ($seeded)"
    assert equal (open --raw $config | into binary) (open --raw $seed | into binary) "the config seeded byte for byte"
    "spec = '1kb1'\n" | save --raw -f $config
    assert equal (do $in_xdg { spec configured $ws }) "1kb1" "a config there read as it is"
    assert equal (open --raw $config | into binary | decode) "spec = '1kb1'\n" "a config there never written over"
    let unflagged = (do $in_xdg { jab plan --kernel $kernel --image $image --out ($out | path join "unflagged") })
    assert equal $unflagged.machine.spec.name "1kb1" $"a launch naming neither flag on the configured spec: ($unflagged.machine)"
    assert equal (with-env { XDG_CONFIG_HOME: $xdg, JAB_SPEC: "1ka1" } { spec configured $ws }) "1ka1" "JAB_SPEC ahead of the config"
    "other = 1\n" | save --raw -f $config
    let unnamed = (refusal { do $in_xdg { spec configured $ws } })
    assert ($unnamed | str contains "names no `spec`") $"a config naming no spec refused: ($unnamed)"
    let gone = ($out | path join "xdg_gone")
    target retire $gone
    let absent = (refusal { with-env { XDG_CONFIG_HOME: $gone, JAB_SPEC: "" } { spec configured $ws } })
    assert ($absent | str contains $"the XDG config home ($gone) is not there") $"a home that is not there refused: ($absent)"
    assert (($gone | path type) == null) $"the XDG config home never made: ($gone)"
    print $"spec: ($provisioned | length) specs provisioned, each line and tree from the table; ($specs | length) defined; the startup check's ($CHECKS | length) machines, the minimum, the legacy path twice, ($malformed | length) malformed first pages, and a kernel without the check; the launch's bound, ($real.path); Windows' pipes and their relays"
    print "spec: ok"
}

# A value as the kernel prints one in hex: 0x and sixteen digits.
def hex16 [v: int]: nothing -> string {
    $"0x($v | into binary --endian big | encode hex | str lowercase)"
}

# A copy of an image with its first page patched: each of `m.patches`, a
# word's offset and its value, written little-endian; or `m.count` as the
# declaration's count of specs, the CRC made again over the declaration so
# the count alone is wrong. Beside it a `home` naming the program, so a
# launch finds its workspace. Its path.
def patched [bytes: binary, m: record, dir: path, home: path]: nothing -> string {
    target retire $dir
    mkdir $dir
    mut b = $bytes
    for p in ($m | get -o patches | default []) {
        $b = (put-word $b $p.0 $p.1)
    }
    let count = ($m | get -o count)
    if $count != null {
        let length = ($b | bytes at 20..<24 | into int --endian little)
        $b = (($b | bytes at 0..<66) ++ ($count | into binary --endian little | bytes at 0..<1) ++ ($b | bytes at 67..))
        $b = (put-word $b 24 (jab crc32 ($b | bytes at 64..<(64 + $length))))
    }
    let file = ($dir | path join "spec.jab")
    $b | save -f $file
    $home | save -f ($dir | path join "home")
    $file
}

# Bytes with the little-endian word at `at` made `value`.
def put-word [b: binary, at: int, value: int]: nothing -> binary {
    ($b | bytes at 0..<$at) ++ ($value | into binary --endian little | bytes at 0..<4) ++ ($b | bytes at ($at + 4)..)
}

# An image built as every program was before the first page: a fixture's
# source assembled and linked by the tools its flags stamp names under the
# link script of then, LEGACY_LD, its code at the window's base and no
# header; beside it a `home` naming the fixture, so a launch finds its
# workspace. Its path.
def legacy-image [ws: path, fixture: path, built: path, dir: path]: nothing -> string {
    target retire $dir
    mkdir $dir
    let prefix = (open --raw ($built | path join "flags") | decode | lines | first | split row " " | last)
    let script = ($dir | path join "legacy.ld")
    $LEGACY_LD | save -f $script
    let obj = ($dir | path join "legacy.o")
    let elf = ($dir | path join "legacy.elf")
    let image = ($dir | path join "legacy.jab")
    ^$"($prefix)as" -march=rva23u64 -I ($ws | path join "sdk" "src") ($fixture | path join "src" "main.S") -o $obj
    ^$"($prefix)ld" -T $script -nostdlib $obj -o $elf
    ^$"($prefix)objcopy" -O binary $elf $image
    $fixture | save -f ($dir | path join "home")
    $image
}

# A kernel without the startup check, as every kernel before it entered an
# image: a copy of the kernel's sources with kernel.S's one call of
# start_check taken out, assembled and linked by the tools the test's
# kernel's flags stamp names, with the build's symbols. Its ELF.
def unchecked-kernel [ws: path, kernel: path, set: string, dir: path]: nothing -> string {
    target retire $dir
    mkdir $dir
    cp -r ($ws | path join "kernel" "src") $dir
    let main = ($dir | path join "src" "kernel.S")
    let lines = (open --raw $main | decode | lines)
    let kept = ($lines | where {|l| not ($l | str starts-with "    call start_check") })
    assert equal (($lines | length) - ($kept | length)) 1 "the kernel's one call of the check taken out"
    ($kept | str join "\n") + "\n" | save -f $main
    let prefix = (open --raw ($kernel | path dirname | path join "flags") | decode | lines | first | split row " " | last)
    let symbols = ($set | split row "," | where {|s| $s != "" } | each {|s| ["--defsym" $"($s)=1"] } | flatten)
    let objects = (walk paths ($dir | path join "src" "*.S") | sort | each {|f|
        let o = ($dir | path join (($f | path parse | get stem) + ".o"))
        ^$"($prefix)as" -march=rva23s64 -I ($dir | path join "src" "include") -I ($ws | path join "sdk" "src") ...$symbols $f -o $o
        $o
    })
    let elf = ($dir | path join "jab.elf")
    ^$"($prefix)ld" -T ($dir | path join "src" "link.ld") -nostdlib ...$objects -o $elf
    $elf
}

# A stand-in for the relay's binary in `dir`, a shell script named `name`
# taking the relay's arguments and doing only what `body` says. Its path.
def stand-in [dir: path, name: string, body: string]: nothing -> string {
    let file = ($dir | path join $name)
    $"#!/bin/sh\n($body)\n" | save -f $file
    ^chmod +x $file
    $file
}

# The message a call raises, "" when it raises none.
def refusal [call: closure]: nothing -> string {
    try { do $call | ignore; "" } catch {|e| $e.msg }
}

# Whether a QEMU line carries the word `key` with `value` after it.
def paired [words: list<string>, key: string, value: string]: nothing -> bool {
    $words | window 2 | any {|w| $w.0 == $key and $w.1 == $value }
}

# The word after `key` on a QEMU line, "" where it is not there.
def after [words: list<string>, key: string]: nothing -> string {
    $words | window 2 | where {|w| $w.0 == $key } | get -o 0.1 | default ""
}

# A fixture program of the test's own, built through the tool: its
# manifest naming the workspace and `body` after it, a program that exits
# 0, or with `--forever` one that awaits the display's tick forever. Its
# image.
def fixture [ws: path, dir: path, name: string, body: string, --forever]: nothing -> string {
    target retire $dir
    mkdir ($dir | path join "src")
    let sdk = ($ws | path join "sdk")
    $"name = '($name)'\nsdk = '($sdk)'\nworkspace = '($ws)'\nincludes = ['($sdk | path join src)']\nlink = '($sdk | path join src program.ld)'\ndisplay = 'none'\n($body)" | save -f ($dir | path join "program.jab.toml")
    let code = (if $forever { "1:\n    jab.sys.display.await\n    j 1b\n" } else { "    jab.sys.exit 0\n" })
    $".include \"jab.inc\"\n\n.section .text\n.global _start\n_start:\n($code)" | save -f ($dir | path join "src" "main.S")
    let made = (^nu ($ws | path join "sdk" "nu" "jab.nu") build $dir | complete)
    if $made.exit_code != 0 { error make { msg: $"the fixture ($name) did not build: ($made.stderr)" } }
    jab program-out $dir release | path join $"($name).jab"
}

# A tree's header fields.
def header [b: binary]: nothing -> record<off_struct: int, off_strings: int, size_strings: int, size_struct: int> {
    let w = {|o| $b | bytes at $o..<($o + 4) | into int --endian big }
    { off_struct: (do $w 8), off_strings: (do $w 12), size_strings: (do $w 32), size_struct: (do $w 36) }
}

# Every node of a tree with its path, and each property of it, by name
# with its value, read on the host.
def nodes-of [b: binary]: nothing -> list<record<path: string, props: record>> {
    let h = (header $b)
    let strings = ($b | bytes at $h.off_strings..<($h.off_strings + $h.size_strings))
    let end = ($h.off_struct + $h.size_struct)
    mut at = $h.off_struct
    mut names = []
    mut open = []
    mut done = []
    while $at < $end {
        let kind = ($b | bytes at $at..<($at + 4) | into int --endian big)
        $at = $at + 4
        if $kind == 1 {
            let n = ($b | bytes at $at..<$end | bytes index-of 0x[00])
            $names = ($names | append ($b | bytes at $at..<($at + $n) | decode))
            $open = ($open | append {})
            $at = $at + ((($n + 4) // 4) * 4)
        } else if $kind == 2 {
            $done = ($done | append { path: ("/" + ($names | skip 1 | str join "/")), props: ($open | last) })
            $names = ($names | drop 1)
            $open = ($open | drop 1)
        } else if $kind == 3 {
            let len = ($b | bytes at $at..<($at + 4) | into int --endian big)
            let off = ($b | bytes at ($at + 4)..<($at + 8) | into int --endian big)
            let tail = ($strings | bytes at $off..)
            let pname = ($tail | bytes at 0..<($tail | bytes index-of 0x[00]) | decode)
            let value = ($b | bytes at ($at + 8)..<($at + 8 + $len))
            $open = ($open | drop 1 | append (($open | last) | insert $pname $value))
            $at = $at + 8 + ((($len + 3) // 4) * 4)
        } else if $kind == 9 {
            break
        }
    }
    $done
}

# The cpus a tree holds under /cpus.
def cpus-of [b: binary]: nothing -> int {
    nodes-of $b | where {|n| $n.path =~ '^/cpus/cpu@[0-9a-f]+$' } | length
}

# The banks of a tree's memory nodes, two cells a base and two a size, as
# QEMU's virt writes them.
def banks-of [b: binary]: nothing -> list<record<base: int, size: int>> {
    let memory = (nodes-of $b | where {|n| ($n.props | get -o device_type) == ("memory" | into binary | bytes add 0x[00] --end) })
    $memory | each {|n|
        let reg = ($n.props | get reg)
        0..<(($reg | bytes length) // 16) | each {|i|
            let at = ($i * 16)
            { base: ($reg | bytes at $at..<($at + 8) | into int --endian big --signed), size: ($reg | bytes at ($at + 8)..<($at + 16) | into int --endian big --signed) }
        }
    } | flatten
}
