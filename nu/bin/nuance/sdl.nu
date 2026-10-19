#!/usr/bin/env nu
# The SDK's sdl module's path, bound at parse time
const SDL = path self ../../mod/sdl
use $SDL

# A probe directory's run bundled into a new directory, its extra files named
def "main bundle" [probe: path, bundle: path, ...extra: string, --profile: string = ""] {
    sdl bundle $probe $bundle --profile $profile --extra $extra
}

# A bundle held to its manifest stage by stage; a paired one wants its guest
def "main bundle-check" [bundle: path] {
    sdl bundle-check $bundle
}

# A shim log's report: its flips, renders, and their callers as one record
def "main report" [log: path] {
    sdl report $log
}

def main [] { help main }
