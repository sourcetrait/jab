use ../../../../../../nu/mod/walk
use ../../picture
use std/assert

# The peak sample under which a recording is silence, of 32767
const SOUND_SILENCE = 8

# The peak a window must reach to be heard, its mean an eighth of it
const SOUND_HEARD = 64

# Render One's sounds: one ambient, every recipe, the MIDI hum, the servo
export def assets [context: record, records: record]: nothing -> record {
    let render_1_expected = $records."render_one poses".render_1_expected
    let game = $context.game
    let render_1_tree = $context.render_1.tree
    assert equal $render_1_expected.ambients 1 "render_1 names one ambient"
    let recipes = (walk paths ($game | path join "content" "sound" "*.nuon") | length)
    assert equal $render_1_expected.sounds $recipes $"render_1's tree carries every sound the content holds: ($render_1_expected.sounds) against ($recipes) recipes"
    let hum = (open --raw ($render_1_tree | path join "ambient" "hum.mid") | into binary)
    assert equal ($hum | bytes at 0..<4) ("MThd" | into binary) "the hum is a Standard MIDI File"
    assert equal ($hum | bytes at 8..<10 | into int --endian big) 0 "the hum is format 0"
    assert equal ($hum | bytes at 10..<12 | into int --endian big) 1 "the hum holds one track"
    let servo_recipe = (open ($game | path join "content" "sound" "servo.nuon"))
    let servo = (open --raw ($render_1_tree | path join "sound" "servo.pcm") | into binary)
    assert equal ($servo | bytes length) (((($servo_recipe.seconds | into float) * 48000) | math round | into int) * 2) "the servo is its seconds of 16-bit samples"
    {}
}

# The soundfont off the generic disk, the hum playing in the north room
export def soundfont [context: record, records: record]: nothing -> record {
    let render_1_lines = $records."render_one loaded".render_1_lines
    let render_1_run = $records."render_one launched".render_1_run
    let fonts = ($render_1_lines | where {|l| $l starts-with "fps: soundfont " })
    assert equal ($fonts | length) 1 $"the soundfont reported once on render_1: ($render_1_run.serial)"
    let font = ($fonts | get 0 | parse "fps: soundfont {presets} presets, {instruments} instruments, {samples} samples")
    assert (not ($font | is-empty)) $"the soundfont loaded off the generic disk: ($fonts | get 0)"
    assert (($font | get 0.presets | into int) > 0) $"the soundfont holds presets: ($fonts | get 0)"
    assert ("fps: ambient 0 playing" in $render_1_lines) $"the hum plays in the north room: ($render_1_lines | where {|l| $l starts-with 'fps: ambient' })"
    {}
}

# The hum heard: silent in the hall, sounding once in the north room
export def heard [context: record, records: record]: nothing -> record {
    let render_1_run = $records."render_one launched".render_1_run
    assert ($render_1_run.sound != "") "the render_1 run recorded its sound"
    let hall_level = (picture sound-level $render_1_run.sound 0.3 1.4)
    let room_level = (picture sound-level $render_1_run.sound 3.5 5.4)
    assert ($hall_level.peak < $SOUND_SILENCE) $"the hall is silent, having no ambient: ($hall_level)"
    assert ($room_level.peak >= $SOUND_HEARD and $room_level.mean >= ($SOUND_HEARD / 8)) $"the hum is heard in the north room: ($room_level) against silence ($hall_level)"
    {}
}
