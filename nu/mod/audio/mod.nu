use (path self ../disco)

# The sound device over a host backend at the kernel's one rate
export def sound-args [backend: string, --streams: int = 2]: nothing -> list<string> {
    ["-audiodev" $"($backend),id=snd0,out.frequency=48000" "-device" $"virtio-sound-device,audiodev=snd0,streams=($streams)"]
}

# A run's audio backend from discovery's record, JAB_AUDIO first
export def audio-plan [found: oneof<record, nothing>]: nothing -> string {
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

# The audio backend a live run on this host plays through, none with no output
export def live-backend [ws: oneof<string, nothing>]: nothing -> string {
    let found = (if (disco discovery-wanted false true) { disco discover $ws | get audio } else { null })
    audio-plan $found
}
