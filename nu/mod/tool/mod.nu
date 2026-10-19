use (path self ../host)
use (path self ../target)

# The jabdisco binary, built as a package of the tool workspace
export def disco-build [ws: path]: nothing -> string {
    tool-build $ws "jabdisco" "JAB_PAD names a pad's evdev path outright and --no-pad leaves the pad off; JAB_AUDIO names the audio backend outright and --no-sound leaves the sound device off"
}

# The robojab binary, the play harness, built as a package of the tool workspace
export def robojab [ws: path]: nothing -> string {
    tool-build $ws "robojab" "the harness needs it"
}

# The jabpair binary, the pairing's bracket, built in the tool workspace
export def pair [ws: path]: nothing -> string {
    tool-build $ws "jabpair" "a pairing's bracket needs it"
}

# A tool workspace package's binary, cargo building it on first use and change
def tool-build [ws: path, package: string, without: string]: nothing -> string {
    let tool = ($ws | path join "tool")
    let manifest = ($tool | path join "Cargo.toml")
    if not ($manifest | path exists) { error make {msg: $"no tool workspace in this one at ($tool); ($without)"} }
    let built = (^cargo build --release --quiet --manifest-path $manifest -p $package | complete)
    if $built.exit_code != 0 { error make {msg: $"building ($package) failed:\n($built.stderr)"} }
    $tool | path join "target" "release" $package
}

# A shim built into the target's shim/: its library, or its binary with --bin
export def shim [ws: path, name: string, --bin, --static]: nothing -> string {
    let manifest = ($ws | path join "shim" "Cargo.toml")
    let target = (target root $ws | path join "shim")
    let built = (if $static {
        ^cargo rustc --release --quiet --manifest-path $manifest -p $name --bin $name --target-dir $target -- -C relocation-model=static | complete
    } else {
        ^cargo build --release --quiet --manifest-path $manifest -p $name --target-dir $target | complete
    })
    if $built.exit_code != 0 { error make {msg: $"building the shim package ($name) failed:\n($built.stderr)"} }
    if $bin or $static { $target | path join "release" (host exe-name $name) } else { $target | path join "release" $"lib($name).so" }
}
