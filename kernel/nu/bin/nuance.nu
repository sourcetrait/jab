#!/usr/bin/env nu
# The kernel's font module's path, bound at parse time
const FONT = path self ../mod/font
use $FONT

# The kernel's console font regenerated into src/font.S from a Spleen 12x24 BDF
def "main font" [bdf: path] {
    font $bdf
}

def main [] { help main }
