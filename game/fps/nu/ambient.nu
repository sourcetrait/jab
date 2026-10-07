# ambient.nu: an ambient piece from a note list. `nu ambient.nu render
# <list.nuon> <out.mid>` writes a Standard MIDI File, format 0, from a
# NUON of tracks and notes in seconds and General MIDI numbers, the
# tree's `ambient/<name>.mid` the engine plays by sector; `to-midi` is
# the encoder for a caller of its own. The file's beat is a second at
# DIVISION ticks, so a note at 1.5 seconds sits at tick 720.

const division = 480
const microseconds_a_beat = 1000000

# Ambient: a piece as a note list. A track is a channel with its
# General MIDI program and volume, channel 9 the drum kit; a note
# starts at `at` seconds and sounds for `length` seconds at a velocity.
# The piece's `gain`, 1 when absent, scales every volume and velocity
# as rendered, each capped at 127, so a piece authored soft plays up.
# record<
#     gain: float,
#     tracks: table<
#         channel: int,
#         program: int,
#         volume: int,
#         notes: table<at: float, note: int, velocity: int, length: float>,
#     >,
# >

def main [] {
    print "ambient.nu render <list.nuon> <out.mid>"
}

# The list rendered to the file; a line with the counts.
def "main render" [list: path, out: path] {
    let piece = (open $list)
    to-midi $piece | save --raw -f $out
    let notes = ($piece.tracks | each {|t| $t.notes | length } | math sum)
    print $"ambient: ($list) -> ($out): ($piece.tracks | length) tracks, ($notes) notes, (length-of $piece) s"
}

# The piece's length in seconds, its last note's end.
export def length-of [piece: record]: nothing -> float {
    $piece.tracks | each {|t| $t.notes | each {|n| $n.at + $n.length } } | flatten | math max
}

# The piece as a Standard MIDI File, format 0: one track holding every
# track's program, volume, and notes merged in time order, a note's off
# before another's on at the same tick, the tempo a second a beat.
export def to-midi [piece: record]: nothing -> binary {
    let gain = ($piece.gain? | default 1.0 | into float)
    mut events = []
    for t in $piece.tracks {
        let ch = ($t.channel bit-and 15)
        $events = ($events | append { tick: 0, order: 0, bytes: ([(byte (0xC0 bit-or $ch)), (byte ($t.program bit-and 127))] | bytes collect) })
        $events = ($events | append { tick: 0, order: 0, bytes: ([(byte (0xB0 bit-or $ch)), 0x[07], (byte (gained $t.volume $gain))] | bytes collect) })
        for n in $t.notes {
            let on = ((($n.at | into float) * $division) | math round | into int)
            let off = (((($n.at | into float) + ($n.length | into float)) * $division) | math round | into int)
            $events = ($events | append { tick: $on, order: 2, bytes: ([(byte (0x90 bit-or $ch)), (byte ($n.note bit-and 127)), (byte (gained $n.velocity $gain))] | bytes collect) })
            $events = ($events | append { tick: $off, order: 1, bytes: ([(byte (0x80 bit-or $ch)), (byte ($n.note bit-and 127)), 0x[40]] | bytes collect) })
        }
    }
    let sorted = ($events | sort-by tick order)
    mut track = ([(vlq 0), 0x[FF 51 03], (be24 $microseconds_a_beat)] | bytes collect)
    mut last = 0
    for e in $sorted {
        $track = ([$track, (vlq ($e.tick - $last)), $e.bytes] | bytes collect)
        $last = $e.tick
    }
    $track = ([$track, (vlq 0), 0x[FF 2F 00]] | bytes collect)
    [0x[4D 54 68 64], (be32 6), (be16 0), (be16 1), (be16 $division), 0x[4D 54 72 6B], (be32 ($track | bytes length)), $track] | bytes collect
}

# A volume or velocity scaled by the piece's gain and capped at 127.
def gained [v: int, gain: float]: nothing -> int {
    [((($v | into float) * $gain) | math round | into int), 127] | math min
}

# A MIDI variable-length quantity, seven bits a byte, high bit set on
# every byte but the last.
def vlq [v: int]: nothing -> binary {
    mut bytes = [($v bit-and 127)]
    mut rest = ($v bit-shr 7)
    while $rest > 0 {
        $bytes = ([(($rest bit-and 127) bit-or 128)] ++ $bytes)
        $rest = ($rest bit-shr 7)
    }
    $bytes | each {|b| byte $b } | bytes collect
}

def byte [v: int]: nothing -> binary { $v | into binary --endian little | bytes at 0..<1 }
def be16 [v: int]: nothing -> binary { $v | into binary --endian big | bytes at 6..<8 }
def be24 [v: int]: nothing -> binary { $v | into binary --endian big | bytes at 5..<8 }
def be32 [v: int]: nothing -> binary { $v | into binary --endian big | bytes at 4..<8 }
