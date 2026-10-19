use (path self ../../../../../../nu/mod/launch)
use (path self ../../picture)
use (path self ../../../../test/pose.nu)
use (path self ../../tree)
use std/assert
use (path self ../../frame) [CRACKS FRAME LOAD]
use (path self ../../tree) [FIXTURE_BACKDROP GROW_FAR GROW_MAP]

# The growth pose in the camera's room C
const GROW_POSE = { name: "grow", x: 3.7, y: 0.4, z: 1.6, yaw: 72, pitch: 0 }

# A point on the far room's far wall, read through its doorway
const GROW_POINT = [8.1, 13.0, 1.6]

# The flow's growth: the far room reached only through the grown rectangle
export def flow [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let grow_tree = $records."load title".grow_tree
    let grow_far = ((tree grow-source).sectors | enumerate | where {|s| $s.item.name == $GROW_FAR } | get 0.index)
    let grow_run = (launch --kernel $kernel --image $image --out ($out | path join "grow_run") --set $set --sound --api --disk (tree romfs $grow_tree ($out | path join "grow.romfs")) --serial "fps" --send [{ at: 1500ms, bytes: (pose pose-frame $GROW_POSE) }] --capture 2500ms --seconds 5)
    assert equal (open --raw $grow_run.qemu_log) "" "QEMU has no complaint about the guest on the growth run"
    let grow_lines = ($grow_run.serial | lines)
    let grow_loads = ($grow_lines | where {|l| $l starts-with $"fps: ($GROW_MAP) loaded" })
    assert equal ($grow_loads | length) 1 $"the growth map loaded once: ($grow_run.serial)"
    let grow_load = ($grow_loads | get 0 | parse $LOAD | get 0 | update cells {|c| if $c =~ '^\d+$' { $c | into int } else { $c } })
    assert equal $grow_load.missing 0 $"every material of the growth map in its tree: ($grow_loads | get 0)"
    let grow_frames = ($grow_lines | where {|l| $l starts-with "fps: frame in" } | each {|f| $f | parse $FRAME | get 0 | update cells {|c| $c | into int } })
    assert equal ($grow_frames | length) 2 $"the first frame and the growth pose's reported: ($grow_run.serial)"
    let grow_frame = ($grow_frames | last)
    assert ($grow_frame.uncovered < $CRACKS) $"no pixel uncovered on the growth view: ($grow_frame)"
    let grow_sectors = ($grow_lines | where {|l| $l starts-with "fps: sectors " } | last | str substring 13.. | str trim | split row " " | each {|s| $s | into int })
    assert ($grow_far in $grow_sectors) $"the far room reached through the hall's grown rectangle: ($grow_sectors)"
    assert ($grow_run.screen != "") "a screen was taken on the growth run"
    let grow_at = (picture project { x: $GROW_POSE.x, y: $GROW_POSE.y, z: $GROW_POSE.z } $GROW_POSE.yaw $GROW_POINT)
    assert ($grow_at != null) "the far wall's point is on screen"
    assert equal (picture pixel $grow_run.screen $grow_at) $FIXTURE_BACKDROP.colour $"the far room's wall at ($grow_at), seen only through the grown rectangle, reads the backdrop: ($grow_run.screen)"
    {grow_frame: $grow_frame, grow_sectors: $grow_sectors, grow_at: $grow_at}
}
