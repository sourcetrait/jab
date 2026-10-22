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
# three harts recorded diagnostic, its 4 GiB and no `jab.spec`; a named
# launch whose bootargs carry a `jab.spec=` of the caller's refused, and a
# kernel command line of 256 bytes refused, its length named, 255 taken; a
# name the spec data does not define refused; a program listing 1KA1 alone
# refused on 1KB1, naming both. Then the startup check (ProgramMinimums): this
# program's first page read back, its declaration the spec data's; the
# kernel refusing machines off the spec their command line names (CHECKS);
# a program's base demand held on a custom machine, its refusal skipped by
# the debug kernel's knob and the run recorded below the minimum, a release
# kernel refusing it still; a program declaring nothing and one built
# before the header each on the legacy path; malformed first pages each
# refused by the kernel by name; and a kernel without
# the check running a new image through its jump. Then the launch's bound
# (LaunchBound): the one GNU timeout a run resolves, a stand-in refused or
# passed over, its bound on a child, and a program that never exits ending
# at its bound. Then Windows' pipes (PipeShape):
# the chardev's path on each host, the pipe pairs, and a plan's relays.
# Then the launch's supervision (RelaySupervision), the caller's side: the
# lock refusing and taking over a stale record, the records and their
# models, a stop, the backstop, a withheld go, a silent supervisor's forced
# end after its go and before its go is published, the launch's tag, and
# the host's lock outside every target. Last the default, in a
# scratch XDG config home: `jab/config.toml` seeded from
# asset/default/config.toml byte for byte, one there never written over,
# JAB_SPEC ahead of it, one naming no spec refused, a home that is not
# there refused and never made, and a launch naming neither flag on the
# configured spec.
use ../../../nu/mod/bound
use ../../../nu/mod/target
use ../../../nu/mod/spec
use ../../../nu/mod/chardev
use ../../../nu/mod/demand
use ../../../nu/mod/build
use ../../../nu/mod/machine
use ../../../nu/mod/launch
use ../../../nu/mod/nutype
use ../../../nu/mod/supervise
use std/assert
use ./pipes.nu
use ./startup.nu
use ./startup.nu [CHECKS NOMINIMUM SHORT legacy-image patched unchecked-kernel]

const GIB = 1073741824

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let ws = ($env.FILE_PWD | path join ".." ".." ".." | path expand)
    let specs = (spec data $ws)

    # each spec provisioned: the line and the tree from the table
    let provisioned = ($specs | where {|s| $s.cores <= 8 and $s.display == { width: 1920, height: 1080 } })
    assert equal ($provisioned | get name | each {|n| $n | str lowercase }) ["1ka1" "1kb1"] $"the specs the launcher provisions: ($provisioned | get name)"
    for s in $provisioned {
        let name = ($s.name | str lowercase)
        let ram = ($s.ram / 1GiB | into int)
        let p = (launch plan --kernel $kernel --image $image --out ($out | path join $"plan_($name)") --spec $name)
        assert (paired $p.qemu "-smp" ($s.cores | into string)) $"($name): -smp ($s.cores): ($p.qemu)"
        assert (paired $p.qemu "-m" $"($ram)G") $"($name): -m ($ram)G: ($p.qemu)"
        assert (paired $p.qemu "-device" $"virtio-gpu-device,xres=($s.display.width),yres=($s.display.height)") $"($name): the GPU at its display: ($p.qemu)"
        assert ((after $p.qemu "-append") | split row " " | any {|w| $w == $"jab.spec=($name)" }) $"($name): jab.spec=($name) on the kernel's line: ($p.qemu)"
        assert equal [$p.machine.spec $p.machine.diagnostic] [{ name: $name, cores: $s.cores, ram_gib: $ram, display: $s.display } null] $"($name): the machine's record the spec's: ($p.machine)"
        let tree = (open --raw (machine dump-tree --kernel $kernel --image $image --out ($out | path join $"($name).dtb") --spec $name) | into binary)
        assert equal (cpus-of $tree) $s.cores $"($name): its tree's cpus"
        assert equal (banks-of $tree) [{ base: 0x80000000, size: ($ram * $GIB) }] $"($name): its tree's one bank, its RAM from RAM's base"
        let run = (launch --kernel $kernel --image $image --out ($out | path join $"run_($name)") --set $set --spec $name --seconds 20)
        assert equal [$run.status ($run.serial | lines)] [0 ["spec: up"]] $"($name): the program runs on it: ($run.serial)"
        assert equal [$run.declared $run.diagnostic] [true false] $"($name): a declared run, not diagnostic: ($run.declared), ($run.diagnostic)"
    }

    # every other spec refused before QEMU starts, naming why
    for s in ($specs | where {|s| $s.name not-in ($provisioned | get name) }) {
        let said = (refusal { launch plan --kernel $kernel --image $image --out ($out | path join $"plan_($s.name)") --spec $s.name })
        let why = (if $s.cores > 8 { $"($s.name) has ($s.cores) cores, past the 8 harts a machine takes" } else { $"($s.name)'s display is ($s.display.width) by ($s.display.height), and the ABI's 1920 by 1080" })
        assert ($said | str contains $why) $"($s.name) refused, saying ($why): ($said)"
    }

    # --spec with --harts, refused naming both, no QEMU run
    let both = $"--spec 1ka1 with --harts 3"
    let both_out = ($out | path join "both")
    target retire $both_out
    for c in [
        { name: "plan", call: { launch plan --kernel $kernel --image $image --out $both_out --spec 1ka1 --harts 3 } }
        { name: "launch", call: { launch --kernel $kernel --image $image --out $both_out --set $set --spec 1ka1 --harts 3 } }
        { name: "dump-tree", call: { machine dump-tree --kernel $kernel --image $image --out ($both_out | path join "both.dtb") --spec 1ka1 --harts 3 } }
    ] {
        let said = (refusal $c.call)
        assert ($said | str contains $both) $"($c.name): --spec with --harts refused naming both: ($said)"
    }
    assert (($both_out | path join "serial.log" | path type) == null) $"no QEMU run for --spec with --harts: ($both_out)"

    # a custom machine of three harts: diagnostic, 4 GiB, no jab.spec
    let custom = (launch plan --kernel $kernel --image $image --out ($out | path join "custom") --harts 3)
    assert equal [$custom.machine.spec $custom.machine.diagnostic] [null { harts: 3, ram_gib: 4 }] $"a custom machine of three harts, diagnostic: ($custom.machine)"
    assert (paired $custom.qemu "-m" "4G") $"a custom machine's 4 GiB: ($custom.qemu)"
    assert (not ($custom.qemu | any {|w| $w =~ 'jab\.spec=' })) $"no jab.spec on a custom machine's line: ($custom.qemu)"
    let custom_run = (launch --kernel $kernel --image $image --out ($out | path join "custom_run") --set $set --harts 3 --seconds 20)
    assert equal [$custom_run.status $custom_run.declared $custom_run.diagnostic] [0 true true] $"a custom machine's run declared and diagnostic: ($custom_run.serial)"

    # the kernel's command line (SpecSelection's S4), refused before QEMU
    # starts: a named launch's bootargs holding a jab.spec= of the caller's,
    # the launcher's name the only one; and a line past the 255 bytes the
    # kernel reads, its length named, a line of 255 taken whole
    let renamed = (refusal { launch plan --kernel $kernel --image $image --out ($out | path join "renamed") --spec 1ka1 --bootargs "jab.late=2 jab.spec=1kb1" })
    assert ($renamed | str contains "--bootargs holds jab.spec=1kb1, and this launch names the spec 1ka1") $"a named launch's own jab.spec= refused: ($renamed)"
    let long = (refusal { launch plan --kernel $kernel --image $image --out ($out | path join "long") --spec 1ka1 --bootargs ("" | fill --character "x" --width 242) })
    assert ($long | str contains "the kernel's command line is 256 bytes, past the 255 the kernel reads") $"a line of 256 bytes refused, its length named: ($long)"
    let edge = (launch plan --kernel $kernel --image $image --out ($out | path join "edge") --spec 1ka1 --bootargs ("" | fill --character "x" --width 241))
    assert equal (after $edge.qemu "-append" | str length) 255 $"a line of 255 bytes taken whole: ($edge.qemu)"

    # a name the data does not define
    let unknown = (refusal { launch plan --kernel $kernel --image $image --out ($out | path join "unknown") --spec 9zz9 })
    assert ($unknown | str contains "no spec 9zz9 in the spec data, which defines 1KA1") $"an unknown spec refused: ($unknown)"

    # a program listing 1KA1 alone, refused on 1KB1, naming both
    let listed = (fixture $ws ($out | path join "fixtures" "listed") "listed" "specs = ['1ka1']\n")
    let unlisted = (refusal { launch plan --kernel $kernel --image $listed --out ($out | path join "unlisted") --spec 1kb1 })
    assert ($unlisted | str contains "listed does not list 1kb1, the spec this launch names; it lists 1KA1") $"a spec its program does not list refused: ($unlisted)"
    let on_listed = (launch plan --kernel $kernel --image $listed --out ($out | path join "listed_plan") --spec 1ka1)
    assert equal $on_listed.machine.spec.name "1ka1" $"the spec it lists planned: ($on_listed.machine)"

    # the startup check: this program's first page, its declaration the
    # spec data's for both specs it lists and its base demand the main hart
    let own = (demand check-image $image)
    assert equal [$own.kind $own.declaration.base] ["declared" 1] $"this program's image declared, its base demand one hart: ($own | to nuon)"
    let declared = ($provisioned | each {|s| { name: ($s.name | str lowercase), cores: $s.cores, ram_gib: ($s.ram / 1GiB | into int), display: $s.display, fps: $s.fps, isa: $s.isa_profile } })
    assert equal $own.declaration.specs $declared $"its declaration's entries the spec data's: ($own.declaration.specs | to nuon)"
    # the kernel's refusals of a machine off the named spec, each before the
    # program starts, its line alone on the UART and status 1; a name in
    # capitals read as the entries' lowercase
    for r in $CHECKS {
        let run = (launch --kernel $kernel --image $image --out ($out | path join $"check_($r.name)") --set $set --harts $r.harts --bootargs $r.bootargs --qemu $r.qemu --seconds 20)
        assert equal [$run.status ($run.serial | lines)] [$r.status [$r.line]] $"($r.name): ($r.bootargs) on ($r.harts) harts (($r.qemu | str join ' ')): ($run.status), ($run.serial)"
    }

    # the minimum: a program reserving two graphics harts, its base demand
    # three, refused on a custom machine of two and run on three; past the
    # minimum on the debug kernel by its knob, the run recorded below it; and
    # the release kernel, reading no knob, refusing it still
    let reserving = (fixture $ws ($out | path join "fixtures" "reserving") "reserving" "specs = ['1ka1']\n\n[reserved]\ngfx_harts = 2\n")
    assert equal (demand check-image $reserving | get declaration.base) 3 "the reserving program's base demand three harts"
    let short = (launch --kernel $kernel --image $reserving --out ($out | path join "short") --set $set --harts 2 --seconds 20)
    assert equal [$short.status ($short.serial | lines)] [1 [$SHORT]] $"two harts short of the base demand refused: ($short.serial)"
    let held = (launch --kernel $kernel --image $reserving --out ($out | path join "held") --set $set --harts 3 --seconds 20)
    assert equal [$held.status ($held.serial | lines) $held.diagnostic] [0 [] true] $"three harts hold it, diagnostic as a custom machine: ($held.serial)"
    let below = (launch --kernel $kernel --image $reserving --out ($out | path join "below") --set $set --harts 2 --bootargs $NOMINIMUM --seconds 20)
    assert equal [$below.status ($below.machine | get -o below_minimum) $below.diagnostic] [0 true true] $"the knob runs it below the minimum, so recorded and diagnostic: ($below.serial), ($below.machine)"
    let tool = ($ws | path join "nu" "bin" "do.nu")
    ^nu $tool build --kernel ($ws | path join "kernel")
    let release = (target root $ws | path join "release" "kernel" "jab.elf")
    let release_below = (launch --kernel $release --image $reserving --out ($out | path join "release_below") --harts 2 --bootargs $NOMINIMUM --seconds 20)
    assert equal [$release_below.status ($release_below.serial | lines)] [1 [$SHORT]] $"the release kernel refuses it under the knob too: ($release_below.serial)"

    # no declaration: a program listing no specs, its header undeclared, and
    # one built before the header under the link script of then, its code at
    # the window's base; each runs on the legacy path, on a named machine its
    # kernel checks nothing of
    let undeclared = (fixture $ws ($out | path join "fixtures" "undeclared") "undeclared" "")
    assert equal (demand check-image $undeclared | get kind) "undeclared" "a program listing no specs has its header undeclared"
    let legacy = (legacy-image $ws ($out | path join "fixtures" "undeclared") ($undeclared | path dirname) ($out | path join "legacy"))
    assert equal (demand check-image $legacy | get kind) "legacy" "an image built before the header reads as legacy"
    for c in [{ name: "undeclared", image: $undeclared } { name: "legacy", image: $legacy }] {
        let run = (launch --kernel $kernel --image $c.image --out ($out | path join $"($c.name)_run") --set $set --spec 1kb1 --seconds 20)
        assert equal [$run.status ($run.serial | lines) $run.declared $run.diagnostic] [0 [] false true] $"the ($c.name) image on 1KB1, undeclared and diagnostic: ($run.serial)"
    }

    # malformed first pages: copies of this program's image, each patched,
    # the CRC made again where the patch lies inside the declaration, and
    # refused by name by the kernel before the program starts
    let bytes = (open --raw $image | into binary)
    let crc = ($bytes | bytes at 24..<28 | into int --endian little)
    let malformed = (startup malformed $crc)
    # a loop rather than each, so an assertion raises alone, its own title
    mut copies = []
    for m in $malformed {
        let copy = (patched $bytes $m ($out | path join "malformed" $m.name) ($env.FILE_PWD | path join ".." | path expand))
        let run = (launch --kernel $kernel --image $copy --out ($out | path join $"malformed_($m.name)") --set $set --spec 1ka1 --seconds 20)
        assert equal [$run.status ($run.serial | lines)] [1 [$"jab: declaration refused: ($m.why)"]] $"($m.name): the kernel refuses it, ($m.why): ($run.serial)"
        $copies = ($copies | append { name: $m.name, image: $copy })
    }

    # a kernel without the check, from a copy of the kernel's sources with
    # its one call taken out, as every kernel before it entered an image at
    # its base: the jump takes it to the code, the bad CRC's copy unread
    let unchecked = (unchecked-kernel $ws $kernel $set ($out | path join "unchecked"))
    for c in [{ name: "own", image: $image } { name: "crc", image: ($copies | where name == "crc" | first | get image) }] {
        let run = (launch --kernel $unchecked --image $c.image --out ($out | path join $"unchecked_($c.name)") --set $set --spec 1ka1 --seconds 20)
        assert equal [$run.status ($run.serial | lines)] [0 ["spec: up"]] $"a kernel without the check runs the ($c.name) image through its jump: ($run.serial)"
    }

    # the launch's bound (LaunchBound): one GNU coreutils timeout resolved a
    # run, GNU's on PATH here; JAB_TIMEOUT naming a stand-in whose --version
    # is not GNU's refused naming it; with no override a stand-in first on
    # PATH passed over for the real one; the real one bounding a child of
    # 30 s at a second, 124 within two; the stand-ins on every host but
    # Windows; and a launch of a program that never exits ending at its
    # --seconds 2 with 124 and the resolved timeout in its result, and off
    # Windows the same launch under a bare override, its result holding
    # GNU's resolved path and the name as given
    let real = (with-env { JAB_TIMEOUT: "" } { bound timeout })
    assert ($real.version | str starts-with "timeout (GNU coreutils) ") $"the timeout resolved GNU's: ($real)"
    if $nu.os-info.name != "windows" {
        let stand_in = (pipes stand-in $out)
        let stand = $stand_in.stand
        let fake = $stand_in.fake
        let forced = (refusal { with-env { JAB_TIMEOUT: $fake } { bound timeout } })
        assert ($forced | str contains $"JAB_TIMEOUT names ($fake)") $"a JAB_TIMEOUT not GNU's refused naming it, GNU's on PATH: ($forced)"
        let shadowed = (with-env { JAB_TIMEOUT: "", PATH: ([$stand] ++ $env.PATH) } { bound timeout })
        assert equal $shadowed.path $real.path $"a stand-in first on PATH passed over for GNU's: ($shadowed)"
        # the override resolved once (ResolvedOverride): an absolute path, a
        # path relative to another working directory, and a bare name on PATH
        # each resolved to GNU's one absolute path and recorded as given; a
        # bare name finding the stand-in first on PATH refused, no fall to
        # GNU's beside it; a path to no file refused naming it
        let relative = (pipes relative $out $real)
        let resolved = [
            (with-env { JAB_TIMEOUT: $real.path } { bound timeout })
            (with-env { JAB_TIMEOUT: $relative } { cd $out; bound timeout })
            (with-env { JAB_TIMEOUT: ($real.path | path basename) } { bound timeout })
        ]
        assert equal ($resolved | get path) [$real.path $real.path $real.path] $"each override resolved to GNU's absolute path: ($resolved | to nuon)"
        assert equal ($resolved | get override) [$real.path $relative ($real.path | path basename)] $"each override recorded as given: ($resolved | to nuon)"
        let found = (refusal { with-env { JAB_TIMEOUT: "timeout", PATH: ([$stand] ++ $env.PATH) } { bound timeout } })
        assert ($found | str contains $"resolved to ($fake)") $"a bare name finding the stand-in first refused, no fall to GNU's: ($found)"
        let missing = (refusal { with-env { JAB_TIMEOUT: ($stand | path join "absent") } { bound timeout } })
        assert ($missing | str contains "resolves to no file") $"an override naming no file refused: ($missing)"
    }
    let t0 = (date now)
    let bounded = (^$real.path 1 sleep 30 | complete)
    let took = (((date now) - $t0) / 1sec)
    assert ($bounded.exit_code == 124 and $took < 2) $"sleep 30 under a one-second bound: ($bounded.exit_code) in ($took) s"
    let forever = (fixture $ws ($out | path join "fixtures" "forever") "forever" "" --forever)
    let bound_run = (launch --kernel $kernel --image $forever --out ($out | path join "forever_run") --set $set --harts 1 --seconds 2)
    assert equal [$bound_run.status $bound_run.timeout_binary $bound_run.timeout_override] [124 $real.path ""] $"a program that never exits ends at its bound, the resolved timeout in its record, no override: ($bound_run.status), ($bound_run.timeout_binary), ($bound_run.timeout_override)"
    if $nu.os-info.name != "windows" {
        let bare = ($real.path | path basename)
        let bare_run = (with-env { JAB_TIMEOUT: $bare } { launch --kernel $kernel --image $forever --out ($out | path join "forever_bare") --set $set --harts 1 --seconds 2 })
        assert equal [$bare_run.status $bare_run.timeout_binary $bare_run.timeout_override] [124 $real.path $bare] $"a launch under a bare override ends at its bound, GNU's path and the name as given in its record: ($bare_run.status), ($bare_run.timeout_binary), ($bare_run.timeout_override)"
    }

    # Windows' pipes (PipeShape): the chardev's path on each host, a POSIX
    # host's `<out>/<endpoint>` and Windows' bare name by the run's nonce,
    # none without one; Windows' pair of two plain files and, elsewhere,
    # this host's, a fifo in and a plain file out, each made empty with a
    # previous run's retired; and a plan's relays, the monitor's and the
    # API's on Windows and none elsewhere, the monitor and the API on fifos
    # as before. The relays run in the launch's supervisor, its crate's
    # tests holding them over stand-ins (TestRelay)
    let pipes = (pipes home $out)
    let root = (target root $ws)
    for os in ["linux" "macos"] {
        assert equal (chardev pipe-path $pipes "api" 42 $os) ($pipes | path join "api") $"($os): the chardev's path the pair's base"
    }
    assert equal (chardev pipe-path $pipes "monitor" 42 "windows") "jab-000000000000002a-monitor" "windows: the pipe's bare name by the run's nonce"
    let nameless = (refusal { chardev pipe-path $pipes "api" 0 "windows" })
    assert ($nameless | str contains "named by its nonce") $"windows: a pipe with no nonce refused: ($nameless)"
    let windows = (chardev pipe-pair $pipes "padport" 42 "windows" $root)
    assert equal [$windows.name ($windows.inward | path type) ($windows.outward | path type)] ["jab-000000000000002a-padport" "file" "file"] $"Windows' pair, two plain files: ($windows)"
    pipes leftover $windows
    let renewed = (chardev pipe-pair $pipes "padport" 42 "windows" $root)
    assert equal [(ls $renewed.inward | get 0.size) (ls $renewed.outward | get 0.size)] [0B 0B] "a previous run's pair retired, the new one empty"
    let piped = (launch plan --kernel $kernel --image $image --out ($pipes | path join "plan") --spec 1ka1 --api)
    if $nu.os-info.name == "windows" {
        assert equal ($piped.relays | each {|r| $r.endpoint }) ["monitor" "api"] $"the monitor's relay and the API's: ($piped.relays)"
        assert ((after $piped.qemu "-monitor") | str starts-with "pipe:jab-") $"the monitor on a named pipe: ($piped.qemu)"
        assert equal ($piped.api_in | path type) "file" $"the API's in-file a plain file: ($piped.api_in)"
    } else {
        let here = (chardev pipe-pair $pipes "api" 0 $nu.os-info.name $root)
        assert equal [$here.name ($here.inward | path type) ($here.outward | path type) (ls $here.outward | get 0.size)] [($pipes | path join "api") "pipe" "file" 0B] $"this host's pair, a fifo in and an empty file out: ($here)"
        assert equal [$piped.relays $piped.bridge_pipe] [[] ""] $"no relay and no bridge's pipe: ($piped.relays), ($piped.bridge_pipe)"
        assert equal [(after $piped.qemu "-monitor") ($piped.api_in | path type)] [$"pipe:($piped.monitor)" "pipe"] $"the monitor's pair and the API's fifo as before: ($piped.qemu)"
        let watched = (chardev pipe-pair $pipes "monitor" 42 "windows" $root)
        let relays = (chardev relays-of [{ endpoint: "monitor", pipe: $watched } { endpoint: "padport", pipe: null }])
        assert equal ($relays | each {|r| [$r.endpoint $r.name $r.inward $r.outward] }) [["monitor" "jab-000000000000002a-monitor" $watched.inward $watched.outward]] $"a relay for each pipe the machine has: ($relays)"
    }

    # the launch's supervision (RelaySupervision), the caller's side, on a
    # lock home of the test's own: a launch refused while another holds the
    # lock, naming it; a stale record replaced and named; two launches, each
    # its own token, each record held to its model, its control files gone;
    # a stop's quit at its time after the sends due before it, no screen,
    # and a stop beside a capture refused; the caller's backstop on a
    # supervisor paused before its readiness, nothing measured run; a startup
    # the caller withholds its go from, expired; a supervisor silent after
    # its go, the run ended by the record kept and reported incomplete; one
    # silent once it has decided the go and before publishing it, the inert
    # gate ended by the record kept and nothing measured run; and the
    # launch's tag, a retired alarm's message and another launch's discarded
    # ahead of the supervisor's result
    let locks = ($out | path join "locks")
    target retire $locks
    mkdir $locks
    with-env { JAB_LAUNCH_LOCK: $locks } {
        let binary = (supervise binary)
        let lock = {|words: list<string>| ^$binary lock ...$words | complete | get stdout | from json }
        let holder = (do $lock ["acquire" "--token" "00000000000000a1" "--caller" ($nu.pid | into string)])
        assert equal $holder.outcome "ok" $"the test holds the lock: ($holder)"
        let refused = (refusal { launch --kernel $kernel --image $image --out ($out | path join "locked") --set $set --spec 1ka1 --seconds 20 })
        assert ($refused | str contains "the launch 00000000000000a1 holds the lock") $"a launch refused while another holds the lock, naming it: ($refused)"
        assert equal (do $lock ["release" "--token" "00000000000000a1"] | get outcome) "ok" "the test's hold released"
        let dead = (^sh -c 'echo $$' | str trim | into int)
        let stale = { token: "00000000000000b2", state: "running", caller: { pid: $dead, start: 1 }, supervisor: { pid: $dead, start: 1 }, gate: null, replaced: null, utc: "then" }
        $stale | to json | save --raw -f ($locks | path join "owner.nuon")
        let one = (launch --kernel $kernel --image $image --out ($out | path join "token_one") --set $set --spec 1ka1 --seconds 20)
        let owner = (open --raw ($locks | path join "owner.nuon") | decode | from json)
        assert equal [$owner.state $owner.replaced.token] ["released" "00000000000000b2"] $"the stale record replaced and named, then released: ($owner)"
        let two = (launch --kernel $kernel --image $image --out ($out | path join "token_two") --set $set --spec 1ka1 --seconds 20)
        let records = ([$one $two] | each {|r| open --raw $r.launch | decode | from nuon })
        assert ($records.0.receipt.token != $records.1.receipt.token) $"two launches, two tokens: ($records | each {|r| $r.receipt.token })"
        let model = (open --raw ($ws | path join "nu" "type" "launch" "Launch.nutype") | decode)
        for r in $records {
            assert equal (nutype problems $r $model "Launch.nutype") [] "a launch's record held to its model"
        }
        for r in [$one $two] {
            assert (glob ($r.launch | path dirname | path join "launch-*.json") | is-empty) $"its control files gone: ($r.launch | path dirname)"
        }
        let stopped = (launch --kernel $kernel --image $forever --out ($out | path join "stopped") --set $set --harts 1 --send [[at bytes]; [500ms 0x[01 02]]] --stop 1500ms --seconds 20)
        assert equal [$stopped.status $stopped.screen] [0 ""] $"a stop ends the run with no screen: ($stopped.status)"
        assert ($stopped.send_seconds.0 < $stopped.quit_seconds and $stopped.quit_seconds >= 1.5 and $stopped.quit_seconds < 2.5) $"the send, then the quit at its time: ($stopped.send_seconds), ($stopped.quit_seconds)"
        assert ($stopped.wall_seconds >= $stopped.quit_seconds and $stopped.wall_seconds < ($stopped.quit_seconds + 3)) $"the run's end after its quit: ($stopped.wall_seconds)"
        let both_ends = (refusal { launch --kernel $kernel --image $forever --out ($out | path join "both_ends") --set $set --harts 1 --capture 1sec --stop 2sec --seconds 20 })
        assert ($both_ends | str contains "--capture and --stop together") $"a stop beside a capture refused: ($both_ends)"
        let b0 = (date now)
        let backstopped = (refusal { with-env { JABPIPE_TEST_PAUSE: "readiness:16000" } { launch --kernel $kernel --image $image --out ($out | path join "backstop") --set $set --spec 1ka1 --seconds 20 } })
        let held = (((date now) - $b0) / 1sec)
        assert ($backstopped | str contains "gave no outcome within the caller's backstop") $"a supervisor silent before its readiness refused at the backstop: ($backstopped)"
        assert ($held >= 14 and $held < 18) $"the backstop's 14 s: ($held) s"
        assert (not ($out | path join "backstop" "serial.log" | path exists)) "nothing measured ran under the backstop"
        let w0 = (date now)
        let withheld = (refusal { with-env { JAB_LAUNCH_TEST: "withhold" } { launch --kernel $kernel --image $image --out ($out | path join "withheld") --set $set --spec 1ka1 --seconds 20 } })
        let expired = (((date now) - $w0) / 1sec)
        assert ($withheld | str contains "the launch's startup ended expired") $"a go withheld past the allowance: ($withheld)"
        assert ($expired >= 11 and $expired < 15) $"the allowance's 11 s: ($expired) s"
        assert (not ($out | path join "withheld" "serial.log" | path exists)) "nothing measured ran with the go withheld"
        let silent = (with-env { JABPIPE_TEST_PAUSE: "run:30000" } { launch --kernel $kernel --image $forever --out ($out | path join "silent") --set $set --harts 1 --seconds 2 })
        assert ($silent.incomplete | default "" | str contains "the completion alarm") $"a supervisor silent after its go, the run reported incomplete: ($silent.incomplete)"
        assert equal [$silent.status $silent.wall_seconds $silent.cpu_seconds] [null null null] "an incomplete run's status and times null, never zero"
        let record = (open --raw $silent.launch | decode | from nuon)
        assert equal [$record.receipt ($record.incomplete | str contains "the completion alarm")] [null true] $"its record says so: ($record.incomplete)"
        assert (ps -l | where {|p| $p.command | str contains ($out | path join "silent") } | is-empty) "no QEMU of it left, nor its supervisor"
        assert equal (open --raw ($locks | path join "owner.nuon") | decode | from json | get state) "released" "the lock released once the group was empty"
        let o0 = (date now)
        let unpublished = (with-env { JABPIPE_TEST_PAUSE: "outcome:16000" } { launch --kernel $kernel --image $image --out ($out | path join "unpublished") --set $set --spec 1ka1 --seconds 20 })
        let waited = (((date now) - $o0) / 1sec)
        assert ($unpublished.incomplete | default "" | str contains "the startup alarm") $"a supervisor silent before its go is published, the run reported incomplete: ($unpublished.incomplete)"
        assert ($waited >= 14 and $waited < 18) $"the backstop's 14 s: ($waited) s"
        assert equal $unpublished.status null "no status for a run that never went"
        assert (not ($out | path join "unpublished" "serial.log" | path exists)) "nothing measured ran before the go was published"
        assert (ps -l | where {|p| $p.command | str contains ($out | path join "unpublished") } | is-empty) "no gate of it left, nor its supervisor"
        assert equal (open --raw ($locks | path join "owner.nuon") | decode | from json | get state) "released" "the lock released once the gate's group was empty"
        let tag = 4242
        { token: $tag, source: "startup" } | job send --tag $tag 0
        { token: 7, source: "supervisor" } | job send --tag $tag 0
        { token: $tag, source: "supervisor", result: { exit_code: 0 } } | job send --tag $tag 0
        let got = (supervise receive $tag ["startup"] null)
        assert equal [$got.source $got.result.exit_code] ["supervisor" 0] $"the result taken past a retired alarm's message and another launch's: ($got)"
        assert equal (supervise receive $tag [] 0sec) null "the tag empty after it"
    }

    # the host's own lock, which this test's launches outside that block
    # took, lies outside the workspace and every checkout's target, so no
    # clean or retirement ever takes it
    let state = (match $nu.os-info.name {
        "windows" => $env.LOCALAPPDATA
        _ => (if ($env.XDG_STATE_HOME? | default "") == "" { $env.HOME | path join ".local" "state" } else { $env.XDG_STATE_HOME })
    })
    let host_lock = ($state | path join "jab" "launch")
    let targets = (target root $ws | path dirname)
    assert ($host_lock | path join "lock" | path exists) $"the host's launch lock where this test's launches took it: ($host_lock)"
    assert (not ($host_lock | str starts-with $targets) and not ($host_lock | str starts-with $ws)) $"the lock outside the targets and the workspace: ($host_lock)"

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
    let unflagged = (do $in_xdg { launch plan --kernel $kernel --image $image --out ($out | path join "unflagged") })
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
    print $"spec: ($provisioned | length) specs provisioned, each line and tree from the table; ($specs | length) defined; the startup check's ($CHECKS | length) machines, the minimum, the legacy path twice, ($malformed | length) malformed first pages, and a kernel without the check; the launch's bound, ($real.path); Windows' pipes; the launch's supervision"
    print "spec: ok"
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
    let made = (^nu ($ws | path join "nu" "bin" "do.nu") build $dir | complete)
    if $made.exit_code != 0 { error make { msg: $"the fixture ($name) did not build: ($made.stderr)" } }
    build program-out $dir release | path join $"($name).jab"
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
