# owners' integration test (DriverInventory): every driver global is hart
# 0's, held on the built code. Every kernel source file is classified, a
# file no class names refused, and the drivers, the frame clock, the
# decoders, and hart 0's storage are forbidden to a worker's paths,
# routines and data alike. From every entry a worker's hart takes in the
# kernel, the trap vector's worker path, each call the worker class admits,
# and the drain, no transfer reaches a forbidden routine and no instruction
# refers to forbidden data but the allowlist's one instruction a row, each
# under its condition. The model the walk rests on is checked as bounded
# patterns, any other form refused by name: the hart split and the approach
# it protects, the admissions, the dispatch, and the drain's cut, a worker's
# claim holding the wake alone, which a debug kernel holds as it runs. The
# graph is read off the debug and release kernels' ELFs through the
# toolchain's objdump, each function a symbol's range and each address's
# file from where the objects beside the ELF were laid, so macros and tail
# transfers count as the assembler emitted them. A transfer through a
# register is direct only as the call and tail pseudos emit it, the auipc
# of that register just before; any other is indirect, and a transfer
# whose target does not parse and a function whose file the link order
# does not resolve are refused. The data scan covers the pc-relative
# addresses objdump annotates; an address held in a register and
# dereferenced is outside it, carried by the hart-0-only calls. Then the
# program runs, its worker woken asleep in its wait, and no hart claims or
# enables a device identity or disables its wake.
use ../../../nu/mod/target
use ../../../nu/mod/launch
use std/assert
use ./check.nu [owners-check]
use ./instructions.nu [hex]
use ./inventory.nu [classes forbidden_classes]
use ./model.nu [class_site dispatch_site dispatch_table drain service vector worker_calls]

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    assert ($set | str contains "DEBUG") $"the run's checks are a debug kernel's, and the build is ($set)"
    let ws = ($env.FILE_PWD | path join ".." ".." ".." | path expand)
    let kernel_dir = ($ws | path join (open ($ws | path join "workspace.jab.toml") | get kernel))
    let tool = ($ws | path join "nu" "bin" "do.nu")
    let values = (model-values $ws $kernel_dir)

    # the clean kernels: the debug kernel the test runs on, and the release
    # kernel, built here as purity builds it
    ^nu $tool build --kernel $kernel_dir
    let release = (target root $ws | path join "release" "kernel" "jab.elf")
    assert ($release | path exists) $"the release kernel was built at ($release)"
    let debug_reading = (owners-check $kernel $values)
    assert equal $debug_reading.violations [] $"owners: the debug kernel's worker paths reach no driver: (violation-text $debug_reading.violations)"
    let release_reading = (owners-check $release $values)
    assert equal $release_reading.violations [] $"owners: the release kernel's worker paths reach no driver: (violation-text $release_reading.violations)"

    # the run: the worker woken asleep in its wait, every drain off hart 0
    # claiming the wake alone, every secondary's file enabling it alone
    let run = (launch --kernel $kernel --image $image --out ($out | path join "run") --set $set --seconds 20)
    assert (not ($run.serial | str contains " claimed a device identity ")) $"owners: no hart but 0 claimed a device identity: ($run.serial)"
    assert (not ($run.serial | str contains " enabled a device identity ")) $"owners: no secondary's file enabled a device identity: ($run.serial)"
    assert (not ($run.serial | str contains " disabled the wake identity ")) $"owners: no secondary's file disabled its wake: ($run.serial)"
    assert equal $run.status 0 $"owners: exit status, with the UART: ($run.serial)"
    assert equal $run.serial "owners: woken asleep, then done\n" "owners: the worker slept in its wait, was woken there, and finished"

    for reading in [[name, r]; [debug, $debug_reading] [release, $release_reading]] {
        let r = $reading.r
        print $"owners: the ($reading.name) kernel: ($r.reached) functions reached from ($r.entries | str join ', ') and the calls ($r.class | str join ' ') through ($dispatch_site), ($r.handlers | str join ', ')"
        print $"owners:   the hart split at ($vector)+(hex $r.split.test), its approach entered by its own fall-through alone and ($dispatch_site) by ($class_site)'s ($r.class | length) admissions alone, no address of either formed in the code or held in the data; the dispatch ($dispatch_table) indexed by a7 times 8"
        print $"owners:   the drain's mask at ($drain)+(hex $r.cut.mask) on every path to its calls into ($service) at ($r.cut.cuts | each {|c| $'($drain)+(hex $c)' } | str join ' and '), each reached from the mask only through an xor of s0 \(($r.cut.forms | str join ', ')\), the only writes of s0 there"
        print $"owners:   permitted ($r.permitted | each {|p| $'($p.symbol) at ($p.function)+(hex $p.offset), ($p.kind)' } | str join '; ')"
    }
    print $"owners: the inventory: ($classes | each {|c| $'($c.class) ($c.files | length)' } | str join ', '); the ($forbidden_classes | str join ', ') classes forbidden to a worker's paths"
    print "owners: the data scan covers the pc-relative addresses objdump annotates, la and lla and the loads and stores through them; an address held in a register and dereferenced is outside it, carried by the hart-0-only calls"
    print "owners: the drain's cut assumes a worker's claim holds the wake alone: a secondary's file enables the wake alone (aia_file_open) and every device source targets hart 0's file (irq_enable); the debug kernel's claim and configuration checks hold it as it runs"
    print "owners: ok"
}

# The numbers the model reads from the includes: HART_ID's offset in a
# hart's record, the wake's identity, JAB_DENIED, and the worker calls
def model-values [ws: path, kernel_dir: path]: nothing -> record {
    let jab = (open --raw ($ws | path join "sdk" "src" "jab.inc") | decode)
    let hart = (open --raw ($kernel_dir | path join "src" "include" "hart.inc") | decode)
    let aia = (open --raw ($kernel_dir | path join "src" "include" "aia.inc") | decode)
    {
        hart_id: (set-value $hart HART_ID)
        wake: (set-value $aia AIA_WAKE)
        denied: (set-value $jab JAB_DENIED)
        calls: ($worker_calls | each {|n| set-value $jab $n } | sort)
    }
}

# A `.set` constant's value where an include writes it as a literal
def set-value [text: string, name: string]: nothing -> int {
    let v = ($text | parse --regex ('(?m)^\.set ' + $name + ', (?P<v>-?\d+)\b') | get -o 0.v)
    if $v == null { error make {msg: $"no literal .set of ($name)"} }
    $v | into int
}

# Violations as one line each, their paths with them
def violation-text [vs: list<any>]: nothing -> string {
    if ($vs | is-empty) { return "none" }
    $vs | each {|v|
        if $v.kind == "model" { $"model: ($v.detail)" } else {
            $"($v.kind) ($v.function)(if $v.symbol == '' { '' } else { ' ' + $v.symbol }) at (hex $v.offset): ($v.detail); path ($v.path)"
        }
    } | str join "; "
}
