use (path self ../tool)

# Whether a run needs jabdisco's record, no override deciding pad or sound
export def discovery-wanted [pad: bool, sound: bool]: nothing -> bool {
    let pad_wanted = ($pad and ($env.JAB_PAD? | default "") == "" and ($nu.os-info.name in ["linux" "macos" "windows"]))
    let sound_wanted = ($sound and ($env.JAB_AUDIO? | default "") == "")
    $pad_wanted or $sound_wanted
}

# jabdisco's record: the expected gamepad and the audio output, each or null
export def discover [ws: oneof<string, nothing>]: nothing -> record {
    if $ws == null { return { gamepad: null, audio: null } }
    let disco = (tool disco-build $ws)
    let found = (^$disco | complete)
    if $found.exit_code != 0 { error make {msg: $"jabdisco failed:\n($found.stderr)"} }
    $found.stdout | from nuon
}
