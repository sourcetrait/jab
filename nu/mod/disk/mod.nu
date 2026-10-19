use (path self ../stamp)
use (path self ../target)
use (path self ../walk)

# QEMU's arguments for raw images as PCI virtio-blk disks, in the order given
export def disks-args [disks: table<id: string, file: string, serial: string, readonly: bool>]: nothing -> list<string> {
    $disks | each {|d| [
        "-drive" $"if=none,id=($d.id),file=($d.file | path expand),format=raw(if $d.readonly { ',readonly=on' } else { '' })"
        "-device" $"virtio-blk-pci,disable-legacy=on,vectors=0,drive=($d.id),serial=($d.serial)"
    ] } | flatten
}

# A machine's disks: the program's own first, then the generic assets disk
export def machine-disks [own: string, own_serial: string, own_readonly: bool, ws: oneof<string, nothing>]: nothing -> table<id: string, file: string, serial: string, readonly: bool> {
    let first = (if ($own | is-empty) { [] } else { [{ id: "disk0", file: $own, serial: $own_serial, readonly: $own_readonly }] })
    let mix = (mix-image $ws)
    let second = (if $mix == "" { [] } else { [{ id: "mix", file: $mix, serial: "mix", readonly: true }] })
    $first ++ $second
}

# The generic assets disk, built when generic/ or its manifest changes; "" none
def mix-image [ws: oneof<string, nothing>]: nothing -> string {
    if $ws == null { return "" }
    let generic = ($ws | path join "generic")
    if not ($generic | path exists) { return "" }
    let target = (target root $ws)
    let image = ($target | path join "mix.romfs")
    let stamp = ($target | path join "mix.flags")
    let manifest_path = ($generic | path join "manifest.nuon")
    let manifest = (if ($manifest_path | path exists) { open $manifest_path } else { [] })
    let inputs = (walk tree [$generic])
    let flags = (stamp id ($manifest | to nuon) $inputs)
    if ($image | path exists) and (not (stamp stale $image $inputs $flags $stamp)) { return $image }
    let stage = ($target | path join "generic")
    target retire $stage $target
    mkdir $stage
    for f in (walk files [$generic]) {
        let relative = ($f | path relative-to $generic)
        if $relative == "manifest.nuon" { continue }
        let dest = ($stage | path join $relative)
        mkdir ($dest | path dirname)
        cp $f $dest
    }
    for entry in $manifest {
        let archive = (fetched $target $entry.url $entry.sha256)
        let unpack = ($target | path join "fetch" "unpack")
        target retire $unpack $target
        mkdir $unpack
        ^tar -xzf $archive -C $unpack ...($entry.members | get from)
        for m in $entry.members {
            let dest = ($stage | path join $m.to)
            mkdir ($dest | path dirname)
            mv ($unpack | path join $m.from) $dest
        }
        target retire $unpack $target
    }
    assets-names $stage
    ^genromfs -d $stage -f $image -V (volume-name "mix")
    $flags | save -f $stamp
    $image
}

# An archive the manifest names, fetched once and verified by its sha256
def fetched [target: path, url: string, sha256: string]: nothing -> string {
    let dir = ($target | path join "fetch")
    mkdir $dir
    let file = ($dir | path join ($url | path basename))
    if not ($file | path exists) {
        http get --raw $url | save --raw -f $file
    }
    let digest = (open --raw $file | hash sha256)
    if $digest != $sha256 { error make {msg: $"($file): sha256 ($digest), where the manifest says ($sha256)"} }
    $file
}

# A program's assets as a romfs image, built when its tree has moved on
export def assets-image [c: record]: nothing -> string {
    let declared = ($c.manifest | get -o assets | default "")
    let compiled = ($c.manifest | get -o target_assets | default "")
    if $declared == "" and $compiled == "" { return "" }
    if $declared != "" and $compiled != "" { error make {msg: $"($c.manifest.name): assets and target_assets together; a program's disk is one or the other"} }
    let dir = (if $compiled != "" { target shard-dir $c "asset" | path join $compiled } else { $c.here | path join $declared | path expand })
    if not ($dir | path exists) {
        let named = (if $compiled != "" { $"target_assets = '($compiled)'" } else { $"assets = '($declared)'" })
        error make {msg: $"($c.manifest.name): ($named) names no directory at ($dir)"}
    }
    assets-names $dir
    let image = ($c.out | path join $"($c.manifest.name).romfs")
    let stamp = ($c.out | path join "assets.flags")
    let inputs = (walk tree [$dir])
    let id = (stamp id $c.manifest.name $inputs)
    if ($image | path exists) and (not (stamp stale $image $inputs $id $stamp)) { return $image }
    mkdir $c.out
    ^genromfs -d $dir -f $image -V (volume-name $c.manifest.name)
    $id | save -f $stamp
    $image
}

# Refuses a name under an assets tree past romfs's 127 bytes
def assets-names [dir: path]: nothing -> nothing {
    let long = (walk paths ($dir | path join "**" "*") | each {|p| $p | path basename } | where {|n| ($n | str length) > 127 })
    if not ($long | is-empty) {
        error make {msg: $"romfs names are 127 bytes at most, which is what a linux mount can read; too long: ($long | first)"}
    }
}

# A volume's name within romfs's 127 bytes, cut on a character
def volume-name [name: string]: nothing -> string { cut-bytes $name 127 }

# A disk's serial within virtio's 19 bytes, cut on a character
export def disk-serial [name: string]: nothing -> string { cut-bytes $name 19 }

# The longest prefix of a name within `limit` bytes that ends on a character
def cut-bytes [name: string, limit: int]: nothing -> string {
    mut out = ""
    for g in ($name | split chars --grapheme-clusters) {
        if (($out + $g) | str length) > $limit { break }
        $out = ($out + $g)
    }
    $out
}
