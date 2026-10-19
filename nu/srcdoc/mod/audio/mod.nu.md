# audio

## sound-args

The sound device over a host backend: `backend` is an -audiodev
driver name with any of its own options after it (`pipewire`,
`coreaudio`, `none`, `wav,path=...`), and the backend runs at the
kernel's one rate so nothing resamples between them. The device
carries `streams`, playback and capture by default; a launch's wav
recorder has no capture voice and QEMU says so on its stderr for a
device that asks for one, so a launch gives the device playback
alone, the one stream the kernel drives.

## audio-plan

The host's audio backend for a run, from jabdisco's audio record:
JAB_AUDIO as given is the backend and its options verbatim; no
output found is `none`, which discards, so a program's sound calls
still answer; an output found goes to the backend that reaches it,
the device named: on Linux ALSA's `default`, which is the sound
server's default sink, the one the record names, through the server's
ALSA plugin (the pipewire backend dropped the start of a stream and
the pa backend errored on volume and cut off, both measured on the
reference host); on macOS coreaudio and on Windows dsound, whose
default is the system's chosen output, the one the record names.
