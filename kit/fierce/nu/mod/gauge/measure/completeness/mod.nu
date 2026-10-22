use (path self ../../identity) [SCHEMAS]

# What keeps a window from complete, from the records before its marker
export def window-problems [s: record, schema: oneof<int, nothing>]: nothing -> list<string> {
    mut problems = []
    if $s.end == null {
        $problems = ($problems | append "no end marker: the measurement never closed")
    }
    if $schema not-in $SCHEMAS {
        $problems = ($problems | append $"the clock records at schema ($schema), this reader's being ($SCHEMAS | str join ', ')")
    }
    let last = (if $s.end == null { ($s.frames | length) - 1 } else { $s.end.frame })
    let at = ($schema | default 1)
    let records = ([[name items]; [frame $s.frames] [draw $s.draws]]
        | append (if $at >= 2 { [[name items]; [presentation $s.presents]] } else { [] })
        | append (if $at >= 3 { [[name items]; [packet $s.packets]] } else { [] })
        | append (if $at >= 5 { [[name items]; [tile $s.tiles] [storage $s.storages]] } else { [] })
        | append (if $at >= 6 { [[name items]; [harts $s.harts]] } else { [] })
        | append (if $at >= 7 { [[name items]; [receipt $s.receipts]] } else { [] })
        | append (if ($s.services | is-empty) { [] } else { [[name items]; [service $s.services]] }))
    for kind in $records {
        let order = ($kind.items | enumerate | where {|e| $e.item.frame != $e.index } | length)
        if $order > 0 { $problems = ($problems | append $"($order) ($kind.name) records out of order or repeated") }
        if ($kind.items | length) != ($last + 1) { $problems = ($problems | append $"($kind.items | length) ($kind.name) records before the end marker for ($last + 1) frames") }
    }
    if ($s.states | length) != ($last + 1) { $problems = ($problems | append $"($s.states | length) state records before the end marker for ($last + 1) frames") }
    if $at >= 5 {
        let froms = ($s.configs | each {|c| $c.from })
        let first = (if ($froms | is-empty) { null } else { $froms | math min })
        if $first == null or $first > 0 { $problems = ($problems | append $"frames before any configuration of the tile pool: the first from frame ($first | default 'none')") }
        let arriving = ($s.configs | where {|c| $c.arrival_states != $c.from or $c.arrival_frames != $c.from })
        if ($arriving | is-not-empty) {
            let named = ($arriving | each {|c| $"from ($c.from) after ($c.arrival_states) state and ($c.arrival_frames) frame records" } | str join "; ")
            $problems = ($problems | append $"($arriving | length) configurations of the tile pool arriving other than at the first frame they govern: ($named)")
        }
    }
    if $at >= 7 {
        let before = ($s.loads | where arrival_states == 0)
        if ($s.loads | is-empty) { $problems = ($problems | append "no load record: the load's presents and the nonce never came") }
        if ($s.loads | length) > 1 { $problems = ($problems | append $"($s.loads | length) load records, where the program writes one") }
        if ($before | length) != ($s.loads | length) { $problems = ($problems | append "a load record after the first state, where the program writes it before") }
    }
    if $at >= 8 {
        if ($s.bounds | is-empty) { $problems = ($problems | append "no bounds record: the load's calls' bounds never came") }
        if ($s.bounds | length) > 1 { $problems = ($problems | append $"($s.bounds | length) bounds records, where the program writes one") }
        if ($s.bounds | any {|b| $b.arrival_states != 0 }) { $problems = ($problems | append "a bounds record after the first state, where the program writes it before") }
        if ($s.bounds | any {|b| $b.arrival_loads == 0 }) { $problems = ($problems | append "a bounds record before the load record, where the program writes it after") }
    } else if ($s.bounds | is-not-empty) {
        $problems = ($problems | append $"a bounds record in a capture at schema ($schema), which carries none")
    }
    let marker = (if $s.end == null { [] } else { [$s.end.schema] })
    let others = ($s.frames | append $s.draws | append $s.presents | append $s.packets | append $s.tiles | append $s.storages | append $s.configs | append $s.harts | append $s.receipts | append $s.loads | append $s.bounds | each {|r| $r.schema } | append $marker | uniq | where {|v| $v != $schema })
    if not ($others | is-empty) { $problems = ($problems | append $"clock records at schemas ($others | str join ', ') in a capture at schema ($schema)") }
    $problems
}
