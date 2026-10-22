# Every kernel source file by its class (DecoderInventory): the drivers and
# the frame clock, the decoders, and hart 0's storage, written by hart 0's
# calls or at boot, forbidden to a worker's paths, routines and data; the
# drain, the worker machinery, and the shared lock reachable, their state
# their own; and the files the objects hold to no mutable storage
export const classes = [
    [class, files];
    [driver, [display keyboard pad sound synth smf soundfont block romfs serial random pci timer]]
    [decoder, [png deflate gz tar sha3 xxh3 sprite]]
    [hart0, [start page ram owners]]
    [drain, [aia]]
    [machinery, [workers harts]]
    [lock, [uart]]
    [stateless, [boot dtb font kernel trap virtio virtio_pci]]
]
export const forbidden_classes = [driver decoder hart0]
const storage_sections = [".data" ".bss" ".sdata" ".sbss"]

# A file's class, or none
export def class-of [file: string]: nothing -> string {
    $classes | where {|c| $file in $c.files } | get -o 0.class | default ""
}

# The inventory against the objects: every object's file in one class,
# every classified file linked, and the stateless holding no mutable
# storage
export def inventory-problems [objects: list<any>]: nothing -> list<string> {
    let named = ($classes | each {|c| $c.files } | flatten)
    let linked = ($objects | get file)
    let twice = ($named | uniq --count | where count > 1 | get value | each {|f| $"($f).S is in more than one class" })
    let unclassified = ($linked | where {|f| $f not-in $named } | each {|f| $"($f).S is in no class, and a new file is placed on purpose" })
    let unlinked = ($named | where {|f| $f not-in $linked } | each {|f| $"($f).S is classified and not linked" })
    let stateless = ($classes | where class == "stateless" | get 0.files)
    let holding = ($objects | where {|o| $o.file in $stateless } | each {|o|
        let held = ($o.sections | where {|s| $s.name in $storage_sections and $s.size > 0 })
        if ($held | is-empty) { null } else { $"($o.file).S is classed stateless and holds ($held | each {|s| $'($s.size) bytes of ($s.name)' } | str join ', ')" }
    } | compact)
    $twice ++ $unclassified ++ $unlinked ++ $holding
}
