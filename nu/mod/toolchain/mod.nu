use (path self ../host)

# The riscv64 binutils prefixes: the official triple, then the packaged ones
const triples = [
    "riscv64-unknown-linux-gnu-" "riscv64-linux-gnu-"
    "riscv64-unknown-elf-" "riscv64-elf-"
]

# The toolchain's install directory, or null for the tools on PATH
export def main [here: path, workspace: oneof<string, nothing>]: nothing -> oneof<string, nothing> {
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

# The tools' command prefix, the first triple whose `as` is found
export def tool-prefix [toolchain: oneof<string, nothing>] {
    let looked = ($triples | each {|t| host exe-name ($t + "as") } | str join ", ")
    if $toolchain != null {
        let bin = ($toolchain | path join "bin")
        for t in $triples {
            let prefix = ($bin | path join $t)
            if (host exe-name ($prefix + "as") | path exists) { return $prefix }
        }
        error make {msg: $"no riscv64 binutils under ($bin): looked for ($looked)"}
    }
    for t in $triples {
        if not (which ($t + "as") | is-empty) { return $t }
    }
    error make {msg: $"no riscv64 binutils on PATH: looked for ($looked); set RISCV_TOOLCHAIN or link extern/riscv to a toolchain"}
}

# Refuses an assembler that takes no RVA23 profile, naming its version
export def march-check [asm: string, march: string, dir: path] {
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
