# A present sequence's violations of the device's count, one a fault
export def ordinal-violations [anchor: int, frames: list<record<presented: bool, ordinal: int>>]: nothing -> list<record<index: int, rule: string, ordinal: int, wanted: int>> {
    mut last = $anchor
    mut found = []
    for f in ($frames | enumerate) {
        let got = $f.item.ordinal
        let wanted = (if $f.item.presented { $last + 1 } else { $last })
        if $got != $wanted {
            let rule = (if $got < $last { "backward" } else if not $f.item.presented { "advance" } else if $got == $last { "repeat" } else { "skip" })
            $found = ($found | append { index: $f.index, rule: $rule, ordinal: $got, wanted: $wanted })
        }
        $last = $got
    }
    $found
}

# The presentation contract K's violations over presented acceptances
export def k-violations [accepted: list<int>, period: int, eps: int]: nothing -> list<record<index: int, witness: int, gap: int, bound: int>> {
    mut found = []
    mut top = 0
    mut witness = -1
    for a in ($accepted | enumerate) {
        let q = ($a.item - $a.index * $period)
        if $witness >= 0 and $q <= ($top - $eps) {
            let before = ($accepted | get $witness)
            $found = ($found | append { index: $a.index, witness: $witness, gap: ($a.item - $before), bound: (($a.index - $witness) * $period - $eps) })
        }
        if $witness < 0 or $q > $top {
            $top = $q
            $witness = $a.index
        }
    }
    $found
}
