# pad's integration test, through a played gamepad and the API: the
# host pushes the left stick full right for most of a second, centres
# it, presses THUMBR, then East, then pushes the right stick full
# right, sending the events into a gamepad played from table.nuon, and
# reads back the records. The drive vector is reported as the left
# stick goes over and comes back and as the right stick's high third
# takes hold at twice ACCEL, your sphere's velocity grows while the
# left stick is held and falls after, THUMBR stops it, East
# reports its colour, the right stick's position paints the sphere the
# colour its position makes and the screen shows it, East's name sits
# centred in the strip at the top, the ball's first velocity is
# bounce's, every wall hit's contact point lies on a screen edge, a
# meeting is reported for both spheres at one point, and the screen
# agrees: your sphere has moved right. The pad is played both ways the
# kernel takes one on Linux, as a device through the evdev shim and
# over the pad port, and over the port alone on macOS; on any other
# host, where no gamepad can be played, D is held through the API
# instead, wasd's own test, and neither the stop nor the colours are
# asked for.
use ../../../sdk/nu/jab.nu
use std/assert

# The API's records, as example/pad/src/main.S lays them out
const CMD_SIZE = 4
const REPORT_SIZE = 12
const REPORT_VELOCITY = 1
const REPORT_ACCELERATION = 2
const REPORT_HIT = 3
const REPORT_COLOR = 4
const SPHERE_PLAYER = 1
const SPHERE_BALL = 2
const AGAINST_WALL = 0
# The program's numbers: 8 fractional bits, speeds in pixels a second,
# the push ACCEL in pixels a second squared, the ball's speed bounce's
const ONE = 256
const ACCEL = 184320
const TOP_SPEED = 199680
const BALL_VX = 53760
const BALL_VY = 38400
# A stop is a jump to zero from at least this, more than a frame's
# drag at any cap of thirty or above, so a sphere that slowed to a
# stop on its own is not mistaken for a stopped one
const STOP_LEAST = 8192
# Where a contact point lies on a wall: a centre at LEFT or TOP less a
# radius is 0, at RIGHT or BOTTOM plus a radius the last pixel
const WALL_LEFT = 0
const WALL_RIGHT = 491264
const WALL_TOP = 0
const WALL_BOTTOM = 276224
# Linux's codes, as sdk/jab_keys.inc
const KEY_D = 32
const PRESSED = 1
const RELEASED = 0
# evdev's East, as sdk/jab_pad.inc, and the least any channel of a
# button's colour can be
const BTN_EAST = 305
const COLOR_FLOOR = 64
# The label's off-white and its strip, as example/pad/src/main.S sets
# them: y 16, a cell 18 wide and 36 high at the label's scale
const LABEL_COLOR = "ebe6dc"
const LABEL_Y = 16
const LABEL_CELL = 18
const LABEL_HEIGHT = 36
# The right stick full right: red full, green half, blue full, and the
# high third's strength, twice ACCEL
const STICK_COLOR = "ff7fff"
const ACCEL_MAX = 368640

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let routes = (match $nu.os-info.name { "linux" => ["device" "port"], "macos" => ["port"], _ => ["keys"] })
    for route in $routes {
        exercise $route $kernel $image $out $set
    }
    print "pad: ok"
}

# One run with the pad played over `route`, `device` or `port`, or
# with D held over the API for `keys`, and every assertion on it.
def exercise [route: string, kernel: path, image: path, out: path, set: string] {
    let played = ($route != "keys")
    let table = ($env.FILE_PWD | path join "table.nuon")
    let run = (match $route {
        "device" => { jab launch --kernel $kernel --image $image --out $out --set $set --api --pad $table --capture 3500ms },
        "port" => { jab launch --kernel $kernel --image $image --out $out --set $set --api --pad $table --pad-port --capture 3500ms },
        _ => {
            let hold = (key-event $KEY_D $PRESSED)
            let free = (key-event $KEY_D $RELEASED)
            jab launch --kernel $kernel --image $image --out $out --set $set --api --send [[at, bytes]; [1sec, $hold], [1800ms, $free]] --capture 3500ms
        },
    })
    print $"pad: status ($run.status) after ($run.wall_seconds | math round -p 2) seconds over the ($route), ($run.api | bytes length) bytes of records, ($run.debug | lines | length) kernel debug lines"
    assert equal $run.serial "" $"the UART stays silent: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    assert ($run.screen != "") "a screen was taken"
    if $played {
        let found = (if $route == "port" { "jab: pad on port" } else { "jab: pad at " })
        assert ($run.debug | str contains $found) $"the kernel found the pad over the ($route): ($run.debug)"
    }
    let reports = (records $run.api)
    assert (($reports | length) > 0) "pad reported over the API"
    assert equal (($run.api | bytes length) mod $REPORT_SIZE) 0 "whole records only"

    # the drive vector: the left stick over, then back, then the right
    # stick's high third
    let drive = ($reports | where kind == $REPORT_ACCELERATION and sphere == $SPHERE_PLAYER)
    let expected_drive = (if $played { [{x: $ACCEL, y: 0}, {x: 0, y: 0}, {x: $ACCEL_MAX, y: 0}] } else { [{x: $ACCEL, y: 0}, {x: 0, y: 0}] })
    assert equal ($drive | select x y) $expected_drive $"the drive vector as the pushes come and go: ($drive)"

    # your velocity: grows while pushed, never past the top speed, and
    # is smaller the frame after the push comes off than the frame
    # before, whichever way the ball may have sent it meanwhile; the
    # records are in order, so the drive record that zeroes the push
    # sits between those two velocities
    let mine = ($reports | where kind == $REPORT_VELOCITY and sphere == $SPHERE_PLAYER)
    assert (($mine | length) > 10) $"your velocity was reported frame by frame: ($mine | length)"
    let xs = ($mine | get x)
    let peak = ($xs | math max)
    assert ($peak > $ACCEL / 2 and $peak <= $TOP_SPEED) $"a peak speed from most of a second of push: ($peak)"
    let numbered = ($reports | enumerate)
    let off_at = ($numbered | where {|r| $r.item.kind == $REPORT_ACCELERATION and $r.item.sphere == $SPHERE_PLAYER and $r.item.x == 0 and $r.item.y == 0 } | first | get index)
    let before = ($numbered | where {|r| $r.index < $off_at and $r.item.kind == $REPORT_VELOCITY and $r.item.sphere == $SPHERE_PLAYER } | last | get item.x)
    let after = ($numbered | where {|r| $r.index > $off_at and $r.item.kind == $REPORT_VELOCITY and $r.item.sphere == $SPHERE_PLAYER } | first | get item.x)
    assert (($after | math abs) < ($before | math abs)) $"slowing once the push is off: ($after) after ($before)"
    if $played {
        # a stop is a jump to zero from more than one frame's slowing;
        # THUMBR comes a fifth of a second after the push is off, while
        # the sphere still moves however the ball has sent it
        let stopped = ($xs | window 2 | any {|w| (($w | first) | math abs) > $STOP_LEAST and ($w | last) == 0 })
        assert $stopped $"THUMBR stopped your sphere outright: ($xs)"
        # a wall or the ball may have turned it since, at a higher cap
        # within the same real time, so the sign is not the test
        assert (($xs | last) != 0) $"and the right stick set it going again: ($xs | last)"
    }

    # East's colour: reported once, every channel from the floor up
    let colors = ($reports | where kind == $REPORT_COLOR)
    let player_color = (if $played {
        assert equal ($colors | get y) [$BTN_EAST] $"East's press was reported as a colour, once: ($colors)"
        let c = ($colors | first | get x)
        for channel in [($c bit-shr 16), (($c bit-shr 8) bit-and 0xff), ($c bit-and 0xff)] {
            assert ($channel >= $COLOR_FLOOR and $channel <= 255) $"a channel of the colour is from the floor up: ($c)"
        }
        # then the right stick's position painted over it
        $STICK_COLOR
    } else {
        assert equal $colors [] "no colour without a pad"
        "ff5533"
    })

    # the ball: bounce's speed first, and every wall hit on an edge
    let ball = ($reports | where kind == $REPORT_VELOCITY and sphere == $SPHERE_BALL)
    assert equal ($ball | first | select x y) {x: $BALL_VX, y: $BALL_VY} "the ball starts at bounce's speed"
    let wall_hits = ($reports | where kind == $REPORT_HIT and against == $AGAINST_WALL)
    for h in $wall_hits {
        assert ($h.x == $WALL_LEFT or $h.x == $WALL_RIGHT or $h.y == $WALL_TOP or $h.y == $WALL_BOTTOM) $"a wall hit's contact point lies on an edge: ($h)"
    }

    # a meeting is one point reported for both spheres
    let meetings = ($reports | where kind == $REPORT_HIT and against != $AGAINST_WALL)
    let yours = ($meetings | where sphere == $SPHERE_PLAYER)
    let theirs = ($meetings | where sphere == $SPHERE_BALL)
    assert equal ($yours | select x y) ($theirs | select x y) "each meeting is reported for both spheres at the same point"

    # the screen agrees
    let screen = (jab screen $run.screen)
    let player = (jab ink $screen $player_color)
    assert ($player.count > 24900 and $player.count < 26000) $"your sphere, a disc of radius 90 in ($player_color), has about 25447 pixels, not ($player.count)"
    if $played {
        assert equal (jab ink $screen "ff5533" | get count) 0 "and none of its first colour is left"
        # East's name at the top of the screen, bold off-white at the
        # label's scale, four cells wide at most, centred in the strip
        let label = (jab ink $screen $LABEL_COLOR)
        assert ($label.count > 200) $"the button's name is on the screen: ($label.count) off-white pixels"
        assert ($label.top >= $LABEL_Y and $label.bottom < $LABEL_Y + $LABEL_HEIGHT) $"inside the label's strip: ($label)"
        assert (($label.right - $label.left + 1) <= 4 * $LABEL_CELL + 1) $"four cells wide at most: ($label)"
        let middle = (($label.left + $label.right) // 2)
        assert ($middle > 960 - $LABEL_CELL and $middle < 960 + $LABEL_CELL) $"and centred: ($label)"
    }
    let centre_x = (($player.left + $player.right) // 2)
    let centre_y = (($player.top + $player.bottom) // 2)
    if ($yours | is-empty) {
        assert ($centre_x > 1160) $"with no meeting, your sphere has moved right from the centre: ($centre_x)"
        assert ($centre_y >= 538 and $centre_y <= 542) $"with no meeting, your sphere stays level: ($centre_y)"
    } else {
        assert ($centre_x > 90 and $centre_x < 1830 and $centre_y > 90 and $centre_y < 990) $"after a meeting, your sphere is still whole on the screen: ($centre_x),($centre_y)"
    }
    let disc = (jab ink $screen "8f00ff")
    assert ($disc.count > 24900 and $disc.count < 26000) $"the other sphere is whole on the screen, since the two never overlap: ($disc.count) pixels"
    print $"pad: ($reports | length) records, yours at ($centre_x),($centre_y) in ($player_color) peaking at ($peak), ($wall_hits | length) wall hits, ($yours | length) meetings; QEMU used ($run.cpu_seconds) CPU seconds over ($run.wall_seconds | math round -p 2) seconds"
    assert ($run.cpu_seconds < ($run.wall_seconds * 0.5)) "the hart halts between frames"
}

# A key event as the port takes it: the code and the value, 16 bits
# each, little-endian.
def key-event [code: int, value: int]: nothing -> binary {
    ($code | into binary --endian little | bytes at 0..<2) ++ ($value | into binary --endian little | bytes at 0..<2)
}

# pad's reports, one record each.
def records [data: binary]: nothing -> table<kind: int, sphere: int, against: int, x: int, y: int> {
    let count = (($data | bytes length) // $REPORT_SIZE)
    0..<$count | each {|i|
        let r = ($data | bytes at ($i * $REPORT_SIZE)..<(($i + 1) * $REPORT_SIZE))
        {
            kind: ($r | bytes at 0..<1 | into int),
            sphere: ($r | bytes at 1..<2 | into int),
            against: ($r | bytes at 2..<3 | into int),
            x: ($r | bytes at 4..<8 | into int --endian little --signed),
            y: ($r | bytes at 8..<12 | into int --endian little --signed),
        }
    }
}
