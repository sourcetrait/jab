# A refusal's message: each fault, how many of its unit hold it, examples
export def sdl-refusal [faults: table<fault: string, held: int, unit: string, examples: list<string>>]: nothing -> string {
    let parts = ($faults | each {|f|
        let plural = (if $f.held == 1 { "" } else { "s" })
        let shown = (if ($f.examples | is-empty) { "" } else { ", among them " + ($f.examples | first 4 | str join ", ") })
        $"($f.fault): ($f.held) ($f.unit)($plural)($shown)"
    })
    $"the sdl probe refuses the log: ($parts | str join '; ')"
}
