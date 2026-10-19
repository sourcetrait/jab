use ../demand
use ../stamp
use ../target
use ../toolchain
use ../walk
use ../workspace

# The assembler's profile for a program, which runs in U-mode
const march_program = "-march=rva23u64"

# The assembler's profile for the kernel, the supervisor's
const march_kernel = "-march=rva23s64"

# A build's symbols from --set: screaming snake case, sorted, a digit-led refused
export def symbols [set: string]: nothing -> list<string> {
    let names = ($set | split row "," | each {|s| $s | str trim } | where {|s| $s != "" } | each {|s| $s | str screaming-snake-case } | uniq | sort)
    for n in $names {
        if not ($n =~ '^[A-Z_][A-Z0-9_]*$') {
            error make {msg: $"--set ($n): not a symbol the assembler takes; a name starts with a letter"}
        }
    }
    $names
}

# A test build's symbols: those asked and DEBUG
export def with-debug [names: list<string>]: nothing -> list<string> { $names | append "DEBUG" | uniq | sort }

# The tree a build lands in: debug with DEBUG set, else release
def profile [names: list<string>]: nothing -> string { if "DEBUG" in $names { "debug" } else { "release" } }

# The symbols as the assembler takes them, each `--defsym NAME=1`
def defsyms [names: list<string>]: nothing -> list<string> { $names | each {|n| ["--defsym" $"($n)=1"] } | flatten }

# A program's directory in the target for one purpose, whatever the tree
export def program-shard [dir: path, purpose: string]: nothing -> string {
    let c = (context ($dir | path expand) "program" [])
    target shard-dir $c $purpose
}

# Where a program's build of a tree lands, its tests' and runs' output beside it
export def program-out [dir: path, tree: string]: nothing -> string {
    (context ($dir | path expand) "program" (target tree-symbols $tree)).out
}

# The kernel a program runs on in a tree
export def program-kernel [dir: path, tree: string]: nothing -> string {
    kernel-elf (context ($dir | path expand) "program" (target tree-symbols $tree))
}

# A kernel's or program's build context: manifest, toolchain, target, out
export def context [dir: path, kind: string, names: list<string>]: nothing -> record {
    let here = ($dir | path expand)
    let manifest_path = ($here | path join $"($kind).jab.toml")
    let manifest = (open $manifest_path)
    let workspace = (workspace workspace-of $here $manifest)
    let tree = (profile $names)
    let root = (target root (if $workspace == null { $here } else { $workspace }))
    let place = (target shard-of $here $workspace $root $manifest.name)
    let target = (if $place.inside { $here | path join $tree } else { $root | path join $tree })
    let tc = (toolchain $here $workspace)
    {
        here: $here,
        manifest: $manifest,
        manifest_path: $manifest_path,
        workspace: $workspace,
        toolchain: $tc,
        prefix: (toolchain tool-prefix $tc),
        symbols: $names,
        profile: $tree,
        root: $root,
        shard: $place.relative,
        inside: $place.inside,
        target: $target,
        out: (if $place.inside { $target } else { $target | path join $place.relative }),
    }
}

# The kernel ELF a program runs on: its workspace's in its tree, or JAB_KERNEL
export def kernel-elf [c: record] {
    if $c.workspace != null {
        let ws = (open ($c.workspace | path join "workspace.jab.toml"))
        return (target root $c.workspace | path join $c.profile $ws.kernel "jab.elf")
    }
    let from_env = ($env.JAB_KERNEL? | default "")
    if $from_env != "" { return $from_env }
    error make {msg: "no workspace above this program and no JAB_KERNEL: where is the kernel?"}
}

# The kernel built from its sources into the tree its symbols pick, when stale
export def build-kernel [dir: path, names: list<string>]: nothing -> nothing {
    let c = (context $dir "kernel" $names)
    let m = $c.manifest
    let includes = ($m | get -o includes | default [])
    let include_flags = ($includes | each {|i| ["-I" $i] } | flatten)
    let set_flags = (defsyms $names)
    let flags = (($include_flags ++ $set_flags ++ [$march_kernel $c.prefix]) | str join " ")
    let elf = ($c.out | path join "jab.elf")
    let stamp = ($c.out | path join "flags")
    cd $c.here
    let inputs = ((walk files (["src"] ++ $includes)) ++ [$c.manifest_path $m.link])
    let id = (stamp id $flags $inputs)
    if not (stamp stale $elf $inputs $id $stamp) { return }
    mkdir $c.out
    let asm = ($c.prefix + "as")
    let ld = ($c.prefix + "ld")
    let objdump = ($c.prefix + "objdump")
    toolchain march-check $asm $march_kernel $c.out
    let objects = (walk paths ("src" | path join "*.S") | sort | each {|f|
        let obj = ($c.out | path join (($f | path parse | get stem) + ".o"))
        ^$asm $march_kernel ...$include_flags ...$set_flags $f -o $obj
        $obj
    })
    for stray in (walk paths ($c.out | path join "*.o") | where {|o| $o not-in $objects }) { target retire $stray $c.root }
    ^$ld -T $m.link -nostdlib ...$objects -o $elf
    ^$objdump -d $elf | save -f ($c.out | path join "jab.disas")
    $id | save -f $stamp
}

# The spec data a program listing specs builds from, inputs of its build
def spec-inputs [c: record]: nothing -> list<string> {
    if ($c.manifest | get -o specs) == null { return [] }
    if $c.workspace == null { error make {msg: $"($c.manifest.name) lists specs and has no workspace, whose asset/spec.nuon defines them"} }
    let asset = ($c.workspace | path join "asset")
    let files = [($asset | path join "spec.nuon") ($asset | path join "spec.nutype")]
    let missing = ($files | where {|f| not ($f | path exists) })
    if not ($missing | is-empty) { error make {msg: $"($c.manifest.name) lists specs, and its workspace has no ($missing | str join ' or ')"} }
    $files
}

# A program's image built when stale, with its first page, demand, and home
export def build-program [dir: path, names: list<string>]: nothing -> nothing {
    let c = (context $dir "program" $names)
    let m = $c.manifest
    let specs = (spec-inputs $c)
    let demand = (demand program-demand $m $c.workspace)
    let declaration = (demand image-declaration $demand $c.workspace $m.name)
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
    let constants = (if $demand == null { [] } else { [(demand demand-include $demand $c.out)] })
    let header = (demand header-source $declaration $c.out)
    cd $c.here
    let inputs = ((walk files (["src"] ++ $includes)) ++ [$c.manifest_path $m.link] ++ $specs ++ $constants ++ [$header])
    let id = (stamp id $flags $inputs)
    if (not (stamp stale $image $inputs $id $stamp)) and (demand record-holds $image $demand) { return }
    mkdir $c.out
    if $demand == null { target retire ($c.out | path join "jab_manifest.inc") $c.root }
    let asm = ($c.prefix + "as")
    let ld = ($c.prefix + "ld")
    let objcopy = ($c.prefix + "objcopy")
    toolchain march-check $asm $march_program $c.out
    let obj = ($c.out | path join $"($m.name).o")
    let header_obj = ($c.out | path join "jab_header.o")
    let elf = ($c.out | path join $"($m.name).elf")
    ^$asm $march_program $header -o $header_obj
    ^$asm $march_program ...$include_flags ...$set_flags src/main.S -o $obj
    ^$ld -T $m.link -nostdlib $header_obj $obj -o $elf
    ^$objcopy -O binary $elf $image
    { image: (open --raw $image | hash sha256), demand: $demand } | to nuon | save -f (demand demand-record-of $image)
    $id | save -f $stamp
}

# A program's prepare script run from its directory with the phase; none without
export def prepare [dir: path, phase: string]: nothing -> nothing {
    let here = ($dir | path expand)
    let script = (open ($here | path join "program.jab.toml") | get -o prepare | default "")
    if $script == "" { return }
    let r = (do { cd $here; ^nu ($here | path join $script) $phase } | complete)
    print -n $r.stdout
    if $r.exit_code != 0 { error make {msg: $"preparing ($here) to ($phase) failed:\n($r.stderr)"} }
}

# The kernel, then the programs at or under a path, each prepared first
def build-under [ws: path, words: list<string>, names: list<string>]: nothing -> nothing {
    let ws = ($ws | path expand)
    let m = (open ($ws | path join "workspace.jab.toml"))
    build-kernel ($ws | path join $m.kernel) $names
    for p in (workspace programs-under $ws $words) {
        let dir = ($ws | path join $p)
        prepare $dir "build"
        build-program $dir $names
    }
}

# The whole target retired, or the outputs of the programs at or under a path
export def clean [ws: path, ...words: string]: nothing -> nothing {
    if not (workspace is-workspace $ws) { error make {msg: $"($ws | path expand) is no workspace's root"} }
    let ws = ($ws | path expand)
    let at = ($words | enumerate | where item == "--tree" | get -o 0.index)
    let trees = (if $at == null { ["release" "debug"] } else { [($words | get -o ($at + 1) | default "")] })
    for t in $trees { if $t not-in ["release" "debug"] { error make {msg: $"--tree is release or debug, not ($t)"} } }
    let words = (if $at == null { $words } else { $words | enumerate | where {|e| $e.index != $at and $e.index != ($at + 1) } | get item })
    if ($words | is-empty) { target clean $ws; return }
    let target = (target root $ws)
    let stamp = (date now | format date "%Y%m%d-%H%M%S")
    let dirs = (if (workspace path-words $words) == "kernel" {
        let m = (open ($ws | path join "workspace.jab.toml"))
        $trees | each {|t| (context ($ws | path join $m.kernel) "kernel" (target tree-symbols $t)).out }
    } else {
        workspace programs-under $ws $words | each {|p| $trees | each {|t| program-out ($ws | path join $p) $t } } | flatten
    })
    mut retired = []
    for d in $dirs {
        if ($d | path type) != null {
            target retire $d $target --stamp $stamp
            $retired = ($retired | append $d)
        }
    }
    print (if ($retired | is-empty) { "jab: nothing built there to retire" } else { $"jab: retired ($retired | str join ', ') to ((target retire-home $target).tmp | path join 'retired' $stamp)" })
}

# The kernel and every program, or those at or under a path, or one program
export def main [dir: path, ...words: string, --kernel, --set: string = ""] {
    let names = (symbols $set)
    if (workspace is-workspace $dir) { build-under $dir $words $names; return }
    if $kernel { build-kernel $dir $names } else {
        prepare $dir "build"
        build-program $dir $names
    }
}

# Everything retired deleted, the workspace checked first
export def retire [ws: path] {
    if not (workspace is-workspace $ws) { error make {msg: $"($ws | path expand) is no workspace's root"} }
    target retire-all ($ws | path expand)
}
